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

### 3️⃣ **Мониторинг**
- Health check скрипты
- Логирование и ротация
- Автоматические отчёты безопасности

## 🚀 Быстрый старт

### Установка Ansible (на мастер-ноде)

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

```bash
# Проверка синтаксиса
ansible-playbook playbooks/optimize-node.yml --syntax-check

# Dry-run
ansible-playbook playbooks/optimize-node.yml --check

# Реальный запуск
ansible-playbook playbooks/optimize-node.yml
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
│   └── backup-configs.yml     # Backup конфигураций
├── roles/
│   ├── honeypot/              # Honeypot deployment
│   ├── fail2ban/              # Fail2ban конфигурация
│   ├── ssh_security/          # SSH hardening
│   └── system_optimization/   # System tuning
├── scripts/
│   ├── autoban-honeypot.sh    # Автоматический бан атакующих
│   └── health-check.sh        # Проверка здоровья системы
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

### `security-analysis.yml`
Глубокий анализ безопасности:
- Honeypot статус и логи
- Fail2ban статистика и banned IPs
- Open ports анализ
- Sysctl network параметры
- IPTables/UFW правила

## 🔧 Roles

### `honeypot`
Разворачивает honeypot на портах:
- 21 (FTP), 22 (SSH), 23 (Telnet)
- 25 (SMTP), 110 (POP3), 143 (IMAP)
- 3306 (MySQL), 3389 (RDP), 5432 (PostgreSQL)

### `fail2ban`
Настраивает fail2ban с jail'ами:
- sshd (реальный SSH на порту 27015)
- honeypot (автобан атакующих)
- Custom фильтры

### `ssh_security`
Hardening SSH:
- Нестандартный порт (27015)
- PasswordAuthentication no
- PermitRootLogin prohibit-password
- MaxAuthTries 3

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

```bash
# Статус всех компонентов
ansible-playbook playbooks/check-optimization.yml

# Health check
/usr/local/bin/k3s-health-check

# Fail2ban статистика
fail2ban-client status

# Honeypot логи
tail -f /var/log/honeypot.log
```

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

⚡ **Production-ready** | 🔒 **Security-focused** | 🚀 **Performance-optimized**
