#!/bin/bash
#
# Quick setup script for Ansible K3s Optimization
# Usage: curl -fsSL https://raw.githubusercontent.com/KomarovAI/ansible-k3s-optimization/main/setup.sh | bash
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🚀 Ansible K3s Optimization - Quick Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Please run as root or with sudo${NC}"
  exit 1
fi

echo -e "${GREEN}1/5 Installing dependencies...${NC}"
apt update -qq
apt install -y python3 python3-pip python3-venv git curl -qq

echo -e "${GREEN}2/5 Creating virtual environment...${NC}"
python3 -m venv /opt/ansible-venv

echo -e "${GREEN}3/5 Installing Ansible...${NC}"
source /opt/ansible-venv/bin/activate
pip install -q ansible ansible-core

echo -e "${GREEN}4/5 Cloning repository...${NC}"
if [ -d "/opt/k3s-ansible" ]; then
  echo -e "${YELLOW}⚠️  Directory /opt/k3s-ansible already exists, updating...${NC}"
  cd /opt/k3s-ansible
  git pull origin main
else
  git clone -q https://github.com/KomarovAI/ansible-k3s-optimization.git /opt/k3s-ansible
  cd /opt/k3s-ansible
fi

echo -e "${GREEN}5/5 Creating logs directory...${NC}"
mkdir -p logs

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. ${GREEN}cd /opt/k3s-ansible${NC}"
echo -e "  2. ${GREEN}source /opt/ansible-venv/bin/activate${NC}"
echo -e "  3. ${GREEN}ansible-playbook playbooks/full-setup.yml --check${NC}  (dry run)"
echo -e "  4. ${GREEN}ansible-playbook playbooks/full-setup.yml${NC}  (real deployment)"
echo ""
echo -e "${BLUE}Documentation: https://github.com/KomarovAI/ansible-k3s-optimization${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
