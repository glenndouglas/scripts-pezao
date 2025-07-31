#!/bin/bash

set -e
set -o pipefail

NOME_SITE="fpfm2"
SITE_PATH="/home2/futeb379/public_html/fpfm2"
PASTA_SITE="/home2/futeb379/bkps_diarios/fpfm2"
LOG="$PASTA_SITE/log_restore_${NOME_SITE}_$(date +%d%m%y-%H%M).txt"
WP="/usr/local/bin/wp"
TOKEN="1946983588:AAHiKhTJVpotgrH2F27i5FyEo85SngclTTU"
CHAT_ID="804554535"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

enviar_telegram() {
  curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="$1" > /dev/null
}

erro_fatal() {
  log "❌ ERRO: $1"
  enviar_telegram "❌ *Erro ao restaurar $NOME_SITE*: $1"
  exit 1
}

log "==================== RESTAURANDO $NOME_SITE ===================="
enviar_telegram "♻️ Iniciando restauração de *$NOME_SITE*"

cd "$PASTA_SITE"
BACKUPS=($(ls -1d [0-9]* | sort))
if [ "${#BACKUPS[@]}" -eq 0 ]; then
  erro_fatal "Nenhum backup encontrado em $PASTA_SITE"
fi

echo "Backups disponíveis:"
select SELECIONADO in "${BACKUPS[@]}"; do
  [ -n "$SELECIONADO" ] && break
done

PASTA_BKP="$PASTA_SITE/$SELECIONADO"
ARQUIVO_BANCO=$(find "$PASTA_BKP" -name "*-banco-*.sql.gz" | head -n1)
ARQUIVO_HASH="$PASTA_BKP/hash_arquivos.md5"
ARQUIVOS_PARTS=("$PASTA_BKP"/*.part*)

[ ! -f "$ARQUIVO_BANCO" ] && erro_fatal "Arquivo do banco não encontrado"
[ ! -f "$ARQUIVO_HASH" ] && erro_fatal "Arquivo de hash não encontrado"
[ "${#ARQUIVOS_PARTS[@]}" -eq 0 ] && erro_fatal "Partes do backup não encontradas"

log "🔐 Validando integridade dos arquivos..."
cd "$PASTA_BKP"
md5sum -c hash_arquivos.md5 || erro_fatal "Hashes não conferem"
cd - > /dev/null

log "🛠️ Ativando modo manutenção..."
if $WP --path="$SITE_PATH" core is-installed > /dev/null 2>&1; then
  $WP --path="$SITE_PATH" maintenance-mode activate || true
fi

log "🧹 Limpando arquivos antigos de forma segura..."
rm -rf "$SITE_PATH"/* "$SITE_PATH"/.[!.]* "$SITE_PATH"/..?* || erro_fatal "Erro ao limpar site"

log "📦 Restaurando arquivos do backup..."
cat "$PASTA_BKP"/bkp-*-arquivos-*.part* | tar -xzpf - -C "$SITE_PATH"

log "💾 Restaurando banco de dados..."
gunzip -c "$ARQUIVO_BANCO" | $WP --path="$SITE_PATH" db import - || erro_fatal "Erro ao restaurar banco"

log "✅ Restauração concluída com sucesso!"
if $WP --path="$SITE_PATH" core is-installed > /dev/null 2>&1; then
  $WP --path="$SITE_PATH" maintenance-mode deactivate || true
fi

enviar_telegram "✅ *Restauração concluída de $NOME_SITE!*
📁 Pasta usada: \`$SELECIONADO\`"
exit 0
