# 🪟 Windows Automation Scripts

Coleção de scripts para automação, otimização e troubleshooting em Windows Server.

---

## 📦 Scripts disponíveis

### ⚡ Windows Server Performance Tuner
Script para otimização de performance do Windows Server.

**Arquivo:**
`windows-server-performance-tuner.ps1`

**Funcionalidades:**
- Desabilita serviços não essenciais
- Opção de desabilitar serviços críticos
- Ativa plano Ultimate Performance

---

### 🌐 Network Free IP Scanner
Ferramenta para identificar IPs livres na rede.

**Arquivo:**
`network-free-ip-scanner.ps1`

**Funcionalidades:**
- Varredura de rede /24
- Detecção via ICMP (ping)
- Verificação adicional via ARP
- Exibe IPs disponíveis
- Contador total

---

### 📊 Find-FreeIPs (versão inicial)
Primeira versão do scanner de IPs.

**Arquivo:**
`Find-FreeIPs.ps1`

**Observação:**
Versão mantida para histórico e evolução do script.

---

## 🚀 Como usar

Execute os scripts como Administrador:

```powershell
.\Find-FreeIPs.ps1

---

### 🧹 Windows Cleanup Script
Script para limpeza de arquivos temporários, logs e cache do Windows.

**Arquivo:**
`windows_cleanup.ps1`

**Funcionalidades:**
- Remove arquivos temporários do usuário e sistema
- Limpa logs antigos automaticamente
- Remove cache do Windows Update
- Esvazia a lixeira
- Limpeza segura baseada em tempo (dias)
