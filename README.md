# Ansible K3s Optimization

🚀 **Production-ready Ansible playbooks** для оптимизации K3s кластера, security hardening, honeypot deployment и автоматизации.

## 📋 Содержание

- **Playbooks**: готовые к запуску сценарии оптимизации
- **Roles**: модульные роли для переиспользования
- **Scripts**: bash скрипты для автобана и мониторинга
- **Templates**: конфигурационные файлы

## 🎯 Возможности

### 1️⃣ **Оптимизация системы**
- Kernel tuning (sysctl параметры)
- Zram swap конфигурация
- System limits (file descriptors, processes)
- Disk optimization (fstrim)

### 2️⃣ **Security Hardening**
- SSH hardening (нестандартный порт, отключение password auth)
- UFW firewall конфигурация
- Fail2ban с кастомными jail'ами
- Honeypot для обнаружения атак

### 3️⃣ **Advanced Security Stack** 🔥
- **PSAD** - Port scan attack detector с автобаном
- **ARPwatch** - ARP spoofing detection
- **ipset** - High-performance IP blacklisting (O(1) vs O(N))
- **xt_recent** - Kernel-based rate limiting & port scan detection
- **SYN cookies** - DDoS protection на уровне kernel
- **conntrack limits** - Connection exhaustion prevention
- **AppArmor** - Container escape protection

### 4️⃣ **Мониторинг**
- Health check скрипты
- Логирование и ротация
- Автоматические отчёты безопасности

## 🚀 Быстрый старт

### Установка Ansible (на мастер-ноде)

```bash
# Быстрая установка одной командой
curl -fsSL https://raw.githubusercontent.com/KomarovAI/ansible-k3s-optimization/main/setup.sh | bash
```

Или вручную:

```bash
# Установка Ansible
apt update && apt install -y python3-pip python3-venv git
python3 -m venv /opt/ansible-venv
source /opt/ansible-venv/bin/activate
pip install ansible ansible-core

# Клонирование репозитория
git clone https://github.com/KomarovAI/ansible-k3s-optimization.git /opt/k3s-ansible
cd /opt/k3s-ansible
```

### Запуск оптимизации

#### Базовая установка

```bash
cd /opt/k3s-ansible
source /opt/ansible-venv/bin/activate

# Dry run first
ansible-playbook playbooks/full-setup.yml --check

# Real deployment
ansible-playbook playbooks/full-setup.yml
```

#### Полная установка с Advanced Security 🔥

```bash
# Все security инструменты включая PSAD, ipset, xt_recent, ARPwatch
ansible-playbook playbooks/full-setup-enhanced.yml --check  # dry run
ansible-playbook playbooks/full-setup-enhanced.yml          # deploy
```

#### Только Advanced Security Stack

```bash
# Если базовая оптимизация уже установлена
ansible-playbook playbooks/advanced-security.yml
```

## 📁 Структура проекта

```
ansible-k3s-optimization/
├── ansible.cfg                 # Ansible конфигурация
├── inventory/
│   └── localhost.ini          # Inventory для localhost
├── playbooks/
│   ├── optimize-node.yml      # Основная оптимизация ноды
│   ├── security-analysis.yml  # Анализ безопасности
│   ├── full-setup.yml         # Базовая установка
│   ├── full-setup-enhanced.yml # С advanced security
│   ├── advanced-security.yml  # Только security stack
│   └── backup-configs.yml     # Backup конфигураций
├── roles/
│   ├── honeypot/              # Honeypot deployment
│   ├── fail2ban/              # Fail2ban конфигурация
│   ├── ssh_security/          # SSH hardening
│   ├── system_optimization/   # System tuning
│   ├── psad/                  # Port scan detection 🔥
│   ├── arpwatch/              # ARP spoofing protection 🔥
│   ├── ipset/                 # Performance IP blacklisting 🔥
│   ├── xt_recent/             # Kernel rate limiting 🔥
│   └── kernel_security/       # SYN cookies, conntrack, AppArmor 🔥
├── scripts/
│   ├── autoban-honeypot.sh    # Автоматический бан атакующих
│   ├── health-check.sh        # Проверка здоровья системы
│   └── port-security-check.sh # Анализ открытых портов
└── templates/
    └── ...                    # Jinja2 templates
```

## 🛠️ Playbooks

### `optimize-node.yml`
Основной playbook для оптимизации K3s ноды:
- Kernel modules (overlay, br_netfilter, nf_conntrack, zram)
- Sysctl параметры (network, memory, K8s specific)
- System limits (nofile, nproc)
- Zram swap setup
- Security hardening

### `advanced-security.yml` 🔥
Развёртывание продвинутого security stack:
- **PSAD** - детектирует port scans и автоматически банит
- **ipset** - ускоряет iptables в 10-30 раз при тысячах IP
- **xt_recent** - kernel-level autoban без парсинга логов
- **ARPwatch** - защита от MITM атак
- **SYN cookies** - защита от SYN flood DDoS
- **conntrack limits** - rate limiting на уровне kernel
- **AppArmor** - защита от container escape

### `security-analysis.yml`
Глубокий анализ безопасности:
- Honeypot статус и логи
- Fail2ban статистика и banned IPs
- Open ports анализ
- Sysctl network параметры
- IPTables/UFW правила

## 🔧 Roles

### Базовые роли

#### `honeypot`
Разворачивает honeypot на портах:
- 21 (FTP), 22 (SSH), 23 (Telnet)
- 25 (SMTP), 110 (POP3), 143 (IMAP)
- 3306 (MySQL), 3389 (RDP), 5432 (PostgreSQL)

#### `fail2ban`
Настраивает fail2ban с jail'ами:
- sshd (реальный SSH на порту 27015)
- honeypot (автобан атакующих)
- Custom фильтры

#### `ssh_security`
Hardening SSH:
- Нестандартный порт (27015)
- PasswordAuthentication no
- PermitRootLogin prohibit-password
- MaxAuthTries 3

### Advanced Security роли 🔥

#### `psad` - Port Scan Attack Detector
**Ресурсы**: 10-15 MB RAM, <1% CPU  
**Импакт**: Детектирует nmap, port sweeps, backdoor scans  
**Автобан**: При danger level 4+

```bash
# Проверка статуса
psad --Status
psad --Analyze
```

#### `ipset` - High-Performance IP Blacklisting
**Ресурсы**: ~5 MB RAM, <0.1% CPU  
**Импакт**: O(1) lookup vs O(N) в iptables  
**Performance**: 10-30% CPU экономия при 1000+ IP

```bash
# Команды
ipset list                          # Все sets
ipset add blacklist 1.2.3.4         # Добавить IP
ipset del blacklist 1.2.3.4         # Удалить IP
```

#### `xt_recent` - Kernel-Based Rate Limiting
**Ресурсы**: 0 MB (kernel module)  
**Импакт**: Детектирует port scans БЕЗ логов  
**Автобан**: На уровне kernel space

```bash
# Проверка tracked IPs
cat /proc/net/xt_recent/ssh_attack
cat /proc/net/xt_recent/portscan
```

#### `arpwatch` - ARP Spoofing Detection
**Ресурсы**: 3-5 MB RAM, <0.5% CPU  
**Импакт**: Защита от MITM атак  
**Мониторинг**: eth0, cni0 (pod network)

```bash
# Логи
tail -f /var/log/arpwatch-*.log
cat /var/lib/arpwatch/arp.dat
```

#### `kernel_security` - Kernel-Level Protection
**Компоненты**:
- **SYN cookies**: DDoS protection (0 overhead)
- **conntrack limits**: Connection exhaustion prevention
- **AppArmor**: Container escape protection

## 📊 Scripts

### `autoban-honeypot.sh`
Автоматический бан атакующих на honeypot:
```bash
# Запуск вручную
/opt/k3s-ansible/scripts/autoban-honeypot.sh

# Автоматический запуск каждый час
*/60 * * * * /opt/k3s-ansible/scripts/autoban-honeypot.sh
```

### `health-check.sh`
Проверка состояния системы:
```bash
/opt/k3s-ansible/scripts/health-check.sh
```

### `security-stack-status` 🔥
Проверка advanced security stack:
```bash
/usr/local/bin/security-stack-status
```

### `security-daily-report` 🔥
Ежедневный отчёт безопасности:
```bash
/usr/local/bin/security-daily-report
```

## 🔒 Security

Рекомендуемая конфигурация портов:
- **27015**: SSH (реальный, hardened)
- **6443**: K3s API (secured with certs)
- **21-5432**: Honeypot traps
- **10250**: Kubelet (закрыть извне!)

### Закрыть Kubelet от внешнего доступа

```bash
ufw delete allow 10250/tcp
ufw insert 6 allow from 10.42.0.0/16 to any port 10250 proto tcp comment 'K3s Kubelet - pod network only'
ufw reload
```

## 📈 Мониторинг

### Общий статус

```bash
# Статус всех компонентов
ansible-playbook playbooks/check-optimization.yml

# Advanced security stack
/usr/local/bin/security-stack-status

# Health check
/usr/local/bin/k3s-health-check
```

### Fail2ban + ipset

```bash
# Статистика
fail2ban-client status
fail2ban-client status sshd

# ipset списки
ipset list fail2ban-sshd
ipset list fail2ban-honeypot
```

### PSAD

```bash
# Статус и анализ
psad --Status
psad --Analyze

# Логи
tail -f /var/log/psad/psadfifo
```

### Honeypot

```bash
# Логи
tail -f /var/log/honeypot.log

# Статистика атак за сегодня
grep "$(date +%Y-%m-%d)" /var/log/honeypot.log | wc -l
```

## 📊 Performance Impact

### Базовая установка
| Компонент | RAM | CPU | Impact |
|-----------|-----|-----|--------|
| System optimization | 0 MB | 0% | 🔥🔥🔥🔥🔥 |
| SSH hardening | 0 MB | 0% | 🔥🔥🔥🔥 |
| Fail2ban | 20 MB | 1-2% | 🔥🔥🔥🔥 |
| Honeypot | 5 MB | <1% | 🔥🔥🔥🔥 |
| **Total** | **~25 MB** | **~3%** | - |

### Advanced Security Stack 🔥
| Компонент | RAM | CPU | Impact |
|-----------|-----|-----|--------|
| PSAD | 10-15 MB | <1% | 🔥🔥🔥🔥 |
| ARPwatch | 3-5 MB | <0.5% | 🔥🔥🔥🔥 |
| ipset | 5 MB | <0.1% | 🔥🔥🔥🔥🔥 |
| xt_recent | 0 MB | 0% | 🔥🔥🔥🔥 |
| SYN cookies | 0 MB | 0% | 🔥🔥🔥🔥🔥 |
| conntrack | 0 MB | <0.1% | 🔥🔥🔥 |
| AppArmor | 5-10 MB | <0.5% | 🔥🔥🔥🔥 |
| **Total** | **~30-40 MB** | **~2-3%** | - |

### **ПОЛНАЯ УСТАНОВКА**: ~55-65 MB RAM, ~5-6% CPU → **MAXIMUM SECURITY** 🔥

## 🎓 Best Practices

1. **Всегда делай dry-run** перед реальным запуском
2. **Бэкапь конфиги** перед изменениями
3. **Тестируй SSH доступ** после изменения порта
4. **Мониторь логи** fail2ban и honeypot
5. **Регулярно обновляй** banned IP lists

## 🤝 Contributing

Пул реквесты приветствуются! Пожалуйста:
1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

MIT License

## 👤 Author

**Artur Komarov** - [KomarovAI](https://github.com/KomarovAI)

---

⚡ **Production-ready** | 🔒 **Security-focused** | 🚀 **Performance-optimized** | 🔥 **Advanced Security Stack**
