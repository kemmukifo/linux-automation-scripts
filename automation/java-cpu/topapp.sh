#!/bin/bash
# ==========================================================
# SCRIPT: TOPAPP ULTIMATE - CORREÇÃO DO ERRO DE TOP
# AUTOR: Kleber Eduardo Maximo
# DATA: 06/03/2026
# VERSAO: 5.5 - FILTRO POR CLIENTE
# ==========================================================

# ==========================================================
# CONFIGURAÇÕES
# ==========================================================

CPU_LIMIT=800.0
TOP_N=15
BARRA_LARGURA=25

# ==========================================================
# PARÂMETROS
# ==========================================================

CLIENTE_FILTRO="$1"  # Primeiro parâmetro: nome do cliente (opcional)

# ==========================================================
# CORES ANSI
# ==========================================================

VERMELHO='\033[0;31m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
ROXO='\033[0;35m'
CIANO='\033[0;36m'
BRANCO='\033[1;37m'
CINZA='\033[0;37m'
NEGRITO='\033[1m'
UNDERLINE='\033[4m'
RESET='\033[0m'

FUNDO_VERMELHO='\033[41m'
FUNDO_VERDE='\033[42m'
FUNDO_AMARELO='\033[43m'
FUNDO_ROXO='\033[45m'

# ==========================================================
# FUNÇÃO: BARRA DE PROGRESSO
# ==========================================================

criar_barra() {
    local percentual=$1
    local largura=${2:-$BARRA_LARGURA}
    local preenchido=0
    
    if command -v bc >/dev/null 2>&1; then
        preenchido=$(echo "$percentual * $largura / 800" | bc -l 2>/dev/null | cut -d. -f1)
    else
        preenchido=$((percentual * largura / 800))
    fi
    
    [[ $preenchido -lt 0 ]] && preenchido=0
    [[ $preenchido -gt $largura ]] && preenchido=$largura
    
    local vazio=$((largura - preenchido))
    
    if (( $(echo "$percentual > 800" | bc -l 2>/dev/null) )); then
        cor_barra=$FUNDO_ROXO
    elif (( $(echo "$percentual > 200" | bc -l 2>/dev/null) )); then
        cor_barra=$FUNDO_VERMELHO
    elif (( $(echo "$percentual > 100" | bc -l 2>/dev/null) )); then
        cor_barra=$FUNDO_AMARELO
    else
        cor_barra=$FUNDO_VERDE
    fi
    
    printf "${cor_barra}"
    printf "%0.s " $(seq 1 $preenchido)
    printf "${RESET}${CINZA}"
    printf "%0.s░" $(seq 1 $vazio)
    printf "${RESET}"
}

# ==========================================================
# FUNÇÃO: CENTRALIZAR TEXTO
# ==========================================================

centralizar() {
    local texto="$1"
    local largura_total=80
    local tamanho_texto=${#texto}
    local espacos=$(( (largura_total - tamanho_texto) / 2 ))
    
    printf "%${espacos}s" " "
    echo -e "$texto"
}

# ==========================================================
# CABEÇALHO
# ==========================================================

clear
echo -e "${AZUL}════════════════════════════════════════════════════════════════════════════${RESET}"
centralizar "${NEGRITO}${BRANCO}🔍 TOPAPP ULTIMATE - MONITOR DE CPU WILDFLY/JBOSS${RESET}"
echo -e "${AZUL}════════════════════════════════════════════════════════════════════════════${RESET}"
echo ""

echo -e "${CIANO}📅 Data:${RESET} $(date '+%d/%m/%Y %H:%M:%S')"
echo -e "${CIANO}⚡ Limite:${RESET} ${BRANCO}$CPU_LIMIT%${RESET} ${CIANO}| Exibindo top:${RESET} ${BRANCO}$TOP_N${RESET}"

# Mostra filtro se foi passado algum cliente
if [[ -n "$CLIENTE_FILTRO" ]]; then
    echo -e "${CIANO}🎯 Filtrando por cliente:${RESET} ${BRANCO}$CLIENTE_FILTRO${RESET}"
else
    echo -e "${CIANO}🌐 Exibindo:${RESET} ${BRANCO}Todos os clientes${RESET}"
fi
echo ""

echo -e "${NEGRITO}LEGENDA:${RESET}"
echo -e "  ${VERDE}■${RESET} Normal (<100%)    ${AMARELO}■${RESET} Elevado (100-200%)    ${VERMELHO}■${RESET} Crítico (200-800%)    ${ROXO}■${RESET} TRAVADO (>800%)"
echo ""

# ==========================================================
# ARQUIVOS TEMPORÁRIOS
# ==========================================================

TEMP_FILE=$(mktemp)
HIGH_CPU_FILE=$(mktemp)

# ==========================================================
# COLETA DOS PROCESSOS - COM FILTRO OPCIONAL
# ==========================================================

declare -A APP_MAP
PIDS_LIST=""

echo -e "${NEGRITO}${UNDERLINE}PID     USER    COMMAND      %CPU    %MEM    APLICAÇÃO                          CONSUMO${RESET}"
echo "----------------------------------------------------------------------------------------------------------------"

# Coleta os processos com base no filtro
while IFS= read -r line; do
    PID=$(echo "$line" | awk '{print $2}')
    CMD=$(echo "$line" | cut -d' ' -f11-)
    
    # Verifica se é um processo Wildfly/JBoss
    if [[ "$CMD" =~ (/opt/(wildfly|jboss)_([^/]+)) ]]; then
        APP_NAME=$(basename "${BASH_REMATCH[1]}")
        
        # Se foi passado um filtro, verifica se o nome do cliente está no APP_NAME
        if [[ -n "$CLIENTE_FILTRO" ]]; then
            # Converte ambos para minúsculo para comparação case-insensitive
            APP_NAME_LOWER=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
            CLIENTE_FILTRO_LOWER=$(echo "$CLIENTE_FILTRO" | tr '[:upper:]' '[:lower:]')
            
            # Verifica se o APP_NAME contém o nome do cliente
            if [[ "$APP_NAME_LOWER" == *"$CLIENTE_FILTRO_LOWER"* ]]; then
                APP_MAP["$PID"]="$APP_NAME"
                PIDS_LIST+="$PID,"
            fi
        else
            # Sem filtro, adiciona todos
            APP_MAP["$PID"]="$APP_NAME"
            PIDS_LIST+="$PID,"
        fi
    fi
done < <(ps aux | grep java | grep -E '/opt/(wildfly|jboss)')

# Mostra quantos processos encontramos
TOTAL_ENCONTRADOS=$(echo "$PIDS_LIST" | tr ',' '\n' | grep -c '[0-9]')
echo -e "${CINZA}🔍 Total de processos Wildfly/JBoss encontrados: $TOTAL_ENCONTRADOS${RESET}"

PIDS_LIST="${PIDS_LIST%,}"

if [[ -z "$PIDS_LIST" ]]; then
    echo -e "${VERMELHO}❌ Nenhum processo Wildfly/JBoss encontrado.${RESET}"
    if [[ -n "$CLIENTE_FILTRO" ]]; then
        echo -e "${AMARELO}⚠️  Cliente '$CLIENTE_FILTRO' não encontrado ou não possui processos ativos.${RESET}"
        echo -e "${CIANO}💡 Clientes disponíveis:${RESET}"
        # Lista clientes únicos encontrados
        ps aux | grep java | grep -E '/opt/(wildfly|jboss)_' | sed -n 's/.*\/opt\/\(wildfly\|jboss\)_\([^\/]*\).*/\2/p' | sort -u | while read cliente; do
            echo -e "   • $cliente"
        done
    fi
    rm -f "$TEMP_FILE" "$HIGH_CPU_FILE"
    exit 0
fi

# ==========================================================
# COLETA TOP - PROCESSANDO EM LOTES DE 10 PIDS
# ==========================================================

echo -e "${CINZA}📊 Coletando métricas...${RESET}"

IFS=',' read -ra PID_ARRAY <<< "$PIDS_LIST"
TOTAL_PIDS=${#PID_ARRAY[@]}
LOTE_TAMANHO=10

> "$TEMP_FILE"

for ((i=0; i<TOTAL_PIDS; i+=LOTE_TAMANHO)); do
    LOTE_ATUAL=""
    for ((j=i; j<i+LOTE_TAMANHO && j<TOTAL_PIDS; j++)); do
        LOTE_ATUAL+="${PID_ARRAY[j]},"
    done
    LOTE_ATUAL="${LOTE_ATUAL%,}"
    
    echo -e "${CINZA}   Processando lote $((i/LOTE_TAMANHO + 1)) de $(( (TOTAL_PIDS + LOTE_TAMANHO - 1)/LOTE_TAMANHO ))...${RESET}"
    
    TOP_OUTPUT=$(top -b -n 1 -p "$LOTE_ATUAL" 2>/dev/null)
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+ ]]; then
            PID="${BASH_REMATCH[1]}"
            APP_NAME="${APP_MAP[$PID]}"
            
            if [[ -n "$APP_NAME" ]]; then
                CPU=$(echo "$line" | awk '{print $9}')
                MEM=$(echo "$line" | awk '{print $10}')
                USER=$(ps -o user= -p "$PID" 2>/dev/null | tr -d ' ')
                
                echo "$CPU $PID $USER $MEM $APP_NAME" >> "$TEMP_FILE"
                
                if command -v bc >/dev/null 2>&1; then
                    CPU_COMPARE=$(echo "$CPU > $CPU_LIMIT" | bc -l 2>/dev/null)
                    if (( CPU_COMPARE )); then
                        echo "$APP_NAME $CPU" >> "$HIGH_CPU_FILE"
                    fi
                else
                    if (( $(echo "$CPU" | cut -d. -f1) > $(echo "$CPU_LIMIT" | cut -d. -f1) )); then
                        echo "$APP_NAME $CPU" >> "$HIGH_CPU_FILE"
                    fi
                fi
            fi
        fi
    done <<< "$TOP_OUTPUT"
done

echo -e "\033[1A\033[2K"

# ==========================================================
# EXIBIÇÃO DOS PROCESSOS
# ==========================================================

if [[ -s "$TEMP_FILE" ]]; then
    TOTAL_COM_DADOS=$(wc -l < "$TEMP_FILE")
    
    sort -k1,1nr "$TEMP_FILE" | head -n $TOP_N | while read CPU PID USER MEM APP_NAME; do
        
        CPU_INT=$(echo "$CPU" | cut -d. -f1)
        
        if (( $(echo "$CPU > 800" | bc -l 2>/dev/null) )); then
            COR_TEXTO=$ROXO
        elif (( $(echo "$CPU > 200" | bc -l 2>/dev/null) )); then
            COR_TEXTO=$VERMELHO
        elif (( $(echo "$CPU > 100" | bc -l 2>/dev/null) )); then
            COR_TEXTO=$AMARELO
        else
            COR_TEXTO=$VERDE
        fi
        
        BARRA=$(criar_barra "$CPU_INT")
        
        printf "${COR_TEXTO}%-8s %-8s %-12s %-6s %-6s %-35s %s${RESET}\n" \
        "$PID" "$USER" "java" "$CPU" "$MEM" "$APP_NAME" "$BARRA"
        
    done
    
    if [[ $TOTAL_COM_DADOS -gt $TOP_N ]]; then
        echo -e "${CINZA}... e mais $((TOTAL_COM_DADOS - TOP_N)) processos não exibidos (total: $TOTAL_COM_DADOS)${RESET}"
    fi
else
    echo -e "${VERMELHO}❌ Não foi possível obter métricas dos processos.${RESET}"
fi

echo "----------------------------------------------------------------------------------------------------------------"

# ==========================================================
# PROCESSOS ACIMA DO LIMITE
# ==========================================================

declare -A HIGH_CPU_NODES
if [[ -s "$HIGH_CPU_FILE" ]]; then
    while IFS= read -r line; do
        APP_NAME=$(echo "$line" | awk '{print $1}')
        CPU=$(echo "$line" | awk '{print $2}')
        HIGH_CPU_NODES["$APP_NAME"]="$CPU"
    done < "$HIGH_CPU_FILE"
fi

# ==========================================================
# ESTATÍSTICAS
# ==========================================================

NORM=0; ELEV=0; CRIT=0; TRV=0

if [[ -s "$TEMP_FILE" ]]; then
    while IFS= read -r line; do
        CPU=$(echo "$line" | awk '{print $1}')
        if (( $(echo "$CPU > 800" | bc -l 2>/dev/null) )); then
            ((TRV++))
        elif (( $(echo "$CPU > 200" | bc -l 2>/dev/null) )); then
            ((CRIT++))
        elif (( $(echo "$CPU > 100" | bc -l 2>/dev/null) )); then
            ((ELEV++))
        else
            ((NORM++))
        fi
    done < "$TEMP_FILE"
fi

# ==========================================================
# ALERTA DE TRAVADOS
# ==========================================================

if [[ ${#HIGH_CPU_NODES[@]} -gt 0 ]]; then
    echo -e "\n${ROXO}${NEGRITO}🚨 ALERTA CRÍTICO - PROCESSOS TRAVADOS ACIMA DE $CPU_LIMIT%:${RESET}"
    echo -e "${ROXO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    for NODE in "${!HIGH_CPU_NODES[@]}"; do
        CPU_VAL=${HIGH_CPU_NODES[$NODE]}
        CPU_INT=$(echo "$CPU_VAL" | cut -d. -f1)
        BARRA=$(criar_barra "$CPU_INT")
        
        echo -e "${ROXO}⚠️  ${NEGRITO}${NODE}${RESET}${ROXO} está CONSUMINDO ${NEGRITO}$CPU_VAL%${RESET}${ROXO} de CPU${RESET}"
        echo -e "${ROXO}   Possível processo travado! Verificar imediatamente.${RESET} ${BARRA}"
        echo ""
    done
    
    echo -e "${AMARELO}💡 DICA: Para reiniciar, use: elawctl NOME_AMBIENTE restart${RESET}"
else
    echo -e "\n${VERDE}✅ Nenhum processo travado acima de $CPU_LIMIT%. Ambiente estável.${RESET}"
fi

# ==========================================================
# LIMPEZA
# ==========================================================

rm -f "$TEMP_FILE" "$HIGH_CPU_FILE"

# ==========================================================
# RODAPÉ
# ==========================================================

echo ""
echo -e "${AZUL}════════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${CIANO}📊 RESUMO:${RESET} ${VERDE}Normal: $NORM${RESET} | ${AMARELO}Elevado: $ELEV${RESET} | ${VERMELHO}Crítico: $CRIT${RESET} | ${ROXO}Travados: $TRV${RESET}"
echo -e "${AZUL}════════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${CIANO}✅ Script finalizado em $(date '+%H:%M:%S')${RESET}"

# Mostra dica de como usar o filtro
if [[ -z "$CLIENTE_FILTRO" ]]; then
    echo -e "${CINZA}💡 Dica: Use '$0 NOME_CLIENTE' para filtrar por um cliente específico${RESET}"
else
    echo -e "${CINZA}💡 Dica: Use '$0' sem parâmetros para ver todos os clientes${RESET}"
fi

echo -e "${CINZA}💡 Use 'watch -n 5 $0 $CLIENTE_FILTRO' para monitoramento contínuo${RESET}"
echo -e "${AZUL}════════════════════════════════════════════════════════════════════════════${RESET}"