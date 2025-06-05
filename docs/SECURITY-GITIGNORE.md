# VPN Security & Git Configuration

## Git Ignore Strategy

Following Elon Musk's principle of "security through simplicity", our `.gitignore` is designed to protect sensitive data while maintaining a clean repository structure.

### Protected Files & Directories

#### 🔒 **Highly Sensitive (Never Commit)**
- `wg-data/` - Contains all Wireguard configurations, private keys, and client certificates
- `.env` - Environment variables with production secrets
- `logs/` - May contain connection logs with user IP addresses
- `*_data/` - Docker volume data with persistent state

#### 🔐 **Moderately Sensitive**
- `monitoring/data/` - Prometheus metrics data
- `fail2ban/` - Security logs and banned IP databases
- `*.pem, *.key, *.crt` - SSL/TLS certificates and private keys

#### 📦 **Build Artifacts**
- `client-configs-*.zip` - Generated client configuration packages
- `*.backup, *.bak` - Backup files that may contain sensitive data

### Directory Structure Maintenance

We use `.gitkeep` files to maintain essential directory structure:
- `wg-data/.gitkeep` - Ensures Wireguard config directory exists
- `logs/.gitkeep` - Ensures log directory exists for Docker volumes

### Configuration Templates

- `.env.example` - Safe template showing required environment variables
- Never commit actual `.env` files to prevent credential leaks

## Security Best Practices

1. **Always use `.env.example`** - Copy to `.env` and customize locally
2. **Never commit private keys** - All `privatekey-*` files are ignored
3. **Rotate credentials regularly** - Especially Grafana admin password
4. **Monitor git commits** - Use `git status` before committing

## Emergency Procedures

If sensitive data is accidentally committed:
```bash
# Remove from git history (use with extreme caution)
git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch path/to/sensitive/file' --prune-empty --tag-name-filter cat -- --all
```

## Verification Commands

```bash
# Check what will be committed
git status

# Verify sensitive files are ignored
git check-ignore wg-data/peer1/privatekey-peer1
git check-ignore .env

# Should return the file paths if properly ignored
```

---
*Following the principle: "The best security is the one that works without thinking about it"*
