#!/bin/bash
# WireGuard Management Script
# File: manage-wireguard.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "FAIL") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "HIGHLIGHT") echo -e "${CYAN}🔸 $message${NC}" ;;
        *) echo "$message" ;;
    esac
}

show_usage() {
    echo "WireGuard VPN Management Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  start         Start WireGuard VPN"
    echo "  stop          Stop WireGuard VPN"
    echo "  restart       Restart WireGuard VPN"
    echo "  status        Show VPN status"
    echo "  logs          Show recent logs"
    echo "  peers         List all peer configurations"
    echo "  show-config   Show peer config (usage: $0 show-config peer1)"
    echo "  show-qr       Display QR code path (usage: $0 show-qr peer1)"
    echo "  test          Run connection tests"
    echo "  firewall      Test firewall configuration"
    echo "  stats         Show resource usage"
    echo "  backup        Backup configurations"
    echo "  help          Show this help message"
    echo
}

start_vpn() {
    print_status "INFO" "Starting WireGuard VPN..."
    docker compose up -d
    print_status "SUCCESS" "WireGuard VPN started"
}

stop_vpn() {
    print_status "INFO" "Stopping WireGuard VPN..."
    docker compose down
    print_status "SUCCESS" "WireGuard VPN stopped"
}

restart_vpn() {
    print_status "INFO" "Restarting WireGuard VPN..."
    docker compose restart
    print_status "SUCCESS" "WireGuard VPN restarted"
}

show_status() {
    print_status "INFO" "WireGuard VPN Status:"
    echo
    
    # Container status
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "wg-vpn"; then
        print_status "SUCCESS" "Container is running"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "wg-vpn"
    else
        print_status "FAIL" "Container is not running"
        return 1
    fi
    
    echo
    
    # WireGuard interface status
    if docker exec wg-vpn wg show >/dev/null 2>&1; then
        print_status "SUCCESS" "WireGuard interface is active"
        wg_info=$(docker exec wg-vpn wg show 2>/dev/null)
        peer_count=$(echo "$wg_info" | grep -c "peer:" || echo "0")
        print_status "INFO" "Active peers: $peer_count"
    else
        print_status "FAIL" "WireGuard interface is not active"
    fi
    
    echo
    
    # Health check
    health=$(docker inspect wg-vpn --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$health" = "healthy" ]; then
        print_status "SUCCESS" "Health check: $health"
    else
        print_status "WARNING" "Health check: $health"
    fi
}

show_logs() {
    print_status "INFO" "Recent WireGuard logs:"
    docker compose logs --tail=20 -f wireguard
}

list_peers() {
    print_status "INFO" "Available peer configurations:"
    echo
    
    peer_count=0
    for peer_dir in wg-data/peer*/; do
        if [ -d "$peer_dir" ]; then
            peer_name=$(basename "$peer_dir")
            config_file="$peer_dir${peer_name}.conf"
            qr_file="$peer_dir${peer_name}.png"
            
            if [ -f "$config_file" ]; then
                print_status "SUCCESS" "📁 $peer_name"
                echo "   Config: $config_file"
                echo "   QR Code: $qr_file"
                echo "   Size: $(du -h "$config_file" | cut -f1)"
                peer_count=$((peer_count + 1))
            fi
        fi
    done
    
    echo
    print_status "INFO" "Total peers: $peer_count"
}

show_config() {
    local peer_name=$1
    
    if [ -z "$peer_name" ]; then
        print_status "FAIL" "Please specify peer name (e.g., peer1)"
        return 1
    fi
    
    config_file="wg-data/${peer_name}/${peer_name}.conf"
    
    if [ -f "$config_file" ]; then
        print_status "SUCCESS" "Configuration for $peer_name:"
        echo
        cat "$config_file"
    else
        print_status "FAIL" "Configuration file not found: $config_file"
        return 1
    fi
}

show_qr() {
    local peer_name=$1
    
    if [ -z "$peer_name" ]; then
        print_status "FAIL" "Please specify peer name (e.g., peer1)"
        return 1
    fi
    
    qr_file="wg-data/${peer_name}/${peer_name}.png"
    
    if [ -f "$qr_file" ]; then
        print_status "SUCCESS" "QR Code for $peer_name:"
        print_status "INFO" "File location: $qr_file"
        print_status "INFO" "You can download this file and scan it with WireGuard mobile app"
        
        # Show file size
        file_size=$(du -h "$qr_file" | cut -f1)
        print_status "INFO" "File size: $file_size"
    else
        print_status "FAIL" "QR code file not found: $qr_file"
        return 1
    fi
}

run_tests() {
    if [ -f "tests/test-connection.sh" ]; then
        print_status "INFO" "Running connection tests..."
        ./tests/test-connection.sh
    else
        print_status "FAIL" "Test script not found: tests/test-connection.sh"
        return 1
    fi
}

test_firewall() {
    if [ -f "tests/test-firewall.sh" ]; then
        print_status "INFO" "Running firewall tests..."
        ./tests/test-firewall.sh
    else
        print_status "FAIL" "Firewall test script not found: tests/test-firewall.sh"
        return 1
    fi
}

show_stats() {
    print_status "INFO" "WireGuard VPN Resource Usage:"
    echo
    
    if docker ps | grep -q "wg-vpn"; then
        docker stats wg-vpn --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
        
        echo
        print_status "INFO" "Detailed container information:"
        docker inspect wg-vpn --format='
Container: {{.Name}}
Image: {{.Config.Image}}
Created: {{.Created}}
Status: {{.State.Status}}
Uptime: {{.State.StartedAt}}'
    else
        print_status "FAIL" "Container is not running"
        return 1
    fi
}

backup_configs() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    
    print_status "INFO" "Creating backup..."
    mkdir -p "$backup_dir"
    
    # Backup configs
    if [ -d "wg-data" ]; then
        cp -r wg-data "$backup_dir/"
        print_status "SUCCESS" "WireGuard data backed up"
    fi
    
    # Backup docker-compose and env
    cp docker-compose.yml "$backup_dir/" 2>/dev/null || true
    cp .env "$backup_dir/" 2>/dev/null || true
    
    # Create backup info
    cat > "$backup_dir/backup-info.txt" << EOF
WireGuard VPN Backup
Created: $(date)
Server: $(hostname)
Docker Compose Version: $(docker compose version --short)
WireGuard Image: $(docker inspect wg-vpn --format='{{.Config.Image}}' 2>/dev/null || echo "N/A")

Files included:
- wg-data/ (complete WireGuard configuration)
- docker-compose.yml
- .env

To restore:
1. Stop current VPN: docker compose down
2. Replace wg-data directory with backed up version
3. Replace docker-compose.yml and .env if needed
4. Start VPN: docker compose up -d
EOF
    
    print_status "SUCCESS" "Backup created: $backup_dir"
    print_status "INFO" "Backup size: $(du -sh "$backup_dir" | cut -f1)"
}

# Main script logic
case "${1:-help}" in
    "start")
        start_vpn
        ;;
    "stop")
        stop_vpn
        ;;
    "restart")
        restart_vpn
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "peers")
        list_peers
        ;;
    "show-config")
        show_config "$2"
        ;;
    "show-qr")
        show_qr "$2"
        ;;
    "test")
        run_tests
        ;;
    "firewall")
        test_firewall
        ;;
    "stats")
        show_stats
        ;;
    "backup")
        backup_configs
        ;;
    "help"|*)
        show_usage
        ;;
esac
