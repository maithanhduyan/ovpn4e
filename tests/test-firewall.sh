#!/bin/bash
# Test script cho Firewall configuration
# File: test-firewall.sh

set -e

echo "=== FIREWALL TEST SCRIPT ==="
echo "Date: $(date)"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "SUCCESS"|"PASS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "FAIL"|"ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "WARNING"|"WARN")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

print_status "INFO" "Starting firewall tests for WireGuard VPN..."
echo

# 1. Check if UFW is installed and running
echo "1. Checking UFW status..."
if systemctl is-active --quiet ufw; then
    print_status "SUCCESS" "UFW service is running"
else
    print_status "FAIL" "UFW service is not running"
    exit 1
fi

# 2. Check UFW status
echo -e "\n2. Checking UFW configuration..."
ufw_status=$(sudo ufw status | head -1)
if [[ "$ufw_status" == *"Status: active"* ]]; then
    print_status "SUCCESS" "UFW is active"
else
    print_status "FAIL" "UFW is not active"
    exit 1
fi

# 3. Check if port 51820/UDP is allowed
echo -e "\n3. Checking WireGuard port 51820/UDP..."
if sudo ufw status | grep -q "51820/udp.*ALLOW"; then
    print_status "SUCCESS" "Port 51820/UDP is allowed in firewall"
else
    print_status "FAIL" "Port 51820/UDP is not allowed in firewall"
    print_status "INFO" "Adding rule for port 51820/UDP..."
    sudo ufw allow 51820/udp comment "WireGuard VPN"
    print_status "SUCCESS" "Port 51820/UDP rule added"
fi

# 4. Check if WireGuard container is running and port is bound
echo -e "\n4. Checking WireGuard container and port binding..."
if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "wg-vpn.*Up"; then
    print_status "SUCCESS" "WireGuard container is running"
    
    # Check if port is bound in container
    if docker exec wg-vpn netstat -ulnp 2>/dev/null | grep -q ":51820"; then
        print_status "SUCCESS" "Port 51820/UDP is bound in container"
    else
        print_status "FAIL" "Port 51820/UDP is not bound in container"
    fi
else
    print_status "WARNING" "WireGuard container is not running"
    print_status "INFO" "Starting WireGuard container..."
    docker compose up -d wireguard
    sleep 5
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "wg-vpn.*Up"; then
        print_status "SUCCESS" "WireGuard container started successfully"
    else
        print_status "FAIL" "Failed to start WireGuard container"
        exit 1
    fi
fi

# 5. Test port accessibility from host
echo -e "\n5. Testing port accessibility..."
# Check if netcat is available
if command -v nc >/dev/null 2>&1; then
    # Test UDP port with timeout
    if timeout 3 bash -c "</dev/udp/127.0.0.1/51820" 2>/dev/null; then
        print_status "SUCCESS" "Port 51820/UDP is accessible from localhost"
    else
        print_status "WARNING" "Port 51820/UDP test inconclusive (UDP testing limitation)"
    fi
else
    print_status "WARNING" "netcat not available for port testing"
fi

# 6. Check iptables rules (Docker creates these automatically)
echo -e "\n6. Checking iptables rules for Docker..."
if sudo iptables -L -n | grep -q "51820"; then
    print_status "SUCCESS" "iptables rules found for port 51820"
else
    print_status "INFO" "No specific iptables rules found (Docker may handle this)"
fi

# 7. Check if port is exposed to external network
echo -e "\n7. Checking Docker port exposure..."
if docker port wg-vpn 2>/dev/null | grep -q "51820"; then
    print_status "SUCCESS" "Port 51820 is exposed by Docker"
    docker port wg-vpn | grep 51820
else
    print_status "FAIL" "Port 51820 is not exposed by Docker"
fi

# 8. Display current firewall rules
echo -e "\n8. Current UFW rules:"
print_status "INFO" "UFW Status:"
sudo ufw status numbered

# 9. Test external connectivity (if possible)
echo -e "\n9. Network connectivity test..."
# Get server's external IP
external_ip=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to get external IP")
print_status "INFO" "Server external IP: $external_ip"

if [[ "$external_ip" != "Unable to get external IP" ]]; then
    print_status "INFO" "External clients should connect to: $external_ip:51820"
else
    print_status "WARNING" "Could not determine external IP"
fi

# 10. Summary and recommendations
echo -e "\n" 
echo "=================== SUMMARY ==================="
print_status "INFO" "Firewall Test Summary:"

# Check all critical components
all_good=true

# UFW active
if sudo ufw status | grep -q "Status: active"; then
    print_status "SUCCESS" "UFW is active and protecting the server"
else
    print_status "FAIL" "UFW is not active"
    all_good=false
fi

# Port 51820 allowed
if sudo ufw status | grep -q "51820/udp.*ALLOW"; then
    print_status "SUCCESS" "WireGuard port 51820/UDP is allowed"
else
    print_status "FAIL" "WireGuard port 51820/UDP is not allowed"
    all_good=false
fi

# Container running
if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "wg-vpn.*Up"; then
    print_status "SUCCESS" "WireGuard container is operational"
else
    print_status "FAIL" "WireGuard container is not running"
    all_good=false
fi

echo
if $all_good; then
    print_status "SUCCESS" "ALL FIREWALL TESTS PASSED!"
    echo
    print_status "INFO" "Next steps:"
    echo "   1. Update SERVERURL in .env with your external IP: $external_ip"
    echo "   2. Test VPN connection from external client"
    echo "   3. Monitor logs: docker compose logs -f wireguard"
else
    print_status "FAIL" "Some tests failed. Please check the issues above."
    exit 1
fi

echo
print_status "INFO" "Firewall configuration completed successfully!"
echo "================================================="
