# 🔒 Security Guide

## Overview

This repository implements a **defense-in-depth** security strategy for K3s clusters:

1. **Deception Layer**: Honeypot to attract and log attackers
2. **Blocking Layer**: Fail2ban to automatically ban malicious IPs
3. **Firewall Layer**: UFW to control network access
4. **Hardening Layer**: SSH and system security configurations
5. **Monitoring Layer**: Logging and alerting

## Security Architecture

```
Internet
   ↓
┌─────────────────────────────┐
│  UFW Firewall               │
│  - Allow: 27015 (SSH)       │
│  - Allow: 6443 (K3s API)    │
│  - Allow: Honeypot ports    │
└─────────────────────────────┘
   ↓                    ↓
┌────────────┐    ┌────────────────┐
│ Real SSH   │    │ Honeypot Ports │
│ (27015)    │    │ (21,22,23,...) │
└────────────┘    └────────────────┘
   ↓                    ↓
┌────────────┐    ┌────────────────┐
│ Fail2ban   │    │ Logging        │
│ (sshd jail)│    │ Auto-ban script│
└────────────┘    └────────────────┘
```

## Honeypot Security

### What is a Honeypot?

A honeypot is a **decoy system** designed to:
- Attract attackers away from real services
- Log attack patterns and techniques
- Automatically identify malicious IPs
- Provide early warning of attacks

### Deployed Honeypot Ports

| Port | Service | Purpose |
|------|---------|----------|
| 21 | FTP | Common brute-force target |
| 22 | SSH | Fake SSH (real SSH on 27015) |
| 23 | Telnet | IoT botnet scanner |
| 25 | SMTP | Spam relay attempts |
| 110 | POP3 | Email credential theft |
| 143 | IMAP | Email credential theft |
| 3306 | MySQL | Database attack attempts |
| 3389 | RDP | Windows brute-force |
| 5432 | PostgreSQL | Database scanning |

### Honeypot Logs

All connection attempts are logged to `/var/log/honeypot.log`:

```
[2025-11-15 02:39:45] Connection from 192.168.1.100:54321 to SSH (port 22)
[2025-11-15 02:40:12] Connection from 192.168.1.100:54322 to MySQL (port 3306)
```

### Automatic Banning

The `autoban-honeypot.sh` script:
1. Analyzes honeypot logs hourly
2. Identifies IPs with >5 attempts
3. Bans them via fail2ban and UFW
4. Logs banned IPs for reporting

## Fail2ban Configuration

### Jails

#### 1. SSH Jail (Real SSH on port 27015)

```ini
[sshd]
enabled  = true
port     = 27015
maxretry = 3
bantime  = 86400  # 24 hours
```

#### 2. Honeypot Jail

```ini
[honeypot]
enabled  = true
port     = 21,22,23,25,110,143,3306,3389,5432
maxretry = 1  # Ban immediately!
bantime  = 86400
```

### Check Banned IPs

```bash
# All jails
fail2ban-client status

# Specific jail
fail2ban-client status honeypot

# Unban IP
fail2ban-client set honeypot unbanip 192.168.1.100
```

## SSH Hardening

### Applied Configurations

```
Port 27015                          # Non-standard port
PermitRootLogin prohibit-password   # Only key-based root login
PasswordAuthentication no           # Disable password auth
PubkeyAuthentication yes            # Enable key-based auth
MaxAuthTries 3                      # Limit brute-force attempts
X11Forwarding no                    # Disable X11
AllowTcpForwarding no               # Disable tunneling
ClientAliveInterval 300             # Timeout idle sessions
```

### SSH Key Management

**Before** changing SSH port:

```bash
# Generate SSH key (if not already done)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server

# Test key-based auth
ssh -i ~/.ssh/id_ed25519 user@server
```

**After** running playbook:

```bash
# Connect on new port
ssh -p 27015 user@server

# Add to ~/.ssh/config
Host k3s-master
  HostName 31.56.39.58
  Port 27015
  User root
  IdentityFile ~/.ssh/id_ed25519

# Then simply:
ssh k3s-master
```

## Firewall Rules

### Current UFW Configuration

```bash
# Check status
ufw status numbered

# Expected rules:
[1] 27015/tcp    ALLOW IN    Anywhere    # SSH
[2] 6443/tcp     ALLOW IN    Anywhere    # K3s API
[3] 21/tcp       ALLOW IN    Anywhere    # Honeypot FTP
[4] 22/tcp       ALLOW IN    Anywhere    # Honeypot SSH
...
```

### Critical: Close Kubelet Port

**IMPORTANT**: Port 10250 (Kubelet API) should **NOT** be exposed externally!

```bash
# Remove external access
ufw delete allow 10250/tcp

# Allow only from pod network
ufw insert 6 allow from 10.42.0.0/16 to any port 10250 proto tcp comment 'Kubelet - pod network only'

# Verify
ss -tlnp | grep 10250
```

## Port Security Analysis

### Run Port Security Check

```bash
/opt/k3s-ansible/scripts/port-security-check.sh
```

This script:
- Lists all listening ports
- Categorizes them by risk level
- Identifies externally exposed services
- Provides remediation commands

### Port Categories

- 🍯 **HONEYPOT**: Intentional decoys (safe)
- 🔑 **SECURE**: Hardened services (27015 SSH)
- 🟢 **SAFE**: Localhost-only bindings
- ⚠️ **K3S Internal**: Required for cluster (6443)
- 🔴 **CRITICAL RISK**: Exposed sensitive ports (10250)

## Monitoring and Alerting

### Daily Security Report

Create `/usr/local/bin/security-report.sh`:

```bash
#!/bin/bash
REPORT_FILE="/var/log/security-report-$(date +%Y-%m-%d).txt"

cat > "$REPORT_FILE" <<EOF
=== SECURITY REPORT $(date) ===

Honeypot Attacks (last 24h):
$(grep "$(date +%Y-%m-%d)" /var/log/honeypot.log | wc -l) connections

Top 10 Attacking IPs:
$(grep "Connection from" /var/log/honeypot.log | \
  grep "$(date +%Y-%m-%d)" | \
  awk '{print $4}' | cut -d':' -f1 | \
  sort | uniq -c | sort -rn | head -10)

Currently Banned IPs:
SSH: $(fail2ban-client status sshd | grep "Currently banned" | awk '{print $NF}')
Honeypot: $(fail2ban-client status honeypot | grep "Currently banned" | awk '{print $NF}')

Open Ports:
$(ss -tlnp | grep LISTEN | wc -l) listening ports

EOF

cat "$REPORT_FILE"
```

### Schedule Daily Reports

```bash
chmod +x /usr/local/bin/security-report.sh

# Add to crontab
echo "0 0 * * * /usr/local/bin/security-report.sh" | crontab -
```

## Incident Response

### Detected Attack

1. **Check logs**:
   ```bash
   tail -100 /var/log/honeypot.log
   tail -100 /var/log/fail2ban.log
   tail -100 /var/log/auth.log
   ```

2. **Identify attacker IP**:
   ```bash
   grep "ATTACKER_IP" /var/log/honeypot.log
   ```

3. **Manual ban** (if not auto-banned):
   ```bash
   fail2ban-client set honeypot banip ATTACKER_IP
   ufw insert 1 deny from ATTACKER_IP
   ```

4. **Report** (optional):
   ```bash
   # Report to AbuseIPDB, etc.
   ```

### Compromised SSH Key

1. **Immediately disable** compromised key:
   ```bash
   # Remove from authorized_keys
   sed -i '/COMPROMISED_KEY_FINGERPRINT/d' ~/.ssh/authorized_keys
   ```

2. **Generate new key** on client:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new
   ```

3. **Add new key** to server

4. **Rotate all keys**

## Best Practices

### ✅ DO

- Use SSH keys instead of passwords
- Regularly update and patch systems
- Monitor honeypot logs daily
- Backup fail2ban ban lists
- Test SSH access before logging out
- Keep Ansible playbooks in version control
- Review banned IPs periodically
- Enable automatic security updates

### ❌ DON'T

- Expose Kubelet port (10250) externally
- Use default SSH port (22) for real access
- Disable fail2ban or honeypot
- Ignore security alerts
- Share SSH private keys
- Run services as root unnecessarily
- Allow password authentication
- Forget to test configuration changes

## Security Checklist

```bash
# Run this checklist monthly

☐ SSH hardened (port 27015, keys only)
☐ Fail2ban active and monitoring
☐ Honeypot running and logging
☐ UFW firewall enabled
☐ Port 10250 restricted to pod network
☐ System updates applied
☐ Logs reviewed (honeypot, fail2ban, auth)
☐ Banned IPs list reviewed
☐ Backup configs exist
☐ Health check passing
```

## Compliance

This configuration helps meet:

- **CIS Kubernetes Benchmark**: SSH hardening, firewall rules
- **NIST Cybersecurity Framework**: Defense-in-depth, monitoring
- **PCI DSS**: Strong access controls, logging
- **GDPR**: Data protection through security controls

## References

- [K3s Security Best Practices](https://docs.k3s.io/security)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Fail2ban Documentation](https://www.fail2ban.org/)
- [OpenSSH Best Practices](https://www.openssh.com/security.html)
