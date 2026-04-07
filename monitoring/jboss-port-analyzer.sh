#!/bin/bash
###############################################################################
# Script: jboss-port-analyzer.sh
#
# Descrição:
#   Ferramenta avançada para análise de portas em ambientes JBoss/WildFly.
#
#   O script identifica automaticamente os ambientes instalados em /opt,
#   calcula suas portas com base no offset configurado e realiza validações
#   completas de uso e conflitos.
#
# Funcionalidades:
#   - Listagem de ambientes e portas configuradas
#   - Verificação de portas em uso no sistema (ss)
#   - Detecção de conflitos de configuração (offset duplicado)
#   - Identificação de processos que estão utilizando portas
#   - Análise detalhada de uma porta específica
#   - Teste opcional de conectividade HTTP
#
# Objetivo:
#   Facilitar troubleshooting em ambientes com múltiplas instâncias JBoss,
#   reduzindo tempo de diagnóstico de conflitos de porta.
#
# Uso:
#   ./jboss-port-analyzer.sh
#   ./jboss-port-analyzer.sh --resumo
#   ./jboss-port-analyzer.sh --porta 8080
#   ./jboss-port-analyzer.sh --conflitos
#
# Requisitos:
#   - Linux
#   - ss (iproute2)
#   - curl (opcional para testes)
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################

export JAVA_HOME=/opt/java/jdk8
export PATH=$PATH:$JAVA_HOME/bin

APPLICATIONPATH="/opt"
VAR_IPSERVER=$(hostname -I | tr -d ' ')

echo "================================================================"
echo "           LISTA COMPLETA DE PORTAS - AMBIENTES JBOSS           "
echo "================================================================"
echo "Data/Hora: $(date '+%d/%m/%Y %H:%M:%S')"
echo "Host IP: $VAR_IPSERVER"
echo "Diretório Base: $APPLICATIONPATH"
echo "================================================================"
echo ""

# Função para verificar portas duplicadas
verificar_duplicatas() {
    echo ""
    echo "=== VERIFICAÇÃO DE PORTAS DUPLICADAS ==="
    
    declare -A PORTAS_MAP
    DUPLICATAS_ENCONTRADAS=0
    
    # Coleta todas as portas
    for AMBIENTE in $(find ${APPLICATIONPATH} -maxdepth 1 -type d \( -name "*wildfly*" -o -name "*jboss*" \) | sort); do
        NOME_AMBIENTE=$(basename $AMBIENTE)
        
        if [ -f "${AMBIENTE}/standalone/configuration/standalone.xml" ]; then
            VAR_OFFSET=$(grep -i offset ${AMBIENTE}/standalone/configuration/standalone.xml 2>/dev/null | grep -v '#' | cut -d ":" -f2 | cut -d"}" -f1 | tr -d '[:space:]')
            
            if [ -n "$VAR_OFFSET" ] && [[ "$VAR_OFFSET" =~ ^[0-9]+$ ]]; then
                VAR_PORTA=$((8080 + VAR_OFFSET))
                
                # Adiciona ao mapa de portas
                if [ -n "${PORTAS_MAP[$VAR_PORTA]}" ]; then
                    PORTAS_MAP[$VAR_PORTA]="${PORTAS_MAP[$VAR_PORTA]}, $NOME_AMBIENTE"
                    DUPLICATAS_ENCONTRADAS=1
                else
                    PORTAS_MAP[$VAR_PORTA]="$NOME_AMBIENTE"
                fi
            fi
        fi
    done
    
    # Verifica duplicatas
    if [ $DUPLICATAS_ENCONTRADAS -eq 0 ]; then
        echo -e "✓ \033[32mNenhuma porta duplicada encontrada\033[0m"
    else
        echo -e "⚠ \033[33mPORTAS DUPLICADAS ENCONTRADAS:\033[0m"
        
        for PORTA in $(printf '%s\n' "${!PORTAS_MAP[@]}" | sort -n); do
            AMBIENTES=${PORTAS_MAP[$PORTA]}
            # Verifica se há vírgula (indicando múltiplos ambientes)
            if [[ "$AMBIENTES" == *,* ]]; then
                echo -e "\033[31m● Porta $PORTA está configurada para múltiplos ambientes:\033[0m"
                echo "  $AMBIENTES"
                
                # Verifica qual está realmente em uso
                if ss -ltn 2>/dev/null | grep -q ":$PORTA "; then
                    echo -e "  \033[31mStatus: EM USO (conflito!)\033[0m"
                    
                    # Tenta identificar qual processo está usando
                    PID=$(ss -ltnp 2>/dev/null | grep ":$PORTA " | awk '{print $6}' | cut -d'=' -f2 | cut -d',' -f1 | head -n1)
                    if [ -n "$PID" ]; then
                        PROC=$(ps -p $PID -o comm= 2>/dev/null || echo "Desconhecido")
                        echo -e "  \033[33mProcesso atual usando a porta: $PROC (PID: $PID)\033[0m"
                    fi
                else
                    echo -e "  \033[32mStatus: LIVRE (mas conflito de configuração)\033[0m"
                fi
                echo ""
            fi
        done
    fi
}

# Função para listar portas
listar_portas() {
    # Encontra todos os diretórios que contenham wildfly ou jboss no nome
    AMBIENTES=$(find ${APPLICATIONPATH} -maxdepth 1 -type d \( -name "*wildfly*" -o -name "*jboss*" \) | sort)
    
    if [ -z "$AMBIENTES" ]; then
        echo "Nenhum ambiente JBoss/WildFly encontrado em $APPLICATIONPATH"
        echo "Diretórios disponíveis:"
        ls -la $APPLICATIONPATH/
        exit 1
    fi
    
    echo "Ambientes encontrados ($(echo "$AMBIENTES" | wc -l)):"
    echo ""
    
    # Primeiro, coletamos todas as portas para verificar duplicatas
    declare -A PORTAS_UNICAS
    declare -A CONFLITOS
    
    for AMBIENTE in $AMBIENTES; do
        NOME_AMBIENTE=$(basename $AMBIENTE)
        
        if [ -f "${AMBIENTE}/standalone/configuration/standalone.xml" ]; then
            VAR_OFFSET=$(grep -i offset ${AMBIENTE}/standalone/configuration/standalone.xml 2>/dev/null | grep -v '#' | cut -d ":" -f2 | cut -d"}" -f1 | tr -d '[:space:]')
            
            if [ -n "$VAR_OFFSET" ] && [[ "$VAR_OFFSET" =~ ^[0-9]+$ ]]; then
                VAR_PORTA=$((8080 + VAR_OFFSET))
                
                # Verifica se a porta já foi usada por outro ambiente
                if [ -n "${PORTAS_UNICAS[$VAR_PORTA]}" ]; then
                    CONFLITOS[$VAR_PORTA]="${PORTAS_UNICAS[$VAR_PORTA]}, $NOME_AMBIENTE"
                else
                    PORTAS_UNICAS[$VAR_PORTA]="$NOME_AMBIENTE"
                fi
            fi
        fi
    done
    
    # Cabeçalho da tabela
    printf "%-35s | %-6s | %-8s | %-15s | %s\n" "AMBIENTE" "PORTA" "OFFSET" "STATUS" "ACESSO"
    echo "------------------------------------------------------------------------------------------------"
    
    for AMBIENTE in $AMBIENTES; do
        NOME_AMBIENTE=$(basename $AMBIENTE)
        
        # Verifica se é um ambiente válido (tem standalone.xml)
        if [ -f "${AMBIENTE}/standalone/configuration/standalone.xml" ]; then
            # Obtém o offset
            VAR_OFFSET=$(grep -i offset ${AMBIENTE}/standalone/configuration/standalone.xml 2>/dev/null | grep -v '#' | cut -d ":" -f2 | cut -d"}" -f1 | tr -d '[:space:]')
            
            if [ -n "$VAR_OFFSET" ] && [[ "$VAR_OFFSET" =~ ^[0-9]+$ ]]; then
                # Calcula a porta
                VAR_PORTA=$((8080 + VAR_OFFSET))
                
                # Status base
                STATUS_COLOR=""
                STATUS_TEXT=""
                
                # Verifica se a porta está em uso no sistema
                if ss -ltn 2>/dev/null | grep -q ":$VAR_PORTA "; then
                    # Porta em uso
                    STATUS_COLOR="\033[31m"
                    
                    # Verifica se é duplicata
                    if [ -n "${CONFLITOS[$VAR_PORTA]}" ]; then
                        STATUS_TEXT="● EM USO (CONFLITO!)"
                    else
                        STATUS_TEXT="● EM USO"
                    fi
                else
                    # Porta livre
                    STATUS_COLOR="\033[32m"
                    
                    # Verifica se é duplicata
                    if [ -n "${CONFLITOS[$VAR_PORTA]}" ]; then
                        STATUS_TEXT="● LIVRE (CONFLITO)"
                        STATUS_COLOR="\033[33m"
                    else
                        STATUS_TEXT="● LIVRE"
                    fi
                fi
                
                # Imprime linha formatada
                printf "%-35s | %-6s | %-8s | ${STATUS_COLOR}%-15s\033[0m | \033[34mhttp://%s:%s\033[0m\n" \
                    "$NOME_AMBIENTE" "$VAR_PORTA" "$VAR_OFFSET" "$STATUS_TEXT" "$VAR_IPSERVER" "$VAR_PORTA"
                    
            else
                # Offset não encontrado ou inválido
                printf "%-35s | %-6s | %-8s | %-15s | %s\n" \
                    "$NOME_AMBIENTE" "N/A" "N/A" "● INVÁLIDO" "offset não encontrado"
            fi
        else
            # Não é um ambiente JBoss válido
            printf "%-35s | %-6s | %-8s | %-15s | %s\n" \
                "$NOME_AMBIENTE" "N/A" "N/A" "● INVÁLIDO" "sem standalone.xml"
        fi
    done
    
    # Mostra avisos de conflitos
    if [ ${#CONFLITOS[@]} -gt 0 ]; then
        echo ""
        echo -e "⚠ \033[33mAVISO: CONFLITOS DE PORTA DETECTADOS\033[0m"
        for PORTA in $(printf '%s\n' "${!CONFLITOS[@]}" | sort -n); do
            echo -e "  \033[31mPorta $PORTA: ${CONFLITOS[$PORTA]}\033[0m"
        done
    fi
}

# Função para mostrar resumo
mostrar_resumo() {
    echo ""
    echo "================================================================"
    echo "                      RESUMO DAS PORTAS                         "
    echo "================================================================"
    
    TOTAL_AMBIENTES=$(find ${APPLICATIONPATH} -maxdepth 1 -type d \( -name "*wildfly*" -o -name "*jboss*" \) | wc -l)
    
    # Conta portas em uso, livres e duplicadas
    PORTAS_EM_USO=0
    PORTAS_LIVRES=0
    PORTAS_DUPLICADAS=0
    declare -A PORTAS_VISTAS
    
    for AMBIENTE in $(find ${APPLICATIONPATH} -maxdepth 1 -type d \( -name "*wildfly*" -o -name "*jboss*" \) | sort); do
        if [ -f "${AMBIENTE}/standalone/configuration/standalone.xml" ]; then
            VAR_OFFSET=$(grep -i offset ${AMBIENTE}/standalone/configuration/standalone.xml 2>/dev/null | grep -v '#' | cut -d ":" -f2 | cut -d"}" -f1 | tr -d '[:space:]')
            if [ -n "$VAR_OFFSET" ] && [[ "$VAR_OFFSET" =~ ^[0-9]+$ ]]; then
                VAR_PORTA=$((8080 + VAR_OFFSET))
                
                # Verifica duplicidade
                if [ -n "${PORTAS_VISTAS[$VAR_PORTA]}" ]; then
                    ((PORTAS_DUPLICADAS++))
                else
                    PORTAS_VISTAS[$VAR_PORTA]=1
                fi
                
                # Verifica uso
                if ss -ltn 2>/dev/null | grep -q ":$VAR_PORTA "; then
                    ((PORTAS_EM_USO++))
                else
                    ((PORTAS_LIVRES++))
                fi
            fi
        fi
    done
    
    echo -e "Total de ambientes: $TOTAL_AMBIENTES"
    echo -e "Portas em uso: \033[31m$PORTAS_EM_USO\033[0m"
    echo -e "Portas livres: \033[32m$PORTAS_LIVRES\033[0m"
    
    if [ $PORTAS_DUPLICADAS -gt 0 ]; then
        echo -e "Conflitos de porta: \033[33m$PORTAS_DUPLICADAS\033[0m"
    fi
    
    echo ""
    
    # Lista portas em uso
    echo "Portas em uso:"
    for AMBIENTE in $(find ${APPLICATIONPATH} -maxdepth 1 -type d \( -name "*wildfly*" -o -name "*jboss*" \) | sort); do
        if [ -f "${AMBIENTE}/standalone/configuration/standalone.xml" ]; then
            VAR_OFFSET=$(grep -i offset ${AMBIENTE}/standalone/configuration/standalone.xml 2>/dev/null | grep -v '#' | cut -d ":" -f2 | cut -d"}" -f1 | tr -d '[:space:]')
            if [ -n "$VAR_OFFSET" ] && [[ "$VAR_OFFSET" =~ ^[0-9]+$ ]]; then
                VAR_PORTA=$((8080 + VAR_OFFSET))
                if ss -ltn 2>/dev/null | grep -q ":$VAR_PORTA "; then
                    NOME_AMBIENTE=$(basename $AMBIENTE)
                    echo -e "  \033[31m● $NOME_AMBIENTE: $VAR_PORTA\033[0m"
                fi
            fi
        fi
    done
    
    # Chama a função de verificação de duplicatas
    verificar_duplicatas
}

# Função para verificar uma porta específica
verificar_porta() {
    PORTA=$1
    
    echo ""
    echo "================================================================"
    echo "               VERIFICAÇÃO DETALHADA - PORTA $PORTA             "
    echo "================================================================"
    
    # Verifica uso no sistema
    echo -e "\n1. VERIFICAÇÃO DO SISTEMA:"
    if ss -ltn 2>/dev/null | grep -q ":$PORTA "; then
        echo -e "   Status: \033[31m● EM USO NO SISTEMA\033[0m"
        
        # Mostra detalhes do processo
        PID=$(ss -ltnp 2>/dev/null | grep ":$PORTA " | awk '{print $6}' | cut -d'=' -f2 | cut -d',' -f1 | head -n1)
        if [ -n "$PID" ]; then
            echo -e "   Processo usando a porta:"
            echo -e "   - PID: $PID"
            echo -e "   - Comando: $(ps -p $PID -o comm= 2>/dev/null || echo 'Desconhecido')"
            echo -e "   - Linha de comando completa:"
            ps -p $PID -o command= 2>/dev/null | head -n1 | sed 's/^/     /'
        fi
    else
        echo -e "   Status: \033[32m● LIVRE NO SISTEMA\033[0m"
    fi
    
    # Verifica configurações JBoss
    echo -e "\n2. CONFIGURAÇÕES JBOSS PARA ESTA PORTA:"
    
    AMBIENTES_CONFIGURADOS=()
    for AMBIENTE in $(find ${APPLICATIONPATH} -maxdepth 1 -type d \( -name "*wildfly*" -o -name "*jboss*" \) | sort); do
        NOME_AMBIENTE=$(basename $AMBIENTE)
        
        if [ -f "${AMBIENTE}/standalone/configuration/standalone.xml" ]; then
            VAR_OFFSET=$(grep -i offset ${AMBIENTE}/standalone/configuration/standalone.xml 2>/dev/null | grep -v '#' | cut -d ":" -f2 | cut -d"}" -f1 | tr -d '[:space:]')
            
            if [ -n "$VAR_OFFSET" ] && [[ "$VAR_OFFSET" =~ ^[0-9]+$ ]]; then
                VAR_PORTA_CALC=$((8080 + VAR_OFFSET))
                
                if [ "$VAR_PORTA_CALC" -eq "$PORTA" ]; then
                    AMBIENTES_CONFIGURADOS+=("$NOME_AMBIENTE (offset: $VAR_OFFSET)")
                fi
            fi
        fi
    done
    
    if [ ${#AMBIENTES_CONFIGURADOS[@]} -eq 0 ]; then
        echo "   Nenhum ambiente JBoss configurado para esta porta"
        echo "   Offset sugerido: $((PORTA - 8080))"
    elif [ ${#AMBIENTES_CONFIGURADOS[@]} -eq 1 ]; then
        echo -e "   ✓ \033[32m1 ambiente configurado:\033[0m"
        echo "   - ${AMBIENTES_CONFIGURADOS[0]}"
    else
        echo -e "   ⚠ \033[33mMÚLTIPLOS AMBIENTES CONFIGURADOS (CONFLITO!):\033[0m"
        for AMBIENTE in "${AMBIENTES_CONFIGURADOS[@]}"; do
            echo "   - $AMBIENTE"
        done
    fi
    
    # Informações de acesso
    echo -e "\n3. INFORMAÇÕES DE ACESSO:"
    echo -e "   URL: \033[34mhttp://$VAR_IPSERVER:$PORTA\033[0m"
    
    if ss -ltn 2>/dev/null | grep -q ":$PORTA "; then
        # Testa se responde (opcional - pode ser lento)
        echo -e "\n4. TESTE DE CONECTIVADE (opcional):"
        read -p "   Testar conexão com a porta? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            timeout 3 curl -s -I "http://$VAR_IPSERVER:$PORTA" > /tmp/curl_test_$PORTA 2>&1
            if [ $? -eq 0 ]; then
                echo -e "   ✓ \033[32mResponde à requisição HTTP\033[0m"
                head -n 5 /tmp/curl_test_$PORTA | sed 's/^/     /'

