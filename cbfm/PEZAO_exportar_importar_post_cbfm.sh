#!/bin/bash

# Ativa modo seguro: falha ao mínimo erro
set -euo pipefail

# ===============================================================
# 🧩 CONFIGURAÇÃO DO SERVIDOR DE ORIGEM (onde o post será exportado)
# ===============================================================

# Caminho completo do WP-CLI no servidor origem.
# 🔍 Descubra com: which wp
WP="/usr/local/bin/wp"

# Caminho absoluto da instalação WordPress no servidor origem.
# 🔍 Descubra com: execute o comando pwd dentro da pasta do WordPress
SITE_PATH="/home1/cbfmco47/public_html"

# Pasta onde o XML será salvo (dentro da instalação do WP)
EXPORT_DIR="$SITE_PATH/exports"

# ===============================================================
# 🧩 CONFIGURAÇÃO DO SERVIDOR DE DESTINO (onde o post será importado)
# ===============================================================

# Usuário SSH do servidor de destino
DEST_USER="futeb379"

# Endereço IP ou domínio do servidor de destino (clonado)
DEST_HOST="192.185.210.208"

# Caminho da instalação WordPress no servidor de destino
# 🔍 Descubra com: ssh no servidor destino + pwd na pasta WordPress
DEST_PATH="/home2/futeb379/public_html/cbfm5"

# Caminho completo da pasta onde o XML será enviado no destino
DEST_EXPORT_DIR="$DEST_PATH/exports"

# ===============================================================
# 📢 CONFIGURAÇÃO DO TELEGRAM (avisos automáticos)
# ===============================================================

# Token do bot (criado no BotFather)
TOKEN="1946983588:AAHiKhTJVpotgrH2F27i5FyEo85SngclTTU"

# Chat ID (pode ser seu usuário ou grupo) — veja com bots como @userinfobot
CHAT_ID="804554535"

# Função para enviar mensagens via Telegram
telegram() {
  curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="$1" > /dev/null
}

# ===============================================================
# 🚀 INÍCIO DO PROCESSO
# ===============================================================

# Entra na pasta da instalação WP origem
cd "$SITE_PATH"

# Lista os 10 últimos posts para facilitar a escolha
echo "🔍 Listando os últimos 10 posts:"
$WP post list --post_type=post --orderby=ID --order=desc \
  --fields=ID,post_title,post_date,post_status --format=table \
  --posts_per_page=10

# Pede ao usuário o ID do post que deseja exportar
read -p "Digite o ID do post que deseja exportar: " POST_ID

# Valida se o post existe no WordPress
if ! $WP post get "$POST_ID" &>/dev/null; then
  echo "❌ Post ID $POST_ID não encontrado."
  exit 1
fi

# Obtém o título do post e define nome do arquivo XML
TITULO=$($WP post get "$POST_ID" --field=post_title)
ARQUIVO="post-${POST_ID}.xml"

# Envia mensagem inicial para o Telegram
telegram "🚀 Iniciando exportação do post *#${POST_ID}*:
*${TITULO}*"

# Garante que a pasta exports/ exista localmente
mkdir -p "$EXPORT_DIR"

# Exporta o post com mídias para o arquivo XML
echo "📦 Exportando post $POST_ID com mídias..."
$WP export --post__in="$POST_ID" --with_attachments --dir=exports --filename_format="$ARQUIVO"

# Confirma que o arquivo foi criado corretamente
if [ ! -f "$EXPORT_DIR/$ARQUIVO" ]; then
  echo "❌ Erro: Arquivo não foi criado em $EXPORT_DIR"
  exit 1
fi

echo "✅ Arquivo exportado com sucesso: $EXPORT_DIR/$ARQUIVO"

# ===============================================================
# ✈️ ENVIO PARA O SERVIDOR DESTINO (via SCP)
# ===============================================================

echo "🔐 Enviando arquivo para o servidor GLENN (será solicitada a senha)"

# ⚠️ Se você tiver problemas de autenticação, adicione:
# -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no
scp -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no "$EXPORT_DIR/$ARQUIVO" "$DEST_USER@$DEST_HOST:$DEST_EXPORT_DIR/"

# ===============================================================
# ⏎ IMPORTAÇÃO REMOTA (via SSH + WP-CLI)
# ===============================================================

echo "🚀 Conectando no servidor GLENN para importar..."

# Executa o comando de importação via SSH remoto
# -tt força terminal interativo (necessário para aceitar senha)
ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no "$DEST_USER@$DEST_HOST" \
  "$WP --path=$DEST_PATH import $DEST_EXPORT_DIR/$ARQUIVO --authors=create --allow-root"


# ===============================================================
# 📢 AVISO FINAL NO TELEGRAM
# ===============================================================

telegram "✅ *Post #${POST_ID} importado com sucesso no GLENN!*
Título: *${TITULO}*"

# Mensagem no terminal
echo "🎉 Post $POST_ID exportado de CBFM e importado com sucesso em GLENN!"
