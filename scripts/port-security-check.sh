#!/bin/bash
#
# Port Security Analysis Script
# Analyzes all listening ports and identifies security risks
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔒 Port Security Analysis${NC}"
echo -e "${BLUE}$(date)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Define port categories
declare -A PORT_TYPES
PORT_TYPES[21]="FTP Honeypot"
PORT_TYPES[22]="SSH Honeypot"
PORT_TYPES[23]="Telnet Honeypot"
PORT_TYPES[25]="SMTP Honeypot"
PORT_TYPES[110]="POP3 Honeypot"
PORT_TYPES[143]="IMAP Honeypot"
PORT_TYPES[3306]="MySQL Honeypot"
PORT_TYPES[3389]="RDP Honeypot"
PORT_TYPES[5432]="PostgreSQL Honeypot"
PORT_TYPES[27015]="SSH Real"
PORT_TYPES[6443]="K3s API Server"
PORT_TYPES[10250]="Kubelet API (RISK!)"
PORT_TYPES[2379]="etcd"
PORT_TYPES[2380]="etcd peer"

echo -e "${GREEN}🔍 Scanning listening ports...${NC}"
echo ""

# Get all listening TCP ports
LISTENING_PORTS=$(ss -tlnH | awk '{print $4}' | grep -oP ':\K[0-9]+$' | sort -n | uniq)

echo -e "${YELLOW}📡 Listening TCP Ports:${NC}"
echo ""

# Categorize ports
HONEYPOT_PORTS=()
RISK_PORTS=()
K3S_PORTS=()
SAFE_PORTS=()

for PORT in $LISTENING_PORTS; do
    # Get bind address for this port
    BIND_ADDR=$(ss -tlnH | grep ":$PORT " | awk '{print $4}' | head -1 | cut -d':' -f1)
    PROCESS=$(ss -tlnpH | grep ":$PORT " | grep -oP 'users:\(\("\K[^"]+' | head -1 || echo "unknown")
    
    # Determine category
    CATEGORY="Unknown"
    STATUS="❓"
    COLOR="$NC"
    
    if [[ -n "${PORT_TYPES[$PORT]:-}" ]]; then
        CATEGORY="${PORT_TYPES[$PORT]}"
        
        case $PORT in
            21|22|23|25|110|143|3306|3389|5432)
                STATUS="🍯 HONEYPOT"
                COLOR="$GREEN"
                HONEYPOT_PORTS+=("$PORT")
                ;;
            27015)
                STATUS="🔑 SECURE"
                COLOR="$GREEN"
                SAFE_PORTS+=("$PORT")
                ;;
            10250)
                if [[ "$BIND_ADDR" == "0.0.0.0" || "$BIND_ADDR" == "*" ]]; then
                    STATUS="🔴 CRITICAL RISK"
                    COLOR="$RED"
                    RISK_PORTS+=("$PORT")
                else
                    STATUS="🟢 SAFE (localhost)"
                    COLOR="$GREEN"
                    SAFE_PORTS+=("$PORT")
                fi
                ;;
            6443|2379|2380)
                STATUS="⚠️  K3S Internal"
                COLOR="$YELLOW"
                K3S_PORTS+=("$PORT")
                ;;
        esac
    else
        # Check if localhost-only
        if [[ "$BIND_ADDR" == "127.0.0.1" || "$BIND_ADDR" == "::1" ]]; then
            STATUS="🔒 Localhost only"
            COLOR="$GREEN"
            SAFE_PORTS+=("$PORT")
        else
            STATUS="⚠️  External"
            COLOR="$YELLOW"
        fi
    fi
    
    echo -e "${COLOR}Port $PORT\t$BIND_ADDR\t$STATUS\t$CATEGORY\t($PROCESS)${NC}"
done

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Summary:${NC}"
echo ""
echo -e "${GREEN}🍯 Honeypot ports: ${#HONEYPOT_PORTS[@]}${NC}"
echo -e "${YELLOW}⚠️  K3s internal ports: ${#K3S_PORTS[@]}${NC}"
echo -e "${GREEN}🔒 Safe ports: ${#SAFE_PORTS[@]}${NC}"
echo -e "${RED}🔴 Risk ports: ${#RISK_PORTS[@]}${NC}"
echo ""

if [ ${#RISK_PORTS[@]} -gt 0 ]; then
    echo -e "${RED}⚠️  SECURITY RECOMMENDATIONS:${NC}"
    echo ""
    
    for PORT in "${RISK_PORTS[@]}"; do
        echo -e "${RED}🔴 Port $PORT (${PORT_TYPES[$PORT]:-Unknown}) is exposed externally!${NC}"
        
        if [ "$PORT" -eq 10250 ]; then
            echo -e "${YELLOW}   FIX: Restrict Kubelet API to pod network only:${NC}"
            echo "   ufw delete allow 10250/tcp"
            echo "   ufw insert 6 allow from 10.42.0.0/16 to any port 10250 proto tcp"
            echo "   ufw reload"
            echo ""
        fi
    done
else
    echo -e "${GREEN}✅ No critical security risks detected!${NC}"
fi

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
