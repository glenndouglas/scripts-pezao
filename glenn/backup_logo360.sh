#!/bin/bash
set -e  # Encerra imediatamente se algum comando falhar

############################################################
#     BACKUP WORDPRESS COM WP-CLI, LOGS, TELEGRAM e MD5    #
#           Script padronizado para o site: logo360        #
############################################################

# === ⚙️ CONFIGURAÇÃO INICIAL ===============================

SITE_PATH="/home2/futeb379/public_html/logo360"  # Caminho absoluto do site WordPress
WP="/usr/local/bin/wp"                           # Caminho para o WP-CLI
NOME_SITE="logo360"                              # Nome identificador do site
TOKEN="1946983588:AAHiKhTJVpotgrH2F27i5FyEo85SngclTTU"  # Token do seu bot Telegram
CHAT_ID="804554535"                              # ID do chat Telegram
PASTA_BASE="/home2/futeb379/bkps_diarios"        # Pasta base onde ficam os backups de todos os sites
PASTA_SITE="$PASTA_BASE/$NOME_SITE"              # Pasta específica deste site
DATA=$(date +%d%m%y-%H%M)                         # Data e hora atual no formato DDMMYY-HHMM
PASTA_BKP="$PASTA_SITE/$DATA"                    # Pasta deste backup específico
ARQUIVO_BKP="$PASTA_BKP/bkp-$NOME_SITE-arquivos-$DATA.tar.gz"  # Nome do arquivo compactado dos arquivos
BANCO_BKP="$PASTA_BKP/bkp-$NOME_SITE-banco-$DATA.sql.gz"        # Nome do arquivo compactado do banco
LOG="$PASTA_BKP/backup-$NOME_SITE-$DATA.log"     # Arquivo de log do processo

# Lista de pastas/arquivos a serem ignorados na compactação
EXCLUDE_LIST=("wp-content/cache" "*.log" "wp-content/et-cache" "wp-content/uploads/cache")

# Cria a pasta do backup
mkdir -p "$PASTA_BKP"

# Redireciona toda a saída do terminal para o arquivo de log e também exibe no terminal
exec > >(tee -a "$LOG") 2>&1

# === 🔔 Função para envio de mensagens ao Telegram =========
telegram() {
  /usr/bin/curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$1" \
    -d parse_mode="Markdown" > /dev/null
}

# === 🔰 INÍCIO DO BACKUP ===================================

echo -e "\n==================== $(date '+%d/%m/%Y %H:%M:%S') ===================="
echo "📦 Backup iniciado em $(date)"
telegram "🟡 *Iniciando backup de $NOME_SITE em $DATA*"

# === [1/2] EXPORTAÇÃO DO BANCO DE DADOS ===================

echo "🧠 Exportando banco de dados..."
telegram "📤 *Exportando banco de dados...*"

if ! "$WP" db export - --path="$SITE_PATH" --allow-root | gzip > "$BANCO_BKP"; then
  echo "❌ ERRO ao exportar banco!"
  telegram "❌ *Erro:* falha ao exportar banco de *$NOME_SITE*."
  exit 1
fi

echo "✅ Banco exportado com sucesso: $BANCO_BKP"
telegram "✅ *Banco exportado com sucesso*"

# === [2/2] COMPACTAÇÃO DOS ARQUIVOS =======================

echo "🗼️ Compactando arquivos do site..."
telegram "🗼️ *Compactando arquivos do site...*"

EXCLUDE_ARGS=()
for item in "${EXCLUDE_LIST[@]}"; do
  EXCLUDE_ARGS+=("--exclude=$item")
done

INICIO_COMPAC=$(date +%s)

if tar --ignore-failed-read --warning=no-file-changed -czf "$ARQUIVO_BKP" "${EXCLUDE_ARGS[@]}" -C "$SITE_PATH" . >> "$LOG" 2>&1; then
  echo "📦 Compactação concluída."
else
  echo "❌ ERRO ao compactar arquivos!"
  telegram "❌ *Erro:* falha ao compactar arquivos de *$NOME_SITE*."
  exit 1
fi

# === ✅ VERIFICAÇÕES FINAIS ================================

# Verifica se o .tar.gz gerado é íntegro
echo "🔍 Verificando integridade do .tar.gz..."
if ! tar -tzf "$ARQUIVO_BKP" > /dev/null; then
  echo "❌ Arquivo .tar.gz corrompido!"
  telegram "❌ *Erro:* arquivo .tar.gz de *$NOME_SITE* está corrompido!"
  exit 1
fi
echo "✅ Arquivo .tar.gz verificado com sucesso."

# Gera hashes MD5 para os dois arquivos principais
echo "🔐 Gerando hash MD5..."
md5sum "$ARQUIVO_BKP" > "$ARQUIVO_BKP.md5"
md5sum "$BANCO_BKP" > "$BANCO_BKP.md5"
echo "✅ Hashes salvos."

# Tamanhos dos arquivos gerados
TAM_ARQ=$(du -h "$ARQUIVO_BKP" | cut -f1)
TAM_SQL=$(du -h "$BANCO_BKP" | cut -f1)

# Contagem de backups existentes (sem lixeira)
TOTAL_BKPS=$(find "$PASTA_SITE" -maxdepth 1 -mindepth 1 -type d ! -name "_lixeira" | wc -l)
LIXEIRA_PATH="$PASTA_SITE/_lixeira"
[ -d "$LIXEIRA_PATH" ] && TOTAL_LIXO=$(find "$LIXEIRA_PATH" -mindepth 1 -maxdepth 1 -type d | wc -l) || TOTAL_LIXO=0

# Tempo total de compactação
FIM=$(date +%s)
DURACAO=$((FIM - INICIO_COMPAC))
MIN=$((DURACAO / 60))
SEG=$((DURACAO % 60))

# === ✅ FINALIZAÇÃO ========================================

echo -e "\n🏁 Backup finalizado em $(date)"
echo "⏱️ Duração: ${MIN}m ${SEG}s"
echo "📦 Arquivo: $(basename "$ARQUIVO_BKP") ($TAM_ARQ)"
echo "🗃️ Banco: $(basename "$BANCO_BKP") ($TAM_SQL)"
echo "🗂️ Pasta de backups contém $TOTAL_BKPS bkps + 🗑️ lixeira com $TOTAL_LIXO bkps"
echo "🕐 Tempo de compactação: ${MIN}m ${SEG}s"

telegram "✅ *Backup finalizado de $NOME_SITE*
⏱️ Duração: ${MIN}m ${SEG}s
📦 Arquivo: $(basename "$ARQUIVO_BKP") ($TAM_ARQ)
🗃️ Banco: $(basename "$BANCO_BKP") ($TAM_SQL)

🗂️ Pasta de backups contém $TOTAL_BKPS bkps + 🗑️ lixeira com $TOTAL_LIXO bkps
🕐 Tempo de compactação: ${MIN}m ${SEG}s"

exit 0
