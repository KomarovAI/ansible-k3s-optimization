# 📖 Usage Guide

## Quick Start

### 1. Install Ansible on Master Node

```bash
# Run on your K3s master node
curl -fsSL https://raw.githubusercontent.com/KomarovAI/ansible-k3s-optimization/main/setup.sh | bash
```

Or manually:

```bash
# Install dependencies
apt update && apt install -y python3-pip python3-venv git

# Create virtual environment
python3 -m venv /opt/ansible-venv
source /opt/ansible-venv/bin/activate

# Install Ansible
pip install ansible ansible-core

# Clone repository
git clone https://github.com/KomarovAI/ansible-k3s-optimization.git /opt/k3s-ansible
cd /opt/k3s-ansible
```

### 2. Run Full Setup

```bash
cd /opt/k3s-ansible
source /opt/ansible-venv/bin/activate

# Dry run first
ansible-playbook playbooks/full-setup.yml --check

# Real deployment
ansible-playbook playbooks/full-setup.yml
```

## Individual Playbooks

### System Optimization Only

```bash
ansible-playbook playbooks/optimize-node.yml
```

This playbook configures:
- Kernel modules (overlay, br_netfilter, nf_conntrack, zram)
- Sysctl parameters for network and memory
- System limits (file descriptors, processes)
- Zram swap
- Monitoring tools

### Security Analysis

```bash
ansible-playbook playbooks/security-analysis.yml
```

Provides detailed report on:
- Honeypot status and logs
- Fail2ban jails and banned IPs
- Open ports and security risks
- Firewall rules (UFW/iptables)
- SSH configuration

### System Analysis

```bash
ansible-playbook playbooks/analyze-master.yml
```

Shows:
- System resources (CPU, RAM, disk)
- Running systemd services
- Kubernetes pods and services
- Container runtime status
- Network configuration

### Check Optimization Status

```bash
ansible-playbook playbooks/check-optimization.yml
```

### Backup Configurations

```bash
ansible-playbook playbooks/backup-configs.yml
```

Creates backup of:
- K3s configurations
- etcd snapshots
- Sysctl settings
- SSH config
- Firewall rules
- Fail2ban config

## Using Roles

### Deploy Only Honeypot

```bash
cat > deploy-honeypot.yml <<'EOF'
---
- hosts: localhost
  become: yes
  roles:
    - honeypot
EOF

ansible-playbook deploy-honeypot.yml
```

### Configure Only Fail2ban

```bash
cat > deploy-fail2ban.yml <<'EOF'
---
- hosts: localhost
  become: yes
  roles:
    - fail2ban
EOF

ansible-playbook deploy-fail2ban.yml
```

## Bash Scripts

### Automatic Honeypot Ban

```bash
# Run manually
/opt/k3s-ansible/scripts/autoban-honeypot.sh

# Schedule with cron (every hour)
crontab -e
# Add:
0 * * * * /opt/k3s-ansible/scripts/autoban-honeypot.sh
```

### Health Check

```bash
# Run health check
/opt/k3s-ansible/scripts/health-check.sh

# Or use the installed version
/usr/local/bin/k3s-health-check
```

### Port Security Check

```bash
/opt/k3s-ansible/scripts/port-security-check.sh
```

## Customization

### Override Default Variables

Create `group_vars/all.yml`:

```yaml
---
# System optimization
zram_size_mb: 1024
zram_compression: zstd

# SSH security
ssh_port: 2222
ssh_max_auth_tries: 5

# Fail2ban
fail2ban_bantime: 172800  # 48 hours
fail2ban_maxretry: 5

# Honeypot
honeypot_ports:
  - { port: 21, name: 'FTP', protocol: 'tcp' }
  - { port: 22, name: 'SSH', protocol: 'tcp' }
  - { port: 3389, name: 'RDP', protocol: 'tcp' }
```

Then run:

```bash
ansible-playbook playbooks/full-setup.yml
```

### Run Specific Tags

```bash
# Only apply sysctl changes
ansible-playbook playbooks/optimize-node.yml --tags sysctl

# Only setup zram
ansible-playbook playbooks/optimize-node.yml --tags zram

# Multiple tags
ansible-playbook playbooks/optimize-node.yml --tags "sysctl,zram,limits"
```

## Troubleshooting

### Verbose Output

```bash
ansible-playbook playbooks/full-setup.yml -v    # Verbose
ansible-playbook playbooks/full-setup.yml -vv   # More verbose
ansible-playbook playbooks/full-setup.yml -vvv  # Very verbose
```

### Check Syntax

```bash
ansible-playbook playbooks/full-setup.yml --syntax-check
```

### List Tasks

```bash
ansible-playbook playbooks/full-setup.yml --list-tasks
```

### Check What Would Change (Dry Run)

```bash
ansible-playbook playbooks/full-setup.yml --check --diff
```

### View Logs

```bash
# Ansible logs
tail -f /opt/k3s-ansible/logs/ansible.log

# Honeypot logs
tail -f /var/log/honeypot.log

# Fail2ban logs
tail -f /var/log/fail2ban.log

# SSH authentication logs
tail -f /var/log/auth.log
```

## Automated Deployment

### Systemd Timer for Regular Optimization

```bash
cat > /etc/systemd/system/ansible-optimize.service <<'EOF'
[Unit]
Description=Ansible K3s Optimization

[Service]
Type=oneshot
WorkingDirectory=/opt/k3s-ansible
Environment="PATH=/opt/ansible-venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/opt/ansible-venv/bin/ansible-playbook playbooks/optimize-node.yml
EOF

cat > /etc/systemd/system/ansible-optimize.timer <<'EOF'
[Unit]
Description=Run Ansible optimization weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now ansible-optimize.timer
```

### Git Auto-Update

```bash
cat > /etc/systemd/system/ansible-git-sync.service <<'EOF'
[Unit]
Description=Sync Ansible playbooks from Git

[Service]
Type=oneshot
WorkingDirectory=/opt/k3s-ansible
ExecStart=/usr/bin/git pull origin main
EOF

cat > /etc/systemd/system/ansible-git-sync.timer <<'EOF'
[Unit]
Description=Sync playbooks hourly

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now ansible-git-sync.timer
```

## Monitoring

### Check Service Status

```bash
# K3s
systemctl status k3s

# Honeypot
systemctl status honeypot

# Fail2ban
systemctl status fail2ban

# Check all at once
for svc in k3s honeypot fail2ban; do
  echo "=== $svc ==="
  systemctl is-active $svc
done
```

### View Fail2ban Statistics

```bash
# Active jails
fail2ban-client status

# Specific jail details
fail2ban-client status sshd
fail2ban-client status honeypot

# Currently banned IPs
for jail in sshd honeypot; do
  echo "=== $jail ==="
  fail2ban-client status $jail | grep "Banned IP"
done
```

### Monitor Resources

```bash
# Real-time monitoring
htop

# Network traffic
nethogs

# Disk I/O
iotop

# System stats
sar -u 1 10  # CPU
sar -r 1 10  # Memory
```
