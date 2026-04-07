#!/bin/bash
#
# Script: verifica_instancias.sh
# Autor: Kleber Maximo
# Criado em: 24/04/2025
# Descrição: Verifica a memória alocada (Xms, Xmx) e o uso de CPU/memória das instâncias JBoss/Wildfly.
#
# Funcionalidades:
# - Verificação do uso de memória e CPU das instâncias ativas
# - Cálculo de diferença entre memória alocada e memória real usada
# - Relatório completo do estado das instâncias
# - Sugestões de ajuste de memória, se necessário
#
# Uso: ./verifica_instancias.sh
#
# Observações:
# - Este script busca as instâncias JBoss/Wildfly no diretório /opt
# - Requer permissão para acessar as instâncias e seus arquivos de configuração


echo "🔍 Verificando instâncias JBoss/Wildfly..."

AMBIENTES=$(ls /opt/ 2>/dev/null | grep -i 'jboss\|wildfly' | grep -iv 'disabled\|default\|rollback\|migrated')
TOTALMEMORY=0

for AMB in ${AMBIENTES}; do
  # Pega o Xmx configurado
  XMX=$(grep "Xmx" /opt/${AMB}/bin/standalone.conf 2>/dev/null | cut -d"-" -f3 | sed 's/[a-zA-Z]//g')
  [ -z "${XMX}" ] && XMX=0
  TOTALMEMORY=$(awk "BEGIN {print ${TOTALMEMORY}+${XMX}}")
  XMX_GB=$(awk "BEGIN {printf \"%.2f\", ${XMX}/1000}")

  # Pega o PID da instância
  PID=$(pgrep -f "/opt/${AMB}/jboss-modules.jar")
  if [ -n "$PID" ]; then
    CPU=$(top -n 1 -b -p "$PID" | awk 'NR>7 {print $9}')
    MEM_RAW=$(top -n 1 -b -p "$PID" | awk 'NR>7 {print $6}')

    # Converte MEM_RAW para GB
    if [[ "$MEM_RAW" =~ [gG]$ ]]; then
      MEM_GB=$(echo "$MEM_RAW" | sed 's/[gG]//' | awk '{printf "%.2f", $1}')
    elif [[ "$MEM_RAW" =~ [mM]$ ]]; then
      MEM_GB=$(echo "$MEM_RAW" | sed 's/[mM]//' | awk '{printf "%.2f", $1/1000}')
    elif [[ "$MEM_RAW" =~ [kK]$ ]]; then
      MEM_GB=$(echo "$MEM_RAW" | sed 's/[kK]//' | awk '{printf "%.2f", $1/1000000}')
    else
      MEM_GB=$(awk "BEGIN {printf \"%.2f\", ${MEM_RAW}/1000000}")
    fi

    # Calcula a diferença: Xmx - MEM usada
    DIF=$(awk "BEGIN {printf \"%.2f\", ${MEM_GB}-${XMX_GB}}")
  else
    CPU="N/A"
    MEM_GB="N/A"
    PID="N/A"
    DIF="N/A"
  fi

  echo "-----------------------------"
  echo "🔧 Ambiente: $AMB"
  echo "🔢 Memória alocada: ${XMX_GB} GB"
  echo "📛 PID: $PID"
  echo "🧮 CPU: $CPU%"
  echo "💾 MEM usada: $MEM_GB GB"
  echo "💥 Excedendo: $DIF GB"
done

TOTALMEMORY_GB=$(awk "BEGIN {printf \"%.2f\", ${TOTALMEMORY}/1000}")
SYSMEMORY=$(free -h | awk '/Mem/{print $2}')

echo ""
echo "🧠 Total de memória alocada aos ambientes: ${TOTALMEMORY_GB} GB"
echo "🖥️  Memória total do servidor: ${SYSMEMORY}"
