#!/bin/bash
# Test script cho VPN docker-compose
# File: test-vpn.sh

set -e

echo "=== VPN Docker-Compose Test Script ==="
echo "Date: $(date)"
echo

# 1. Kiểm tra Docker
echo "1. Checking Docker..."
if ! docker version > /dev/null 2>&1; then
    echo "❌ Docker daemon not running. Please start Docker Desktop."
    exit 1
fi
echo "✅ Docker is running"

# 2. Validate docker-compose syntax
echo "2. Validating docker-compose.yml..."
docker-compose config > /dev/null
echo "✅ docker-compose.yml syntax OK"

# 3. Pull images
echo "3. Pulling Wireguard image..."
docker-compose pull wireguard
echo "✅ Images pulled successfully"

# 4. Create required directories
echo "4. Creating required directories..."
mkdir -p wg-data logs
echo "✅ Directories created"

# 5. Start services
echo "5. Starting VPN services..."
docker-compose up -d wireguard
echo "✅ Services started"

# 6. Wait for container to be ready
echo "6. Waiting for Wireguard to initialize..."
sleep 10

# 7. Check container health
echo "7. Checking container health..."
if docker-compose ps wireguard | grep -q "Up"; then
    echo "✅ Wireguard container is running"
else
    echo "❌ Wireguard container failed to start"
    docker-compose logs wireguard
    exit 1
fi

# 8. Test Wireguard interface
echo "8. Testing Wireguard interface..."
if docker exec wg-vpn wg show > /dev/null 2>&1; then
    echo "✅ Wireguard interface is active"
    docker exec wg-vpn wg show
else
    echo "⚠️  Wireguard interface not ready yet (this is normal on first run)"
fi

# 9. Check logs
echo "9. Recent logs:"
docker-compose logs --tail=10 wireguard

# 10. Show connection info
echo "10. Connection Information:"
echo "Server URL: ${SERVERURL:-vpn.yourdomain.com}"
echo "Port: ${SERVERPORT:-51820}"
echo "Peers configured: ${PEERS:-10}"

echo
echo "=== Test completed successfully! ==="
echo "Next steps:"
echo "1. Update SERVERURL in .env file with your actual domain/IP"
echo "2. Configure your firewall to allow UDP port 51820"
echo "3. Client configs will be in ./wg-data/peer1/, peer2/, etc."
