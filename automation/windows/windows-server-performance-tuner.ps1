###############################################################################
# Script: windows-server-performance-tuner.ps1
#
# Descrição:
#   Script para otimização de performance em Windows Server, desabilitando
#   serviços não essenciais e ativando plano de energia de alto desempenho.
#
# Objetivo:
#   Melhorar desempenho em ambientes de servidor, especialmente para:
#     - Servidores de aplicação
#     - Máquinas dedicadas
#     - Ambientes de laboratório
#
# Funcionamento:
#   - Para e desabilita serviços selecionados
#   - Permite controle de serviços críticos
#   - Ativa plano de energia "Ultimate Performance"
#
# Uso:
#   Executar como Administrador:
#   .\windows-server-performance-tuner.ps1
#
# Observações:
#   - NÃO recomendado desabilitar Firewall e Windows Update em produção
#   - Utilize com cautela
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################

# =========================
# Verificar Admin
# =========================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {

    Write-Host "❌ Execute como Administrador!" -ForegroundColor Red
    exit
}

# =========================
# Configuração
# =========================
$disableCritical = $false  # 🔥 Mude para $true se quiser desabilitar serviços críticos

# Serviços padrão (seguros)
$services = @(
    "Audiosrv",     # Windows Audio
    "SysMain",      # Superfetch
    "Themes",       # Temas
    "WSearch",      # Indexação
    "WbioSrvc"      # Biometria
)

# Serviços críticos (opcional)
$criticalServices = @(
    "wuauserv",     # Windows Update
    "MpsSvc",       # Firewall
    "Spooler"       # Impressão
)

if ($disableCritical) {
    $services += $criticalServices
}

# =========================
# Execução
# =========================
foreach ($svc in $services) {

    $serviceObj = Get-Service -Name $svc -ErrorAction SilentlyContinue

    if ($serviceObj) {
        Write-Host "🔧 Processando serviço: $svc"

        try {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled

            Write-Host "✅ $svc desabilitado"
        }
        catch {
            Write-Host "❌ Erro ao processar $svc"
        }
    } else {
        Write-Host "⚠️ Serviço não encontrado: $svc"
    }
}

# =========================
# Plano de energia
# =========================
Write-Host ""
Write-Host "⚡ Configurando plano de energia..."

$ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"

try {
    powercfg -duplicatescheme $ultimateGUID 2>$null
    powercfg -setactive $ultimateGUID

    Write-Host "✅ Plano Ultimate Performance ativado"
}
catch {
    Write-Host "❌ Erro ao configurar plano de energia"
}

Write-Host ""
Write-Host "🚀 Otimização concluída!"
