# 📊 Java Network Usage Monitor

Script avançado para monitoramento de consumo de banda de rede por ambientes Java (WildFly/JBoss/Tomcat).

---

## 🎯 Objetivo

Fornecer visibilidade detalhada do consumo de rede por aplicação Java em execução, permitindo:

- Identificar ambientes com alto consumo de banda
- Detectar gargalos de rede
- Analisar distribuição de tráfego entre aplicações
- Apoiar troubleshooting em ambientes produtivos

---

## ⚙️ Funcionamento

O script realiza:

- 🔍 Detecção automática da interface de rede ativa
- ☕ Identificação de processos Java em execução
- 🔗 Correlação de PID com ambiente (WildFly / Tomcat)
- 📡 Coleta de tráfego em tempo real usando `nethogs`
- 📊 Consolidação e exibição dos dados em MB/s

---

## 🚀 Como usar

### Execução padrão (10 segundos)
```bash
sudo ./java_net_usage.sh
