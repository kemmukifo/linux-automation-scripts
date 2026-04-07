<#
===================================================================================
SCRIPT: windows-vm-optimizer.ps1
VERSÃO: 3.0
DATA: 17/12/2024
AUTOR: Kleber Maximo

DESCRIÇÃO:
    Script completo para otimização e limpeza de máquinas Windows (VMs ou físicos).

FUNCIONALIDADES:
    - Limpeza de arquivos temporários
    - Limpeza de cache de aplicações
    - Limpeza de logs do sistema
    - Flush de DNS
    - Otimização de disco
    - Limpeza do Windows Update
    - Remoção de hibernação
    - Otimização de serviços
    - Configuração de plano de energia

ATENÇÃO:
    - Firewall e Spooler serão desativados
    - Executar como Administrador
===================================================================================
#>

Write-Host "=== INICIANDO OTIMIZAÇÃO DE VM WINDOWS ===" -ForegroundColor Cyan
Write-Host "Script: windows-vm-optimizer.ps1"
Write-Host "⚠️ Firewall e Spooler serão desativados!" -ForegroundColor Red

# 1. LIMPEZA TEMP
Write-Host "`n[1/11] Limpando temporários..." -ForegroundColor Yellow

$tempFolders = @(
    "$env:TEMP",
    "C:\Windows\Temp",
    "$env:SystemRoot\Prefetch",
    "$env:SystemRoot\Logs\CBS",
    "$env:LOCALAPPDATA\Temp",
    "$env:USERPROFILE\AppData\Local\Temp"
)

foreach ($folder in $tempFolders) {
    if (Test-Path $folder) {
        Get-ChildItem $folder -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# 2. CACHE APPS
Write-Host "[2/11] Limpando cache de apps..."
Get-AppxPackage -AllUsers | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
}

# 3. LOGS
Write-Host "[3/11] Limpando logs..."
wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null }

# 4. DNS
Write-Host "[4/11] Limpando DNS..."
ipconfig /flushdns | Out-Null

# 5. DISCO
Write-Host "[5/11] Otimizando disco..."
Optimize-Volume -DriveLetter C -Defrag -ReTrim -ErrorAction SilentlyContinue

# 6. CLEANMGR
Write-Host "[6/11] Executando cleanmgr..."
Start-Process cleanmgr "/sagerun:1" -Wait -ErrorAction SilentlyContinue

# 7. WINDOWS UPDATE
Write-Host "[7/11] Limpando Windows Update..."
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue

# 8. HIBERNAÇÃO
Write-Host "[8/11] Removendo hibernação..."
powercfg -h off

# 9. SERVIÇOS
Write-Host "[9/11] Otimizando serviços..."

$servicesToDisable = @("Audiosrv","SysMain","Themes","WSearch","WbioSrvc","MpsSvc","Spooler")

foreach ($svc in $servicesToDisable) {
    Stop-Service $svc -Force -ErrorAction SilentlyContinue
    Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
}

# 10. ENERGIA
Write-Host "[10/11] Configurando energia..."
$guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
powercfg -duplicatescheme $guid 2>$null
powercfg -setactive $guid

# 11. RESUMO
Write-Host "[11/11] Finalizando..." -ForegroundColor Green

$disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$free = [math]::Round($disk.FreeSpace / 1GB, 2)

Write-Host "Espaço livre: $free GB" -ForegroundColor Green
Write-Host "✅ VM otimizada com sucesso!" -ForegroundColor Green
