# 🔒 Git Security Configuration

## Overview
This document explains the `.gitignore` configuration for the WireGuard VPN server project with nginx load balancer.

## 🛡️ Security Priorities

### Critical Security Items (NEVER COMMIT)
- **Private keys**: `privatekey-*`, `publickey-*`, `presharedkey-*`
- **Client configurations**: `peer*.conf` files containing connection details
- **Certificates**: `*.pem`, `*.key`, `*.crt` files
- **Environment files**: `.env*` files with sensitive configuration
- **QR codes**: `*.png` files containing configuration data

### Sensitive Data Directories
- `wg-data/` - All WireGuard configuration data
- `wg-data-*/` - Additional WireGuard instances
- `logs/` - May contain connection data and IP addresses
- `secrets/` - Authentication and API keys
- `ssl/` - SSL certificates and keys

## 📁 Directory Structure Protection

### Preserved Directories (with .gitkeep)
- `logs/.gitkeep` - Maintains log directory structure
- `logs/nginx/.gitkeep` - Nginx-specific logs directory
- `wg-data/.gitkeep` - WireGuard data directory structure

### Additional Security Layers
- `wg-data/.gitignore` - Extra protection for WireGuard data
- Template files allowed: `templates/*.conf` (sanitized templates only)

## 🔄 Load Balancer Specific

### Nginx Exclusions
- `nginx/cache/` - Nginx cache files
- `nginx/tmp/` - Temporary nginx files
- `nginx/*.pid` - Process ID files
- `logs/nginx/*.log` - Access and error logs

### Test Artifacts
- `tests/*_output.txt` - Test result files
- `tests/*_results.log` - Test execution logs
- `tests/performance_*.json` - Performance test data

## 🐳 Docker & Container Security

### Docker-specific
- `docker-compose.override.yml` - Local overrides (may contain secrets)
- `volumes/` - Docker volume data
- `.docker/` - Docker configuration

### Container Data
- `*_data/` - Named volume data
- `containers/` - Container-specific files

## 🚀 Production Security

### Deployment
- `config/production/` - Production configurations
- `deploy/production/` - Deployment scripts with credentials
- `*.production.conf` - Production-specific configs

### Infrastructure as Code
- `*.tfstate*` - Terraform state files (may contain secrets)
- `.terraform/` - Terraform cache and modules
- `inventory/hosts` - Ansible inventory with server details
- `group_vars/*/vault.yml` - Encrypted variables

## ✅ Best Practices Applied

1. **Defense in Depth**: Multiple layers of protection
2. **Explicit Exclusions**: Specific patterns for sensitive data
3. **Directory Structure**: Preserved with .gitkeep files
4. **Documentation**: Clear explanations for security decisions
5. **Template Safety**: Only sanitized templates are allowed

## 🔍 Verification Commands

Check what would be committed:
```bash
git status
git add --dry-run .
```

Verify sensitive files are ignored:
```bash
git check-ignore wg-data/peer1/privatekey-peer1
git check-ignore logs/nginx/access.log
```

## 🚨 Emergency Procedures

If sensitive data was accidentally committed:
1. **DO NOT** just delete and recommit
2. Use `git filter-branch` or `BFG Repo-Cleaner`
3. Force push to rewrite history
4. Rotate all compromised keys/certificates
5. Notify team members to re-clone repository

## 📞 Security Contact
If you discover sensitive data in the repository, immediately contact the security team.

---
*Last updated: June 6, 2025*
*Security level: CRITICAL - VPN Infrastructure*
