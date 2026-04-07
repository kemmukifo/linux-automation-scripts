# 🖥️ Linux Domain Join Script (SSSD + Realmd)

Script para ingressar automaticamente uma máquina Linux (Ubuntu/Debian) em um domínio Active Directory utilizando SSSD e Realmd.

---

## 📌 Descrição

Este script automatiza todo o processo de integração com Active Directory, incluindo:

- Instalação de dependências necessárias
- Configuração do Kerberos (`krb5.conf`)
- Ingresso no domínio (`realm join`)
- Configuração do SSSD
- Ajustes no NSS (Name Service Switch)
- Teste de autenticação final

---

## ⚙️ Requisitos

- Sistema baseado em Debian/Ubuntu
- Acesso ao domínio Active Directory
- Permissão de usuário para ingressar máquinas no domínio
- Conectividade com o controlador de domínio (rede interna ou VPN)

---

## 🚀 Como usar

1. Torne o script executável:

```bash
chmod +x domain_join.sh
