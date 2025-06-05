# 🔧 Docker-Compose Test Guide

## 📋 Pre-requisites
- Docker Desktop installed and running on Windows
- PowerShell (or Git Bash)
- Port 51820/UDP available

## 🚀 Quick Test

### Method 1: PowerShell (Recommended)
```powershell
# Run test script
.\test-vpn.ps1
```

### Method 2: Manual Steps
```powershell
# 1. Check docker-compose syntax
docker-compose config

# 2. Create directories
mkdir wg-data, logs

# 3. Start services
docker-compose up -d

# 4. Check status
docker-compose ps
docker-compose logs wireguard

# 5. Test Wireguard
docker exec wg-vpn wg show
```

## 📊 Expected Results

### ✅ Success Indicators
- Container status: `Up`
- Wireguard interface shows: `interface: wg0`
- Client configs generated in `.\wg-data\peer1\`, `peer2\`, etc.
- Logs show: `Peer 1 created`

### ⚠️ Common Issues & Fixes

#### Issue 1: Docker not running
```
❌ Error: Docker daemon not running
```
**Fix**: Start Docker Desktop

#### Issue 2: Port already in use
```
❌ Error: bind: address already in use
```
**Fix**: Change SERVERPORT in `.env` or stop conflicting service

#### Issue 3: Permission denied
```
❌ Error: permission denied
```
**Fix**: Run PowerShell as Administrator

#### Issue 4: DNS resolution
```
❌ Error: server vpn.yourdomain.com not found
```
**Fix**: Update SERVERURL in `.env` with your actual IP/domain

## 🔍 Validation Checklist

- [ ] Docker-compose syntax valid
- [ ] Container starts without errors
- [ ] Wireguard interface active
- [ ] Client configs generated
- [ ] UDP port 51820 listening
- [ ] Logs show peer creation

## 📁 File Structure After Test
```
ovpn4e/
├── docker-compose.yml
├── .env
├── wg-data/
│   ├── wg0.conf
│   ├── peer1/
│   │   ├── peer1.conf
│   │   ├── peer1.png (QR code)
│   └── peer2/
├── logs/
└── test-vpn.ps1
```

## 🌐 Testing Connection

1. **Get client config**:
   ```powershell
   Get-Content .\wg-data\peer1\peer1.conf
   ```

2. **Install Wireguard client** from [official site](https://www.wireguard.com/install/)

3. **Import config** and test connection

## 📈 Performance Testing

```powershell
# Monitor resources
docker stats wg-vpn

# Test throughput (requires iperf3)
docker exec wg-vpn iperf3 -s
```

## 🛠️ Troubleshooting

### View detailed logs:
```powershell
docker-compose logs -f wireguard
```

### Restart services:
```powershell
docker-compose restart wireguard
```

### Clean reset:
```powershell
docker-compose down
Remove-Item -Recurse -Force wg-data, logs
docker-compose up -d
```
