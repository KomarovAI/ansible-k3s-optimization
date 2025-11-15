# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Idempotency checks for ipset role
- Centralized iptables save handler across all security roles

### Fixed
- **CRITICAL**: iptables rules conflict between kernel_security, ipset, and xt_recent roles
  - Created centralized "Save iptables rules" handler
  - All roles now use `notify` instead of direct `iptables-save`
  - Prevents rule overwrites between roles
  - Commits: 60c3f9a, 1e45851, b30d46e, 01ac41e

- **CRITICAL**: xt_recent role using incorrect iptables module syntax
  - Complete rewrite using shell commands with correct xt_recent syntax
  - Added idempotency checks via `iptables -S`
  - Role now works correctly with `--set`, `--update` parameters
  - Commit: 78ca28c

- **HIGH**: Missing idempotency in ipset role
  - Added existence checks before creating ipset sets
  - Added IP existence check before adding to blacklist
  - Shell commands now properly report changed status
  - Commit: 01ac41e

- **HIGH**: Duplicate nf_conntrack_max parameter conflict
  - Removed from system_optimization/defaults/main.yml
  - Kept only in kernel_security role (security-specific parameter)
  - Commit: b5ba631

### Changed
- xt_recent role now uses shell module instead of ansible iptables module
- ipset role handlers now include iptables save

## Known Issues

### Remaining (Non-Critical)

**MEDIUM Priority:**
- Duplicate tcp_max_syn_backlog in 3 locations (values match, no conflict)
- system_performance vs system_optimization role ordering in full-setup-ultimate.yml
- fail2ban ipset integration timing (configured after fail2ban role completes)
- AppArmor k3s-restricted profile may need tuning for specific K3s workloads

**LOW Priority:**
- Duplicate zram configuration in optimize-node.yml and system_optimization role
- Missing root privilege checks in playbooks
- Missing role dependencies in meta/main.yml files

## Testing Recommendations

Before production deployment:

1. **Test on staging environment:**
   ```bash
   ansible-playbook playbooks/full-setup-enhanced.yml --check
   ansible-playbook playbooks/full-setup-enhanced.yml
   ```

2. **Verify iptables rules:**
   ```bash
   iptables -S
   ipset list
   ```

3. **Check xt_recent functionality:**
   ```bash
   cat /proc/net/xt_recent/ssh_attack
   cat /proc/net/xt_recent/portscan
   ```

4. **Monitor security services:**
   ```bash
   /usr/local/bin/security-stack-status
   systemctl status fail2ban psad arpwatch
   ```

## Migration Guide

If upgrading from previous version:

1. **Backup current configuration:**
   ```bash
   ansible-playbook playbooks/backup-configs.yml
   ```

2. **Clear old iptables rules (optional):**
   ```bash
   iptables -F
   iptables -X
   ```

3. **Run updated playbooks:**
   ```bash
   ansible-playbook playbooks/full-setup-enhanced.yml
   ```

4. **Verify no rule conflicts:**
   ```bash
   iptables -S | grep -E 'blacklist|fail2ban|ssh_attack|portscan'
   ```

## Contributors

- **Artur Komarov** (@KomarovAI) - Critical fixes and security improvements

---

**Status:** ✅ Critical issues resolved - Ready for staging testing  
**Last Updated:** 2025-11-15