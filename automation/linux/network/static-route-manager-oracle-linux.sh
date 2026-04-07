#!/bin/bash

#################################################################
# SCRIPT: STATIC ROUTE CONFIGURATOR V4 - "PERSISTÊNCIA TOTAL"
# AUTOR: Kleber Eduardo Maximo
# DATA: 18/03/2026
#
# DESCRIÇÃO:
# Script que CAPTURA TODAS as rotas existentes e as torna persistentes!
# - Rotas do script
# - Rotas manuais (adicionadas com ip route)
# - Rotas de outros administradores
# - Rotas de aplicações
#
# FUNCIONALIDADES NOVAS:
# - Captura TODAS as rotas da tabela de roteamento
# - Converte rotas temporárias em permanentes
# - Preserva gateway e interface corretas
# - Mantém consistência pós-reboot
#
#################################################################

set -eo pipefail

echo "======================================="
echo "Static Route Manager V4 - PERSISTÊNCIA TOTAL"
echo "Início: $(date)"
echo "======================================="

# =========================
# ROTAS DEFINIDAS NO SCRIPT
# =========================
# (você pode manter vazio se quiser apenas capturar as existentes)

ROUTES=(
"172.80.1.0/24 172.30.1.99"
"172.28.1.0/24 172.30.1.1"
"10.122.0.0/22 172.30.1.254"
"172.31.1.0/24 172.30.1.1"
"172.16.16.0/22 172.30.1.254"
"10.21.0.0/24 172.30.1.254"
"10.0.2.0/24 172.30.1.99"
"172.31.2.0/24 172.30.1.254"
)

# =========================
# CORES PARA OUTPUT
# =========================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# =========================
# DETECTAR DISTRO E INTERFACE
# =========================

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}❌ Não foi possível identificar a distribuição${NC}"
    exit 1
fi

echo -e "${GREEN}✔ Distro detectada: $DISTRO${NC}"

IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
if [[ -z "$IFACE" ]]; then
    echo -e "${RED}❌ Interface default não detectada${NC}"
    exit 1
fi

echo -e "${GREEN}✔ Interface detectada: $IFACE${NC}"

# =========================
# FUNÇÃO: CAPTURAR TODAS AS ROTAS
# =========================

capturar_todas_rotas() {
    echo ""
    echo -e "${BLUE}🔍 CAPTURANDO TODAS AS ROTAS DO SISTEMA...${NC}"
    
    # Array para armazenar TODAS as rotas
    ALL_ROUTES=()
    
    # Pega todas as rotas, excluindo:
    # - default gateway
    # - rotas locais da interface (kernel scope link)
    # - rotas multicast/broadcast
    while IFS= read -r line; do
        # Pula linhas vazias
        [[ -z "$line" ]] && continue
        
        # Pula default gateway
        [[ "$line" =~ ^default ]] && continue
        
        # Pula rotas locais da interface (scope link)
        [[ "$line" =~ scope\ link ]] && continue
        
        # Extrai rota no formato "destino via gateway"
        if [[ "$line" =~ ^([0-9./]+)\ via\ ([0-9.]+) ]]; then
            DEST="${BASH_REMATCH[1]}"
            GW="${BASH_REMATCH[2]}"
            ALL_ROUTES+=("$DEST $GW")
            echo -e "  ${GREEN}✔ Capturada: $DEST via $GW${NC}"
        fi
    done < <(ip route show)
    
    echo -e "${GREEN}📊 Total de rotas capturadas: ${#ALL_ROUTES[@]}${NC}"
}

# =========================
# FUNÇÃO: MERGE DE ROTAS (script + capturadas)
# =========================

merge_rotas() {
    echo ""
    echo -e "${PURPLE}🔄 FAZENDO MERGE DAS ROTAS...${NC}"
    
    # Usando associative array para garantir unicidade (por destino)
    declare -A MERGED_ROUTES
    
    # Primeiro, adiciona rotas do script (prioridade mais alta)
    echo -e "${BLUE}📋 Processando rotas do script:${NC}"
    for route in "${ROUTES[@]}"; do
        DEST=$(echo $route | awk '{print $1}')
        MERGED_ROUTES["$DEST"]="$route"
        echo -e "  ${CYAN}📌 Script: $route${NC}"
    done
    
    # Depois, adiciona rotas capturadas (não sobrescreve as do script)
    echo -e "${YELLOW}🌐 Processando rotas capturadas:${NC}"
    for route in "${ALL_ROUTES[@]}"; do
        DEST=$(echo $route | awk '{print $1}')
        if [[ -z "${MERGED_ROUTES[$DEST]}" ]]; then
            MERGED_ROUTES["$DEST"]="$route"
            echo -e "  ${GREEN}➕ Capturada (nova): $route${NC}"
        else
            echo -e "  ${YELLOW}⏩ Capturada (já existe no script): $route${NC}"
        fi
    done
    
    # Converte de volta para array
    FINAL_ROUTES=()
    for route in "${MERGED_ROUTES[@]}"; do
        FINAL_ROUTES+=("$route")
    done
    
    echo -e "${GREEN}📊 Total de rotas FINAIS: ${#FINAL_ROUTES[@]}${NC}"
}

# =========================
# FUNÇÃO: APLICAR PERSISTÊNCIA (por método)
# =========================

aplicar_persistencia() {
    echo ""
    echo -e "${BLUE}➡ APLICANDO PERSISTÊNCIA PARA TODAS AS ROTAS${NC}"
    
    case $METHOD in
        "NetworkManager")
            echo -e "${GREEN}✔ Usando NetworkManager${NC}"
            
            CON_NAME=$(nmcli -t -f NAME,DEVICE connection show --active | grep ":$IFACE" | cut -d: -f1)
            
            if [[ -z "$CON_NAME" ]]; then
                echo -e "${RED}❌ Conexão NetworkManager não encontrada${NC}"
                return 1
            fi
            
            # Limpa rotas existentes
            nmcli connection modify "$CON_NAME" ipv4.routes ""
            
            # Adiciona TODAS as rotas finais
            for route in "${FINAL_ROUTES[@]}"; do
                DEST=$(echo $route | awk '{print $1}')
                GW=$(echo $route | awk '{print $2}')
                nmcli connection modify "$CON_NAME" +ipv4.routes "$DEST $GW"
                echo -e "  ${GREEN}✔ Persistida: $DEST via $GW${NC}"
            done
            
            nmcli connection up "$CON_NAME"
            ;;
            
        "Netplan")
            echo -e "${GREEN}✔ Usando Netplan${NC}"
            
            NETPLAN_FILE=$(ls /etc/netplan/*.yaml | head -n1)
            BACKUP="${NETPLAN_FILE}.bak.$(date +%F-%H%M%S)"
            cp "$NETPLAN_FILE" "$BACKUP"
            
            # Remove configurações de rotas existentes
            sed -i '/routes:/,/^[^ ]/d' "$NETPLAN_FILE"
            
            # Adiciona TODAS as rotas
            for route in "${FINAL_ROUTES[@]}"; do
                DEST=$(echo $route | awk '{print $1}')
                GW=$(echo $route | awk '{print $2}')
                sed -i "/$IFACE:/a\      routes:\n        - to: $DEST\n          via: $GW" "$NETPLAN_FILE"
                echo -e "  ${GREEN}✔ Persistida: $DEST via $GW${NC}"
            done
            
            netplan apply
            ;;
            
        "network-scripts")
            echo -e "${GREEN}✔ Usando network-scripts${NC}"
            
            ROUTE_FILE="/etc/sysconfig/network-scripts/route-$IFACE"
            
            # Cria novo arquivo
            echo "# Rotas persistentes para $IFACE" > "$ROUTE_FILE"
            echo "# Criado em: $(date)" >> "$ROUTE_FILE"
            echo "# Gerenciado por: Static Route Manager V4" >> "$ROUTE_FILE"
            echo "" >> "$ROUTE_FILE"
            
            # Adiciona TODAS as rotas
            for route in "${FINAL_ROUTES[@]}"; do
                DEST=$(echo $route | awk '{print $1}')
                GW=$(echo $route | awk '{print $2}')
                echo "$DEST via $GW dev $IFACE" >> "$ROUTE_FILE"
                echo -e "  ${GREEN}✔ Persistida: $DEST via $GW${NC}"
            done
            
            # Reinicia rede
            if command -v systemctl >/dev/null 2>&1; then
                systemctl restart NetworkManager 2>/dev/null || systemctl restart network 2>/dev/null
            else
                service network restart 2>/dev/null
            fi
            ;;
    esac
}

# =========================
# FUNÇÃO: VALIDAÇÃO FINAL
# =========================

validar_rotas() {
    echo ""
    echo -e "${BLUE}📊 VALIDAÇÃO FINAL:${NC}"
    echo -e "${CYAN}Rotas que DEVERIAM existir:${NC}"
    
    MISSING=0
    for route in "${FINAL_ROUTES[@]}"; do
        DEST=$(echo $route | awk '{print $1}')
        GW=$(echo $route | awk '{print $2}')
        
        if ip route | grep -q "$DEST via $GW"; then
            echo -e "  ${GREEN}✔ OK: $DEST via $GW${NC}"
        else
            echo -e "  ${RED}❌ FALTOU: $DEST via $GW${NC}"
            MISSING=$((MISSING + 1))
        fi
    done
    
    echo ""
    echo -e "${PURPLE}Rotas EXTRAS encontradas:${NC}"
    while IFS= read -r line; do
        if [[ "$line" =~ ^([0-9./]+)\ via\ ([0-9.]+) ]]; then
            DEST="${BASH_REMATCH[1]}"
            GW="${BASH_REMATCH[2]}"
            
            found=0
            for route in "${FINAL_ROUTES[@]}"; do
                if [[ "$route" == "$DEST $GW" ]]; then
                    found=1
                    break
                fi
            done
            
            if [[ $found -eq 0 ]]; then
                echo -e "  ${YELLOW}⚠ Extra: $line${NC}"
            fi
        fi
    done < <(ip route show | grep -v "default\|scope link")
    
    if [[ $MISSING -eq 0 ]]; then
        echo -e "${GREEN}✅ VALIDAÇÃO OK: Todas as rotas estão presentes!${NC}"
    else
        echo -e "${RED}❌ VALIDAÇÃO FALHOU: $MISSING rotas faltando${NC}"
    fi
}

# =========================
# EXECUÇÃO PRINCIPAL
# =========================

# PASSO 1: Capturar TODAS as rotas existentes
capturar_todas_rotas

# PASSO 2: Fazer merge com rotas do script
merge_rotas

# PASSO 3: Detectar método de persistência
if command -v nmcli >/dev/null 2>&1; then
    METHOD="NetworkManager"
elif command -v netplan >/dev/null 2>&1; then
    METHOD="Netplan"
elif [ -d /etc/sysconfig/network-scripts ]; then
    METHOD="network-scripts"
else
    echo -e "${RED}❌ Método de persistência não suportado${NC}"
    exit 1
fi

# PASSO 4: Aplicar persistência para TODAS as rotas
aplicar_persistencia

# PASSO 5: Validar resultado
validar_rotas

# =========================
# RESUMO FINAL
# =========================
echo ""
echo "======================================="
echo -e "${GREEN}✅ OPERAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo "======================================="
echo -e "📊 Estatísticas:"
echo -e "  • Rotas no script: ${#ROUTES[@]}"
echo -e "  • Rotas capturadas do sistema: ${#ALL_ROUTES[@]}"
echo -e "  • Rotas finais (após merge): ${#FINAL_ROUTES[@]}"
echo -e "  • Método usado: $METHOD"
echo -e "  • Interface: $IFACE"
echo "======================================="
