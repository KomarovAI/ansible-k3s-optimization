#!/bin/bash
#
# Automatic IP ban script for honeypot attackers
# Usage: Run manually or via cron every hour
#

set -euo pipefail

HONEYPOT_LOG="/var/log/honeypot.log"
BANNED_IPS_FILE="/var/log/honeypot-banned-ips.txt"
ATTACK_THRESHOLD=5  # Ban after 5 connection attempts
TIME_WINDOW="1 hour ago"  # Look at last hour only

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🔥 Honeypot Automatic IP Ban Script${NC}"
echo -e "${GREEN}Started: $(date)${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""

# Check if honeypot log exists
if [ ! -f "$HONEYPOT_LOG" ]; then
    echo -e "${RED}❌ Honeypot log not found: $HONEYPOT_LOG${NC}"
    exit 1
fi

# Get timestamp for time window
SINCE_TIMESTAMP=$(date -d "$TIME_WINDOW" '+%Y-%m-%d %H:%M:%S')

echo -e "${YELLOW}🔍 Analyzing attacks since: $SINCE_TIMESTAMP${NC}"
echo ""

# Find aggressive attackers (IPs with more than ATTACK_THRESHOLD attempts)
AGGRESSIVE_IPS=$(grep "Connection from" "$HONEYPOT_LOG" | \
    awk -v since="$SINCE_TIMESTAMP" '$1 " " $2 >= since' | \
    grep -oP '\d+\.\d+\.\d+\.\d+' | \
    sort | uniq -c | \
    awk -v threshold="$ATTACK_THRESHOLD" '$1 > threshold {print $2}')

if [ -z "$AGGRESSIVE_IPS" ]; then
    echo -e "${GREEN}✅ No aggressive attackers found (threshold: >$ATTACK_THRESHOLD attempts)${NC}"
    exit 0
fi

echo -e "${RED}⚠️  Found aggressive attackers:${NC}"
echo "$AGGRESSIVE_IPS" | while read -r IP; do
    ATTEMPTS=$(grep "$IP" "$HONEYPOT_LOG" | grep "Connection from" | wc -l)
    echo -e "  ${RED}•${NC} $IP ($ATTEMPTS attempts)"
done
echo ""

# Ban each IP
BANNED_COUNT=0
for IP in $AGGRESSIVE_IPS; do
    # Check if already banned
    if fail2ban-client status honeypot 2>/dev/null | grep -q "$IP"; then
        echo -e "${YELLOW}⏭️  $IP already banned in fail2ban${NC}"
        continue
    fi
    
    if ufw status | grep -q "$IP"; then
        echo -e "${YELLOW}⏭️  $IP already banned in UFW${NC}"
        continue
    fi
    
    # Ban in fail2ban (if honeypot jail exists)
    if fail2ban-client status honeypot &>/dev/null; then
        fail2ban-client set honeypot banip "$IP" 2>/dev/null && \
            echo -e "${GREEN}✅ Banned $IP in fail2ban (honeypot jail)${NC}" || \
            echo -e "${RED}❌ Failed to ban $IP in fail2ban${NC}"
    fi
    
    # Ban in UFW firewall
    ufw insert 1 deny from "$IP" comment "Honeypot attacker - auto-banned $(date +%Y-%m-%d)" &>/dev/null && \
        echo -e "${GREEN}✅ Banned $IP in UFW${NC}" || \
        echo -e "${RED}❌ Failed to ban $IP in UFW${NC}"
    
    # Log banned IP
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Banned $IP (honeypot attacks)" >> "$BANNED_IPS_FILE"
    
    ((BANNED_COUNT++))
done

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Auto-ban complete!${NC}"
echo -e "${GREEN}Banned: $BANNED_COUNT new IPs${NC}"
echo -e "${GREEN}Total banned (all time): $(wc -l < "$BANNED_IPS_FILE" 2>/dev/null || echo 0)${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
