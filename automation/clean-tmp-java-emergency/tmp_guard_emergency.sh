#!/bin/bash
# ==========================================================
# SCRIPT: TMP GUARD EMERGENCY MODE
# AUTOR: Kleber Eduardo Maximo
# DATA: $(date +%d/%m/%Y)
# VERSAO: 1.0
# ==========================================================
#
# DESCRICAO:
# Este script monitora o uso do diretório /tmp e executa
# limpeza EMERGENCIAL quando o espaço entra em estado crítico.
#
# FUNCIONAMENTO:
# - Executa a cada 30 minutos via crontab
# - Verifica duas condições:
#     1) Uso do /tmp >= 90%
#     2) Espaço livre <= 12GB
#
# SE QUALQUER UMA DAS CONDIÇÕES FOR VERDADEIRA:
# → Entra em MODO EMERGÊNCIA
# → Remove TODOS os arquivos com mais de 10 minutos
# → NÃO verifica se estão em uso (liberação imediata de espaço)
#
# SE NENHUMA CONDIÇÃO FOR ATINGIDA:
# → Não executa nenhuma limpeza
#
# REGRAS:
# - Não atravessa outros filesystems
# - Ignora diretórios /tmp/.mount_*
# - Atua somente em arquivos
#
# LOG:
# - Não grava em arquivo
# - Mostra saída padrão para histórico do CRON
#
# ==========================================================

# Limites de segurança
LIMIT_PCT=90          # percentual de uso crítico
LIMIT_FREE_GB=12      # espaço livre mínimo aceitável (GB)
AGE_CRITICAL=10       # idade mínima para remoção em modo emergência (minutos)

# Coleta uso em %
TMP_PCT=$(df /tmp --output=pcent | tail -1 | tr -cd '0-9')

# Coleta espaço livre em GB
TMP_FREE_GB=$(df -BG /tmp --output=avail | tail -1 | tr -cd '0-9')

# Loga estado atual no STDOUT
echo "[$(date)] CHECK TMP -> uso=${TMP_PCT}% | livre=${TMP_FREE_GB}GB"

# Verifica condição de emergência
if [ "$TMP_PCT" -ge "$LIMIT_PCT" ] || [ "$TMP_FREE_GB" -le "$LIMIT_FREE_GB" ]; then

    echo "[$(date)] 🚨 MODO EMERGÊNCIA ATIVADO - limpeza agressiva iniciada"

    # Remove arquivos sem verificar uso (ação emergencial)
    find /tmp -xdev -type f -mmin +${AGE_CRITICAL} \
        -not -path "/tmp/.mount_*" \
        -print -delete 2>/dev/null

    echo "[$(date)] ✅ limpeza emergencial finalizada"

else
    echo "[$(date)] 👍 TMP dentro do limite - nenhuma ação necessária"
fi

# FIM DO SCRIPT
# ==========================================================