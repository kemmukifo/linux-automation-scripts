###############################################################################
# Script: windows-server-performance-tuner.ps1
#
# Descricao:
#   Script para otimizacao de performance em Windows Server, desabilitando
#   servicos nao essenciais e ativando plano de energia de alto desempenho.
#
# Objetivo:
#   Melhorar desempenho em ambientes de servidor, especialmente para:
#     - Servidores de aplicacao
#     - Maquinas dedicadas
#     - Ambientes de laboratorio
#
# Funcionamento:
#   - Para e desabilita servicos selecionados
#   - Permite controle de servicos criticos
#   - Ativa plano de energia "Ultimate Performance"
#
# Uso:
#   Executar como Administrador:
#   .\windows-server-performance-tuner.ps1
#
# Observacoes:
#   - NAO recomendado desabilitar Firewall e Windows Update em producao
#   - Utilize com cautela
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versao: 2.0
###############################################################################

# =========================
# Verificar Admin
# =========================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {

    Write-Host "[ERRO] Execute como Administrador!" -ForegroundColor Red
    exit
}

# =========================
# Configuracao
# =========================
$disableCritical = $false  # Altere para $true se quiser desabilitar servicos criticos

# Servicos padrao (seguros)
$services = @(
    "Audiosrv",     # Windows Audio
    "SysMain",      # Superfetch
    "Themes",       # Temas
    "WSearch",      # Indexacao
    "WbioSrvc"      # Biometria
)

# Servicos criticos (opcional)
$criticalServices = @(
    "wuauserv",     # Windows Update
    "MpsSvc",       # Firewall
    "Spooler"       # Impressao
)

if ($disableCritical) {
    $services += $criticalServices
}

# =========================
# Execucao
# =========================
foreach ($svc in $services) {

    $serviceObj = Get-Service -Name $svc -ErrorAction SilentlyContinue

    if ($serviceObj) {
        Write-Host "[OK] Processando servico: $svc"

        try {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled

            Write-Host "[OK] $svc desabilitado"
        }
        catch {
            Write-Host "[ERRO] Erro ao processar $svc"
        }
    } else {
        Write-Host "[AVISO] Servico nao encontrado: $svc"
    }
}

# =========================
# Plano de energia
# =========================
Write-Host ""
Write-Host "[INFO] Configurando plano de energia..."

$ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"

try {
    powercfg -duplicatescheme $ultimateGUID 2>$null
    powercfg -setactive $ultimateGUID

    Write-Host "[OK] Plano Ultimate Performance ativado"
}
catch {
    Write-Host "[ERRO] Erro ao configurar plano de energia"
}

Write-Host ""
Write-Host "[OK] Otimizacao concluida!"
