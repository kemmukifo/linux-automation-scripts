#!/bin/bash
# --------------------------------------------------------------------------------
# Script: ghost-process-detector.sh
# Autor: Kleber Maximo
# Versão: 2.0
# Data: 2025-08-12
#
# Descrição:
#   Identifica processos que estão escutando em portas TCP (LISTEN)
#   mas que não possuem conexões ESTABELECIDAS (ativas).
#
#   Esses processos podem indicar:
#     - Serviços ociosos
#     - Aplicações travadas
#     - Consumo desnecessário de recursos
#
# Funcionalidades:
#   - Lista processos "fantasmas"
#   - Exibe porta, PID, nome do processo e aplicação
#   - Permite encerrar processos selecionados
#   - Tentativa de kill normal + forçado (kill -9)
#
# Uso:
#   chmod +x ghost-process-detector.sh
#   sudo ./ghost-process-detector.sh
#
# Atenção:
#   Encerrar processos pode impactar sistemas em produção.
# --------------------------------------------------------------------------------

echo "🔍 Buscando processos com portas LISTEN..."

mapfile -t listen_list < <(ss -tulpn 2>/dev/null | grep LISTEN | while read -r line; do
    pid=$(echo "$line" | sed -n 's/.*pid=\([0-9]*\),.*/\1/p')
    [[ -z "$pid" ]] && continue

    port=$(echo "$line" | awk '{print $5}' | awk -F':' '{print $NF}')
    pname=$(echo "$line" | sed -n 's/.*users:(("\([^"]*\)".*/\1/p')
    cmd=$(ps -p "$pid" -o cmd=)

    appname=$(echo "$cmd" | sed -n 's#.*/opt/\([^/]*\)/.*#\1#p')
    [[ -z "$appname" ]] && appname="Desconhecido"

    echo "$port|$pid|$pname|$appname"
done)

echo "🔗 Buscando conexões ESTAB..."

mapfile -t estab_list < <(ss -tnp 2>/dev/null | grep ESTAB | while read -r line; do
    pid=$(echo "$line" | sed -n 's/.*pid=\([0-9]*\),.*/\1/p')
    [[ -z "$pid" ]] && continue

    port=$(echo "$line" | awk '{print $4}' | awk -F':' '{print $NF}')
    echo "$pid|$port"
done)

declare -A estab_map
for e in "${estab_list[@]}"; do
    pid=${e%%|*}
    port=${e##*|}
    estab_map["$pid|$port"]=1
done

echo
echo "👻 Processos LISTEN sem conexões ESTAB (fantasmas):"
echo "------------------------------------------------------------"

found=0

for l in "${listen_list[@]}"; do
    port=${l%%|*}
    rest=${l#*|}
    pid=${rest%%|*}
    rest2=${rest#*|}
    pname=${rest2%%|*}
    appname=${rest2#*|}

    if [[ -z "${estab_map["$pid|$port"]}" ]]; then
        printf "Porta: %-6s | PID: %-8s | Processo: %-12s | Aplicação: %s\n" "$port" "$pid" "$pname" "$appname"
        found=1
    fi
done

if [[ $found -eq 0 ]]; then
    echo "✅ Nenhum processo fantasma encontrado."
    exit 0
fi

echo
read -p "Digite o(s) PID(s) que deseja encerrar (ou ENTER para sair): " -a killpids

if [[ ${#killpids[@]} -eq 0 ]]; then
    echo "ℹ️ Nenhum processo será encerrado."
    exit 0
fi

echo "⚠️ PIDs selecionados: ${killpids[*]}"
read -p "Confirmar encerramento? (s/N): " confirm

if [[ "$confirm" =~ ^[Ss]$ ]]; then
    for pid in "${killpids[@]}"; do
        echo "Encerrando PID $pid..."
        kill "$pid" 2>/dev/null
        sleep 1

        if ps -p "$pid" > /dev/null 2>&1; then
            echo "⚠️ Ainda ativo, forçando kill -9..."
            kill -9 "$pid" 2>/dev/null
        fi

        echo "✅ Processo $pid finalizado."
    done
else
    echo "❌ Operação cancelada."
fi
