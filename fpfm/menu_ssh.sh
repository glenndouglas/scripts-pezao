#!/bin/bash
export TERM=xterm

SCRIPT_DIR="$HOME/scripts"

clear
echo "==== MENU DE SCRIPTS DISPONIVEIS - FPFM ===="
echo

i=1
declare -A scripts

# Lista todos os arquivos .sh da pasta
for file in "$SCRIPT_DIR"/*.sh; do
    nome=$(basename "$file")

    # Ignorar o proprio menu
    if [[ "$nome" == "menu_ssh.sh" ]]; then
        continue
    fi

    echo "[$i] $nome"
    scripts[$i]="$file"
    ((i++))
done


echo "[99] Abrir terminal normalmente"
echo "[0] Sair"
echo
read -p "Escolha uma opcao: " opcao

if [[ "$opcao" == "99" ]]; then
    echo
    echo "Entrando no terminal do servidor. Menu encerrado."
    echo
    exec bash
elif [[ "$opcao" =~ ^[0-9]+$ ]] && [[ "$opcao" -ne 0 ]]; then
    script="${scripts[$opcao]}"
    if [[ -x "$script" ]]; then
        echo
        echo "Executando: $script"
        echo "--------------------------------------"
        "$script"
        echo "--------------------------------------"
        echo
        echo "✅ Execução concluída."
        echo "🔁 Pressione ENTER para voltar ao menu ou use o terminal normalmente antes de continuar."
        read -p "" pausa
        exec "$0"
    fi
    
else
    echo "Saindo..."
fi

