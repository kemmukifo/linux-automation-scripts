#!/bin/bash
###############################################################################
# Script: java_net_usage.sh
#
# Descrição:
#   Script para monitoramento de consumo de banda de rede por ambiente Java
#   (WildFly/JBoss), utilizando coleta REAL baseada na ferramenta nethogs.
#
#   O script identifica automaticamente todos os processos Java ativos na VM,
#   correlaciona cada PID ao seu respectivo ambiente (via -Djboss.home.dir)
#   e consolida o consumo de rede por ambiente.
#
# Objetivo:
#   Fornecer uma visão clara e objetiva de quais ambientes estão consumindo
#   banda de rede na VM, permitindo análise de:
#
#     - Alto consumo de rede (download/upload)
#     - Distribuição de tráfego entre ambientes
#     - Identificação de possíveis gargalos ou anomalias
#
# Funcionamento:
#   - Detecta automaticamente a interface de rede ativa
#   - Mapeia processos Java para seus respectivos ambientes
#   - Coleta tráfego em tempo real com nethogs
#   - Agrupa e converte os dados para MB/s
#   - Exibe resultado formatado e ordenado por consumo
#
# Parâmetros:
#   O script aceita um parâmetro opcional que define o tempo de coleta:
#
#     ./java_net_usage.sh 10
#     ./java_net_usage.sh 20
#
#   Caso nenhum valor seja informado, será utilizado o padrão de 10 segundos.
#
#   Quanto maior o intervalo:
#     - Mais precisa será a média de consumo
#     - Melhor a comparação com ferramentas como Zabbix
#
# Requisitos:
#   - Executar como root
#   - nethogs instalado na máquina
#   - bc instalado
#
# Observações:
#   - Os valores apresentados representam média de consumo durante o período
#     de coleta, e não necessariamente o pico instantâneo
#   - Pode haver pequenas diferenças em relação ao Zabbix devido a overhead
#     de kernel e tráfego não associado diretamente a processos
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-06
# Versão: 3.2 (Final - Produção)
###############################################################################
#!/bin/bash

# Cores ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Função para verificar e instalar dependências
check_dependencies() {
    local missing_deps=()
    local to_install=()
    
    echo -e "${CYAN}================================================================"
    echo -e "        VERIFICANDO DEPENDÊNCIAS"
    echo -e "================================================================${NC}"
    
    # Verificar nethogs
    if ! command -v nethogs &> /dev/null; then
        missing_deps+=("nethogs")
        to_install+=("nethogs")
        echo -e "${RED}❌ nethogs não encontrado${NC}"
    else
        echo -e "${GREEN}✅ nethogs encontrado${NC}"
    fi
    
    # Verificar bc
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
        to_install+=("bc")
        echo -e "${RED}❌ bc não encontrado${NC}"
    else
        echo -e "${GREEN}✅ bc encontrado${NC}"
    fi
    
    # Verificar timeout (geralmente já vem instalado)
    if ! command -v timeout &> /dev/null; then
        echo -e "${YELLOW}⚠️ timeout não encontrado (usando fallback)${NC}"
    else
        echo -e "${GREEN}✅ timeout encontrado${NC}"
    fi
    
    # Se faltar dependências, perguntar se quer instalar
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Dependências faltando: ${missing_deps[*]}${NC}"
        echo ""
        read -p "Deseja instalar as dependências automaticamente? (s/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            # Detectar gerenciador de pacotes
            if command -v apt-get &> /dev/null; then
                echo -e "${CYAN}📦 Usando apt-get (Debian/Ubuntu)...${NC}"
                sudo apt-get update
                sudo apt-get install -y ${to_install[@]}
            elif command -v yum &> /dev/null; then
                echo -e "${CYAN}📦 Usando yum (RHEL/CentOS)...${NC}"
                sudo yum install -y epel-release
                sudo yum install -y ${to_install[@]}
            elif command -v dnf &> /dev/null; then
                echo -e "${CYAN}📦 Usando dnf (Fedora)...${NC}"
                sudo dnf install -y ${to_install[@]}
            elif command -v zypper &> /dev/null; then
                echo -e "${CYAN}📦 Usando zypper (OpenSUSE)...${NC}"
                sudo zypper install -y ${to_install[@]}
            else
                echo -e "${RED}❌ Não foi possível detectar o gerenciador de pacotes${NC}"
                echo -e "${YELLOW}Por favor, instale manualmente: ${to_install[*]}${NC}"
                exit 1
            fi
            
            # Verificar novamente se instalou corretamente
            local still_missing=()
            for dep in ${missing_deps[@]}; do
                if ! command -v $dep &> /dev/null; then
                    still_missing+=($dep)
                fi
            done
            
            if [ ${#still_missing[@]} -gt 0 ]; then
                echo -e "${RED}❌ Ainda faltando: ${still_missing[*]}${NC}"
                echo -e "${YELLOW}Por favor, instale manualmente e execute novamente${NC}"
                exit 1
            else
                echo -e "${GREEN}✅ Todas as dependências instaladas com sucesso!${NC}"
            fi
        else
            echo -e "${RED}❌ Dependências necessárias não instaladas. Saindo...${NC}"
            echo -e "${YELLOW}Instale manualmente: sudo apt-get install ${to_install[*]}${NC}"
            echo -e "${YELLOW}Ou: sudo yum install ${to_install[*]}${NC}"
            exit 1
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✅ Todas as dependências estão OK!${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# Verificar se está rodando como root (nethogs precisa)
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Este script precisa ser executado como root (sudo)${NC}"
    echo -e "${YELLOW}Execute: sudo $0${NC}"
    exit 1
fi

# Chamar verificação de dependências
check_dependencies

INTERVAL=${1:-10}

echo -e "${CYAN}================================================================"
echo -e "        MONITOR DE BANDA POR AMBIENTE JAVA (MB/s)"
echo -e "        Intervalo de coleta: ${INTERVAL}s"
echo -e "================================================================${NC}"

# Detectar interface
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo -e "Interface detectada: ${BOLD}$IFACE${NC}"
echo ""

# Mapear Java -> ambiente
declare -A pid_env

echo "Mapeando ambientes Java..."

for pid in $(ps aux | awk '/[j]ava/ {print $2}'); do
    if [ -r "/proc/$pid/cmdline" ]; then
        cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
        
        if [[ "$cmdline" =~ -Djboss\.home\.dir=([^[:space:]]+) ]]; then
            pid_env[$pid]="${BASH_REMATCH[1]}"
        elif [[ "$cmdline" =~ -Dcatalina\.base=([^[:space:]]+) ]]; then
            pid_env[$pid]="${BASH_REMATCH[1]}"
        else
            pid_env[$pid]=$(readlink -f /proc/$pid/cwd 2>/dev/null)
        fi
    fi
done

echo -e "${GREEN}✅ ${#pid_env[@]} processos Java encontrados${NC}"
echo ""

