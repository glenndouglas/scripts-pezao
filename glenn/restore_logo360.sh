#!/bin/bash
set -e  # Encerra imediatamente se algum comando falhar

# Verifica se está em ambiente CLI
if ! php -v | grep -q cli; then
  echo "❌ Este script deve ser executado via linha de comando (CLI)."
  exit 1
fi

############################################################
#       RESTORE ROBUSTO WORDPRESS - SITE: logo360          #
# Validação de integridade, logs, Telegram e wp-config     #
############################################################

# === CONFIGURAÇÕES ========================================

SITE_PATH="/home2/futeb379/public_html/logo360"
WP="/usr/local/bin/wp"
NOME_SITE="logo360"
PASTA_BASE_BACKUPS="/home2/futeb379/bkps_diarios"
TOKEN="1946983588:AAHiKhTJVpotgrH2F27i5FyEo85SngclTTU"
CHAT_ID="804554535"

DATA_RESTORE=$(date +%d-%m-%Y-%Hh%M)
LOG_RESTORE="$PASTA_BASE_BACKUPS/$NOME_SITE/restore-${NOME_SITE}-$DATA_RESTORE.log"

# === TELEGRAM =============================================

telegram() {
  curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" -d text="$1" > /dev/null || echo "Erro ao enviar para Telegram." | tee -a "$LOG_RESTORE"
}

# === FUNÇÃO ERRO FATAL ====================================

erro_fatal() {
  local mensagem="$1"
  echo "❌ ERRO FATAL: $mensagem" | tee -a "$LOG_RESTORE"
  telegram "❌ ERRO FATAL na restauração de *$NOME_SITE*: $mensagem. Abortando."
  exit 1
}

# === INÍCIO ===============================================

echo -e "\n========== INÍCIO RESTAURAÇÃO $NOME_SITE ==========\n" | tee -a "$LOG_RESTORE"
telegram "🔴 Iniciando RESTAURAÇÃO de *$NOME_SITE*."

echo "Procurando backups em: $PASTA_BASE_BACKUPS/$NOME_SITE" | tee -a "$LOG_RESTORE"
BACKUP_DIRS=()
while IFS= read -r -d '' dir; do
  BACKUP_DIRS+=("$dir")
done < <(find "$PASTA_BASE_BACKUPS/$NOME_SITE" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

[ ${#BACKUP_DIRS[@]} -eq 0 ] && erro_fatal "Nenhum backup encontrado."

echo "Backups disponíveis:" | tee -a "$LOG_RESTORE"
for i in "${!BACKUP_DIRS[@]}"; do
  echo "  $((i+1)). $(basename "${BACKUP_DIRS[$i]}")" | tee -a "$LOG_RESTORE"
done

echo "" | tee -a "$LOG_RESTORE"
read -p "Digite o número do backup que deseja restaurar: " SELECTION

if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#BACKUP_DIRS[@]} ]; then
  erro_fatal "Seleção inválida."
fi

SELECTED_BACKUP_PATH="${BACKUP_DIRS[$((SELECTION-1))]}"
SELECTED_BACKUP_NAME=$(basename "$SELECTED_BACKUP_PATH")
ARQUIVO_BKP_RESTORE=$(compgen -G "$SELECTED_BACKUP_PATH/bkp-${NOME_SITE}-arquivos-*.tar.gz")
BANCO_BKP_RESTORE=$(compgen -G "$SELECTED_BACKUP_PATH/bkp-${NOME_SITE}-banco-*.sql.gz")

[ -z "$ARQUIVO_BKP_RESTORE" ] || [ -z "$BANCO_BKP_RESTORE" ] && erro_fatal "Arquivos de backup não encontrados."

echo "Backup selecionado: $SELECTED_BACKUP_NAME" | tee -a "$LOG_RESTORE"
echo "Arquivos: $ARQUIVO_BKP_RESTORE" | tee -a "$LOG_RESTORE"
echo "Banco: $BANCO_BKP_RESTORE" | tee -a "$LOG_RESTORE"

read -p "⚠️ Isso irá APAGAR o site atual. Deseja continuar? (s/N): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Ss]$ ]] && { echo "Cancelado."; telegram "❌ Restauração cancelada."; exit 0; }

telegram "🟡 Restaurando *$NOME_SITE* com backup de $SELECTED_BACKUP_NAME."

# === VERIFICAÇÕES DE INTEGRIDADE ===========================

echo "Verificando integridade..." | tee -a "$LOG_RESTORE"

MD5_ARQ=$(cut -d ' ' -f1 "$SELECTED_BACKUP_PATH/bkp-$NOME_SITE-arquivos-$SELECTED_BACKUP_NAME.md5" 2>/dev/null)
[ -n "$MD5_ARQ" ] && ! echo "$MD5_ARQ  $ARQUIVO_BKP_RESTORE" | md5sum -c --status && erro_fatal "MD5 dos arquivos não confere."

MD5_BD=$(cut -d ' ' -f1 "$SELECTED_BACKUP_PATH/bkp-$NOME_SITE-banco-$SELECTED_BACKUP_NAME.md5" 2>/dev/null)
[ -n "$MD5_BD" ] && ! echo "$MD5_BD  $BANCO_BKP_RESTORE" | md5sum -c --status && erro_fatal "MD5 do banco não confere."

gunzip -c "$BANCO_BKP_RESTORE" | head -n 1 | grep -q -- "-- MySQL dump" || erro_fatal "SQL inválido."

echo "✅ Integridade validada com sucesso." | tee -a "$LOG_RESTORE"

# === MODO MANUTENÇÃO =======================================

"$WP" maintenance-mode activate --path="$SITE_PATH" --allow-root >> "$LOG_RESTORE" 2>&1 || echo "⚠️ Modo já estava ativo." | tee -a "$LOG_RESTORE"

# === RESTAURAR ARQUIVOS ====================================

echo "Limpando site e restaurando arquivos..." | tee -a "$LOG_RESTORE"
rm -rf "$SITE_PATH"/* "$SITE_PATH"/.[!.]* || erro_fatal "Falha ao apagar o site."
tar -xzf "$ARQUIVO_BKP_RESTORE" -C "$SITE_PATH" || erro_fatal "Falha na extração de arquivos."

[ ! -f "$SITE_PATH/wp-config.php" ] && erro_fatal "wp-config.php ausente após extração."

# === RESTAURAR BANCO =======================================

echo "Restaurando banco de dados..." | tee -a "$LOG_RESTORE"
"$WP" db reset --yes --path="$SITE_PATH" --allow-root >> "$LOG_RESTORE" 2>&1 || echo "⚠️ Falha ao resetar, tentando importar direto." | tee -a "$LOG_RESTORE"

gunzip < "$BANCO_BKP_RESTORE" | "$WP" db import - --path="$SITE_PATH" --allow-root >> "$LOG_RESTORE" 2>&1 || erro_fatal "Falha ao importar banco."

# === DESATIVAR MANUTENÇÃO ==================================

"$WP" maintenance-mode deactivate --path="$SITE_PATH" --allow-root >> "$LOG_RESTORE" 2>&1 || telegram "❌ ERRO: Não desativou modo manutenção em *$NOME_SITE*."

echo -e "\n========== RESTAURAÇÃO CONCLUÍDA ==========\n" | tee -a "$LOG_RESTORE"
telegram "✅ Restauração de *$NOME_SITE* concluída com sucesso usando backup de $SELECTED_BACKUP_NAME."

exit 0
