#!/bin/bash
#
# K3s Node Health Check Script
# Checks system resources, K3s status, and key services
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 K3s Node Health Check${NC}"
echo -e "${BLUE}$(date)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 1. SYSTEM UPTIME
echo -e "${GREEN}🕒 System Uptime:${NC}"
uptime -p
echo ""

# 2. MEMORY
echo -e "${GREEN}📡 Memory Usage:${NC}"
free -h | grep -E "^Mem|^Swap"
MEM_USED=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ "$MEM_USED" -gt 80 ]; then
    echo -e "${RED}⚠️  WARNING: Memory usage is ${MEM_USED}%${NC}"
else
    echo -e "${GREEN}✅ Memory OK (${MEM_USED}% used)${NC}"
fi
echo ""

# 3. SWAP (ZRAM)
echo -e "${GREEN}🔄 Swap Status (Zram):${NC}"
if swapon --show | grep -q zram; then
    swapon --show | grep zram
    echo -e "${GREEN}✅ Zram swap is active${NC}"
else
    echo -e "${YELLOW}⚠️  Zram swap not found${NC}"
fi
echo ""

# 4. DISK USAGE
echo -e "${GREEN}💾 Disk Usage:${NC}"
df -h / | tail -1
DISK_USED=$(df / | tail -1 | awk '{print int($5)}')
if [ "$DISK_USED" -gt 80 ]; then
    echo -e "${RED}⚠️  WARNING: Disk usage is ${DISK_USED}%${NC}"
else
    echo -e "${GREEN}✅ Disk OK (${DISK_USED}% used)${NC}"
fi
echo ""

# 5. CPU LOAD
echo -e "${GREEN}💻 CPU Load Average:${NC}"
uptime | awk -F'load average:' '{print $2}'
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
CPU_CORES=$(nproc)
if (( $(echo "$LOAD > $CPU_CORES" | bc -l) )); then
    echo -e "${RED}⚠️  WARNING: Load average ($LOAD) exceeds CPU cores ($CPU_CORES)${NC}"
else
    echo -e "${GREEN}✅ CPU load OK${NC}"
fi
echo ""

# 6. K3S SERVICE
echo -e "${GREEN}🚀 K3s Service Status:${NC}"
if systemctl is-active --quiet k3s; then
    echo -e "${GREEN}✅ K3s service is running${NC}"
    systemctl status k3s --no-pager | grep "Active:" | head -1
else
    echo -e "${RED}❌ K3s service is NOT running${NC}"
fi
echo ""

# 7. KUBERNETES PODS
echo -e "${GREEN}📦 Kubernetes Pods:${NC}"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
if kubectl get nodes &>/dev/null; then
    TOTAL_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep Running | wc -l)
    PENDING_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -E "Pending|ContainerCreating" | wc -l)
    
    echo "Total pods: $TOTAL_PODS"
    echo "Running: $RUNNING_PODS"
    echo "Pending: $PENDING_PODS"
    
    if [ "$PENDING_PODS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $PENDING_PODS pods are pending${NC}"
    else
        echo -e "${GREEN}✅ All pods healthy${NC}"
    fi
else
    echo -e "${RED}❌ Cannot connect to Kubernetes API${NC}"
fi
echo ""

# 8. NODE STATUS
echo -e "${GREEN}🔶 Node Status:${NC}"
kubectl get nodes 2>/dev/null || echo "Cannot get node status"
echo ""

# 9. FAIL2BAN
echo -e "${GREEN}🛑 Fail2ban Status:${NC}"
if systemctl is-active --quiet fail2ban; then
    echo -e "${GREEN}✅ Fail2ban is running${NC}"
    BANNED_COUNT=$(fail2ban-client status 2>/dev/null | grep -c "Banned IP" || echo 0)
    echo "Currently banned IPs: $BANNED_COUNT jails active"
else
    echo -e "${YELLOW}⚠️  Fail2ban is not running${NC}"
fi
echo ""

# 10. HONEYPOT
echo -e "${GREEN}🍯 Honeypot Status:${NC}"
if systemctl is-active --quiet honeypot; then
    echo -e "${GREEN}✅ Honeypot is running${NC}"
    if [ -f /var/log/honeypot.log ]; then
        TODAY_ATTACKS=$(grep "$(date +%Y-%m-%d)" /var/log/honeypot.log | grep -c "Connection from" || echo 0)
        echo "Attacks detected today: $TODAY_ATTACKS"
    fi
else
    echo -e "${YELLOW}⚠️  Honeypot is not running${NC}"
fi
echo ""

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Health check complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
