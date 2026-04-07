# 📊 Verificador de Instâncias JBoss/Wildfly

Script para análise de memória alocada (Xms/Xmx) e consumo real de CPU/memória das instâncias JBoss/Wildfly.

## 📋 Informações

| Item | Detalhe |
|------|---------|
| **Autor** | Kleber Maximo |
| **Data** | 24/04/2025 |

## 🎯 Funcionalidades

- Lista automaticamente instâncias em `/opt`
- Captura memória alocada (Xmx) do `standalone.conf`
- Obtém PID, CPU e memória usada via `top`
- Calcula diferença entre memória alocada e usada
- Exibe total alocado vs memória do servidor

## 🚀 Como usar

```bash
chmod +x verifica_instancias.sh
./verifica_instancias.sh