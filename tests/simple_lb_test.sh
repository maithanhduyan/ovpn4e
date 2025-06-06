#!/bin/bash

echo "🚀 Simple Load Balancer Test"
echo "=========================="

# Test 1: Health endpoint
echo -n "1. Health check: "
if curl -s http://localhost/health | grep -q "nginx-lb-ok"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Test 2: Load balancer status
echo -n "2. LB status: "
if curl -s http://localhost/lb-status | grep -q "Load Balancer Status"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Test 3: WireGuard connect endpoint
echo -n "3. WireGuard connect: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost/wireguard/connect | grep -q "502"; then
    echo "✅ PASS (502 expected - no backend service)"
else
    echo "❌ FAIL"
fi

# Test 4: WireGuard API endpoint
echo -n "4. WireGuard API: "
if curl -s http://localhost/api/wireguard/ | grep -q '"status":"ok"'; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Test 5: Root info page
echo -n "5. Info page: "
if curl -s http://localhost/ | grep -q "Nginx Load Balancer"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Test 6: UDP port test
echo -n "6. UDP port 51821: "
if netstat -un | grep -q ":51821"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

echo ""
echo "🔍 Additional Info:"
echo "- Containers: $(docker compose ps --format 'table {{.Service}}\t{{.Status}}' | tail -n +2)"
echo "- Nginx config test: $(docker exec vpn-proxy nginx -t 2>&1 | grep -q 'successful' && echo 'OK' || echo 'FAIL')"
echo "- UDP Load balancer listening: $(docker exec vpn-proxy netstat -un 2>/dev/null | grep :51820 | wc -l) sockets"

echo ""
echo "✅ Load Balancer Test Complete!"
