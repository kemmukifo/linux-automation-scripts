## 🛠️ Support Panel (GUI) - Windows

Painel gráfico completo para suporte técnico em ambientes Windows.

Interface desenvolvida em PowerShell com Windows Forms, reunindo ferramentas de diagnóstico, rede, manutenção e troubleshooting em um único lugar.

---

### 📂 Arquivo
`support-panel.ps1`

---

### 🚀 Funcionalidades

#### 🖥️ Sistema
- Informações detalhadas do sistema (CPU, memória, uptime)
- Uso de disco
- Top processos por consumo
- Listagem de programas instalados
- Status de serviços críticos
- Dispositivos com erro

#### 🌐 Rede
- Ping e Traceroute interativo
- Teste de portas TCP
- Configuração de adaptadores
- ipconfig completo formatado
- Flush DNS
- Reset TCP/IP e Winsock
- Renovação de IP

#### 🧹 Manutenção
- Limpeza de arquivos temporários
- Limpeza de disco (cleanmgr)
- Execução de SFC
- Execução de DISM
- Reset completo do Windows Update

#### 🛡️ Extras
- Informações de antivírus
- Abertura rápida de ferramentas:
  - Task Manager
  - Event Viewer
  - Explorer
  - Device Manager

#### 📄 Logs
- Exibição em tempo real no painel
- Salvamento automático de logs em arquivo

---

### ⚙️ Requisitos

- Windows 10 / 11 ou Windows Server
- PowerShell 5+
- Execução como Administrador

---

### ▶️ Como usar

Execute o script como administrador:

```powershell
.\support-panel.ps1
