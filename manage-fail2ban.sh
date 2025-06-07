#!/bin/bash
# Fail2ban Management and Monitoring Script
# Tối ưu theo nguyên tắc Elon Musk

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "FAIL") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

show_fail2ban_status() {
    print_status "INFO" "Fail2ban Status:"
    echo
    
    if docker ps | grep -q "f2b-security"; then
        print_status "SUCCESS" "Fail2ban container is running"
        
        # Show jail status
        echo
        print_status "INFO" "Active jails:"
        docker exec f2b-security fail2ban-client status 2>/dev/null || print_status "WARNING" "Cannot get jail status"
        
        # Show banned IPs
        echo
        print_status "INFO" "Currently banned IPs:"
        docker exec f2b-security fail2ban-client status wireguard 2>/dev/null || print_status "INFO" "No IPs banned in wireguard jail"
        
    else
        print_status "FAIL" "Fail2ban container is not running"
        return 1
    fi
}

show_banned_ips() {
    print_status "INFO" "All banned IPs across jails:"
    echo
    
    local jails=("wireguard" "wireguard-aggressive" "ssh-iptables" "recidive")
    
    for jail in "${jails[@]}"; do
        echo "=== $jail ==="
        docker exec f2b-security fail2ban-client status "$jail" 2>/dev/null | grep "Banned IP list:" || echo "No banned IPs"
        echo
    done
}

unban_ip() {
    local ip=$1
    
    if [ -z "$ip" ]; then
        print_status "FAIL" "Please specify IP address to unban"
        return 1
    fi
    
    print_status "INFO" "Unbanning IP: $ip"
    
    local jails=("wireguard" "wireguard-aggressive" "ssh-iptables" "recidive")
    
    for jail in "${jails[@]}"; do
        docker exec f2b-security fail2ban-client set "$jail" unbanip "$ip" 2>/dev/null && \
            print_status "SUCCESS" "Unbanned $ip from $jail" || \
            print_status "INFO" "$ip was not banned in $jail"
    done
}

ban_ip() {
    local ip=$1
    local jail=${2:-wireguard}
    
    if [ -z "$ip" ]; then
        print_status "FAIL" "Please specify IP address to ban"
        return 1
    fi
    
    print_status "INFO" "Manually banning IP: $ip in jail: $jail"
    docker exec f2b-security fail2ban-client set "$jail" banip "$ip" && \
        print_status "SUCCESS" "Successfully banned $ip" || \
        print_status "FAIL" "Failed to ban $ip"
}

show_logs() {
    print_status "INFO" "Recent Fail2ban logs:"
    docker exec f2b-security tail -f /data/fail2ban.log
}

show_stats() {
    print_status "INFO" "Fail2ban Statistics:"
    echo
    
    # Container stats
    if docker ps | grep -q "f2b-security"; then
        docker stats f2b-security --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        
        echo
        # Database size
        db_size=$(docker exec f2b-security du -h /data/fail2ban.sqlite3 2>/dev/null | cut -f1 || echo "N/A")
        print_status "INFO" "Database size: $db_size"
        
        # Log size
        log_size=$(docker exec f2b-security du -h /data/fail2ban.log 2>/dev/null | cut -f1 || echo "N/A")
        print_status "INFO" "Log size: $log_size"
        
    else
        print_status "FAIL" "Fail2ban container is not running"
    fi
}

test_attack_simulation() {
    print_status "WARNING" "Running attack simulation (for testing only)"
    print_status "INFO" "This will trigger Fail2ban detection"
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi
    
    # Simulate bad connections
    for i in {1..10}; do
        # This would normally trigger fail2ban patterns
        echo "$(date): Bad packet from 192.168.1.100: Invalid handshake initiation" >> ./logs/test-attack.log
        sleep 1
    done
    
    print_status "SUCCESS" "Attack simulation completed. Check logs for Fail2ban response."
}

show_usage() {
    echo "Fail2ban Management Script"
    echo
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  status        Show Fail2ban status and jails"
    echo "  banned        Show all banned IPs"
    echo "  unban <ip>    Unban specific IP from all jails"
    echo "  ban <ip> [jail]    Manually ban IP (default jail: wireguard)"
    echo "  logs          Show recent Fail2ban logs"
    echo "  stats         Show resource usage statistics"
    echo "  test          Run attack simulation (testing only)"
    echo "  help          Show this help message"
    echo
}

# Main script logic
case "${1:-help}" in
    "status")
        show_fail2ban_status
        ;;
    "banned")
        show_banned_ips
        ;;
    "unban")
        unban_ip "$2"
        ;;
    "ban")
        ban_ip "$2" "$3"
        ;;
    "logs")
        show_logs
        ;;
    "stats")
        show_stats
        ;;
    "test")
        test_attack_simulation
        ;;
    "help"|*)
        show_usage
        ;;
esac
