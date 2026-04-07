###############################################################################
# Script: exchange-mailbox-cleaner.ps1
#
# Descrição:
#   Script para limpeza de e-mails em caixas do Exchange Online utilizando
#   Compliance Search e purge definitivo.
#
# Objetivo:
#   Automatizar a remoção de e-mails em pastas específicas, como:
#     - TO_BE_DELETED
#     - DeletedItems
#
# Funcionamento:
#   - Conecta ao Exchange Online
#   - Solicita a mailbox alvo
#   - Cria Compliance Search por pasta
#   - Aguarda conclusão da busca
#   - Executa purge permanente
#
# Uso:
#   ./exchange-mailbox-cleaner.ps1
#
# Requisitos:
#   - Módulo ExchangeOnlineManagement
#   - Permissão adequada (Compliance / eDiscovery)
#
# Observações:
#   - A remoção é PERMANENTE (não recuperável)
#   - Utilize com cautela em ambientes produtivos
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################

# =========================
# Verificar módulo
# =========================
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "❌ Módulo ExchangeOnlineManagement não encontrado."
    Write-Host "Instale com: Install-Module ExchangeOnlineManagement"
    exit
}

Import-Module ExchangeOnlineManagement

# =========================
# Conexão (SEM USER FIXO 🔥)
# =========================
Write-Host "🔐 Conectando ao Exchange Online..."
Connect-ExchangeOnline

# =========================
# Entrada de dados
# =========================
$mailbox = Read-Host "📧 Digite o e-mail da mailbox alvo"

if ([string]::IsNullOrWhiteSpace($mailbox)) {
    Write-Host "❌ Mailbox inválida."
    exit
}

# =========================
# Pastas alvo
# =========================
$folders = @("TO_BE_DELETED", "DeletedItems")

foreach ($folder in $folders) {

    $searchName = "Cleanup_" + $folder + "_" + (Get-Random)

    Write-Host ""
    Write-Host "🔍 Criando Compliance Search: $searchName"
    Write-Host "📂 Pasta: $folder"
    Write-Host "📧 Mailbox: $mailbox"

    try {
        # Criar busca
        New-ComplianceSearch `
            -Name $searchName `
            -ExchangeLocation $mailbox `
            -ContentMatchQuery "folderid:$folder"

        # Iniciar busca
        Start-ComplianceSearch -Identity $searchName

        # Aguardar conclusão
        do {
            Start-Sleep -Seconds 5
            $status = (Get-ComplianceSearch -Identity $searchName).Status
            Write-Host "⏳ Status: $status"
        } until ($status -eq "Completed")

        # Purge
        Write-Host "🧹 Executando purge..."
        New-ComplianceSearchAction `
            -SearchName $searchName `
            -Purge `
            -PurgeType HardDelete

        Write-Host "✅ Pasta $folder limpa com sucesso!"

    } catch {
        Write-Host "❌ Erro ao processar $folder"
        Write-Host $_
    }
}

Write-Host ""
Write-Host "🎯 Processo finalizado!"
