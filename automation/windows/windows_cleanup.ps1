<#
.SYNOPSIS
    Windows Cleanup Script

.DESCRIPTION
    Script para limpeza de arquivos temporários, logs antigos e cache
    em servidores Windows.

    Executa uma limpeza segura removendo:
    - Arquivos temporários
    - Logs antigos
    - Cache do sistema
    - Lixeira
    - Arquivos de update antigos

    Ideal para manutenção preventiva e liberação de espaço em disco.

.AUTHOR
    Kleber Eduardo Maximo

.VERSION
    1.1 - 2026-04-07
#>

# ========================
# Função: Remoção segura de arquivos antigos
# ========================
Function Remove-OldFiles {
    param(
        [string]$Path,
        [int]$Days = 7
    )

    if (Test-Path $Path) {
        Write-Host "Limpando: $Path" -ForegroundColor Cyan

        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { 
            -not $_.PSIsContainer -and 
            $_.LastWriteTime -lt (Get-Date).AddDays(-$Days) 
        } |
        ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
            } catch {
                Write-Warning "Falha ao remover: $($_.FullName)"
            }
        }
    }
    else {
        Write-Host "Diretório não encontrado: $Path" -ForegroundColor Yellow
    }
}

# ========================
# Início
# ========================
Write-Host "=====================================" -ForegroundColor Green
Write-Host " INICIANDO LIMPEZA DO WINDOWS SERVER"
Write-Host "=====================================" -ForegroundColor Green

# Temp do usuário
Remove-OldFiles -Path "$env:TEMP" -Days 2

# Temp do sistema
Remove-OldFiles -Path "C:\Windows\Temp" -Days 2

# Logs
Remove-OldFiles -Path "C:\Windows\Logs" -Days 15
Remove-OldFiles -Path "C:\Windows\System32\LogFiles" -Days 15

# Prefetch
Remove-OldFiles -Path "C:\Windows\Prefetch" -Days 7

# Windows Update (downloads antigos)
Remove-OldFiles -Path "C:\Windows\SoftwareDistribution\Download" -Days 2

# Lixeira
Write-Host "Esvaziando Lixeira..." -ForegroundColor Cyan
try {
    (New-Object -ComObject Shell.Application).NameSpace(0xA).Items() | ForEach-Object {
        Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Warning "Falha ao esvaziar Lixeira"
}

# Limpeza de cache do Windows Update
Write-Host "Limpando cache do Windows Update..." -ForegroundColor Cyan
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Remove-OldFiles -Path "C:\Windows\SoftwareDistribution" -Days 2
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

# ========================
# Finalização
# ========================
Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host " LIMPEZA FINALIZADA COM SUCESSO"
Write-Host "=====================================" -ForegroundColor Green