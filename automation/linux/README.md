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


# 🐧 Linux Automation Scripts

Coleção de scripts para automação, troubleshooting e administração de ambientes Linux.

---

## 📦 Scripts disponíveis

### 👻 Ghost Process Detector
Identifica processos que estão escutando portas mas não possuem conexões ativas.

**Arquivo:**
`ghost-process-detector.sh`

**Funcionalidades:**
- Detecta processos em LISTEN sem conexões ESTAB
- Exibe porta, PID, nome do processo e aplicação
- Permite encerrar processos manualmente
- Kill seguro com fallback para kill -9

**Uso:**
```bash
chmod +x ghost-process-detector.sh
sudo ./ghost-process-detector.sh
