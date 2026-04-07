#!/bin/bash
# replicar-xcp-zabbix.sh - Instalação/Atualização do Zabbix Agent para XCP-ng
# Versão com chave SSH (sem sshpass)

VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m'

# Configurações
HOSTS=(
    "172.28.2.101"
    "172.28.2.102"
    "172.28.2.103"
    "172.28.2.104"
    "172.28.2.105"
    "172.28.2.107"
    "172.28.2.108"
    "172.28.2.110"
    "172.28.2.111"
    "172.28.2.114"
    "172.28.2.115"
    "172.28.2.116"
    "172.28.2.120"
    "172.28.2.121"
    "172.28.2.122"
)

HOST_REFERENCIA="172.28.2.213"
SERVER_ZABBIX="172.30.1.60"  # IP do Zabbix Server

# Verifica argumento
MODO=$1
if [ "$MODO" != "install" ] && [ "$MODO" != "update" ]; then
    echo -e "${VERMELHO}Uso: $0 {install|update}${NC}"
    echo "  install - Instalação completa (cria usuário, pastas, copia binários e configs)"
    echo "  update  - Apenas atualiza configurações (xcp.conf, sudoers)"
    exit 1
fi

echo -e "${AZUL}========================================${NC}"
echo -e "${AZUL}  REPLICAR XCP-ZABBIX - MODO: $MODO${NC}"
echo -e "${AZUL}  (com chave SSH - sem senha)${NC}"
echo -e "${AZUL}========================================${NC}"

# Função para executar comandos via SSH
executar_ssh() {
    local host=$1
    local comando=$2
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$host "$comando" 2>/dev/null
    return $?
}

# Loop pelos hosts
for HOST in "${HOSTS[@]}"; do
    echo -e "\n${AZUL}▶ Processando host: ${VERDE}$HOST${NC}"
    
    # Ping test
    if ! ping -c 1 -W 2 $HOST &> /dev/null; then
        echo -e "${VERMELHO}  ✗ Host $HOST sem resposta${NC}"
        continue
    fi
    
    # MODO INSTALL - Configuração inicial
    if [ "$MODO" == "install" ]; then
        echo -e "  ${AMARELO}1. Criando usuário e diretórios...${NC}"
        
        # Criar usuário zabbix se não existir
        executar_ssh $HOST 'id zabbix || useradd -r -s /sbin/nologin zabbix'
        
        # Criar diretórios
        executar_ssh $HOST 'mkdir -p /var/log/zabbix /var/run/zabbix /etc/zabbix /opt/zabbix-agent/sbin'
        
        # COPIAR BINÁRIO DO ZABBIX AGENT (NOVO!)
        echo -e "  ${AMARELO}2. Copiando binário do Zabbix Agent...${NC}"
        scp -o StrictHostKeyChecking=no root@$HOST_REFERENCIA:/opt/zabbix-agent/sbin/zabbix_agentd root@$HOST:/opt/zabbix-agent/sbin/ 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "  ${VERDE}  ✓ Binário copiado${NC}"
            executar_ssh $HOST "chmod 755 /opt/zabbix-agent/sbin/zabbix_agentd"
        else
            echo -e "  ${VERMELHO}  ✗ Falha ao copiar binário${NC}"
            continue
        fi
        
        # Copiar arquivo de configuração base
        echo -e "  ${AMARELO}3. Copiando zabbix_agentd.conf base...${NC}"
        scp -o StrictHostKeyChecking=no root@$HOST_REFERENCIA:/etc/zabbix/zabbix_agentd.conf root@$HOST:/etc/zabbix/ 2>/dev/null
        
        # Ajustar permissões
        executar_ssh $HOST 'chown -R zabbix:zabbix /var/log/zabbix /var/run/zabbix /opt/zabbix-agent /etc/zabbix/zabbix_agentd.conf'
        
        echo -e "  ${VERDE}  ✓ Instalação base concluída${NC}"
    fi
    
    # MODO UPDATE (ou continuação do install) - Configurações do XCP
    echo -e "  ${AMARELO}4. Configurando xcp.conf...${NC}"
    
    # Criar diretório se não existir
    executar_ssh $HOST "mkdir -p /etc/zabbix/zabbix_agentd.d/"
    
    # Copiar xcp.conf do host de referência
    if [ "$HOST" == "$HOST_REFERENCIA" ]; then
        echo -e "  ${AMARELO}   Host $HOST_REFERENCIA é a referência, mantendo arquivo local...${NC}"
    else
        echo -e "  ${AMARELO}   Copiando xcp.conf do host $HOST_REFERENCIA...${NC}"
        scp -o StrictHostKeyChecking=no root@$HOST_REFERENCIA:/etc/zabbix/zabbix_agentd.d/xcp.conf root@$HOST:/etc/zabbix/zabbix_agentd.d/ 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "  ${VERDE}  ✓ xcp.conf copiado${NC}"
            executar_ssh $HOST "chmod 644 /etc/zabbix/zabbix_agentd.d/xcp.conf"
        else
            echo -e "  ${VERMELHO}  ✗ Falha ao copiar xcp.conf${NC}"
            continue
        fi
    fi
    
    # 5. Configurar sudoers
    echo -e "  ${AMARELO}5. Configurando sudoers...${NC}"
    executar_ssh $HOST 'grep -q "/opt/xensource/bin/xe" /etc/sudoers || echo "zabbix ALL=(ALL) NOPASSWD: /opt/xensource/bin/xe" >> /etc/sudoers'
    executar_ssh $HOST 'grep -q "/usr/sbin/xentop" /etc/sudoers || echo "zabbix ALL=(ALL) NOPASSWD: /usr/sbin/xentop" >> /etc/sudoers'
    echo -e "  ${VERDE}  ✓ Sudoers configurado${NC}"
    
    # 6. Ajustar zabbix_agentd.conf (Server e Hostname)
    echo -e "  ${AMARELO}6. Ajustando configurações do agente...${NC}"
    
    # Pegar hostname da máquina
    HOSTNAME=$(executar_ssh $HOST "hostname")
    
    # Ajustar Server
    executar_ssh $HOST "sed -i 's/^Server=.*/Server=$SERVER_ZABBIX,$HOST/' /etc/zabbix/zabbix_agentd.conf"
    executar_ssh $HOST "sed -i 's/^ServerActive=.*/ServerActive=$SERVER_ZABBIX/' /etc/zabbix/zabbix_agentd.conf"
    executar_ssh $HOST "sed -i 's/^Hostname=.*/Hostname=$HOSTNAME/' /etc/zabbix/zabbix_agentd.conf"
    
    # Ajustar UnsafeUserParameters
    executar_ssh $HOST 'sed -i "s/^# UnSafeUserParameters=0/UnsafeUserParameters=1/" /etc/zabbix/zabbix_agentd.conf 2>/dev/null'
    executar_ssh $HOST 'sed -i "s/^UnsafeUserParameters=0/UnsafeUserParameters=1/" /etc/zabbix/zabbix_agentd.conf 2>/dev/null'
    executar_ssh $HOST 'grep -q "^UnsafeUserParameters=1" /etc/zabbix/zabbix_agentd.conf || echo "UnsafeUserParameters=1" >> /etc/zabbix/zabbix_agentd.conf'
    
    # Ajustar Include
    executar_ssh $HOST 'sed -i "s|^# Include=/etc/zabbix/zabbix_agentd.d/\*.conf|Include=/etc/zabbix/zabbix_agentd.d/*.conf|" /etc/zabbix/zabbix_agentd.conf 2>/dev/null'
    executar_ssh $HOST 'grep -q "^Include=/etc/zabbix/zabbix_agentd.d/\*.conf" /etc/zabbix/zabbix_agentd.conf || echo "Include=/etc/zabbix/zabbix_agentd.d/*.conf" >> /etc/zabbix/zabbix_agentd.conf'
    
    echo -e "  ${VERDE}  ✓ Configurações ajustadas${NC}"
    
    # 7. Configurar iptables
    echo -e "  ${AMARELO}7. Configurando firewall...${NC}"
    executar_ssh $HOST 'iptables -I RH-Firewall-1-INPUT -p tcp --dport 10050 -j ACCEPT 2>/dev/null'
    executar_ssh $HOST 'service iptables save 2>/dev/null'
    echo -e "  ${VERDE}  ✓ Firewall configurado${NC}"
    
    # 8. Reiniciar agente
    echo -e "  ${AMARELO}8. Reiniciando Zabbix Agent...${NC}"
    executar_ssh $HOST "pkill zabbix_agentd; sleep 2; /opt/zabbix-agent/sbin/zabbix_agentd -c /etc/zabbix/zabbix_agentd.conf"
    sleep 3
    
    # 9. Verificar se subiu
    PORTA=$(executar_ssh $HOST "ss -lntp | grep -c 10050")
    if [ "$PORTA" -gt 0 ]; then
        echo -e "  ${VERDE}  ✓ Agente rodando na porta 10050${NC}"
    else
        echo -e "  ${VERMELHO}  ✗ Falha ao iniciar agente - verificando log...${NC}"
        executar_ssh $HOST "tail -5 /var/log/zabbix_agentd.log 2>/dev/null || echo 'Sem log disponível'"
    fi
    
    # 10. Testes básicos
    echo -e "  ${AMARELO}9. Testando itens básicos...${NC}"
    
    CPU=$(executar_ssh $HOST "/opt/zabbix-agent/sbin/zabbix_agentd -t xcp.cpu.host -c /etc/zabbix/zabbix_agentd.conf 2>/dev/null | grep -o '[0-9.]\+' | head -1")
    if [ -n "$CPU" ]; then
        echo -e "  ${VERDE}  ✓ CPU: $CPU%${NC}"
    else
        echo -e "  ${VERMELHO}  ✗ Falha no teste de CPU${NC}"
    fi
    
    VMS=$(executar_ssh $HOST "/opt/zabbix-agent/sbin/zabbix_agentd -t xcp.vm.running -c /etc/zabbix/zabbix_agentd.conf 2>/dev/null | grep -o '[0-9]\+' | head -1")
    if [ -n "$VMS" ]; then
        echo -e "  ${VERDE}  ✓ VMs running: $VMS${NC}"
    fi
    
    echo -e "${VERDE}  ✅ Host $HOST processado com sucesso!${NC}"
done

echo -e "\n${AZUL}========================================${NC}"
echo -e "${VERDE}  PROCESSO CONCLUÍDO!${NC}"
echo -e "${AZUL}========================================${NC}"
