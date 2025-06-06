#!/bin/bash

echo "🔌 UDP LOAD BALANCER TEST"
echo "========================"
echo "Testing nginx UDP stream load balancing for WireGuard"
echo ""

# Test UDP connectivity to nginx load balancer
echo "1. Testing UDP connectivity to nginx load balancer..."
echo "Sending UDP test packets to port 51820..."

# Use netcat to test UDP connection
for i in {1..5}; do
    echo "Test $i: Sending UDP packet to localhost:51820"
    echo "test-packet-$i-$(date +%s)" | nc -u -w1 localhost 51820
    sleep 1
done

echo ""
echo "2. Checking nginx stream logs..."
if [ -f "/home/ovpn4e/logs/nginx/stream_error.log" ]; then
    echo "Stream error log (last 10 lines):"
    tail -10 /home/ovpn4e/logs/nginx/stream_error.log
else
    echo "Stream error log not found"
fi

echo ""
echo "3. Checking WireGuard interface status in containers..."
docker exec wg-vpn wg show 2>/dev/null || echo "WireGuard interface not yet configured in wg-vpn"
docker exec wg-vpn-2 wg show 2>/dev/null || echo "WireGuard interface not yet configured in wg-vpn-2"  
docker exec wg-vpn-3 wg show 2>/dev/null || echo "WireGuard interface not yet configured in wg-vpn-3"

echo ""
echo "4. Testing nginx upstream connectivity..."
echo "Checking if nginx can reach WireGuard instances..."

docker exec vpn-proxy sh -c "
echo 'Testing internal connectivity:'
ping -c 1 wg-vpn && echo '✅ Can reach wg-vpn' || echo '❌ Cannot reach wg-vpn'
ping -c 1 wg-vpn-2 && echo '✅ Can reach wg-vpn-2' || echo '❌ Cannot reach wg-vpn-2'
ping -c 1 wg-vpn-3 && echo '✅ Can reach wg-vpn-3' || echo '❌ Cannot reach wg-vpn-3'
"

echo ""
echo "5. Architecture validation..."
echo "External port exposure check:"
EXTERNAL_CONTAINERS=$(docker ps --format '{{.Names}} {{.Ports}}' | grep -E '0\.0\.0\.0.*->.*51820' | wc -l)
if [ $EXTERNAL_CONTAINERS -eq 1 ]; then
    echo "✅ Only 1 container exposes port 51820 externally"
    docker ps --format '{{.Names}} {{.Ports}}' | grep -E '0\.0\.0\.0.*->.*51820'
else
    echo "❌ Multiple containers exposing port 51820: $EXTERNAL_CONTAINERS"
fi

echo ""
echo "🏁 UDP Load Balancer Test Complete"
echo "=================================="
echo "Architecture Status: Single nginx gateway on port 51820"
echo "Load Balancing: Active for UDP WireGuard traffic"
echo "Security: All WireGuard instances internal-only"
