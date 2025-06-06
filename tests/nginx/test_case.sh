#!/bin/bash

# Test Nginx theo nguyên tắc Elon Musk: Đơn giản - Nhanh - Hiệu quả

set -e

echo "🚀 NGINX TEST - Following Musk Principles"
echo "========================================"

# Step 1: Start only nginx (loại bỏ không cần thiết)
echo "📦 Starting nginx service only..."
docker compose up -d nginx

# Step 2: Wait for container (đơn giản triệt để)
echo "⏳ Waiting for nginx to be ready..."
sleep 5

# Step 3: Test health endpoint (test cốt lõi)
echo "🏥 Testing health endpoint..."
if curl -f http://localhost/health &>/dev/null; then
    echo "✅ Health check: PASS"
else
    echo "❌ Health check: FAIL"
    exit 1
fi

# Step 4: Test HTTP basic response (thay vì redirect do tạm thời vô hiệu hóa HTTPS)
echo "📄 Testing HTTP basic response..."
HTTP_RESPONSE=$(curl -s http://localhost/)
if [[ "$HTTP_RESPONSE" == *"nginx-http-ok"* ]]; then
    echo "✅ HTTP response: PASS"
else
    echo "❌ HTTP response: FAIL (got: $HTTP_RESPONSE)"
    exit 1
fi

# Step 5: Test nginx config syntax (tránh runtime error)
echo "📝 Testing nginx config syntax..."
if docker exec vpn-proxy nginx -t &>/dev/null; then
    echo "✅ Config syntax: PASS"
else
    echo "❌ Config syntax: FAIL"
    exit 1
fi

# Step 6: Test container health status (Docker level)
echo "🐳 Testing container health..."
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' vpn-proxy 2>/dev/null || echo "none")
if [ "$HEALTH_STATUS" = "healthy" ] || [ "$HEALTH_STATUS" = "none" ]; then
    echo "✅ Container health: PASS"
else
    echo "❌ Container health: FAIL ($HEALTH_STATUS)"
    exit 1
fi

echo ""
echo "🎉 ALL NGINX TESTS PASSED!"
echo "💡 Musk Principle Applied: Simple, Fast, Effective"
echo ""
echo "Next steps (tối ưu sau khi có dữ liệu):"
echo "- Enable SSL certificate when ready for production"
echo "- Add HTTP to HTTPS redirect when SSL is configured"
echo "- Add load testing when traffic data available"
echo "- Add security headers validation when needed"
