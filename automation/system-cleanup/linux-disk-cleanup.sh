#!/usr/bin/env bash
###############################################################################
# Script: linux-disk-cleanup.sh
#
# Descrição:
#   Script para limpeza e otimização de espaço em disco em sistemas Linux
#   (Oracle Linux, CentOS, RHEL), inspirado no "cleanmgr" do Windows.
#
# Objetivo:
#   Liberar espaço em disco com segurança, removendo arquivos temporários,
#   logs antigos, caches e pacotes desnecessários.
#
# Funcionamento:
#   - Limpa cache de pacotes (dnf/yum)
#   - Remove dependências não utilizadas
#   - Remove logs antigos (>30 dias)
#   - Limpa arquivos temporários (/tmp, /var/tmp)
#   - Limpa cache de usuários
#   - Reduz logs do systemd (journalctl)
#   - Remove kernels antigos
#   - Libera cache de memória
#
# Uso:
#   sudo ./linux-disk-cleanup.sh
#
# Requisitos:
#   - Permissão root
#   - dnf ou yum
#
# Observações:
#   - Mantém os 2 kernels mais recentes
#   - Mantém logs recentes para troubleshooting
#   - Execução segura (não remove arquivos críticos)
#
# Autor: Kleber Eduardo Maximo
# Data: 2026-04-07
# Versão: 2.0
###############################################################################

# =========================
# Verificar root
# =========================
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute como root: sudo $0"
    exit 1
fi

echo "==== 🧹 INICIANDO LIMPEZA DO SISTEMA ===="

# =========================
# Espaço antes
# =========================
BEFORE=$(df / | awk 'NR==2 {print $4}')

# =========================
# 1. Cache de pacotes
# =========================
echo "[1/8] Limpando cache de pacotes..."
dnf clean all -y 2>/dev/null || yum clean all -y

# =========================
# 2. Pacotes órfãos
# =========================
echo "[2/8] Removendo dependências não utilizadas..."
dnf autoremove -y 2>/dev/null || yum autoremove -y

# =========================
# 3. Logs antigos
# =========================
echo "[3/8] Removendo logs antigos (>30 dias)..."
find /var/log -type f -name "*.log*" -mtime +30 -delete 2>/dev/null

# =========================
# 4. Arquivos temporários
# =========================
echo "[4/8] Limpando diretórios temporários..."
find /tmp -type f -atime +7 -delete 2>/dev/null
find /var/tmp -type f -atime +7 -delete 2>/dev/null

# =========================
# 5. Cache de usuários
# =========================
echo "[5/8] Limpando cache de usuários..."
for dir in /home/* /root; do
    if [ -d "$dir/.cache" ]; then
        find "$dir/.cache" -type f -atime +30 -delete 2>/dev/null
    fi
done

# =========================
# 6. Journalctl
# =========================
echo "[6/8] Limpando logs do systemd..."
journalctl --vacuum-time=7d

# =========================
# 7. Kernels antigos
# =========================
echo "[7/8] Removendo kernels antigos..."
if command -v package-cleanup &> /dev/null; then
    package-cleanup --oldkernels --count=2 -y
else
    echo "⚠️ package-cleanup não encontrado"
fi

# =========================
# 8. Cache de memória
# =========================
echo "[8/8] Liberando cache de memória..."
sync
echo 3 > /proc/sys/vm/drop_caches

# =========================
# Espaço depois
# =========================
AFTER=$(df / | awk 'NR==2 {print $4}')
FREED=$((AFTER - BEFORE))

echo ""
echo "==== ✅ LIMPEZA FINALIZADA ===="

echo "📊 Espaço antes : $((BEFORE / 1024)) MB"
echo "📊 Espaço depois: $((AFTER / 1024)) MB"
echo "💾 Liberado     : $((FREED / 1024)) MB"

echo ""
df -h /

echo ""
echo "⚠️ Avisos:"
echo "- Logs antigos removidos (>30 dias)"
echo "- Apenas 2 kernels mantidos"
echo "- Journal mantido por 7 dias"
