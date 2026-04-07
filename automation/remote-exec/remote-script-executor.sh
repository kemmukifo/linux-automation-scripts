#!/usr/bin/env bash
###############################################################################
# Script: remote-script-executor.sh
#
# Descrição:
#   Script para execução remota de comandos/scripts em múltiplos servidores
#   via SSH, de forma automatizada.
#
#   Permite enviar e executar um script local em diversos hosts remotos,
#   facilitando operações em massa como:
#
#     - Configuração de rotas
#     - Atualizações de sistema
#     - Execução de rotinas administrativas
#     - Padronização de ambientes
#
# Objetivo:
#   Reduzir esforço manual e padronizar execuções remotas em múltiplos
#   servidores simultaneamente.
#
# Funcionamento:
#   - Lê lista de IPs definida no script
#   - Utiliza SSH para conectar em cada host
#   - Executa o script remoto via stdin (sem necessidade de cópia prévia)
#   - Retorna status de sucesso ou falha por host
#
# Parâmetros:
#   ./remote-script-executor.sh <usuario> <script>
#
# Exemplo:
#   ./remote-script-executor.sh ubuntu /opt/scripts/set_routes.sh
#
# Requisitos:
#   - Acesso SSH configurado (preferencialmente com chave)
#   - Permissão sudo no host remoto
#
# Observações:
#   - O script remoto será executado com sudo
#   - Certifique-se que o usuário possui permissões adequadas
#   - Timeout de conexão configurado para evitar travamentos
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################

# =========================
# Validação de parâmetros
# =========================
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ Uso: $0 <usuario> <caminho_script>"
    echo "Exemplo: $0 ubuntu /opt/scripts/set_routes.sh"
    exit 1
fi

USER="$1"
SCRIPT="$2"

# =========================
# Lista de servidores
# =========================
IPS=(
172.30.1.17
172.30.1.39
172.30.1.61
172.30.1.12
172.30.1.25
172.30.1.34
172.30.1.63
)

# =========================
# Valida script local
# =========================
if [ ! -f "$SCRIPT" ]; then
    echo "❌ Script não encontrado: $SCRIPT"
    exit 1
fi

echo "=================================================="
echo "🚀 EXECUÇÃO REMOTA EM MÚLTIPLOS HOSTS"
echo "ORIGEM: $(hostname) - $(hostname -I)"
echo "USUÁRIO: $USER"
echo "SCRIPT: $SCRIPT"
echo "=================================================="

SUCCESS=0
FAIL=0

for IP in "${IPS[@]}"
do
    echo ""
    echo ">>> Conectando em $IP..."

    ssh -o ConnectTimeout=5 -o BatchMode=yes ${USER}@${IP} 'sudo bash -s' < "$SCRIPT"

    if [ $? -eq 0 ]; then
        echo "✅ $IP - SUCESSO"
        ((SUCCESS++))
    else
        echo "❌ $IP - FALHA"
        ((FAIL++))
    fi
done

echo ""
echo "=================================================="
echo "📊 RESUMO FINAL"
echo "✔️ Sucesso: $SUCCESS"
echo "❌ Falhas : $FAIL"
echo "=================================================="
