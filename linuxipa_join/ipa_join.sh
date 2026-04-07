#!/bin/bash

#############################################
# SCRIPT: ipa_join.sh
#
# Descrição:
#   Script automatizado para ingressar servidores Linux
#   em um domínio FreeIPA.
#
# Compatível com:
#   - Ubuntu / Debian
#   - RHEL / CentOS / Rocky / Alma / Oracle Linux
#
# Funcionalidades:
#   - Detecta sistema operacional automaticamente
#   - Configura hostname (FQDN)
#   - Configura DNS
#   - Instala certificado da CA do IPA
#   - Instala dependências necessárias
#   - Limpa configurações antigas
#   - Configura sincronização de tempo (chrony)
#   - Realiza ingresso automatizado no domínio
#   - Valida autenticação
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 1.0
#############################################

clear
echo "========================================"
echo " IPA DOMAIN JOIN SCRIPT"
echo " Execucao iniciada em: $(date)"
echo "========================================"

# ===== VARIAVEIS (AJUSTE CONFORME AMBIENTE) =====
IPA_SERVER="ipa.example.local"
DOMAIN="example.local"
REALM="EXAMPLE.LOCAL"
DNS_SERVER="192.168.1.10"

# Solicita senha do admin
echo ""
read -sp "Digite a senha do admin do IPA: " ADMIN_PASSWORD
echo ""

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "[ERRO] Senha nao fornecida"
    exit 1
fi

# ===== HOSTNAME =====
HOST_SHORT=$(hostname -s 2>/dev/null | cut -d. -f1)
HOST_FQDN="$HOST_SHORT.$DOMAIN"
IP_LOCAL=$(hostname -I | awk '{print $1}')

# ===== DETECTA OS =====
source /etc/os-release

case "$ID" in
    ubuntu|debian)
        PKG_UPDATE="apt update -y"
        PKG_INSTALL="apt install -y freeipa-client wget ca-certificates curl chrony"
        CA_UPDATE="update-ca-certificates"
        ;;
    ol|rhel|centos|rocky|almalinux)
        PKG_UPDATE="dnf makecache"
        PKG_INSTALL="dnf install -y ipa-client wget ca-certificates curl chrony"
        CA_UPDATE="update-ca-trust extract"
        ;;
    *)
        echo "[ERRO] Sistema nao suportado"
        exit 1
        ;;
esac

echo "[INFO] Sistema identificado: $ID"

# ===== HOSTNAME =====
hostnamectl set-hostname "$HOST_FQDN"
echo "$HOST_FQDN" > /etc/hostname

# ===== DNS =====
chattr -i /etc/resolv.conf 2>/dev/null
cp /etc/resolv.conf /etc/resolv.conf.bkp_$(date +%F_%H%M%S)

cat <<EOF > /etc/resolv.conf
search $DOMAIN
nameserver $DNS_SERVER
EOF

# ===== VALIDACAO DNS =====
if ! getent hosts "$IPA_SERVER" >/dev/null 2>&1; then
    echo "[ERRO] DNS nao resolve $IPA_SERVER"
    exit 1
fi

# ===== HOSTS =====
cp /etc/hosts /etc/hosts.bkp_$(date +%F_%H%M%S)

sed -i "/$HOST_SHORT/d" /etc/hosts
echo "$IP_LOCAL $HOST_FQDN $HOST_SHORT" >> /etc/hosts

# ===== CERTIFICADO =====
curl -k -o /tmp/ipa-ca.crt https://$IPA_SERVER/ipa/config/ca.crt

if [[ $? -ne 0 ]]; then
    echo "[ERRO] Falha ao baixar certificado"
    exit 1
fi

if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    cp /tmp/ipa-ca.crt /usr/local/share/ca-certificates/ipa-ca.crt
else
    cp /tmp/ipa-ca.crt /etc/pki/ca-trust/source/anchors/ipa-ca.crt
fi

$CA_UPDATE

# ===== PACOTES =====
$PKG_UPDATE
$PKG_INSTALL

# ===== LIMPEZA =====
systemctl stop sssd 2>/dev/null
ipa-client-install --uninstall -U >/dev/null 2>&1

rm -rf /var/lib/ipa-client /etc/ipa /var/lib/sss/db/* /etc/krb5.keytab

# ===== CHRONY =====
if command -v chronyc &> /dev/null; then
    echo "server $IPA_SERVER iburst" >> /etc/chrony/chrony.conf
    systemctl restart chrony
fi

# ===== JOIN =====
ipa-client-install \
    --hostname="$HOST_FQDN" \
    --server="$IPA_SERVER" \
    --domain="$DOMAIN" \
    --realm="$REALM" \
    --mkhomedir \
    --force-join \
    --unattended \
    --principal=admin \
    --password="$ADMIN_PASSWORD" \
    --enable-dns-updates \
    --ntp-server="$IPA_SERVER"

if [[ $? -eq 0 ]]; then
    echo "✅ SUCESSO: Máquina ingressada no domínio"
else
    echo "❌ ERRO no ingresso"
    exit 1
fi