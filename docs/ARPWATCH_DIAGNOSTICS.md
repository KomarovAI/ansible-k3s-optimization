# ARPwatch Integration & Diagnostics

## Обзор

ARPwatch — инструмент мониторинга ARP-таблицы, который **детектирует ARP spoofing атаки** (подмену MAC-адресов) и защищает от **Man-in-the-Middle (MITM)** атак в локальной сети.

## Автоматическая установка

ARPwatch роль **автоматически** определяет интерфейсы для мониторинга:

### Мониторинг интерфейсов:

1. **Главный интерфейс** (автодетект через default route):
   - `ens3`, `eth0`, `enp0s3` и т.д.
   - Защита от MITM атак из внешней сети
   - Флаг `-a` (мониторит все ARP пакеты, включая bogons)

2. **cni0** (Kubernetes pod network):
   - Автодетект если существует
   - Защита от вредоносных pod'ов
   - Детектирует MAC spoofing внутри кластера

### Установка:

```bash
cd /opt/k3s-ansible
source /opt/ansible-venv/bin/activate
ansible-playbook playbooks/advanced-security.yml --tags arpwatch
```

## Диагностика

### Автоматическая проверка

Diagnostic playbook **автоматически проверяет**:

1. **Статус сервисов**: active/inactive
2. **Bogon rate**: высокая частота сканирования (>50/5min)
3. **MAC адрес changes**: подмена MAC (🚨 MITM атака!)
4. **Pod activity**: высокая скорость создания pod'ов
5. **Pod MAC spoofing**: вредоносные pod'ы (🚨 malicious!)

### Запуск диагностики:

```bash
# Быстрая CLI проверка
sudo /usr/local/bin/k3s-conflict-check

# Полная Ansible диагностика
ansible-playbook playbooks/diagnostic-comprehensive.yml
```

## Мониторинг

### Статус сервисов:

```bash
# Проверить статус
systemctl status arpwatch-ens3
systemctl status arpwatch-cni0

# Просмотр процессов
ps aux | grep arpwatch
```

### Real-time логи:

```bash
# Внешний интерфейс
journalctl -u arpwatch-ens3 -f

# Pod network
journalctl -u arpwatch-cni0 -f

# Последние 50 записей
journalctl -u arpwatch-ens3 -n 50 --no-pager
```

### ARP база данных:

```bash
# Просмотр IP ↔ MAC пар
cat /var/lib/arpwatch/arp-ens3.dat
cat /var/lib/arpwatch/arp-cni0.dat

# Количество записей
wc -l /var/lib/arpwatch/arp-*.dat

# Файлы базы
ls -lh /var/lib/arpwatch/
```

## Алерты

### Типы алертов:

#### 1. **New Station** (новое устройство)
```
new station 10.42.0.85
ethernet address: 22:86:5e:ee:3e:9f
```
**Значение**: Новый pod/устройство в сети (нормально)

#### 2. **Bogon** (неизвестная подсеть)
```
arpwatch: bogon 89.213.44.1 00:00:5e:00:01:01 ens3
```
**Значение**: ARP пакет из неизвестной подсети (нормально для `-a` флага)

#### 3. **Changed Ethernet Address** 🚨 **CRITICAL**
```
changed ethernet address 192.168.1.1
from: aa:bb:cc:dd:ee:ff
to: 11:22:33:44:55:66
```
**Значение**: **MITM атака!** IP изменил MAC-адрес

**Действия**:
1. Немедленно проверить кто подменил MAC
2. Блокировать сомнительный IP/MAC
3. Проанализировать трафик

### Примеры алертов:

#### Нормальная активность:
```bash
# Новые pod'ы в Kubernetes
journalctl -u arpwatch-cni0 | grep "new station"

# Bogons (нормально для внешней сети)
journalctl -u arpwatch-ens3 | grep "bogon"
```

#### Подозрительная активность:
```bash
# MAC адрес changes (ПОДОЗРЕНИЕ!)
journalctl -u arpwatch-ens3 --since "1 hour ago" | grep "changed ethernet"

# Высокая bogon rate (возможно ARP flood)
journalctl -u arpwatch-ens3 --since "5 minutes ago" | grep -c "bogon"

# Pod MAC spoofing (ВРЕДОНОСНЫЙ POD!)
journalctl -u arpwatch-cni0 | grep "changed ethernet"
```

## Troubleshooting

### Сервис не запускается:

```bash
# Проверить логи
journalctl -xeu arpwatch-ens3

# Проверить права
ls -ld /var/lib/arpwatch/
ls -l /var/lib/arpwatch/arp-*.dat

# Исправить права
sudo chmod 755 /var/lib/arpwatch/
sudo chown arpwatch:arpwatch /var/lib/arpwatch/arp-*.dat

# Перезапустить
sudo systemctl restart arpwatch-ens3 arpwatch-cni0
```

### Нет данных в базе:

```bash
# Проверить что сервис запущен
systemctl is-active arpwatch-ens3

# Подождать несколько минут для накопления ARP пакетов
sleep 60

# Проверить базу
cat /var/lib/arpwatch/arp-ens3.dat
```

## Performance Impact

| Метрика | Значение |
|---------|----------|
| **RAM** | 1-2 MB per interface |
| **CPU** | < 0.5% |
| **Disk I/O** | Minimal |
| **Network** | Passive listening |

**Вывод**: Minimal overhead, идеально для production!

## Бест Практис

1. **Мониторить логи регулярно**: `journalctl -u arpwatch-* --since "1 day ago"`
2. **Настроить email alerts** (optional): модифицировать systemd service с `-s root@localhost`
3. **Автоматическая диагностика**: Ежедневно в 06:00 (cron)
4. **Бэкап базы**: `cp /var/lib/arpwatch/arp-*.dat /backup/`
5. **Интеграция с SIEM**: парсить syslog для "changed ethernet"

## Интеграция

### Автоматическая диагностика:

- **Cron job**: `/usr/local/bin/k3s-conflict-check` (ежедневно 06:00)
- **Ansible playbook**: `playbooks/diagnostic-comprehensive.yml`
- **Логи**: `/var/log/k3s-conflict-check.log`

### Что проверяется:

1. Статус ARPwatch сервисов
2. Bogon rate (высокая частота = возможное ARP spoofing)
3. MAC address changes (🚨 MITM атака)
4. Pod MAC spoofing (🚨 вредоносные pod'ы)
5. Высокая скорость создания pod'ов

## Summary

ARPwatch — **критичный компонент** security stack для:

- ✅ **MITM защита** на внешнем интерфейсе
- ✅ **Pod security** monitoring в Kubernetes
- ✅ **ARP spoofing detection** в реальном времени
- ✅ **Minimal overhead** (~2-3 MB RAM)
- ✅ **Автоматический setup** (не нужно настраивать интерфейсы)

**Production-ready компонент security stack!** 🛡️
