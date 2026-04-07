#!/bin/bash
###############################################################################
# Script: ubuntu-ad-domain-join-sssd.sh
#
# Descrição:
#   Script para ingressar máquinas Ubuntu em um domínio Active Directory
#   utilizando SSSD.
#
# Funcionalidades:
#   - Instala dependências necessárias
#   - Configura Kerberos (krb5)
#   - Realiza join no domínio
#   - Configura SSSD automaticamente
#   - Ajusta NSS para autenticação via AD
#
# Objetivo:
#   Automatizar o processo de integração Linux + Active Directory,
#   reduzindo erros manuais e tempo de configuração.
#
# Uso:
#   sudo ./ubuntu-ad-domain-join-sssd.sh
#
# Requisitos:
#   - Acesso ao domínio (rede interna ou VPN)
#   - Usuário com permissão para ingressar máquinas no domínio
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################

set -e

echo "=========================================="
echo "   INGRESSO AO DOMÍNIO ACTIVE DIRECTORY   "
echo "=========================================="

# =========================
# Inputs do usuário
# =========================
read -p "Digite o domínio (ex: empresa.local): " DOMAIN
read -p "Digite o servidor AD (ex: dc01.empresa.local): " AD_SERVER
read -p "Digite o usuário com permissão: " AD_USER

REALM=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')

# =========================
# Instala dependências
# =========================
echo "[+] Instalando pacotes..."
sudo apt update
sudo apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin krb5-user

# =========================
# Configuração Kerberos
# =========================
echo "[+] Configurando Kerberos..."
sudo bash -c "cat > /etc/krb5.conf <<EOF
[libdefaults]
 default_realm = $REALM
 dns_lookup_realm = false
 dns_lookup_kdc = true

[realms]
 $REALM = {
  kdc = $AD_SERVER
  admin_server = $AD_SERVER
 }

[domain_realm]
 .$DOMAIN = $REALM
 $DOMAIN = $REALM
EOF"

# =========================
# Join no domínio
# =========================
echo "[+] Ingressando no domínio..."
sudo realm join --user="$AD_USER" "$DOMAIN"

# =========================
# Configuração SSSD
# =========================
echo "[+] Configurando SSSD..."
sudo bash -c "cat > /etc/sssd/sssd.conf <<EOF
[sssd]
domains = $DOMAIN
config_file_version = 2
services = nss, pam

[domain/$DOMAIN]
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = $REALM
id_provider = ad
fallback_homedir = /home/%u@%d
ad_domain = $DOMAIN
use_fully_qualified_names = True
ldap_id_mapping = True
access_provider = ad
EOF"

sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd

# =========================
# NSS
# =========================
echo "[+] Ajustando NSS..."
sudo sed -i '/^passwd:/ s/$/ sss/' /etc/nsswitch.conf
sudo sed -i '/^group:/ s/$/ sss/' /etc/nsswitch.conf
sudo sed -i '/^shadow:/ s/$/ sss/' /etc/nsswitch.conf

# =========================
# Validação
# =========================
echo ""
echo "✅ Ingresso concluído!"
echo "Teste com:"
echo "  id $AD_USER@$DOMAIN"
