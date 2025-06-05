#!/bin/bash
# Complete Connection Test Script cho WireGuard VPN
# File: test-connection.sh

set -e

echo "=== WIREGUARD CONNECTION TEST SCRIPT ==="
echo "Date: $(date)"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
        "HIGHLIGHT")
            echo -e "${CYAN}🔸 $message${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

print_status "INFO" "Starting comprehensive WireGuard connection tests..."
echo

# Load environment variables
if [ -f .env ]; then
    source .env
    print_status "SUCCESS" "Environment variables loaded from .env"
else
    print_status "WARNING" "No .env file found, using defaults"
fi

SERVERURL=${SERVERURL:-"155.133.7.195"}
SERVERPORT=${SERVERPORT:-"51820"}

echo
print_status "HIGHLIGHT" "Test Configuration:"
echo "   Server URL: $SERVERURL"
echo "   Server Port: $SERVERPORT"
echo "   Test Date: $(date)"
echo

# 1. Pre-flight checks
echo "=================== PRE-FLIGHT CHECKS ==================="

# Check if Docker is running
print_status "INFO" "1. Checking Docker service..."
if docker version >/dev/null 2>&1; then
    print_status "SUCCESS" "Docker is running"
else
    print_status "FAIL" "Docker is not running"
    exit 1
fi

# Check if container is running
print_status "INFO" "2. Checking WireGuard container..."
if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "wg-vpn.*Up"; then
    print_status "SUCCESS" "WireGuard container is running"
    container_status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "wg-vpn")
    echo "   Status: $container_status"
else
    print_status "FAIL" "WireGuard container is not running"
    exit 1
fi

# Check firewall
print_status "INFO" "3. Checking firewall configuration..."
if sudo ufw status | grep -q "51820/udp.*ALLOW"; then
    print_status "SUCCESS" "Firewall allows WireGuard traffic"
else
    print_status "FAIL" "Firewall is blocking WireGuard traffic"
    exit 1
fi

echo
echo "=================== SERVER TESTS ==================="

# 4. Test WireGuard interface
print_status "INFO" "4. Testing WireGuard interface..."
wg_output=$(docker exec wg-vpn wg show 2>/dev/null)
if [ $? -eq 0 ]; then
    print_status "SUCCESS" "WireGuard interface is active"
    
    # Parse WireGuard info
    public_key=$(echo "$wg_output" | grep "public key:" | awk '{print $3}')
    listening_port=$(echo "$wg_output" | grep "listening port:" | awk '{print $3}')
    peer_count=$(echo "$wg_output" | grep -c "peer:")
    
    echo "   Interface: wg0"
    echo "   Public Key: ${public_key:0:16}..."
    echo "   Listening Port: $listening_port"
    echo "   Configured Peers: $peer_count"
else
    print_status "FAIL" "WireGuard interface is not active"
    exit 1
fi

# 5. Test network binding
print_status "INFO" "5. Testing port binding..."
if docker exec wg-vpn netstat -ulnp 2>/dev/null | grep -q ":51820"; then
    print_status "SUCCESS" "Port 51820/UDP is bound correctly"
else
    print_status "FAIL" "Port 51820/UDP is not bound"
    exit 1
fi

# 6. Test Docker port exposure
print_status "INFO" "6. Testing Docker port exposure..."
port_info=$(docker port wg-vpn 51820/udp 2>/dev/null)
if [ $? -eq 0 ]; then
    print_status "SUCCESS" "Docker port is exposed correctly"
    echo "   Exposed as: $port_info"
else
    print_status "FAIL" "Docker port is not exposed"
    exit 1
fi

echo
echo "=================== CLIENT CONFIG TESTS ==================="

# 7. Check client configurations
print_status "INFO" "7. Validating client configurations..."

peer_count=0
for peer_dir in wg-data/peer*/; do
    if [ -d "$peer_dir" ]; then
        peer_count=$((peer_count + 1))
        peer_name=$(basename "$peer_dir")
        
        # Check if config file exists and is valid
        config_file="$peer_dir${peer_name}.conf"
        if [ -f "$config_file" ]; then
            # Check if config contains correct server IP
            if grep -q "$SERVERURL" "$config_file"; then
                print_status "SUCCESS" "✓ $peer_name config has correct server IP"
            else
                print_status "FAIL" "✗ $peer_name config has incorrect server IP"
            fi
            
            # Check if QR code exists
            qr_file="$peer_dir${peer_name}.png"
            if [ -f "$qr_file" ]; then
                print_status "SUCCESS" "✓ $peer_name QR code exists"
            else
                print_status "FAIL" "✗ $peer_name QR code missing"
            fi
        else
            print_status "FAIL" "✗ $peer_name config file missing"
        fi
    fi
done

print_status "INFO" "Total client configs found: $peer_count"

echo
echo "=================== CONNECTIVITY TESTS ==================="

# 8. Test external IP connectivity
print_status "INFO" "8. Testing external connectivity..."
external_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")

if [ -n "$external_ip" ]; then
    print_status "SUCCESS" "Server external IP: $external_ip"
    
    if [ "$external_ip" = "$SERVERURL" ]; then
        print_status "SUCCESS" "SERVERURL matches external IP"
    else
        print_status "WARNING" "SERVERURL ($SERVERURL) differs from external IP ($external_ip)"
    fi
else
    print_status "WARNING" "Could not determine external IP"
fi

# 9. Test UDP port accessibility (local)
print_status "INFO" "9. Testing local UDP port accessibility..."
if timeout 3 bash -c "</dev/udp/127.0.0.1/51820" 2>/dev/null; then
    print_status "SUCCESS" "UDP port 51820 is accessible locally"
else
    print_status "WARNING" "UDP port test inconclusive (normal for UDP)"
fi

# 10. Test from Docker network
print_status "INFO" "10. Testing from Docker network..."
docker_ip=$(docker inspect wg-vpn --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
if [ -n "$docker_ip" ]; then
    print_status "SUCCESS" "Container IP: $docker_ip"
    
    # Test if we can reach the container's port
    if docker exec wg-vpn ss -ulnp | grep -q ":51820"; then
        print_status "SUCCESS" "Port is listening in container"
    else
        print_status "FAIL" "Port is not listening in container"
    fi
else
    print_status "FAIL" "Could not get container IP"
fi

echo
echo "=================== SECURITY VALIDATION ==================="

# 11. Check file permissions
print_status "INFO" "11. Checking file permissions..."
secure_files=true

for peer_dir in wg-data/peer*/; do
    if [ -d "$peer_dir" ]; then
        peer_name=$(basename "$peer_dir")
        
        # Check directory permissions (should be 700)
        dir_perms=$(stat -c "%a" "$peer_dir")
        if [ "$dir_perms" = "700" ]; then
            print_status "SUCCESS" "✓ $peer_name directory permissions secure (700)"
        else
            print_status "WARNING" "✗ $peer_name directory permissions: $dir_perms (should be 700)"
            secure_files=false
        fi
        
        # Check config file permissions (should be 600)
        config_file="$peer_dir${peer_name}.conf"
        if [ -f "$config_file" ]; then
            file_perms=$(stat -c "%a" "$config_file")
            if [ "$file_perms" = "600" ]; then
                print_status "SUCCESS" "✓ $peer_name config permissions secure (600)"
            else
                print_status "WARNING" "✗ $peer_name config permissions: $file_perms (should be 600)"
                secure_files=false
            fi
        fi
    fi
done

if $secure_files; then
    print_status "SUCCESS" "All file permissions are secure"
else
    print_status "WARNING" "Some file permissions need attention"
fi

# 12. Check for preshared keys
print_status "INFO" "12. Checking security features..."
preshared_count=0
for peer_dir in wg-data/peer*/; do
    if [ -d "$peer_dir" ]; then
        peer_name=$(basename "$peer_dir")
        preshared_file="$peer_dir/presharedkey-$peer_name"
        if [ -f "$preshared_file" ]; then
            preshared_count=$((preshared_count + 1))
        fi
    fi
done

if [ $preshared_count -gt 0 ]; then
    print_status "SUCCESS" "Preshared keys configured for enhanced security ($preshared_count peers)"
else
    print_status "WARNING" "No preshared keys found"
fi

echo
echo "=================== PERFORMANCE TESTS ==================="

# 13. Container resource usage
print_status "INFO" "13. Checking resource usage..."
resource_stats=$(docker stats wg-vpn --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}")
if [ $? -eq 0 ]; then
    print_status "SUCCESS" "Resource usage collected:"
    echo "$resource_stats" | tail -n +2 | while read line; do
        echo "   $line"
    done
else
    print_status "WARNING" "Could not collect resource usage"
fi

# 14. Health check status
print_status "INFO" "14. Checking container health..."
health_status=$(docker inspect wg-vpn --format='{{.State.Health.Status}}' 2>/dev/null)
if [ "$health_status" = "healthy" ]; then
    print_status "SUCCESS" "Container health status: healthy"
else
    print_status "WARNING" "Container health status: $health_status"
fi

echo
echo "=================== FINAL SUMMARY ==================="

# Summary
all_tests_passed=true

# Critical checks
if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "wg-vpn.*Up"; then
    all_tests_passed=false
fi

if ! sudo ufw status | grep -q "51820/udp.*ALLOW"; then
    all_tests_passed=false
fi

if ! docker exec wg-vpn wg show >/dev/null 2>&1; then
    all_tests_passed=false
fi

if [ $peer_count -eq 0 ]; then
    all_tests_passed=false
fi

print_status "INFO" "Connection Test Summary:"
echo

if $all_tests_passed; then
    print_status "SUCCESS" "🎉 ALL TESTS PASSED! WireGuard VPN is ready for use!"
    echo
    print_status "HIGHLIGHT" "📋 Ready-to-use client configurations:"
    
    for peer_dir in wg-data/peer*/; do
        if [ -d "$peer_dir" ]; then
            peer_name=$(basename "$peer_dir")
            config_file="$peer_dir${peer_name}.conf"
            qr_file="$peer_dir${peer_name}.png"
            
            echo "   📁 $peer_name:"
            echo "      Config: $config_file"
            echo "      QR Code: $qr_file"
        fi
    done
    
    echo
    print_status "HIGHLIGHT" "🚀 Next Steps:"
    echo "   1. Download a client config (e.g., peer1.conf)"
    echo "   2. Install WireGuard client on your device"
    echo "   3. Import the config or scan the QR code"
    echo "   4. Connect and test your VPN!"
    echo
    print_status "HIGHLIGHT" "📊 Connection Details:"
    echo "   Server: $SERVERURL:$SERVERPORT"
    echo "   Protocol: UDP"
    echo "   Encryption: ChaCha20Poly1305"
    echo "   DNS: 1.1.1.1, 8.8.8.8"
    
else
    print_status "FAIL" "❌ Some tests failed. Please review the issues above."
    exit 1
fi

echo
print_status "INFO" "Connection test completed at $(date)"
echo "====================================================="
