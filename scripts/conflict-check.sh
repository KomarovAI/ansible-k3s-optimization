#!/bin/bash
#
# K3s Node Conflict Check Script
# Performs quick conflict detection without Ansible
#
# Usage: /usr/local/bin/k3s-conflict-check
#

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
OK=0

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}K3S NODE CONFLICT CHECK${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo ""

#########################################################################
# 1. IPTABLES CONFLICTS
#########################################################################
echo -e "${BLUE}[1/9] Checking iptables...${NC}"
DUPS=$(iptables -S 2>/dev/null | sort | uniq -d | wc -l)
if [ $DUPS -gt 0 ]; then
    echo -e "  ${RED}❌ Found $DUPS duplicate iptables rules${NC}"
    iptables -S | sort | uniq -d | sed 's/^/    /'
    ((ERRORS++))
else
    echo -e "  ${GREEN}✅ No duplicate rules${NC}"
    ((OK++))
fi

#########################################################################
# 2. SYSCTL CONFLICTS
#########################################################################
echo -e "${BLUE}[2/9] Checking sysctl...${NC}"
SYSCTL_CONFLICTS=0
for param in net.netfilter.nf_conntrack_max net.ipv4.tcp_max_syn_backlog net.ipv4.tcp_syncookies; do
    COUNT=$(grep -rl "^${param}" /etc/sysctl.d/*.conf 2>/dev/null | wc -l)
    if [ $COUNT -gt 1 ]; then
        echo -e "  ${YELLOW}⚠️  $param defined in $COUNT files${NC}"
        ((SYSCTL_CONFLICTS++))
    fi
done

if [ $SYSCTL_CONFLICTS -gt 0 ]; then
    ((WARNINGS++))
else
    echo -e "  ${GREEN}✅ No sysctl conflicts${NC}"
    ((OK++))
fi

#########################################################################
# 3. PORT CONFLICTS
#########################################################################
echo -e "${BLUE}[3/9] Checking ports...${NC}"
HONEYPOT_CONFLICTS=0
honeypot_ports="21 22 23 25 110 143 3306 3389 5432"
for port in $honeypot_ports; do
    real_service=$(netstat -tlnp 2>/dev/null | grep ":$port " | grep -v honeypot | awk '{print $7}' | head -1)
    if [ -n "$real_service" ]; then
        echo -e "  ${RED}❌ Port $port: honeypot conflicts with $real_service${NC}"
        ((HONEYPOT_CONFLICTS++))
    fi
done

if [ $HONEYPOT_CONFLICTS -gt 0 ]; then
    ((ERRORS++))
else
    echo -e "  ${GREEN}✅ No honeypot port conflicts${NC}"
    ((OK++))
fi

#########################################################################
# 4. SYSTEMD SERVICES
#########################################################################
echo -e "${BLUE}[4/9] Checking services...${NC}"
SERVICE_FAILURES=0
for service in fail2ban psad honeypot; do
    if systemctl is-enabled $service &>/dev/null; then
        if ! systemctl is-active $service &>/dev/null; then
            echo -e "  ${RED}❌ $service: $(systemctl is-active $service)${NC}"
            ((SERVICE_FAILURES++))
        fi
    fi
done

if [ $SERVICE_FAILURES -gt 0 ]; then
    ((ERRORS++))
else
    echo -e "  ${GREEN}✅ All enabled services running${NC}"
    ((OK++))
fi

#########################################################################
# 5. KERNEL MODULES
#########################################################################
echo -e "${BLUE}[5/9] Checking kernel modules...${NC}"
MODULE_ISSUES=0

# Check conflicting modules
if lsmod | grep -q ipt_recent && lsmod | grep -q xt_recent; then
    echo -e "  ${RED}❌ Both ipt_recent and xt_recent loaded (conflict)${NC}"
    ((MODULE_ISSUES++))
fi

# Check required modules
for mod in nf_conntrack xt_recent; do
    if ! lsmod | grep -q "^$mod "; then
        echo -e "  ${YELLOW}⚠️  $mod not loaded${NC}"
        ((MODULE_ISSUES++))
    fi
done

if [ $MODULE_ISSUES -gt 0 ]; then
    if lsmod | grep -q ipt_recent && lsmod | grep -q xt_recent; then
        ((ERRORS++))
    else
        ((WARNINGS++))
    fi
else
    echo -e "  ${GREEN}✅ Kernel modules OK${NC}"
    ((OK++))
fi

#########################################################################
# 6. IPSET
#########################################################################
echo -e "${BLUE}[6/9] Checking ipset...${NC}"
IPSET_ISSUES=0

# Check if ipset is installed
if ! command -v ipset &>/dev/null; then
    echo -e "  ${YELLOW}⚠️  ipset not installed${NC}"
    ((IPSET_ISSUES++))
else
    # Check required sets
    for set in blacklist fail2ban-sshd fail2ban-honeypot; do
        if ! ipset list -n 2>/dev/null | grep -q "^$set$"; then
            echo -e "  ${YELLOW}⚠️  Missing ipset: $set${NC}"
            ((IPSET_ISSUES++))
        fi
    done
    
    # Check if sets are used in iptables
    for set in blacklist fail2ban-sshd fail2ban-honeypot; do
        if ipset list -n 2>/dev/null | grep -q "^$set$"; then
            if ! iptables -S 2>/dev/null | grep -q "match-set $set"; then
                echo -e "  ${YELLOW}⚠️  ipset $set exists but not used in iptables${NC}"
                ((IPSET_ISSUES++))
            fi
        fi
    done
fi

if [ $IPSET_ISSUES -gt 0 ]; then
    ((WARNINGS++))
else
    echo -e "  ${GREEN}✅ ipset configuration OK${NC}"
    ((OK++))
fi

#########################################################################
# 7. XT_RECENT
#########################################################################
echo -e "${BLUE}[7/9] Checking xt_recent...${NC}"
XT_RECENT_ISSUES=0

# Check if module loaded
if ! lsmod | grep -q xt_recent; then
    echo -e "  ${RED}❌ xt_recent module not loaded${NC}"
    ((XT_RECENT_ISSUES++))
else
    # Check tracking lists
    for list in ssh_attack portscan; do
        if [ ! -f /proc/net/xt_recent/$list ]; then
            echo -e "  ${YELLOW}⚠️  xt_recent list '$list' not created${NC}"
            ((XT_RECENT_ISSUES++))
        fi
    done
    
    # Check iptables rules
    if ! iptables -S 2>/dev/null | grep -q "recent.*ssh_attack"; then
        echo -e "  ${YELLOW}⚠️  No iptables rules using xt_recent${NC}"
        ((XT_RECENT_ISSUES++))
    fi
fi

if [ $XT_RECENT_ISSUES -gt 0 ]; then
    if ! lsmod | grep -q xt_recent; then
        ((ERRORS++))
    else
        ((WARNINGS++))
    fi
else
    echo -e "  ${GREEN}✅ xt_recent working correctly${NC}"
    ((OK++))
fi

#########################################################################
# 8. ARPWATCH
#########################################################################
echo -e "${BLUE}[8/9] Checking ARPwatch...${NC}"
ARPWATCH_ISSUES=0

# Detect main interface
MAIN_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -z "$MAIN_IFACE" ]; then
    echo -e "  ${YELLOW}⚠️  Could not detect main interface${NC}"
    ((ARPWATCH_ISSUES++))
else
    # Check if ARPwatch service exists
    if ! systemctl list-unit-files | grep -q "arpwatch-${MAIN_IFACE}.service"; then
        echo -e "  ${YELLOW}⚠️  ARPwatch not configured for ${MAIN_IFACE}${NC}"
        ((ARPWATCH_ISSUES++))
    else
        # Check if active
        if ! systemctl is-active arpwatch-${MAIN_IFACE} &>/dev/null; then
            echo -e "  ${RED}❌ arpwatch-${MAIN_IFACE}: inactive${NC}"
            ((ARPWATCH_ISSUES+=2)
        else
            # Check for MAC address changes (MITM attacks)
            MAC_CHANGES=$(journalctl -u arpwatch-${MAIN_IFACE} --since "1 hour ago" 2>/dev/null | grep -c "changed ethernet" || echo 0)
            if [ $MAC_CHANGES -gt 0 ]; then
                echo -e "  ${RED}🚨 MAC ADDRESS CHANGES: $MAC_CHANGES in last hour (MITM ATTACK?)${NC}"
                ((ARPWATCH_ISSUES+=2)
            fi
        fi
    fi
    
    # Check cni0 if exists
    if ip link show cni0 &>/dev/null; then
        if ! systemctl list-unit-files | grep -q "arpwatch-cni0.service"; then
            echo -e "  ${YELLOW}⚠️  ARPwatch not configured for cni0${NC}"
            ((ARPWATCH_ISSUES++))
        else
            if ! systemctl is-active arpwatch-cni0 &>/dev/null; then
                echo -e "  ${RED}❌ arpwatch-cni0: inactive${NC}"
                ((ARPWATCH_ISSUES+=2)
            else
                # Check for pod MAC spoofing
                POD_MAC_CHANGES=$(journalctl -u arpwatch-cni0 --since "1 hour ago" 2>/dev/null | grep -c "changed ethernet" || echo 0)
                if [ $POD_MAC_CHANGES -gt 0 ]; then
                    echo -e "  ${RED}🚨 POD MAC SPOOFING: $POD_MAC_CHANGES changes (MALICIOUS POD?)${NC}"
                    ((ARPWATCH_ISSUES+=2)
                fi
            fi
        fi
    fi
fi

if [ $ARPWATCH_ISSUES -gt 1 ]; then
    ((ERRORS++))
elif [ $ARPWATCH_ISSUES -gt 0 ]; then
    ((WARNINGS++))
else
    echo -e "  ${GREEN}✅ ARPwatch monitoring active${NC}"
    ((OK++))
fi

#########################################################################
# 9. RESOURCE USAGE
#########################################################################
echo -e "${BLUE}[9/9] Checking resources...${NC}"
RESOURCE_CRITICAL=0
RESOURCE_HIGH=0

# Memory
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ $MEM_PERCENT -gt 90 ]; then
    echo -e "  ${RED}❌ Memory usage critical: ${MEM_PERCENT}%${NC}"
    ((RESOURCE_CRITICAL++))
elif [ $MEM_PERCENT -gt 80 ]; then
    echo -e "  ${YELLOW}⚠️  Memory usage high: ${MEM_PERCENT}%${NC}"
    ((RESOURCE_HIGH++))
fi

# Disk
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_PERCENT -gt 90 ]; then
    echo -e "  ${RED}❌ Disk usage critical: ${DISK_PERCENT}%${NC}"
    ((RESOURCE_CRITICAL++))
elif [ $DISK_PERCENT -gt 80 ]; then
    echo -e "  ${YELLOW}⚠️  Disk usage high: ${DISK_PERCENT}%${NC}"
    ((RESOURCE_HIGH++))
fi

if [ $RESOURCE_CRITICAL -gt 0 ]; then
    ((ERRORS++))
elif [ $RESOURCE_HIGH -gt 0 ]; then
    ((WARNINGS++))
else
    echo -e "  ${GREEN}✅ Resource usage normal${NC}"
    ((OK++))
fi

#########################################################################
# SUMMARY
#########################################################################
echo ""
echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}SUMMARY${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo ""
echo -e "  ${GREEN}✅ OK:       $OK/9 checks passed${NC}"
if [ $WARNINGS -gt 0 ]; then
    echo -e "  ${YELLOW}⚠️  WARNINGS: $WARNINGS issues found${NC}"
fi
if [ $ERRORS -gt 0 ]; then
    echo -e "  ${RED}❌ ERRORS:   $ERRORS critical issues${NC}"
fi
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL CHECKS PASSED - NO CONFLICTS DETECTED!${NC}"
    echo ""
    exit 0
elif [ $ERRORS -gt 0 ]; then
    echo -e "${RED}🛑 CRITICAL ISSUES DETECTED - IMMEDIATE ACTION REQUIRED${NC}"
    echo ""
    echo "Run for detailed diagnostics:"
    echo "  ansible-playbook playbooks/diagnostic-comprehensive.yml"
    echo ""
    exit 1
else
    echo -e "${YELLOW}⚠️  WARNINGS FOUND - REVIEW RECOMMENDED${NC}"
    echo ""
    echo "Run for detailed diagnostics:"
    echo "  ansible-playbook playbooks/diagnostic-comprehensive.yml"
    echo ""
    exit 0
fi