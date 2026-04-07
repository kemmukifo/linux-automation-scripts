\# 🔐 IPA Domain Join Script (Linux)



Script para ingressar automaticamente servidores Linux em um domínio \*\*FreeIPA\*\*.



\---



\## 📌 Descrição



Este script automatiza todo o processo de integração com FreeIPA:



\- Configuração de hostname (FQDN)

\- Configuração de DNS

\- Instalação de certificado da CA

\- Instalação de pacotes necessários

\- Limpeza de configurações antigas

\- Sincronização de tempo (NTP/Chrony)

\- Ingresso automatizado no domínio



\---



\## ⚙️ Sistemas Suportados



\- Ubuntu / Debian

\- RHEL / CentOS

\- Rocky Linux / AlmaLinux

\- Oracle Linux



\---



\## ⚙️ Pré-requisitos



\- Acesso ao servidor FreeIPA

\- Usuário com permissão de join (ex: admin)

\- DNS funcional apontando para o IPA

\- Conectividade de rede com o servidor



\---



\## 🚀 Como usar



\### 1. Editar variáveis no script



```bash

IPA\_SERVER="ipa.example.local"

DOMAIN="example.local"

REALM="EXAMPLE.LOCAL"

DNS\_SERVER="192.168.1.10"

