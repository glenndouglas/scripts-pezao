#!/bin/bash
set -euo pipefail

# ===============================================================
# 🧩 CONFIGURAÇÃO DO SERVIDOR DE ORIGEM (onde o post será exportado)
# ===============================================================

WP="/usr/local/bin/wp"
SITE_PATH="/home2/futme692/public_html"
EXPORT_DIR="$SITE_PATH/exports"

# ===============================================================
# 🧩 CONFIGURAÇÃO DO SERVIDOR DE DESTINO (onde o post será importado)
# ===============================================================

DEST_USER="futeb379"
DEST_HOST="192.185.210.208"
DEST_PATH="/home2/futeb379/public_html/fpfm2"
DEST_EXPORT_DIR="$DEST_PATH/exports"

# ===============================================================
# 📢 CONFIGURAÇÃO DO TELEGRAM
# ===============================================================

TOKEN="1946983588:AAHiKhTJVpotgrH2F27i5FyEo85SngclTTU"
CHAT_ID="804554535"

telegram() {
  curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="$1" > /dev/null
}

# ===============================================================
# 🚀 INÍCIO DO PROCESSO
# ===============================================================

cd "$SITE_PATH"

echo "🔍 Listando os últimos 10 posts:"
$WP post list --post_type=post --orderby=ID --order=desc \
  --fields=ID,post_title,post_date,post_status --format=table \
  --posts_per_page=10

read -p "Digite o ID do post que deseja exportar: " POST_ID

if ! $WP post get "$POST_ID" &>/dev/null; then
  echo "❌ Post ID $POST_ID não encontrado."
  exit 1
fi

TITULO=$($WP post get "$POST_ID" --field=post_title)
ARQUIVO="post-${POST_ID}.xml"

telegram "🚀 Iniciando exportação do post *#${POST_ID}*:
*${TITULO}*"

mkdir -p "$EXPORT_DIR"
echo "📦 Exportando post $POST_ID com mídias..."
$WP export --post__in="$POST_ID" --with_attachments --dir=exports --filename_format="$ARQUIVO"

if [ ! -f "$EXPORT_DIR/$ARQUIVO" ]; then
  echo "❌ Erro: Arquivo não foi criado em $EXPORT_DIR"
  exit 1
fi

echo "✅ Arquivo exportado com sucesso: $EXPORT_DIR/$ARQUIVO"

# ===============================================================
# ✈️ ENVIO PARA O SERVIDOR DESTINO (via SCP com chave SSH)
# ===============================================================

echo "🔐 Enviando arquivo via chave SSH..."
scp "$EXPORT_DIR/$ARQUIVO" "$DEST_USER@$DEST_HOST:$DEST_EXPORT_DIR/"

# ===============================================================
# ⏎ IMPORTAÇÃO REMOTA (via SSH + WP-CLI)
# ===============================================================

echo "🚀 Conectando no servidor GLENN para importar..."
ssh "$DEST_USER@$DEST_HOST" \
  "$WP --path=$DEST_PATH import $DEST_EXPORT_DIR/$ARQUIVO --authors=create --allow-root"

# ===============================================================
# 📢 AVISO FINAL NO TELEGRAM
# ===============================================================

telegram "✅ *Post #${POST_ID} importado com sucesso no FPFM2!*
Título: *${TITULO}*"

echo "🎉 Post $POST_ID exportado de FPFM e importado com sucesso em FPFM2!"
