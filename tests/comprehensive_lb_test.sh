#!/bin/bash

echo "🚀 COMPREHENSIVE LOAD BALANCER TEST"
echo "=================================="
echo "Testing complete nginx load balancer setup for WireGuard"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "$(printf '%2d' $TOTAL_TESTS). $test_name: "
    
    result=$(eval "$test_command" 2>/dev/null)
    
    if echo "$result" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        echo -e "   ${YELLOW}Expected:${NC} $expected_pattern"
        echo -e "   ${YELLOW}Got:${NC} $result"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

echo -e "${BLUE}📦 CONTAINER STATUS${NC}"
echo "=================="
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
echo ""

echo -e "${BLUE}🔍 BASIC LOAD BALANCER TESTS${NC}"
echo "============================"

# Test 1: Health endpoint
run_test "Health endpoint" \
    "curl -s http://localhost/health" \
    "nginx-lb-ok"

# Test 2: Load balancer status
run_test "Load balancer status" \
    "curl -s http://localhost/lb-status" \
    "Load Balancer Status"

# Test 3: Root info page
run_test "Info page" \
    "curl -s http://localhost/" \
    "Nginx Load Balancer for WireGuard"

# Test 4: WireGuard connect endpoint (expecting 502)
run_test "WireGuard connect (502 expected)" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost/wireguard/connect" \
    "502"

# Test 5: WireGuard API endpoint
run_test "WireGuard API endpoint" \
    "curl -s http://localhost/api/wireguard/" \
    '"status":"ok"'

echo ""
echo -e "${BLUE}🔧 NGINX CONFIGURATION TESTS${NC}"
echo "============================"

# Test 6: Nginx config syntax
run_test "Nginx config syntax" \
    "docker exec vpn-proxy nginx -t 2>&1" \
    "successful"

# Test 7: Stream module loaded
run_test "Stream module enabled" \
    "docker exec vpn-proxy nginx -V 2>&1" \
    "with-stream"

# Test 8: Upstream configuration
run_test "Upstream config check" \
    "docker exec vpn-proxy grep -c 'upstream.*cluster' /etc/nginx/nginx.conf" \
    "2"

echo ""
echo -e "${BLUE}🌐 NETWORK CONNECTIVITY TESTS${NC}"
echo "============================="

# Test 9: Container network connectivity
run_test "Container network ping" \
    "docker exec vpn-proxy ping -c 1 wg-vpn >/dev/null 2>&1 && echo 'ping-ok'" \
    "ping-ok"

# Test 10: WireGuard container health
run_test "WireGuard container health" \
    "docker exec wg-vpn pgrep wg-quick >/dev/null && echo 'wg-running'" \
    "wg-running"

# Test 11: WireGuard interface active
run_test "WireGuard interface active" \
    "docker exec wg-vpn ip link show wg0 2>/dev/null | grep -q 'UP' && echo 'wg0-up'" \
    "wg0-up"

echo ""
echo -e "${BLUE}🔌 PORT AND SERVICE TESTS${NC}"
echo "========================"

# Test 12: External UDP port 51821 listening
run_test "External UDP port 51821" \
    "netstat -un | grep -q ':51821' && echo 'port-listening'" \
    "port-listening"

# Test 13: WireGuard UDP port 51820 listening
run_test "WireGuard UDP port 51820" \
    "netstat -un | grep -q ':51820' && echo 'wg-port-listening'" \
    "wg-port-listening"

# Test 14: Nginx HTTP port 80 listening
run_test "Nginx HTTP port 80" \
    "netstat -tn | grep -q ':80.*LISTEN' && echo 'http-listening'" \
    "http-listening"

echo ""
echo -e "${BLUE}📊 LOAD BALANCER FUNCTIONALITY${NC}"
echo "============================="

# Test 15: Multiple requests to test load balancing
echo -n "15. Load balancing consistency: "
consistent=true
for i in {1..5}; do
    response=$(curl -s http://localhost/health)
    if ! echo "$response" | grep -q "nginx-lb-ok"; then
        consistent=false
        break
    fi
done

if $consistent; then
    echo -e "${GREEN}✅ PASS${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}❌ FAIL${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Test 16: API response consistency
echo -n "16. API response consistency: "
api_consistent=true
for i in {1..3}; do
    api_response=$(curl -s http://localhost/api/wireguard/)
    if ! echo "$api_response" | grep -q '"status":"ok"'; then
        api_consistent=false
        break
    fi
done

if $api_consistent; then
    echo -e "${GREEN}✅ PASS${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}❌ FAIL${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo ""
echo -e "${BLUE}🔍 DETAILED DIAGNOSTICS${NC}"
echo "======================"

echo "Container Logs (last 5 lines):"
echo "  Nginx errors:"
docker exec vpn-proxy tail -5 /var/log/nginx/error.log 2>/dev/null || echo "    No errors"

echo "  WireGuard status:"
docker exec wg-vpn wg show 2>/dev/null | head -3 || echo "    WireGuard status unavailable"

echo ""
echo "Network Information:"
echo "  Nginx container IP: $(docker inspect vpn-proxy --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
echo "  WireGuard container IP: $(docker inspect wg-vpn --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"

echo ""
echo "Active Ports:"
echo "  TCP ports: $(netstat -tn 2>/dev/null | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | tr '\n' ' ')"
echo "  UDP ports: $(netstat -un 2>/dev/null | grep -E ':[0-9]+\s' | awk '{print $4}' | cut -d: -f2 | sort -n | tr '\n' ' ')"

echo ""
echo -e "${BLUE}📈 PERFORMANCE TEST${NC}"
echo "=================="

echo -n "17. Response time test: "
response_time=$(curl -s -w "%{time_total}" -o /dev/null http://localhost/health)
if [ "$(echo "$response_time < 1.0" | bc 2>/dev/null || echo 1)" = "1" ]; then
    echo -e "${GREEN}✅ PASS${NC} (${response_time}s)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}❌ FAIL${NC} (${response_time}s - too slow)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo ""
echo -e "${BLUE}📋 FINAL RESULTS${NC}"
echo "================"
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL TESTS PASSED! Load balancer is working perfectly.${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some tests failed. Check the configuration.${NC}"
    
    echo ""
    echo -e "${BLUE}🔧 TROUBLESHOOTING TIPS${NC}"
    echo "====================="
    echo "1. Check nginx logs: docker logs vpn-proxy"
    echo "2. Check WireGuard logs: docker logs wg-vpn"
    echo "3. Verify network: docker network inspect ovpn4e_default"
    echo "4. Test config: docker exec vpn-proxy nginx -t"
    echo "5. Reload config: docker exec vpn-proxy nginx -s reload"
    
    exit 1
fi
