#!/bin/bash
# ==========================================================
# SCRIPT: TMP CLEAN SAFE MODE
# AUTOR: Kleber Eduardo Maximo
# DATA: 26/02/2026
# VERSAO: 1.0
# ==========================================================
#
# DESCRICAO:
# Este script realiza a limpeza CONTROLADA do diretório /tmp.
#
# FUNCIONAMENTO:
# - Executa a cada 2 horas via crontab
# - Remove arquivos com mais de 30 minutos de idade
# - ANTES de remover, verifica se o arquivo está em uso por algum processo
# - Caso esteja em uso → NÃO remove (protege aplicações)
# - Caso NÃO esteja em uso → remove para liberar espaço
#
# REGRAS DE SEGURANÇA:
# - Ignora pontos de montagem do tipo /tmp/.mount_*
# - Atua apenas em arquivos (não remove diretórios)
# - Não atravessa outros filesystems montados em /tmp
#
# LOG:
# - Não gera log em arquivo
# - Lista no STDOUT os arquivos removidos (visível no histórico do CRON)
#
# ==========================================================

AGE_MINUTES=30

find /tmp \
    -xdev \
    -type f \
    -mmin +${AGE_MINUTES} \
    -not -path "/tmp/.mount_*" \
    \( -iname "*.doc" -o -iname "*.docx" \
    -o -iname "*.xls" -o -iname "*.xlsx" \
    -o -iname "*.pdf" -o -iname "*.txt" \
    -o -iname "*.jpg" -o -iname "*.jpeg" \
    -o -iname "*.png" -o -iname "*.zip" \
    -o -iname "*.rtf" -o -iname "*.odt" \
    -o -iname "*.eml" -o -iname "*.msg" \
    -o -iname "*.wav" \) \
    ! -exec fuser -s {} \; \
    -print -delete 2>/dev/null