#!/usr/bin/env bash
###############################################################################
# Script: java-memory-tuner.sh
#
# Descrição:
#   Script interativo para ajuste de memória em ambientes Java
#   (WildFly / JBoss), alterando parâmetros de:
#
#     - Heap inicial (-Xms)
#     - Heap máximo (-Xmx)
#     - Metaspace (-XX:MetaspaceSize / MaxMetaspaceSize)
#
# Objetivo:
#   Facilitar o tuning de memória em ambientes Java de forma segura,
#   rápida e padronizada, evitando edição manual de arquivos.
#
# Funcionamento:
#   - Detecta automaticamente ambientes em /opt (wildfly_* / jboss_*)
#   - Permite seleção interativa do ambiente
#   - Identifica valores atuais de memória
#   - Solicita novos valores em GB (conversão automática para MB)
#   - Atualiza o arquivo standalone.conf
#   - Opcionalmente reinicia o serviço via elawctl
#
# Uso:
#   ./java-memory-tuner.sh
#
# Requisitos:
#   - Permissão de escrita no arquivo standalone.conf
#   - Ferramentas: grep, sed, bash
#   - Comando elawctl (opcional para restart)
#
# Observações:
#   - Realiza substituição direta no arquivo (não cria backup)
#   - Recomenda-se validar ambiente antes da execução
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################

clear
echo "🔍 Buscando ambientes disponíveis em /opt..."

# =========================
# Detectar ambientes
# =========================
AMBIENTES=(/opt/wildfly_* /opt/jboss_*)

if [ ${#AMBIENTES[@]} -eq 0 ]; then
    echo "❌ Nenhum ambiente encontrado com prefixo wildfly_ ou jboss_."
    exit 1
fi

echo "Ambientes encontrados:"
select DESTINO in "${AMBIENTES[@]}"; do
    if [ -n "$DESTINO" ]; then
        break
    else
        echo "⚠️ Opção inválida. Tente novamente."
    fi
done

STANDALONE_CONF="$DESTINO/bin/standalone.conf"

if [ ! -f "$STANDALONE_CONF" ]; then
    echo "❌ Arquivo não encontrado: $STANDALONE_CONF"
    exit 1
fi

# =========================
# Capturar valores atuais
# =========================
XMS_ATUAL=$(grep -oP -- '-Xms\K[0-9]+(?=m)' "$STANDALONE_CONF" | head -1)
XMX_ATUAL=$(grep -oP -- '-Xmx\K[0-9]+(?=m)' "$STANDALONE_CONF" | head -1)
METASPACE_ATUAL=$(grep -oP -- '-XX:MetaspaceSize=\K[0-9]+' "$STANDALONE_CONF" | head -1)

echo "📊 Configurações atuais:"
echo "  - Xms: ${XMS_ATUAL:-N/A} MB"
echo "  - Xmx: ${XMX_ATUAL:-N/A} MB"
echo "  - Metaspace: ${METASPACE_ATUAL:-N/A} MB"

# =========================
# Entrada de nova memória
# =========================
read -p "💾 Quantos GB deseja alocar de RAM? (ex: 4): " GB_RAM

if ! [[ "$GB_RAM" =~ ^[0-9]+$ ]]; then
    echo "❌ Valor inválido."
    exit 1
fi

RAM_MB=$((GB_RAM * 1024))

# =========================
# Metaspace
# =========================
AJUSTAR_METASPACE=false

if [ -z "$METASPACE_ATUAL" ] || [ "$METASPACE_ATUAL" -lt 1024 ]; then
    echo "⚠️ Metaspace baixo ou não configurado."
    read -p "Deseja ajustar o Metaspace? (s/N): " RESP
    if [[ "$RESP" =~ ^[sS]$ ]]; then
        read -p "Quantos GB para Metaspace? (ex: 1): " GB_META
        NOVO_METASPACE_MB=$((GB_META * 1024))
        AJUSTAR_METASPACE=true
    fi
else
    read -p "Deseja alterar o Metaspace atual (${METASPACE_ATUAL}MB)? (s/N): " RESP
    if [[ "$RESP" =~ ^[sS]$ ]]; then
        read -p "Quantos GB para Metaspace? (ex: 1): " GB_META
        NOVO_METASPACE_MB=$((GB_META * 1024))
        AJUSTAR_METASPACE=true
    fi
fi

# =========================
# Backup (AGORA TEM 😏)
# =========================
cp "$STANDALONE_CONF" "${STANDALONE_CONF}.bak"
echo "📁 Backup criado: ${STANDALONE_CONF}.bak"

# =========================
# Aplicar alterações
# =========================
sed -i \
    -e "s|-Xms[0-9]*m|-Xms${RAM_MB}m|g" \
    -e "s|-Xmx[0-9]*m|-Xmx${RAM_MB}m|g" \
    "$STANDALONE_CONF"

echo "🔧 Heap configurado para ${RAM_MB}MB"

if [ "$AJUSTAR_METASPACE" = true ]; then
    sed -i \
        -e "s|-XX:MetaspaceSize=[0-9]*m|-XX:MetaspaceSize=${NOVO_METASPACE_MB}m|g" \
        -e "s|-XX:MaxMetaspaceSize=[0-9]*m|-XX:MaxMetaspaceSize=${NOVO_METASPACE_MB}m|g" \
        "$STANDALONE_CONF"

    echo "🔧 Metaspace configurado para ${NOVO_METASPACE_MB}MB"
fi

# =========================
# Restart
# =========================
read -p "🔄 Deseja reiniciar o ambiente agora? (s/N): " RESTART

if [[ "$RESTART" =~ ^[sS]$ ]]; then
    NOME=$(basename "$DESTINO")
    echo "Reiniciando $NOME..."
    elawctl "$NOME" restart
else
    echo "ℹ️ Reinício não realizado."
fi

echo "✅ Finalizado."
