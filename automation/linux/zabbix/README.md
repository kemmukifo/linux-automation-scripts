---

### 🖥️ XCP-ng Zabbix Agent Replicator

Script para instalação e atualização do Zabbix Agent em hosts XCP-ng **sem acesso à internet**, utilizando um host de referência.

**Arquivo:**
`replicar-xcp-zabbix.sh`

**Funcionalidades:**
- Instalação completa do Zabbix Agent via cópia (modo offline)
- Atualização de configurações em massa
- Criação automática de usuário e diretórios
- Replicação de binários e configs via SCP
- Configuração automática de:
  - `zabbix_agentd.conf`
  - `xcp.conf`
  - `sudoers`
  - firewall (porta 10050)
- Testes automáticos:
  - CPU
  - Quantidade de VMs
  - Status do agente
- Execução via SSH com chave (sem senha)

**Modo de uso:**

```bash
# Instalação completa
./replicar-xcp-zabbix.sh install

# Apenas atualização
./replicar-xcp-zabbix.sh update
