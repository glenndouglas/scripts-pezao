#!/bin/bash

# ⚠️ Sai se ocorrer erro e ativa segurança
set -e
set -o pipefail
START_TIME=$(date +%s)

# === ⚙️ CONFIGURAÇÕES INICIAIS =====================================
SITE_PATH="/home2/futeb379/public_html/fpfm2"
WP="/usr/local/bin/wp"
NOME_SITE="fpfm2"

# === 🔐 TELEGRAM ===================================================
TOKEN="1946983588:AAHiKhTJVpotgrH2F27i5FyEo85SngclTTU"
CHAT_ID="804554535"

# === 📁 PASTAS E NOMES DE ARQUIVOS ================================
PASTA_BASE="/home2/futeb379/bkps_diarios"
PASTA_SITE="$PASTA_BASE/$NOME_SITE"
DATA=$(date +%d%m%y-%H%M)
PASTA_BKP="$PASTA_SITE/$DATA"
mkdir -p "$PASTA_BKP"

LOG="$PASTA_BKP/log_completo_${NOME_SITE}_${DATA}.txt"
ARQUIVO_BKP="$PASTA_BKP/bkp-${NOME_SITE}-arquivos-${DATA}.tar.gz"
BANCO_BKP="$PASTA_BKP/bkp-${NOME_SITE}-banco-${DATA}.sql.gz"

# === 🚫 LISTA DE EXCLUSÃO ==========================================
EXCLUDE_LIST=(
  "wp-content/cache"
  "BKP-DA-RAIZ"
  "*.log"
  "cbfm5"
)

# === 🔒 GARANTIA DE SEGURANÇA: DESATIVA MANUTENÇÃO AO SAIR ========
trap 'echo "[Trap] Desativando modo manutenção por segurança..."; $WP --path="$SITE_PATH" maintenance-mode deactivate > /dev/null 2>&1 || true' EXIT

# === 🧠 FUNÇÕES AUXILIARES ==========================================

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
  enviar_telegram "❌ *Erro no backup de $NOME_SITE*: $1"
  exit 1
}

# === 🚀 INÍCIO ======================================================

log "==================== $DATA ===================="
log "📦 Iniciando backup dividido de $NOME_SITE"
enviar_telegram "🟡 Iniciando backup de $NOME_SITE em $DATA"

# === 1. 🔧 ATIVAR MODO MANUTENÇÃO ==========================
log "🔧 Ativando modo manutenção"
$WP --path="$SITE_PATH" maintenance-mode activate || log "Modo manutenção já estava ativo"

# === 2. 💽 BACKUP DO BANCO DE DADOS ========================
log "🧠 Exportando banco de dados..."
enviar_telegram "🧠 Exportando banco de dados..."
$WP --path="$SITE_PATH" db export - | gzip > "$BANCO_BKP" || erro_fatal "Falha ao exportar o banco"
md5sum "$BANCO_BKP" > "$BANCO_BKP.md5"
TAM_BANCO=$(du -sh "$BANCO_BKP" | cut -f1)
log "✅ Banco exportado: $TAM_BANCO"
enviar_telegram "✅ Banco exportado com sucesso"

# === 3. 🗃️ BACKUP DOS ARQUIVOS COM SPLIT =====================
log "🗃️ Compactando arquivos do WordPress com split de 500MB..."
enviar_telegram "🗃️ Compactando arquivos do site..."
EXCLUDE_ARGS=()
for item in "${EXCLUDE_LIST[@]}"; do
  EXCLUDE_ARGS+=(--exclude="$item")
done

cd "$SITE_PATH"

tar -czpf - "${EXCLUDE_ARGS[@]}" . \
  | split -b 500m - "$ARQUIVO_BKP.part" || erro_fatal "Erro ao dividir arquivos"

cd - > /dev/null

# === 4. 🔐 GERAÇÃO DE HASH MD5 PARA CADA PARTE ==============
log "🔐 Gerando hashes MD5..."
enviar_telegram "🔐 Verificando integridade e gerando hashes MD5..."
for parte in "$ARQUIVO_BKP".part*; do
  md5sum "$parte" >> "$PASTA_BKP/hash_arquivos.md5"
done

# === 5. 🚪 DESATIVA MODO MANUTENÇÃO =========================
log "🚪 Desativando modo manutenção"
$WP --path="$SITE_PATH" maintenance-mode deactivate || log "Erro ao desativar modo manutenção"

# === 6. ✅ FINALIZAÇÃO E RESUMO =============================
END_TIME=$(date +%s)
TEMPO_TOTAL=$(( END_TIME - START_TIME ))
MIN=$((TEMPO_TOTAL / 60))
SEG=$((TEMPO_TOTAL % 60))

TAM_TOTAL=$(du -ch "$ARQUIVO_BKP".part* | grep total$ | cut -f1)
NUM_PARTES=$(ls "$ARQUIVO_BKP".part* | wc -l)

# Contagem de backups (sem a lixeira)
TOTAL_BKPS=$(find "$PASTA_SITE" -mindepth 1 -maxdepth 1 -type d ! -name "_lixeira" | wc -l)

# Contagem da lixeira (se existir)
LIXEIRA="$PASTA_SITE/_lixeira"
if [ -d "$LIXEIRA" ]; then
  TOTAL_LIXEIRA=$(find "$LIXEIRA" -mindepth 1 -maxdepth 1 -type d | wc -l)
else
  TOTAL_LIXEIRA=0
fi

log "✅ Backup finalizado com sucesso em ${MIN}m ${SEG}s"

MSG_FINAL=$(
  echo -e "✅ *Backup concluído de $NOME_SITE!*"
  echo -e "🧠 *Banco:* $TAM_BANCO"
  echo -e "📦 *Arquivos compactados:* $TAM_TOTAL (em $NUM_PARTES partes de 500MB)"
  echo -e "📌 *Local:* \`$PASTA_BKP\`"
  echo -e "⏱️ *Duração:* ${MIN}m ${SEG}s"
  echo -e "📂 *Pasta de backups contém $TOTAL_BKPS bkps*"
  if [ "$TOTAL_LIXEIRA" -gt 0 ]; then
    echo -e "🗑️ *Lixeira com $TOTAL_LIXEIRA bkps*"
  fi
)

enviar_telegram "$MSG_FINAL"

exit 0
