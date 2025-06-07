#!/bin/bash
# Quick Setup Fail2ban Security Layer
# Theo nguyên tắc Elon Musk: Đơn giản - Hiệu quả - Nhanh chóng

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Tạo các thư mục cần thiết
print_step "Creating directory structure..."
mkdir -p f2b-data/{jail.d,filter.d,action.d}
mkdir -p logs

print_success "Directory structure created"

# Tạo .env file nếu chưa có
if [ ! -f .env ]; then
    print_step "Creating .env file..."
    cat > .env << EOF
# Environment variables for VPN Security
PUID=1000
PGID=1000
TZ=Asia/Ho_Chi_Minh
SERVERURL=vpn.yourdomain.com
SERVERPORT=51820
PEERS=10
PEERDNS=1.1.1.1,8.8.8.8
INTERNAL_SUBNET=10.8.0.0/24
ALLOWEDIPS=0.0.0.0/0
EOF
    print_success ".env file created"
fi

# Khởi tạo hệ thống
print_step "Starting VPN with Fail2ban protection..."
docker compose up -d

print_success "System started successfully!"

echo
print_info "System is now running with multi-layer security:"
echo "  🛡️  Fail2ban container protection"
echo "  🚧 IPTables rate limiting"
echo "  📊 Health monitoring"
echo "  📝 Comprehensive logging"

echo
print_info "Management commands:"
echo "  ./manage-wireguard.sh status    - Check VPN status"
echo "  ./manage-fail2ban.sh status     - Check security status"
echo "  ./manage-fail2ban.sh banned     - View banned IPs"

echo
print_info "Monitoring logs:"
echo "  docker compose logs -f wireguard"
echo "  docker compose logs -f fail2ban"

print_success "Setup completed! Your enterprise VPN is now secured."
