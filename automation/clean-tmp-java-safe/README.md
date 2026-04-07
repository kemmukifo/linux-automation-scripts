# 🧹 TMP Clean Safe Mode

Script de limpeza segura para o diretório `/tmp` com proteção contra remoção de arquivos em uso.

## 📋 Informações

| Item | Detalhe |
|------|---------|
| **Autor** | Kleber Eduardo Maximo |
| **Versão** | 1.0 |
| **Data** | 26/02/2026 |
| **Execução** | A cada 2 horas via crontab |

## 🎯 Funcionalidade

Este script realiza a limpeza **controlada e segura** do diretório `/tmp`, removendo apenas arquivos que:

- ✅ Possuem mais de **30 minutos** de idade
- ✅ São do tipo **arquivo** (não remove diretórios)
- ✅ **NÃO estão em uso** por nenhum processo em execução

## 🛡️ Mecanismos de Segurança

| Proteção | Descrição |
|----------|-----------|
| `fuser -s` | Verifica se o arquivo está aberto por algum processo antes de remover |
| `-xdev` | Não atravessa outros filesystems montados em `/tmp` |
| `-not -path` | Ignora pontos de montagem do tipo `/.mount_*` (ex: Snap packages) |
| `-type f` | Atua apenas em arquivos, preservando diretórios |

## 📁 Tipos de Arquivo Removidos

| Categoria | Extensões |
|-----------|-----------|
| Documentos | `.doc`, `.docx`, `.pdf`, `.txt`, `.rtf`, `.odt` |
| Planilhas | `.xls`, `.xlsx` |
| Imagens | `.jpg`, `.jpeg`, `.png` |
| Arquivos compactados | `.zip` |
| E-mails | `.eml`, `.msg` |
| Áudio | `.wav` |

## 🚀 Como Usar

### 1. Execução manual

```bash
chmod +x tmp-clean-safe.sh
./tmp-clean-safe.sh