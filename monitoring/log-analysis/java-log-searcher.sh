#!/usr/bin/env bash
###############################################################################
# Script: java-log-searcher.sh
#
# Descrição:
#   Script interativo para busca de termos em logs de ambientes Java
#   (WildFly / JBoss), facilitando troubleshooting.
#
# Objetivo:
#   Acelerar análise de erros em logs, permitindo busca rápida e direcionada
#   em múltiplos ambientes Java.
#
# Funcionamento:
#   - Detecta automaticamente diretórios em /opt (wildfly_* / jboss_*)
#   - Permite seleção interativa do ambiente
#   - Solicita termo de busca (default: "Caused by")
#   - Realiza busca no server.log
#   - Exibe resultado paginado com less
#
# Uso:
#   ./java-log-searcher.sh
#
# Requisitos:
#   - Linux
#   - grep
#   - less
#
# Observações:
#   - Ideal para análise de exceptions Java
#   - Mostra número da linha (-n)
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################

BASE_DIR="/opt"

echo "🔍 Buscando ambientes Java em $BASE_DIR..."

# =========================
# Coletar diretórios
# =========================
mapfile -t DIRS < <(ls -d $BASE_DIR/{wildfly_*,jboss_*} 2>/dev/null)

if [ ${#DIRS[@]} -eq 0 ]; then
    echo "❌ Nenhum ambiente encontrado."
    exit 1
fi

echo "✅ Ambientes encontrados:"
select DIR in "${DIRS[@]}"; do
    if [ -n "$DIR" ]; then
        LOG_PATH="$DIR/standalone/log/server.log"

        if [ ! -f "$LOG_PATH" ]; then
            echo "❌ Log não encontrado: $LOG_PATH"
            exit 1
        fi

        # =========================
        # Entrada do termo
        # =========================
        read -p "✏️  Termo de busca (default: Caused by): " TERMO
        TERMO=${TERMO:-Caused by}

        echo ""
        echo "🔎 Buscando por: '$TERMO'"
        echo "📂 Arquivo: $LOG_PATH"
        echo "------------------------------------------------------------"

        grep -iHn --color=always "$TERMO" "$LOG_PATH" | less -R

        echo "------------------------------------------------------------"
        echo "✅ Busca finalizada."
        break
    else
        echo "⚠️ Opção inválida."
    fi
done
