# 🔍 TOPAPP ULTIMATE - Monitor de CPU Wildfly/JBoss

Script profissional para monitoramento de processos Wildfly/JBoss com detecção de processos travados e filtro por cliente.

## 📋 Informações

| Item | Detalhe |
|------|---------|
| **Autor** | Kleber Eduardo Maximo |
| **Versão** | 5.5 |
| **Data** | 06/03/2026 |

## 🎯 Funcionalidades

- Monitora consumo de CPU de instâncias Wildfly/JBoss
- Filtro por cliente (case-insensitive)
- Cores por nível de severidade
- Barra de progresso visual
- Detecção de processos travados (>800%)
- Processamento em lotes para alta performance

## 🚀 Como usar

```bash
# Todos os clientes
./topapp.sh

# Filtrar por cliente específico
./topapp.sh nomedoCliente

# Monitoramento contínuo
watch -n 5 ./topapp.sh