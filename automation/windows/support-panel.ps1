<#
Painel de Suporte Técnico - Turbinado v2.4
Autor: Kleber & Adaptações por IA
Correções:
- Problema de caracteres especiais resolvido
- Comportamento TopMost corrigido
- Popups funcionando corretamente
- Layout melhorado
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# ---------- Configurações Globais ----------
$global:Encoding = [System.Text.Encoding]::GetEncoding(1252)  # Windows-1252 para caracteres latinos
$global:TopMost = $false  # Controle do comportamento da janela

# ---------- Funções utilitárias ----------
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    if (-not $isAdmin) {
        $ps = Get-Command powershell.exe | Select-Object -First 1
        $arg = "-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`""
        Start-Process -FilePath $ps.Source -ArgumentList $arg -Verb RunAs
        Exit
    }
}

function Timestamp { Get-Date -Format "yyyy-MM-dd_HH-mm-ss" }

# Pasta de logs
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogsDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $LogsDir)) { New-Item -Path $LogsDir -ItemType Directory | Out-Null }

function Append-Output($text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $decodedText = $global:Encoding.GetString($bytes)
    $timestampedText = "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - $decodedText"
    $form.Invoke([Action]{
        $textboxOutput.AppendText($timestampedText + [Environment]::NewLine)
        $textboxOutput.ScrollToCaret()
    })
}

function Save-OutputToFile {
    $fname = "log_$(Timestamp).txt"
    $full = Join-Path $LogsDir $fname
    $textboxOutput.Text | Out-File -FilePath $full -Encoding $global:Encoding
    [System.Windows.Forms.MessageBox]::Show("Log salvo em:`n$full", "Log Salvo", "OK", "Information")
}

# ---------- Funções: Sistema ----------
function Get-SystemInfo {
    Append-Output("=== Informações do Sistema ===")
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = (Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name) -join "; "
        $totalMemMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 0)
        $freeMemMB = [math]::Round($os.FreePhysicalMemory / 1024, 0)
        $uptime = (Get-Date) - $os.LastBootUpTime

        Append-Output("SO: $($os.Caption) - Build: $($os.BuildNumber)")
        Append-Output("CPU: $cpu")
        Append-Output("Memória Total (MB): $totalMemMB")
        Append-Output("Memória Livre (MB): $freeMemMB")
        Append-Output("Uptime (dias.horas): $($uptime.Days).$($uptime.Hours)")
        Append-Output("Arquitetura: $($os.OSArchitecture)")
        Append-Output("Usuário atual: $env:USERNAME")
        Append-Output("PowerShell: $($PSVersionTable.PSVersion)")
    } catch {
        Append-Output("Erro ao coletar info do sistema: $_")
    }
    Append-Output("") 
}

function Get-DiskUsage {
    Append-Output("=== Uso de Disco ===")
    try {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            $sizeGB = [math]::Round($_.Size/1GB,2)
            $freeGB = [math]::Round($_.FreeSpace/1GB,2)
            $pctFree = [math]::Round(($_.FreeSpace/$_.Size)*100,2)
            Append-Output("Drive $($_.DeviceID) - Total: ${sizeGB}GB - Livre: ${freeGB}GB ($pctFree%)")
        }
    } catch {
        Append-Output("Erro disco: $_")
    }
    Append-Output("")
}

function Get-ProcessesTop {
    Append-Output("=== Top processos por CPU (snapshot) ===")
    try {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 | ForEach-Object {
            Append-Output("{0,-30} - CPU: {1,7} - Mem(MB): {2,7}" -f $_.ProcessName, ([math]::Round($_.CPU,2)), ([math]::Round($_.WorkingSet/1MB,2)))
        }
    } catch {
        Append-Output("Erro processos: $_")
    }
    Append-Output("")
}

# ---------- Funções: Rede ----------
function Network-Diagnostics {
    param([string]$defaultTarget = "8.8.8.8")

    # Formulário modal para entrada
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Teste de Rede"
    $inputForm.Size = New-Object System.Drawing.Size(350,150)
    $inputForm.StartPosition = "CenterScreen"
    $inputForm.TopMost = $true
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Digite host/IP para teste:"
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(300,20)
    $inputForm.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,40)
    $textBox.Size = New-Object System.Drawing.Size(300,20)
    $textBox.Text = $defaultTarget
    $inputForm.Controls.Add($textBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.DialogResult = "OK"
    $okButton.Location = New-Object System.Drawing.Point(100,70)
    $inputForm.Controls.Add($okButton)

    $inputForm.AcceptButton = $okButton
    $result = $inputForm.ShowDialog($form)  # Mostra como modal do form principal

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $target = $textBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($target)) { $target = $defaultTarget }

        Append-Output("=== Diagnóstico de Rede para $target ===")

        # Ping
        Append-Output("-- Ping (4 pacotes) --")
        try {
            $ping = Test-Connection -ComputerName $target -Count 4 -ErrorAction Stop
            $ping | ForEach-Object {
                Append-Output("Resposta de $($_.Address): RTT = $($_.ResponseTime) ms")
            }
        } catch {
            Append-Output("Ping falhou: $_")
        }

        # Traceroute
        Append-Output("-- Traceroute --")
        try {
            $tracertOutput = & tracert -d -h 15 $target 2>&1 | Out-String -Stream
            $tracertOutput | ForEach-Object {
                Append-Output($_)
            }
        } catch {
            Append-Output("Traceroute falhou: $_")
        }

        # Teste de porta
        $portForm = New-Object System.Windows.Forms.Form
        $portForm.Text = "Teste de Porta"
        $portForm.Size = New-Object System.Drawing.Size(350,150)
        $portForm.StartPosition = "CenterScreen"
        $portForm.TopMost = $true
        $portForm.FormBorderStyle = "FixedDialog"

        $portLabel = New-Object System.Windows.Forms.Label
        $portLabel.Text = "Digite a porta para teste (ou cancelar):"
        $portLabel.Location = New-Object System.Drawing.Point(10,20)
        $portLabel.Size = New-Object System.Drawing.Size(300,20)
        $portForm.Controls.Add($portLabel)

        $portTextBox = New-Object System.Windows.Forms.TextBox
        $portTextBox.Location = New-Object System.Drawing.Point(10,40)
        $portTextBox.Size = New-Object System.Drawing.Size(300,20)
        $portForm.Controls.Add($portTextBox)

        $portOkButton = New-Object System.Windows.Forms.Button
        $portOkButton.Text = "Testar"
        $portOkButton.DialogResult = "OK"
        $portOkButton.Location = New-Object System.Drawing.Point(60,70)
        $portForm.Controls.Add($portOkButton)

        $portCancelButton = New-Object System.Windows.Forms.Button
        $portCancelButton.Text = "Cancelar"
        $portCancelButton.DialogResult = "Cancel"
        $portCancelButton.Location = New-Object System.Drawing.Point(180,70)
        $portForm.Controls.Add($portCancelButton)

        $portForm.AcceptButton = $portOkButton
        $portForm.CancelButton = $portCancelButton
        $portResult = $portForm.ShowDialog($form)

        if ($portResult -eq [System.Windows.Forms.DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($portTextBox.Text)) {
            $port = $portTextBox.Text.Trim()
            try {
                Append-Output("-- Teste de Porta TCP $port --")
                $tnc = Test-NetConnection -ComputerName $target -Port $port -InformationLevel Detailed
                Append-Output("TcpTestSucceeded: $($tnc.TcpTestSucceeded)")
                Append-Output("RemoteAddress: $($tnc.RemoteAddress)")
                Append-Output("RemotePort: $($tnc.RemotePort)")
            } catch {
                Append-Output("Teste de porta falhou: $_")
            }
        }
        Append-Output("")
    }
}

function Get-NetworkAdapters {
    Append-Output("=== Configuração de Adaptadores de Rede ===")
    try {
        Get-NetIPConfiguration | ForEach-Object {
            Append-Output("Interface: $($_.InterfaceAlias)")
            Append-Output("  IPv4: $($_.IPv4Address.IPAddress)")
            Append-Output("  Gateway: $($_.IPv4DefaultGateway.NextHop)")
            Append-Output("  DNS: $($_.DNSServer.ServerAddresses -join ', ')")
            Append-Output("")
        }
    } catch {
        Append-Output("Erro adaptadores: $_")
    }
    Append-Output("")
}

function Get-NetworkDetailedConfig {
    Append-Output("=== Configuração Detalhada de Rede ===")
    try {
        $output = & ipconfig /all | Out-String
        $output -split "`r`n" | ForEach-Object {
            if ($_ -match ":") {
                $parts = $_ -split ":", 2
                Append-Output(("{0,-30}: {1}" -f $parts[0].Trim(), $parts[1].Trim()))
            } else {
                Append-Output($_)
            }
        }
    } catch {
        Append-Output("Erro ao obter configuração de rede: $_")
    }
    Append-Output("")
}

function Flush-DNS {
    Append-Output("Executando ipconfig /flushdns ...")
    ipconfig /flushdns | ForEach-Object { Append-Output($_) }
    Append-Output("")
}

function Reset-TCP {
    $res = [System.Windows.Forms.MessageBox]::Show("Deseja resetar a pilha TCP/IP e Winsock?","Confirmação", "YesNo", "Question")
    if ($res -eq "Yes") {
        Append-Output("Resetando pilha TCP/IP e Winsock...")
        netsh int ip reset | ForEach-Object { Append-Output($_) }
        netsh winsock reset | ForEach-Object { Append-Output($_) }
        Append-Output("Reinicialize a máquina para completar o processo.")
    } else {
        Append-Output("Reset TCP/IP cancelado pelo usuário.")
    }
    Append-Output("")
}

function Renew-IP {
    Append-Output("Liberando e renovando IP...")
    ipconfig /release | ForEach-Object { Append-Output($_) }
    Start-Sleep -Seconds 2
    ipconfig /renew | ForEach-Object { Append-Output($_) }
    Append-Output("")
}

# ---------- Funções: Limpeza e Manutenção ----------
function Clear-TempFiles {
    $res = [System.Windows.Forms.MessageBox]::Show("Deseja limpar arquivos temporários?","Confirmação", "YesNo", "Question")
    if ($res -eq "Yes") {
        Append-Output("Limpando arquivos temporários...")
        try {
            $tempPaths = @(
                "$env:TEMP\*",
                "$env:WINDIR\Temp\*",
                "$env:LOCALAPPDATA\Temp\*",
                "$env:SystemRoot\Prefetch\*"
            )
            
            $totalFreed = 0
            foreach ($path in $tempPaths) {
                if (Test-Path $path) {
                    $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Append-Output("Limpo: $path (Liberados: $([math]::Round($size,2)) MB)")
                    $totalFreed += $size
                }
            }
            Append-Output("Total liberado: $([math]::Round($totalFreed,2)) MB")
        } catch {
            Append-Output("Erro ao limpar temporários: $_")
        }
    } else {
        Append-Output("Limpeza de temporários cancelada.")
    }
    Append-Output("")
}

function Run-DiskCleanup {
    $res = [System.Windows.Forms.MessageBox]::Show("Deseja executar a Limpeza de Disco?","Confirmação", "YesNo", "Question")
    if ($res -eq "Yes") {
        Append-Output("Executando Limpeza de Disco...")
        try {
            Start-Process cleanmgr -ArgumentList "/sagerun:1" -Wait
            Append-Output("Limpeza de disco concluída.")
        } catch {
            Append-Output("Erro ao executar limpeza de disco: $_")
        }
    } else {
        Append-Output("Limpeza de disco cancelada.")
    }
    Append-Output("")
}

function Run-SFC {
    $res = [System.Windows.Forms.MessageBox]::Show("Deseja executar o System File Checker (SFC)?","Confirmação", "YesNo", "Question")
    if ($res -eq "Yes") {
        Append-Output("Executando SFC /scannow...")
        try {
            $output = sfc /scannow 2>&1
            $output | ForEach-Object { Append-Output($_) }
            Append-Output("Verificação de arquivos do sistema concluída.")
        } catch {
            Append-Output("Erro ao executar SFC: $_")
        }
    } else {
        Append-Output("SFC cancelado pelo usuário.")
    }
    Append-Output("")
}

function Run-DISM {
    $res = [System.Windows.Forms.MessageBox]::Show("Deseja executar o DISM para reparo da imagem do Windows?","Confirmação", "YesNo", "Question")
    if ($res -eq "Yes") {
        Append-Output("Executando DISM /Online /Cleanup-Image /RestoreHealth...")
        try {
            $output = dism /online /cleanup-image /restorehealth 2>&1
            $output | ForEach-Object { Append-Output($_) }
            Append-Output("Reparo da imagem do Windows concluído.")
        } catch {
            Append-Output("Erro ao executar DISM: $_")
        }
    } else {
        Append-Output("DISM cancelado pelo usuário.")
    }
    Append-Output("")
}

function Reset-WindowsUpdate {
    $res = [System.Windows.Forms.MessageBox]::Show("Deseja resetar o Windows Update?","Confirmação", "YesNo", "Question")
    if ($res -eq "Yes") {
        Append-Output("Resetando Windows Update...")
        try {
            # Lista de serviços para reiniciar
            $services = @("wuauserv", "cryptSvc", "bits", "msiserver")
            
            # Parar serviços
            $services | ForEach-Object {
                Stop-Service -Name $_ -Force -ErrorAction SilentlyContinue
                Append-Output("Serviço $_ parado")
            }
            
            # Limpar cache
            $paths = @(
                "$env:SYSTEMROOT\SoftwareDistribution",
                "$env:SYSTEMROOT\System32\catroot2"
            )
            
            $paths | ForEach-Object {
                Get-ChildItem $_ -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Append-Output("Limpo: $_")
            }
            
            # Reiniciar serviços
            $services | ForEach-Object {
                Start-Service -Name $_ -ErrorAction SilentlyContinue
                Append-Output("Serviço $_ iniciado")
            }
            
            Append-Output("Windows Update resetado com sucesso!")
        } catch {
            Append-Output("Erro durante o reset: $_")
        }
    } else {
        Append-Output("Reset do Windows Update cancelado.")
    }
    Append-Output("")
}

# ---------- Funções: Extras ----------
function Get-AntivirusInfo {
    Append-Output("=== Informações de Antivírus ===")
    try {
        $antivirus = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct
        if ($antivirus) {
            $antivirus | ForEach-Object {
                Append-Output("Produto: $($_.displayName)")
                Append-Output("Status: $(if($_.productState -eq 266240){'Protegido'}else{'Não protegido'})")
                Append-Output("")
            }
        } else {
            Append-Output("Nenhum antivírus encontrado via SecurityCenter2")
        }
    } catch {
        Append-Output("Erro ao verificar antivírus: $_")
    }
    Append-Output("")
}

function Get-DeviceList {
    Append-Output("=== Dispositivos (não-PnP) ===")
    try {
        Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | 
        Select-Object Name, DeviceID, ConfigManagerErrorCode | 
        ForEach-Object {
            Append-Output("Dispositivo: $($_.Name)")
            Append-Output("  ID: $($_.DeviceID)")
            Append-Output("  Erro: $($_.ConfigManagerErrorCode)")
            Append-Output("")
        }
    } catch {
        Append-Output("Erro ao listar dispositivos: $_")
    }
    Append-Output("")
}

function Open-DeviceManager {
    Start-Process "devmgmt.msc"
}

# ---------- GUI ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Painel de Suporte Técnico - Turbinado v2.4"
$form.Size = New-Object System.Drawing.Size(1100, 700)
$form.StartPosition = "CenterScreen"
$form.TopMost = $global:TopMost
$form.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$form.MinimumSize = New-Object System.Drawing.Size(900, 600)

# TabControl principal
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(450, 600)
$form.Controls.Add($tabControl)

# Área de saída
$textboxOutput = New-Object System.Windows.Forms.TextBox
$textboxOutput.Multiline = $true
$textboxOutput.ScrollBars = "Both"
$textboxOutput.WordWrap = $false
$textboxOutput.ReadOnly = $true
$textboxOutput.Font = New-Object System.Drawing.Font("Lucida Console", 9)
$textboxOutput.Location = New-Object System.Drawing.Point(470, 10)
$textboxOutput.Size = New-Object System.Drawing.Size(600, 600)
$form.Controls.Add($textboxOutput)

# Botões inferiores
$btnClearOutput = New-Object System.Windows.Forms.Button
$btnClearOutput.Text = "Limpar"
$btnClearOutput.Location = New-Object System.Drawing.Point(470, 620)
$btnClearOutput.Size = New-Object System.Drawing.Size(100, 30)
$btnClearOutput.Add_Click({ $textboxOutput.Clear() })
$form.Controls.Add($btnClearOutput)

$btnSaveOutput = New-Object System.Windows.Forms.Button
$btnSaveOutput.Text = "Salvar Log"
$btnSaveOutput.Location = New-Object System.Drawing.Point(580, 620)
$btnSaveOutput.Size = New-Object System.Drawing.Size(100, 30)
$btnSaveOutput.Add_Click({ Save-OutputToFile })
$form.Controls.Add($btnSaveOutput)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Sair"
$btnExit.Location = New-Object System.Drawing.Point(970, 620)
$btnExit.Size = New-Object System.Drawing.Size(100, 30)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ---------- Aba: Sistema ----------
$tabSystem = New-Object System.Windows.Forms.TabPage
$tabSystem.Text = "Sistema"
$tabControl.Controls.Add($tabSystem)

# Grupo Info Sistema
$grpSysInfo = New-Object System.Windows.Forms.GroupBox
$grpSysInfo.Text = "Informações do Sistema"
$grpSysInfo.Location = New-Object System.Drawing.Point(10, 10)
$grpSysInfo.Size = New-Object System.Drawing.Size(420, 180)
$tabSystem.Controls.Add($grpSysInfo)

$btnSysInfo = New-Object System.Windows.Forms.Button
$btnSysInfo.Text = "Info do Sistema"
$btnSysInfo.Size = New-Object System.Drawing.Size(180, 30)
$btnSysInfo.Location = New-Object System.Drawing.Point(10, 20)
$btnSysInfo.Add_Click({ Get-SystemInfo })
$grpSysInfo.Controls.Add($btnSysInfo)

$btnDisk = New-Object System.Windows.Forms.Button
$btnDisk.Text = "Uso de Disco"
$btnDisk.Size = New-Object System.Drawing.Size(180, 30)
$btnDisk.Location = New-Object System.Drawing.Point(10, 55)
$btnDisk.Add_Click({ Get-DiskUsage })
$grpSysInfo.Controls.Add($btnDisk)

$btnProc = New-Object System.Windows.Forms.Button
$btnProc.Text = "Top Processos"
$btnProc.Size = New-Object System.Drawing.Size(180, 30)
$btnProc.Location = New-Object System.Drawing.Point(10, 90)
$btnProc.Add_Click({ Get-ProcessesTop })
$grpSysInfo.Controls.Add($btnProc)

$btnInstalledPrograms = New-Object System.Windows.Forms.Button
$btnInstalledPrograms.Text = "Programas Instalados"
$btnInstalledPrograms.Size = New-Object System.Drawing.Size(180, 30)
$btnInstalledPrograms.Location = New-Object System.Drawing.Point(200, 20)
$btnInstalledPrograms.Add_Click({
    Append-Output("=== Programas Instalados ===")
    $programs = Get-Package | Sort-Object Name | Select-Object Name, Version, Source | Format-Table -AutoSize | Out-String
    Append-Output($programs)
})
$grpSysInfo.Controls.Add($btnInstalledPrograms)

$btnServices = New-Object System.Windows.Forms.Button
$btnServices.Text = "Serviços Críticos"
$btnServices.Size = New-Object System.Drawing.Size(180, 30)
$btnServices.Location = New-Object System.Drawing.Point(200, 55)
$btnServices.Add_Click({
    $services = @("Winmgmt", "Eventlog", "Dnscache", "Spooler", "Netlogon", "Lanmanserver", "wuauserv")
    Append-Output("=== Status dos Serviços Críticos ===")
    foreach ($service in $services) {
        $status = (Get-Service -Name $service -ErrorAction SilentlyContinue).Status
        Append-Output("$service : $status")
    }
})
$grpSysInfo.Controls.Add($btnServices)

$btnDevices = New-Object System.Windows.Forms.Button
$btnDevices.Text = "Dispositivos com Erro"
$btnDevices.Size = New-Object System.Drawing.Size(180, 30)
$btnDevices.Location = New-Object System.Drawing.Point(200, 90)
$btnDevices.Add_Click({ Get-DeviceList })
$grpSysInfo.Controls.Add($btnDevices)

# Grupo Ferramentas Rápidas
$grpQuickTools = New-Object System.Windows.Forms.GroupBox
$grpQuickTools.Text = "Ferramentas Rápidas"
$grpQuickTools.Location = New-Object System.Drawing.Point(10, 200)
$grpQuickTools.Size = New-Object System.Drawing.Size(420, 120)
$tabSystem.Controls.Add($grpQuickTools)

$btnTaskMgr = New-Object System.Windows.Forms.Button
$btnTaskMgr.Text = "Abrir Task Manager"
$btnTaskMgr.Size = New-Object System.Drawing.Size(180, 25)
$btnTaskMgr.Location = New-Object System.Drawing.Point(10, 20)
$btnTaskMgr.Add_Click({ Start-Process taskmgr })
$grpQuickTools.Controls.Add($btnTaskMgr)

$btnEventViewer = New-Object System.Windows.Forms.Button
$btnEventViewer.Text = "Abrir Event Viewer"
$btnEventViewer.Size = New-Object System.Drawing.Size(180, 25)
$btnEventViewer.Location = New-Object System.Drawing.Point(10, 50)
$btnEventViewer.Add_Click({ Start-Process eventvwr })
$grpQuickTools.Controls.Add($btnEventViewer)

$btnExplorer = New-Object System.Windows.Forms.Button
$btnExplorer.Text = "Abrir Explorer (C:\)"
$btnExplorer.Size = New-Object System.Drawing.Size(180, 25)
$btnExplorer.Location = New-Object System.Drawing.Point(10, 80)
$btnExplorer.Add_Click({ Start-Process explorer "C:\" })
$grpQuickTools.Controls.Add($btnExplorer)

$btnDevManager = New-Object System.Windows.Forms.Button
$btnDevManager.Text = "Gerenciador de Dispositivos"
$btnDevManager.Size = New-Object System.Drawing.Size(180, 25)
$btnDevManager.Location = New-Object System.Drawing.Point(200, 20)
$btnDevManager.Add_Click({ Open-DeviceManager })
$grpQuickTools.Controls.Add($btnDevManager)

# ---------- Aba: Rede ----------
$tabNetwork = New-Object System.Windows.Forms.TabPage
$tabNetwork.Text = "Rede"
$tabControl.Controls.Add($tabNetwork)

# Grupo Diagnóstico
$grpNetDiag = New-Object System.Windows.Forms.GroupBox
$grpNetDiag.Text = "Diagnóstico de Rede"
$grpNetDiag.Location = New-Object System.Drawing.Point(10, 10)
$grpNetDiag.Size = New-Object System.Drawing.Size(420, 180)
$tabNetwork.Controls.Add($grpNetDiag)

$btnNetDiag = New-Object System.Windows.Forms.Button
$btnNetDiag.Text = "Ping/Traceroute"
$btnNetDiag.Size = New-Object System.Drawing.Size(180, 30)
$btnNetDiag.Location = New-Object System.Drawing.Point(10, 20)
$btnNetDiag.Add_Click({ Network-Diagnostics })
$grpNetDiag.Controls.Add($btnNetDiag)

$btnAdapters = New-Object System.Windows.Forms.Button
$btnAdapters.Text = "Info Adaptadores"
$btnAdapters.Size = New-Object System.Drawing.Size(180, 30)
$btnAdapters.Location = New-Object System.Drawing.Point(10, 55)
$btnAdapters.Add_Click({ Get-NetworkAdapters })
$grpNetDiag.Controls.Add($btnAdapters)

$btnNetConfig = New-Object System.Windows.Forms.Button
$btnNetConfig.Text = "Configuração Completa"
$btnNetConfig.Size = New-Object System.Drawing.Size(180, 30)
$btnNetConfig.Location = New-Object System.Drawing.Point(10, 90)
$btnNetConfig.Add_Click({ Get-NetworkDetailedConfig })
$grpNetDiag.Controls.Add($btnNetConfig)

$btnTestInternet = New-Object System.Windows.Forms.Button
$btnTestInternet.Text = "Testar Internet"
$btnTestInternet.Size = New-Object System.Drawing.Size(180, 30)
$btnTestInternet.Location = New-Object System.Drawing.Point(200, 20)
$btnTestInternet.Add_Click({ Network-Diagnostics "google.com" })
$grpNetDiag.Controls.Add($btnTestInternet)

# Grupo Reparo
$grpNetRepair = New-Object System.Windows.Forms.GroupBox
$grpNetRepair.Text = "Reparo de Rede"
$grpNetRepair.Location = New-Object System.Drawing.Point(10, 200)
$grpNetRepair.Size = New-Object System.Drawing.Size(420, 150)
$tabNetwork.Controls.Add($grpNetRepair)

$btnFlushDNS = New-Object System.Windows.Forms.Button
$btnFlushDNS.Text = "Flush DNS"
$btnFlushDNS.Size = New-Object System.Drawing.Size(180, 30)
$btnFlushDNS.Location = New-Object System.Drawing.Point(10, 20)
$btnFlushDNS.Add_Click({ Flush-DNS })
$grpNetRepair.Controls.Add($btnFlushDNS)

$btnResetTCP = New-Object System.Windows.Forms.Button
$btnResetTCP.Text = "Reset TCP/IP"
$btnResetTCP.Size = New-Object System.Drawing.Size(180, 30)
$btnResetTCP.Location = New-Object System.Drawing.Point(10, 55)
$btnResetTCP.Add_Click({ Reset-TCP })
$grpNetRepair.Controls.Add($btnResetTCP)

$btnRenewIP = New-Object System.Windows.Forms.Button
$btnRenewIP.Text = "Renovar IP"
$btnRenewIP.Size = New-Object System.Drawing.Size(180, 30)
$btnRenewIP.Location = New-Object System.Drawing.Point(10, 90)
$btnRenewIP.Add_Click({ Renew-IP })
$grpNetRepair.Controls.Add($btnRenewIP)

# ---------- Aba: Manutenção ----------
$tabMaintenance = New-Object System.Windows.Forms.TabPage
$tabMaintenance.Text = "Manutenção"
$tabControl.Controls.Add($tabMaintenance)

# Grupo Limpeza
$grpCleanup = New-Object System.Windows.Forms.GroupBox
$grpCleanup.Text = "Limpeza do Sistema"
$grpCleanup.Location = New-Object System.Drawing.Point(10, 10)
$grpCleanup.Size = New-Object System.Drawing.Size(420, 150)
$tabMaintenance.Controls.Add($grpCleanup)

$btnTempFiles = New-Object System.Windows.Forms.Button
$btnTempFiles.Text = "Limpar Temporários"
$btnTempFiles.Size = New-Object System.Drawing.Size(180, 30)
$btnTempFiles.Location = New-Object System.Drawing.Point(10, 20)
$btnTempFiles.Add_Click({ Clear-TempFiles })
$grpCleanup.Controls.Add($btnTempFiles)

$btnDiskCleanup = New-Object System.Windows.Forms.Button
$btnDiskCleanup.Text = "Limpeza de Disco"
$btnDiskCleanup.Size = New-Object System.Drawing.Size(180, 30)
$btnDiskCleanup.Location = New-Object System.Drawing.Point(10, 55)
$btnDiskCleanup.Add_Click({ Run-DiskCleanup })
$grpCleanup.Controls.Add($btnDiskCleanup)

# Grupo Manutenção
$grpWinMaintenance = New-Object System.Windows.Forms.GroupBox
$grpWinMaintenance.Text = "Manutenção do Windows"
$grpWinMaintenance.Location = New-Object System.Drawing.Point(10, 170)
$grpWinMaintenance.Size = New-Object System.Drawing.Size(420, 180)
$tabMaintenance.Controls.Add($grpWinMaintenance)

$btnSFC = New-Object System.Windows.Forms.Button
$btnSFC.Text = "Executar SFC"
$btnSFC.Size = New-Object System.Drawing.Size(180, 30)
$btnSFC.Location = New-Object System.Drawing.Point(10, 20)
$btnSFC.Add_Click({ Run-SFC })
$grpWinMaintenance.Controls.Add($btnSFC)

$btnDISM = New-Object System.Windows.Forms.Button
$btnDISM.Text = "Executar DISM"
$btnDISM.Size = New-Object System.Drawing.Size(180, 30)
$btnDISM.Location = New-Object System.Drawing.Point(10, 55)
$btnDISM.Add_Click({ Run-DISM })
$grpWinMaintenance.Controls.Add($btnDISM)

$btnResetWU = New-Object System.Windows.Forms.Button
$btnResetWU.Text = "Reset Windows Update"
$btnResetWU.Size = New-Object System.Drawing.Size(180, 30)
$btnResetWU.Location = New-Object System.Drawing.Point(10, 90)
$btnResetWU.Add_Click({ Reset-WindowsUpdate })
$grpWinMaintenance.Controls.Add($btnResetWU)

# ---------- Inicialização ----------
Ensure-Admin
Append-Output("Painel de Suporte Técnico - Turbinado v2.4")
Append-Output("Codificação configurada: $($global:Encoding.EncodingName)")
Append-Output("Modo Administrador: $([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)")

[void]$form.ShowDialog()