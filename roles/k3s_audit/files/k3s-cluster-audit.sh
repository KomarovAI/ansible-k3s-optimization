#!/bin/bash

################################################################################
# K3s Production Cluster - Complete Audit Script
# Автор: Komarov AI
# Дата: 2025-11-15
# Описание: Полный аудит master-ноды K3s кластера
################################################################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для красивого вывода заголовков
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_subheader() {
    echo -e "\n${YELLOW}➤ $1${NC}"
    echo "────────────────────────────────────────────────────────────"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   print_error "Этот скрипт должен быть запущен с правами root (sudo)"
   exit 1
fi

# Создаем директорию для отчетов
REPORT_DIR="/tmp/k3s-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPORT_DIR"
print_success "Отчеты будут сохранены в: $REPORT_DIR"

################################################################################
# 1. СИСТЕМНАЯ ИНФОРМАЦИЯ
################################################################################
print_header "1. СИСТЕМНАЯ ИНФОРМАЦИЯ MASTER-НОДЫ"

print_subheader "1.1 Базовая информация о системе"
{
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Current Date: $(date)"
} | tee "$REPORT_DIR/01-system-info.txt"

print_subheader "1.2 Ресурсы сервера"
{
    echo "=== CPU ==="
    lscpu | grep -E "Model name|Socket|Core|Thread"
    echo ""
    echo "=== RAM ==="
    free -h
    echo ""
    echo "=== Disk ==="
    df -h | grep -E "Filesystem|/dev/"
    echo ""
    echo "=== Swap ==="
    swapon --show
} | tee "$REPORT_DIR/02-resources.txt"

print_subheader "1.3 Загрузка системы"
{
    echo "=== Load Average ==="
    uptime
    echo ""
    echo "=== Top Processes (CPU) ==="
    ps aux --sort=-%cpu | head -10
    echo ""
    echo "=== Top Processes (Memory) ==="
    ps aux --sort=-%mem | head -10
} | tee "$REPORT_DIR/03-system-load.txt"

################################################################################
# 2. СЕТЕВАЯ КОНФИГУРАЦИЯ
################################################################################
print_header "2. СЕТЕВАЯ КОНФИГУРАЦИЯ"

print_subheader "2.1 Сетевые интерфейсы"
{
    echo "=== IP Addresses ==="
    ip -4 addr show
    echo ""
    echo "=== IP Routes ==="
    ip route show
    echo ""
    echo "=== WireGuard Interface (flannel-wg) ==="
    ip addr show flannel-wg 2>/dev/null || echo "WireGuard интерфейс не найден"
} | tee "$REPORT_DIR/04-network-interfaces.txt"

print_subheader "2.2 Открытые порты и соединения"
{
    echo "=== Listening Ports ==="
    ss -tulpn | grep LISTEN
    echo ""
    echo "=== Established Connections ==="
    ss -tunp | grep ESTAB | wc -l
    echo "Количество активных соединений: $(ss -tunp | grep ESTAB | wc -l)"
} | tee "$REPORT_DIR/05-network-ports.txt"

print_subheader "2.3 Firewall (UFW) правила"
{
    if command -v ufw &> /dev/null; then
        echo "=== UFW Status ==="
        ufw status verbose
        echo ""
        echo "=== UFW Rules (numbered) ==="
        ufw status numbered
    else
        echo "UFW не установлен"
    fi
} | tee "$REPORT_DIR/06-firewall-ufw.txt"

print_subheader "2.4 iptables правила"
{
    echo "=== iptables Filter Table ==="
    iptables -L -n -v --line-numbers
    echo ""
    echo "=== iptables NAT Table ==="
    iptables -t nat -L -n -v --line-numbers
} | tee "$REPORT_DIR/07-firewall-iptables.txt"

print_subheader "2.5 Kernel Network Parameters (sysctl)"
{
    echo "=== Network Performance ==="
    sysctl net.ipv4.tcp_congestion_control
    sysctl net.core.default_qdisc
    sysctl net.core.rmem_max
    sysctl net.core.wmem_max
    echo ""
    echo "=== Connection Tracking ==="
    sysctl net.netfilter.nf_conntrack_max 2>/dev/null || echo "nf_conntrack not loaded"
    sysctl net.nf_conntrack_max 2>/dev/null || echo "nf_conntrack not loaded"
    echo ""
    echo "=== IPv4 Forwarding ==="
    sysctl net.ipv4.ip_forward
    echo ""
    echo "=== All Network Sysctls ==="
    sysctl -a 2>/dev/null | grep -E "net\.(ipv4|core|netfilter)"
} | tee "$REPORT_DIR/08-kernel-network-params.txt"

print_subheader "2.6 DNS Configuration"
{
    echo "=== /etc/resolv.conf ==="
    cat /etc/resolv.conf
    echo ""
    echo "=== DNS Test ==="
    dig +short google.com @8.8.8.8 || echo "dig не установлен"
} | tee "$REPORT_DIR/09-dns-config.txt"

################################################################################
# 3. K3S КОНФИГУРАЦИЯ
################################################################################
print_header "3. K3S КОНФИГУРАЦИЯ"

print_subheader "3.1 K3s Service Status"
{
    echo "=== K3s Service Status ==="
    systemctl status k3s --no-pager
    echo ""
    echo "=== K3s Service Is Active ==="
    systemctl is-active k3s
} | tee "$REPORT_DIR/10-k3s-service-status.txt"

print_subheader "3.2 K3s Version"
{
    echo "=== K3s Version ==="
    k3s --version
    echo ""
    echo "=== Kubectl Version ==="
    kubectl version --short 2>/dev/null || kubectl version
} | tee "$REPORT_DIR/11-k3s-version.txt"

print_subheader "3.3 K3s Configuration Files"
{
    echo "=== /etc/rancher/k3s/config.yaml ==="
    if [ -f /etc/rancher/k3s/config.yaml ]; then
        cat /etc/rancher/k3s/config.yaml
    else
        echo "Файл конфигурации не найден"
    fi
    echo ""
    echo "=== K3s Server Args ==="
    ps aux | grep k3s | grep -v grep
} | tee "$REPORT_DIR/12-k3s-config.txt"

print_subheader "3.4 K3s Cluster Info"
{
    echo "=== Cluster Info ==="
    kubectl cluster-info
    echo ""
    echo "=== Node Info ==="
    kubectl get nodes -o wide
    echo ""
    echo "=== Node Description ==="
    kubectl describe node $(hostname)
} | tee "$REPORT_DIR/13-k3s-cluster-info.txt"

print_subheader "3.5 K3s Pods Status (All Namespaces)"
{
    echo "=== All Pods ==="
    kubectl get pods -A -o wide
    echo ""
    echo "=== Pod Count by Namespace ==="
    kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c
} | tee "$REPORT_DIR/14-k3s-pods.txt"

print_subheader "3.6 K3s Services"
{
    echo "=== All Services ==="
    kubectl get svc -A -o wide
} | tee "$REPORT_DIR/15-k3s-services.txt"

print_subheader "3.7 K3s Namespaces"
{
    echo "=== Namespaces with Labels ==="
    kubectl get namespaces --show-labels
} | tee "$REPORT_DIR/16-k3s-namespaces.txt"

################################################################################
# 4. СЕТЕВЫЕ ПОЛИТИКИ KUBERNETES
################################################################################
print_header "4. KUBERNETES СЕТЕВЫЕ ПОЛИТИКИ"

print_subheader "4.1 Network Policies (All Namespaces)"
{
    echo "=== All Network Policies ==="
    kubectl get networkpolicies -A
    echo ""
    echo "=== Network Policies Details ==="
    for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
        policies=$(kubectl get networkpolicies -n "$ns" -o name 2>/dev/null)
        if [ ! -z "$policies" ]; then
            echo ""
            echo "========================================"
            echo "Namespace: $ns"
            echo "========================================"
            kubectl get networkpolicies -n "$ns" -o yaml
        fi
    done
} | tee "$REPORT_DIR/17-k8s-network-policies.txt"

print_subheader "4.2 Network Policies Summary"
{
    echo "=== Network Policies Count by Namespace ==="
    for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
        count=$(kubectl get networkpolicies -n "$ns" --no-headers 2>/dev/null | wc -l)
        if [ $count -gt 0 ]; then
            echo "Namespace: $ns - Policies: $count"
        fi
    done
} | tee "$REPORT_DIR/18-network-policies-summary.txt"

################################################################################
# 5. БЕЗОПАСНОСТЬ - POD SECURITY & RBAC
################################################################################
print_header "5. БЕЗОПАСНОСТЬ - POD SECURITY & RBAC"

print_subheader "5.1 Pod Security Standards"
{
    echo "=== Namespaces with PSS Labels ==="
    kubectl get namespaces -o json | jq -r '.items[] | select(.metadata.labels | keys[] | contains("pod-security")) | "\(.metadata.name): \(.metadata.labels)"'
} | tee "$REPORT_DIR/19-pod-security-standards.txt"

print_subheader "5.2 RBAC - Roles and RoleBindings"
{
    echo "=== ClusterRoles (custom) ==="
    kubectl get clusterroles | grep -v "system:"
    echo ""
    echo "=== ClusterRoleBindings ==="
    kubectl get clusterrolebindings | head -20
    echo ""
    echo "=== Roles in All Namespaces ==="
    kubectl get roles -A
} | tee "$REPORT_DIR/20-rbac-roles.txt"

print_subheader "5.3 ServiceAccounts"
{
    echo "=== ServiceAccounts by Namespace ==="
    kubectl get serviceaccounts -A
} | tee "$REPORT_DIR/21-service-accounts.txt"

print_subheader "5.4 Secrets (без содержимого)"
{
    echo "=== Secrets by Namespace ==="
    kubectl get secrets -A
} | tee "$REPORT_DIR/22-secrets-list.txt"

print_subheader "5.5 Secrets Encryption Config"
{
    echo "=== Encryption Config ==="
    if [ -f /var/lib/rancher/k3s/server/encryption-config.yaml ]; then
        echo "⚠ ВНИМАНИЕ: Файл существует (содержимое НЕ выводится в целях безопасности)"
        ls -lh /var/lib/rancher/k3s/server/encryption-config.yaml
    else
        echo "Encryption config не найден"
    fi
} | tee "$REPORT_DIR/23-secrets-encryption.txt"

################################################################################
# 6. RESOURCE QUOTAS & LIMITS
################################################################################
print_header "6. RESOURCE QUOTAS & LIMIT RANGES"

print_subheader "6.1 Resource Quotas"
{
    echo "=== Resource Quotas by Namespace ==="
    kubectl get resourcequotas -A
    echo ""
    echo "=== Resource Quotas Details ==="
    for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
        quotas=$(kubectl get resourcequotas -n "$ns" -o name 2>/dev/null)
        if [ ! -z "$quotas" ]; then
            echo ""
            echo "========================================"
            echo "Namespace: $ns"
            echo "========================================"
            kubectl describe resourcequotas -n "$ns"
        fi
    done
} | tee "$REPORT_DIR/24-resource-quotas.txt"

print_subheader "6.2 LimitRanges"
{
    echo "=== LimitRanges by Namespace ==="
    kubectl get limitranges -A
    echo ""
    echo "=== LimitRanges Details ==="
    for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
        limits=$(kubectl get limitranges -n "$ns" -o name 2>/dev/null)
        if [ ! -z "$limits" ]; then
            echo ""
            echo "========================================"
            echo "Namespace: $ns"
            echo "========================================"
            kubectl describe limitranges -n "$ns"
        fi
    done
} | tee "$REPORT_DIR/25-limit-ranges.txt"

################################################################################
# 7. FAIL2BAN КОНФИГУРАЦИЯ
################################################################################
print_header "7. FAIL2BAN КОНФИГУРАЦИЯ"

print_subheader "7.1 Fail2ban Status"
{
    if command -v fail2ban-client &> /dev/null; then
        echo "=== Fail2ban Service Status ==="
        systemctl status fail2ban --no-pager
        echo ""
        echo "=== Fail2ban Version ==="
        fail2ban-client version
        echo ""
        echo "=== Fail2ban Status (all jails) ==="
        fail2ban-client status
    else
        print_warning "Fail2ban не установлен"
        echo "Fail2ban не установлен"
    fi
} | tee "$REPORT_DIR/26-fail2ban-status.txt"

print_subheader "7.2 Fail2ban Jails"
{
    if command -v fail2ban-client &> /dev/null; then
        echo "=== Active Jails ==="
        for jail in $(fail2ban-client status | grep "Jail list" | sed 's/.*://; s/,//g'); do
            echo ""
            echo "========================================"
            echo "Jail: $jail"
            echo "========================================"
            fail2ban-client status "$jail"
        done
    else
        echo "Fail2ban не установлен"
    fi
} | tee "$REPORT_DIR/27-fail2ban-jails.txt"

print_subheader "7.3 Fail2ban Configuration"
{
    if [ -f /etc/fail2ban/jail.local ]; then
        echo "=== /etc/fail2ban/jail.local ==="
        cat /etc/fail2ban/jail.local
    else
        echo "jail.local не найден"
    fi
    echo ""
    if [ -f /etc/fail2ban/jail.conf ]; then
        echo "=== /etc/fail2ban/jail.conf (enabled jails only) ==="
        grep -E "^\\[|^enabled" /etc/fail2ban/jail.conf | grep -B1 "enabled = true"
    fi
} | tee "$REPORT_DIR/28-fail2ban-config.txt"

print_subheader "7.4 Fail2ban Banned IPs"
{
    if command -v fail2ban-client &> /dev/null; then
        echo "=== Currently Banned IPs ==="
        for jail in $(fail2ban-client status | grep "Jail list" | sed 's/.*://; s/,//g'); do
            banned=$(fail2ban-client status "$jail" | grep "Banned IP list" | sed 's/.*://; s/,//g')
            if [ ! -z "$banned" ]; then
                echo "Jail $jail: $banned"
            fi
        done
        echo ""
        echo "=== Recent Fail2ban Log (last 50 lines) ==="
        tail -50 /var/log/fail2ban.log 2>/dev/null || echo "Log file not found"
    else
        echo "Fail2ban не установлен"
    fi
} | tee "$REPORT_DIR/29-fail2ban-banned-ips.txt"

################################################################################
# 8. HONEYPOT (если установлен)
################################################################################
print_header "8. HONEYPOT КОНФИГУРАЦИЯ"

print_subheader "8.1 Проверка наличия популярных honeypot сервисов"
{
    echo "=== Cowrie (SSH/Telnet honeypot) ==="
    if systemctl list-units --full -all | grep -q cowrie; then
        systemctl status cowrie --no-pager
    else
        echo "Cowrie не установлен"
    fi
    echo ""
    echo "=== Honeytrap ==="
    if systemctl list-units --full -all | grep -q honeytrap; then
        systemctl status honeytrap --no-pager
    else
        echo "Honeytrap не установлен"
    fi
    echo ""
    echo "=== Dionaea ==="
    if systemctl list-units --full -all | grep -q dionaea; then
        systemctl status dionaea --no-pager
    else
        echo "Dionaea не установлен"
    fi
    echo ""
    echo "=== Custom Honeypot Ports ==="
    echo "Проверка нестандартных открытых портов (возможные honeypots):"
    ss -tulpn | grep LISTEN | awk '{print $5}' | sed 's/.*://' | sort -n
} | tee "$REPORT_DIR/30-honeypot-check.txt"

print_subheader "8.2 Honeypot Logs (если найдены)"
{
    if [ -d /var/log/cowrie ]; then
        echo "=== Cowrie Logs (last 20 lines) ==="
        tail -20 /var/log/cowrie/cowrie.log 2>/dev/null
    fi
    if [ -d /var/log/honeytrap ]; then
        echo "=== Honeytrap Logs (last 20 lines) ==="
        tail -20 /var/log/honeytrap/honeytrap.log 2>/dev/null
    fi
} | tee "$REPORT_DIR/31-honeypot-logs.txt"

################################################################################
# 9. МОНИТОРИНГ И ЛОГИ
################################################################################
print_header "9. МОНИТОРИНГ И ЛОГИ"

print_subheader "9.1 K3s Service Logs (last 100 lines)"
{
    echo "=== K3s Service Logs ==="
    journalctl -u k3s -n 100 --no-pager
} | tee "$REPORT_DIR/32-k3s-logs.txt"

print_subheader "9.2 Auth Logs (SSH attempts)"
{
    echo "=== Recent SSH Login Attempts (last 50) ==="
    grep -i "sshd" /var/log/auth.log | tail -50 2>/dev/null || echo "auth.log не найден"
    echo ""
    echo "=== Failed SSH Attempts (last 20) ==="
    grep -i "failed password" /var/log/auth.log | tail -20 2>/dev/null || echo "No failed attempts found"
} | tee "$REPORT_DIR/33-auth-logs.txt"

print_subheader "9.3 System Logs (критические события)"
{
    echo "=== Kernel Errors (last 20) ==="
    dmesg -T -l err,crit,alert,emerg | tail -20
    echo ""
    echo "=== Systemd Failed Units ==="
    systemctl list-units --failed
} | tee "$REPORT_DIR/34-system-errors.txt"

################################################################################
# 10. СПЕЦИФИЧНЫЕ ПРОВЕРКИ ДЛЯ VPN
################################################################################
print_header "10. ПРОВЕРКИ ДЛЯ 3X-UI VPN УСТАНОВКИ"

print_subheader "10.1 Проверка портов для 3X-UI"
{
    echo "=== Проверка доступности портов 2053 (Web UI) и 8443 (VLESS) ==="
    if ss -tulpn | grep -q ":2053"; then
        echo "⚠ Порт 2053 занят:"
        ss -tulpn | grep ":2053"
    else
        print_success "Порт 2053 свободен для 3X-UI Web UI"
    fi
    if ss -tulpn | grep -q ":8443"; then
        echo "⚠ Порт 8443 занят:"
        ss -tulpn | grep ":8443"
    else
        print_success "Порт 8443 свободен для VLESS Reality"
    fi
} | tee "$REPORT_DIR/35-ports-for-xui.txt"

print_subheader "10.2 Проверка существующих XUI deployments"
{
    echo "=== XUI Pods in Cluster ==="
    kubectl get pods -A | grep -i xui || echo "XUI pods не найдены"
    echo ""
    echo "=== XUI Namespaces ==="
    kubectl get ns | grep -i xui || echo "XUI namespaces не найдены"
} | tee "$REPORT_DIR/36-existing-xui.txt"

print_subheader "10.3 Kernel Modules для VPN"
{
    echo "=== WireGuard Module ==="
    lsmod | grep wireguard
    echo ""
    echo "=== iptables Modules ==="
    lsmod | grep -E "iptable|nf_conntrack|nf_nat"
    echo ""
    echo "=== TUN/TAP Module ==="
    lsmod | grep tun
} | tee "$REPORT_DIR/37-kernel-modules-vpn.txt"

################################################################################
# ФИНАЛЬНАЯ СВОДКА
################################################################################
print_header "11. ФИНАЛЬНАЯ СВОДКА"

{
    echo "=== Генерация отчета завершена ==="
    echo "Дата: $(date)"
    echo "Hostname: $(hostname)"
    echo "K3s Version: $(k3s --version | head -1)"
    echo ""
    echo "=== Статистика ==="
    echo "Количество нод: $(kubectl get nodes --no-headers | wc -l)"
    echo "Количество подов: $(kubectl get pods -A --no-headers | wc -l)"
    echo "Количество namespaces: $(kubectl get ns --no-headers | wc -l)"
    echo "Количество network policies: $(kubectl get networkpolicies -A --no-headers | wc -l)"
    echo ""
    echo "=== Критические предупреждения ==="
    
    # Проверка на конфликты портов
    if ss -tulpn | grep -q ":2053"; then
        print_warning "Порт 2053 занят - может быть конфликт с 3X-UI"
    fi
    
    if ss -tulpn | grep -q ":8443"; then
        print_warning "Порт 8443 занят - может быть конфликт с VLESS"
    fi
    
    # Проверка Fail2ban
    if ! command -v fail2ban-client &> /dev/null; then
        print_warning "Fail2ban не установлен - рекомендуется для защиты SSH"
    fi
    
    # Проверка UFW
    if ! command -v ufw &> /dev/null; then
        print_warning "UFW не установлен - рекомендуется для firewall"
    fi
    
    echo ""
    echo "=== Рекомендации перед установкой 3X-UI ==="
    echo "1. Убедитесь, что порты 2053 и 8443 свободны"
    echo "2. Проверьте настройки UFW: sudo ufw allow 2053/tcp && sudo ufw allow 8443/tcp"
    echo "3. Убедитесь, что kernel modules загружены: wireguard, iptables, tun"
    echo "4. Создайте strong password для 3X-UI admin: openssl rand -base64 24"
    echo "5. Примените манифест: kubectl apply -f manifests/apps/xui-vless-reality.yaml"
} | tee "$REPORT_DIR/00-summary.txt"

################################################################################
# АРХИВАЦИЯ ОТЧЕТОВ
################################################################################
print_header "12. АРХИВАЦИЯ ОТЧЕТОВ"

ARCHIVE_NAME="k3s-audit-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "/tmp/$ARCHIVE_NAME" -C /tmp $(basename "$REPORT_DIR")

print_success "Все отчеты сохранены в: $REPORT_DIR"
print_success "Архив создан: /tmp/$ARCHIVE_NAME"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 АУДИТ ЗАВЕРШЕН УСПЕШНО"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Для просмотра отчетов:"
echo "  cd $REPORT_DIR"
echo "  ls -lh"
echo ""
echo "Для отправки архива:"
echo "  scp /tmp/$ARCHIVE_NAME user@remote:/path/"
echo ""
echo "Для быстрого просмотра summary:"
echo "  cat $REPORT_DIR/00-summary.txt"
echo ""

exit 0
