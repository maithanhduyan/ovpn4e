#!/bin/bash

echo "🔒 SINGLE PORT ARCHITECTURE TEST"
echo "================================"
echo "Testing nginx as single external endpoint for WireGuard"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -n "Testing $test_name... "
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

echo "1. CONTAINER STATUS TESTS"
echo "========================"

run_test "Nginx container healthy" "docker inspect vpn-proxy --format='{{.State.Health.Status}}' | grep -q healthy"
run_test "WireGuard-1 container healthy" "docker inspect wg-vpn --format='{{.State.Health.Status}}' | grep -q healthy"
run_test "WireGuard-2 container healthy" "docker inspect wg-vpn-2 --format='{{.State.Health.Status}}' | grep -q healthy"
run_test "WireGuard-3 container healthy" "docker inspect wg-vpn-3 --format='{{.State.Health.Status}}' | grep -q healthy"

echo ""
echo "2. PORT EXPOSURE TESTS"
echo "====================="

run_test "Only nginx exposes port 51820" "docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep '51820.*51820' | grep -q vpn-proxy"
run_test "WireGuard-1 has NO external ports" "! docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep wg-vpn | grep -v wg-vpn- | grep -q '->'"
run_test "WireGuard-2 has NO external ports" "! docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep wg-vpn-2 | grep -q '->'"
run_test "WireGuard-3 has NO external ports" "! docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep wg-vpn-3 | grep -q '->'"

echo ""
echo "3. LOAD BALANCER TESTS"
echo "====================="

run_test "Nginx health endpoint working" "curl -s http://localhost/health | grep -q 'nginx-lb-ok'"
run_test "Load balancer status endpoint" "curl -s http://localhost/lb-status | grep -q 'Load Balancer Status'"
run_test "WireGuard API endpoint working" "curl -s http://localhost/api/wireguard/ | grep -q 'status.*ok'"

echo ""
echo "4. FIREWALL TESTS"
echo "=================="

run_test "UFW firewall is active" "sudo ufw status | grep -q 'Status: active'"
run_test "SSH port 22 allowed" "sudo ufw status | grep -q '22/tcp.*ALLOW'"
run_test "SSH port 2222 allowed" "sudo ufw status | grep -q '2222/tcp.*ALLOW'"
run_test "WireGuard port 51820 allowed" "sudo ufw status | grep -q '51820/udp.*ALLOW'"
run_test "No other WireGuard ports allowed" "! sudo ufw status | grep -E '5182[1-3]/udp.*ALLOW'"

echo ""
echo "5. NETWORK CONNECTIVITY TESTS"
echo "============================="

run_test "Port 51820 listening externally" "ss -tulpn | grep ':51820' | grep -q docker-proxy"
run_test "Internal WireGuard networks accessible" "docker exec vpn-proxy ping -c 1 wg-vpn >/dev/null 2>&1"
run_test "Load balancer can reach WG-2" "docker exec vpn-proxy ping -c 1 wg-vpn-2 >/dev/null 2>&1"
run_test "Load balancer can reach WG-3" "docker exec vpn-proxy ping -c 1 wg-vpn-3 >/dev/null 2>&1"

echo ""
echo "6. ARCHITECTURE VALIDATION"
echo "========================="

# Check if only nginx has external access
EXTERNAL_PORTS=$(docker ps --format '{{.Names}} {{.Ports}}' | grep -E '0\.0\.0\.0.*->.*' | wc -l)
run_test "Only 1 container exposes external ports" "[ $EXTERNAL_PORTS -eq 1 ]"

# Check if nginx is the only gateway
run_test "Nginx is the single gateway" "docker ps --format '{{.Names}} {{.Ports}}' | grep '0.0.0.0.*->' | grep -q vpn-proxy"

echo ""
echo "📊 TEST RESULTS SUMMARY"
echo "======================="
echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"
echo -e "Success Rate: ${YELLOW}$(( PASSED_TESTS * 100 / TOTAL_TESTS ))%${NC}"

echo ""
if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! Single-port architecture is working correctly.${NC}"
    echo ""
    echo "Architecture Summary:"
    echo "- ✅ Only nginx exposes port 51820 externally"
    echo "- ✅ All WireGuard instances are internal-only"
    echo "- ✅ Firewall only allows necessary ports (22, 2222, 51820)"
    echo "- ✅ Load balancing is active and healthy"
    echo "- ✅ All containers are healthy and communicating"
else
    echo -e "${RED}❌ Some tests failed. Please check the configuration.${NC}"
fi
