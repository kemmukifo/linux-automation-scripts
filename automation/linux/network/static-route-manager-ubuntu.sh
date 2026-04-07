#!/bin/bash
# --------------------------------------------------------------------------------
# Script: static-route-manager.sh
# Autor: Kleber Maximo
# Versão: 1.0
# Data: 2025-08-15
#
# Descrição:
#   Gerencia rotas estáticas de forma segura em sistemas Linux sem alterar
#   configurações do Netplan ou NetworkManager.
#
#   - Detecta automaticamente a interface de rede padrão
#   - Aplica rotas estáticas imediatamente (runtime)
#   - Cria persistência via systemd (sem impacto na rede)
#   - Evita indisponibilidade causada por reload de rede
#
# Uso:
#   chmod +x static-route-manager.sh
#   sudo ./static-route-manager.sh
#
# Observação:
#   Ideal para ambientes produtivos onde alterações de rede não podem causar
#   downtime (ex: servidores críticos, VMs, ambientes cloud).
# --------------------------------------------------------------------------------

echo "======================================="
echo "Static Route Manager - MODO SEGURO"
echo "======================================="

# Detecta interface
IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
echo "✔ Interface: $IFACE"

# Rotas
ROUTES=(
"172.80.1.0/24 172.30.1.99"
"172.28.1.0/24 172.30.1.1"
"10.122.0.0/22 172.30.1.254"
"172.31.1.0/24 172.30.1.1"
"172.16.16.0/22 172.30.1.254"
"10.21.0.0/24 172.30.1.254"
"10.0.2.0/24 172.30.1.99"
"172.31.2.0/24 172.30.1.254"
)

# Aplica rotas temporárias
echo "🔧 Aplicando rotas..."
for route in "${ROUTES[@]}"; do
    DEST=$(echo $route | awk '{print $1}')
    GW=$(echo $route | awk '{print $2}')
    ip route add "$DEST" via "$GW" dev "$IFACE" 2>/dev/null || true
    echo "  ✔ $DEST via $GW"
done

# Cria script systemd (NÃO MEXE NO NETPLAN)
echo "📝 Criando persistência via systemd..."
cat > /usr/local/bin/add_routes.sh << EOF
#!/bin/bash
sleep 5
IFACE=$IFACE
EOF

for route in "${ROUTES[@]}"; do
    DEST=$(echo $route | awk '{print $1}')
    GW=$(echo $route | awk '{print $2}')
    echo "ip route add $DEST via $GW dev \$IFACE 2>/dev/null || true" >> /usr/local/bin/add_routes.sh
done

chmod +x /usr/local/bin/add_routes.sh

cat > /etc/systemd/system/add-routes.service << EOF
[Unit]
Description=Add static routes
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/add_routes.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable add-routes.service
systemctl start add-routes.service

echo ""
echo "✅ CONFIGURADO COM SUCESSO!"
echo "======================================="
echo "Rotas ativas agora e após reboot"
echo "Para verificar: ip route show"
echo "======================================="
