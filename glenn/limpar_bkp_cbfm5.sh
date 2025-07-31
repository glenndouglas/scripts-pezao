#!/bin/bash
set -e

NOME_SITE="cbfm5"
PASTA_SITE="/home2/futeb379/bkps_diarios/$NOME_SITE"
LIXEIRA="$PASTA_SITE/_lixeira"
mkdir -p "$LIXEIRA"

if [ ! -d "$PASTA_SITE" ]; then
  echo "❌ Pasta de backups não encontrada: $PASTA_SITE"
  exit 1
fi

echo -e "\n📂 Pastas disponíveis:\n"

OPCOES=()
DESCRICOES=()

for dir in $(find "$PASTA_SITE" -mindepth 1 -maxdepth 1 -type d ! -name "_lixeira" | sort); do
  nome=$(basename "$dir")
  OPCOES+=("$dir")
  DESCRICOES+=("📦 $nome")
done

OPCOES+=("__SEPARADOR__")
DESCRICOES+=("📁 _lixeira")

for dir in $(find "$LIXEIRA" -mindepth 1 -maxdepth 1 -type d | sort); do
  nome=$(basename "$dir")
  OPCOES+=("$dir")
  DESCRICOES+=("🗑️ $nome")
done

for i in "${!OPCOES[@]}"; do
  if [[ "${OPCOES[$i]}" == "__SEPARADOR__" ]]; then
    echo -e "\n🔽 ${DESCRICOES[$i]}"
  else
    echo "[$i] → ${DESCRICOES[$i]}"
  fi
done

echo ""
read -p "Digite o número da pasta que deseja manipular: " ESCOLHA

if ! [[ "$ESCOLHA" =~ ^[0-9]+$ ]] || [ "$ESCOLHA" -ge "${#OPCOES[@]}" ]; then
  echo "❌ Escolha inválida."
  exit 1
fi

if [[ "${OPCOES[$ESCOLHA]}" == "__SEPARADOR__" ]]; then
  echo "❌ Opção inválida (linha separadora)."
  exit 1
fi

PASTA_ESCOLHIDA="${OPCOES[$ESCOLHA]}"
NOME_PASTA_ESCOLHIDA=$(basename "$PASTA_ESCOLHIDA")

if [[ "$PASTA_ESCOLHIDA" == "$LIXEIRA/"* ]]; then
  echo -e "\n⚠️ A pasta está na lixeira. Se continuar, ela será excluída DEFINITIVAMENTE."
  read -p "Deseja excluir permanentemente '$NOME_PASTA_ESCOLHIDA'? [s/N]: " CONFIRMA
  if [[ "$CONFIRMA" =~ ^[Ss]$ ]]; then
    rm -rf "$PASTA_ESCOLHIDA"
    echo "✅ Pasta '$NOME_PASTA_ESCOLHIDA' excluída permanentemente da lixeira."
  else
    echo "❌ Ação cancelada."
    exit 0
  fi
else
  echo ""
  read -p "Deseja mover a pasta para a lixeira (_lixeira)? [s/N]: " MOVER
  if [[ "$MOVER" =~ ^[Ss]$ ]]; then
    mv "$PASTA_ESCOLHIDA" "$LIXEIRA/"
    echo "🗑️ Pasta '$NOME_PASTA_ESCOLHIDA' movida para a lixeira."
  else
    rm -rf "$PASTA_ESCOLHIDA"
    echo "✅ Pasta '$NOME_PASTA_ESCOLHIDA' removida permanentemente."
  fi
fi

exit 0