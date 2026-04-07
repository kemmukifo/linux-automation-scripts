# 🚨 TMP Guard - Emergency Mode

Script de monitoramento e limpeza emergencial para o diretório `/tmp` quando o espaço atinge níveis críticos.

## 📋 Informações

| Item | Detalhe |
|------|---------|
| **Autor** | Kleber Eduardo Maximo |
| **Versão** | 1.0 |
| **Execução** | A cada 30 minutos via crontab |

## 🎯 Funcionalidade

Monitora continuamente o espaço em `/tmp` e dispara **limpeza emergencial** quando o sistema entra em estado crítico, removendo arquivos antigos sem verificação de uso para liberar espaço rapidamente.

## ⚠️ Condições de Emergência

O modo emergência é ativado quando **QUALQUER** condição abaixo for verdadeira:

| Condição | Limite | Significado |
|----------|--------|--------------|
| **Uso do /tmp** | ≥ 90% | Diretório quase cheio |
| **Espaço livre** | ≤ 12 GB | Pouco espaço disponível |

## 🔄 Modos de Operação

### Modo Normal (espaço OK)