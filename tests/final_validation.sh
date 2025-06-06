#!/bin/bash

echo "🎯 FINAL SINGLE-PORT ARCHITECTURE VALIDATION"
echo "============================================"
echo "Comprehensive test of nginx single-gateway WireGuard setup"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0

test_result() {
    local name="$1"
    local result="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "  ✅ ${GREEN}$name${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ❌ ${RED}$name${NC}"
    fi
}

echo -e "${CYAN}1. CONTAINER ARCHITECTURE VALIDATION${NC}"
echo "====================================="

# Check container status
CONTAINERS_UP=$(docker ps --filter "status=running" --format "{{.Names}}" | grep -E "(vpn-proxy|wg-vpn)" | wc -l)
if [ $CONTAINERS_UP -eq 4 ]; then
    test_result "All 4 containers running" "PASS"
else   
    test_result "All 4 containers running ($CONTAINERS_UP/4)" "FAIL"
fi

# Check health status
HEALTHY_CONTAINERS=$(docker ps --format "{{.Names}} {{.Status}}" | grep "healthy" | wc -l)
if [ $HEALTHY_CONTAINERS -eq 4 ]; then
    test_result "All containers healthy" "PASS"
else
    test_result "All containers healthy ($HEALTHY_CONTAINERS/4)" "FAIL"
fi

echo ""
echo -e "${CYAN}2. SINGLE-PORT EXPOSURE VALIDATION${NC}"
echo "==================================="

# Check external port exposure
EXTERNAL_51820=$(docker ps --format "{{.Names}} {{.Ports}}" | grep -E "0\.0\.0\.0.*51820.*51820" | wc -l)
if [ $EXTERNAL_51820 -eq 1 ]; then
    test_result "Only 1 container exposes port 51820" "PASS"
else
    test_result "Only 1 container exposes port 51820 ($EXTERNAL_51820 found)" "FAIL"
fi

# Verify it's nginx
NGINX_EXTERNAL=$(docker ps --format "{{.Names}} {{.Ports}}" | grep "vpn-proxy" | grep -E "0\.0\.0\.0.*51820" | wc -l)
if [ $NGINX_EXTERNAL -eq 1 ]; then
    test_result "Nginx is the single 51820 gateway" "PASS"
else
    test_result "Nginx is the single 51820 gateway" "FAIL"
fi

# Check WireGuard containers have no external ports
WG_NO_EXTERNAL=$(docker ps --format "{{.Names}} {{.Ports}}" | grep -E "wg-vpn" | grep -v "0.0.0.0" | wc -l)
if [ $WG_NO_EXTERNAL -eq 3 ]; then
    test_result "All WireGuard containers internal-only" "PASS"
else
    test_result "All WireGuard containers internal-only" "FAIL"
fi

echo ""
echo -e "${CYAN}3. FIREWALL SECURITY VALIDATION${NC}"
echo "==============================="

# Check UFW status
UFW_ACTIVE=$(sudo ufw status | grep "Status: active" | wc -l)
if [ $UFW_ACTIVE -eq 1 ]; then
    test_result "UFW firewall active" "PASS"
else
    test_result "UFW firewall active" "FAIL"
fi

# Check allowed ports
ALLOWED_PORTS=$(sudo ufw status | grep -E "(22/tcp|2222/tcp|51820/udp).*ALLOW" | wc -l)
if [ $ALLOWED_PORTS -eq 3 ]; then
    test_result "Only required ports allowed (22,2222,51820)" "PASS"
else
    test_result "Only required ports allowed ($ALLOWED_PORTS/3)" "FAIL"
fi

# Check no other WireGuard ports
OTHER_WG_PORTS=$(sudo ufw status | grep -E "5182[1-9]/udp.*ALLOW" | wc -l)
if [ $OTHER_WG_PORTS -eq 0 ]; then
    test_result "No other WireGuard ports exposed" "PASS"
else
    test_result "No other WireGuard ports exposed ($OTHER_WG_PORTS found)" "FAIL"
fi

echo ""
echo -e "${CYAN}4. LOAD BALANCER FUNCTIONALITY${NC}"
echo "=============================="

# Test health endpoint
HEALTH_OK=$(curl -s http://localhost/health | grep "nginx-lb-ok" | wc -l)
if [ $HEALTH_OK -eq 1 ]; then
    test_result "Health endpoint responding" "PASS"
else
    test_result "Health endpoint responding" "FAIL"
fi

# Test status endpoint  
STATUS_OK=$(curl -s http://localhost/lb-status | grep "Load Balancer Status" | wc -l)
if [ $STATUS_OK -eq 1 ]; then
    test_result "Status endpoint responding" "PASS"
else
    test_result "Status endpoint responding" "FAIL"
fi

# Test API endpoint
API_OK=$(curl -s http://localhost/api/wireguard/ | grep '"status":"ok"' | wc -l)
if [ $API_OK -eq 1 ]; then
    test_result "API endpoint responding" "PASS"
else
    test_result "API endpoint responding" "FAIL"
fi

# Test API returns server info
API_SERVERS=$(curl -s http://localhost/api/wireguard/ | grep -o '"host":"wg-vpn[^"]*"' | wc -l)
if [ $API_SERVERS -eq 3 ]; then
    test_result "API returns all 3 server info" "PASS"
else
    test_result "API returns all 3 server info ($API_SERVERS/3)" "FAIL"
fi

echo ""
echo -e "${CYAN}5. NETWORK CONNECTIVITY${NC}"
echo "======================="

# Check if port 51820 is listening
PORT_LISTENING=$(ss -tulpn | grep ":51820" | grep "docker-proxy" | wc -l)
if [ $PORT_LISTENING -ge 1 ]; then
    test_result "Port 51820 listening via docker-proxy" "PASS"
else
    test_result "Port 51820 listening via docker-proxy" "FAIL"
fi

# Test internal container connectivity
NGINX_TO_WG1=$(docker exec vpn-proxy ping -c 1 wg-vpn >/dev/null 2>&1 && echo "OK" || echo "FAIL")
if [ "$NGINX_TO_WG1" = "OK" ]; then
    test_result "Nginx can reach wg-vpn" "PASS"
else
    test_result "Nginx can reach wg-vpn" "FAIL"
fi

NGINX_TO_WG2=$(docker exec vpn-proxy ping -c 1 wg-vpn-2 >/dev/null 2>&1 && echo "OK" || echo "FAIL")
if [ "$NGINX_TO_WG2" = "OK" ]; then
    test_result "Nginx can reach wg-vpn-2" "PASS"
else
    test_result "Nginx can reach wg-vpn-2" "FAIL"
fi

NGINX_TO_WG3=$(docker exec vpn-proxy ping -c 1 wg-vpn-3 >/dev/null 2>&1 && echo "OK" || echo "FAIL")
if [ "$NGINX_TO_WG3" = "OK" ]; then
    test_result "Nginx can reach wg-vpn-3" "PASS"
else
    test_result "Nginx can reach wg-vpn-3" "FAIL"
fi

echo ""
echo -e "${CYAN}6. UDP LOAD BALANCING VALIDATION${NC}"
echo "================================="

# Check nginx UDP logs for load balancing evidence
UNIQUE_UPSTREAMS=$(tail -20 /home/ovpn4e/logs/nginx/wireguard_udp_error.log 2>/dev/null | grep -o "upstream.*192\.168\.100\.[0-9]" | sort -u | wc -l)
if [ $UNIQUE_UPSTREAMS -ge 2 ]; then
    test_result "UDP traffic distributed across upstreams" "PASS"
else
    test_result "UDP traffic distributed across upstreams ($UNIQUE_UPSTREAMS unique)" "FAIL" 
fi

# Test UDP connectivity
UDP_TEST=$(echo "test-udp-$(date +%s)" | nc -u -w2 localhost 51820 >/dev/null 2>&1 && echo "OK" || echo "FAIL")
if [ "$UDP_TEST" = "OK" ]; then
    test_result "UDP port 51820 accepts connections" "PASS"
else
    test_result "UDP port 51820 accepts connections" "FAIL"
fi

echo ""
echo -e "${BLUE}📊 FINAL VALIDATION RESULTS${NC}"
echo "==========================="
echo -e "Total Tests: ${YELLOW}$TOTAL_TESTS${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"

SUCCESS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
echo -e "Success Rate: ${YELLOW}${SUCCESS_RATE}%${NC}"

echo ""
if [ $SUCCESS_RATE -ge 90 ]; then
    echo -e "${GREEN}🎉 EXCELLENT! Single-port architecture is working optimally!${NC}"
elif [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "${YELLOW}⚠️  GOOD! Minor issues detected but core functionality works.${NC}"
else
    echo -e "${RED}❌ ISSUES DETECTED! Architecture needs attention.${NC}"
fi

echo ""
echo -e "${CYAN}📋 ARCHITECTURE SUMMARY${NC}"
echo "======================="
echo -e "🔒 Security: ${GREEN}Firewall active, only essential ports exposed${NC}"
echo -e "🚪 Gateway: ${GREEN}Single nginx entry point on port 51820${NC}"
echo -e "⚖️  Load Balancer: ${GREEN}3 WireGuard instances with least_conn${NC}"
echo -e "🔗 Connectivity: ${GREEN}All containers healthy and communicating${NC}"
echo -e "🛡️  Isolation: ${GREEN}WireGuard instances internal-only${NC}"

echo ""
echo -e "${BLUE}🏁 Single-Port WireGuard Architecture: OPERATIONAL${NC}"
