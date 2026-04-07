###############################################################################
# Script: network-free-ip-scanner.ps1
#
# Descrição:
#   Ferramenta para identificação de IPs livres em uma rede /24.
#
#   O script realiza varredura completa utilizando dois métodos:
#     - ICMP (ping)
#     - Tabela ARP
#
#   Isso permite detectar hosts que:
#     - Respondem ping
#     - Não respondem ping, mas estão ativos na rede
#
# Funcionalidades:
#   - Limpeza de cache ARP
#   - Varredura rápida com timeout otimizado
#   - Barra de progresso em tempo real
#   - Listagem de IPs disponíveis
#   - Contador total de IPs livres
#
# Objetivo:
#   Auxiliar na alocação de IPs e troubleshooting de rede.
#
# Uso:
#   .\network-free-ip-scanner.ps1
#
# Requisitos:
#   - Executar como Administrador
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################


# Mensagens iniciais
Write-Host "Varrendo rede 172.30.1.0/24..." -ForegroundColor Yellow
Write-Host "Aguarde alguns segundos..." 
Write-Host ""

# Limpa cache ARP para evitar resultados desatualizados
arp -d * 2>$null

# Define a base da rede
$baseIP = Read-Host "Digite a rede base (ex: 192.168.1)"

# Lista para armazenar IPs livres
$livres = @()

# Loop por todos os IPs de 1 a 254
for ($i = 1; $i -le 254; $i++) {
    # Monta o IP completo
    $ip = "$baseIP.$i"
    
    # Barra de progresso
    Write-Progress -Activity "Varrendo rede" -Status "Verificando $ip" -PercentComplete (($i / 254) * 100)
    
    # Assume que o IP está livre até provar o contrário
    $ocupado = $false
    
    # Método 1: Teste de ping rápido
    $ping = New-Object System.Net.NetworkInformation.Ping
    try {
        $reply = $ping.Send($ip, 50)  # 50ms de timeout
        if ($reply.Status -eq "Success") {
            $ocupado = $true  # Respondeu ping, está ocupado
        }
    } catch {
        # Ignora erros de timeout
    }
    
    # Método 2: Verificação ARP (para IPs que não pingam mas existem)
    if (-not $ocupado) {
        $arp = arp -a $ip 2>$null
        # Se tem entrada ARP válida (não incompleta), está ocupado
        if ($arp -like "*$ip*" -and $arp -notlike "*incompleto*") {
            $ocupado = $true
        }
    }
    
    # Se não está ocupado, adiciona à lista de livres
    if (-not $ocupado) {
        $livres += $ip
        Write-Host $ip -ForegroundColor Green
    }
}

# Finaliza barra de progresso
Write-Progress -Activity "Varrendo rede" -Completed

# Mostra total de IPs livres
Write-Host ""
Write-Host "Total de IPs livres: $($livres.Count)" -ForegroundColor Cyan
