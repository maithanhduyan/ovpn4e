# PowerShell Test Script cho VPN docker-compose
# File: test-vpn.ps1

Write-Host "=== VPN Docker-Compose Test Script ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

try {
    # 1. Kiểm tra Docker
    Write-Host "1. Checking Docker..." -ForegroundColor Yellow
    $dockerVersion = docker version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker daemon not running. Please start Docker Desktop." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Docker is running" -ForegroundColor Green

    # 2. Validate docker-compose syntax
    Write-Host "2. Validating docker-compose.yml..." -ForegroundColor Yellow
    docker-compose config > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ docker-compose.yml has syntax errors" -ForegroundColor Red
        docker-compose config
        exit 1
    }
    Write-Host "✅ docker-compose.yml syntax OK" -ForegroundColor Green

    # 3. Create required directories
    Write-Host "3. Creating required directories..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path "wg-data" | Out-Null
    New-Item -ItemType Directory -Force -Path "logs" | Out-Null
    Write-Host "✅ Directories created" -ForegroundColor Green

    # 4. Pull images
    Write-Host "4. Pulling Wireguard image..." -ForegroundColor Yellow
    docker-compose pull wireguard
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to pull images" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Images pulled successfully" -ForegroundColor Green

    # 5. Start services
    Write-Host "5. Starting VPN services..." -ForegroundColor Yellow
    docker-compose up -d wireguard
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to start services" -ForegroundColor Red
        docker-compose logs wireguard
        exit 1
    }
    Write-Host "✅ Services started" -ForegroundColor Green

    # 6. Wait for container to be ready
    Write-Host "6. Waiting for Wireguard to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15

    # 7. Check container health
    Write-Host "7. Checking container health..." -ForegroundColor Yellow
    $containerStatus = docker-compose ps wireguard
    if ($containerStatus -match "Up") {
        Write-Host "✅ Wireguard container is running" -ForegroundColor Green
    } else {
        Write-Host "❌ Wireguard container failed to start" -ForegroundColor Red
        docker-compose logs wireguard
        exit 1
    }

    # 8. Test Wireguard interface
    Write-Host "8. Testing Wireguard interface..." -ForegroundColor Yellow
    $wgShow = docker exec wg-vpn wg show 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Wireguard interface is active" -ForegroundColor Green
        Write-Host $wgShow -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  Wireguard interface not ready yet (this is normal on first run)" -ForegroundColor Yellow
    }

    # 9. Check logs
    Write-Host "9. Recent logs:" -ForegroundColor Yellow
    docker-compose logs --tail=10 wireguard

    # 10. Show connection info
    Write-Host "10. Connection Information:" -ForegroundColor Yellow
    $serverUrl = if ($env:SERVERURL) { $env:SERVERURL } else { "vpn.yourdomain.com" }
    $serverPort = if ($env:SERVERPORT) { $env:SERVERPORT } else { "51820" }
    $peers = if ($env:PEERS) { $env:PEERS } else { "10" }
    
    Write-Host "Server URL: $serverUrl" -ForegroundColor Cyan
    Write-Host "Port: $serverPort" -ForegroundColor Cyan
    Write-Host "Peers configured: $peers" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "=== Test completed successfully! ===" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Update SERVERURL in .env file with your actual domain/IP"
    Write-Host "2. Configure your firewall to allow UDP port 51820"
    Write-Host "3. Client configs will be in .\wg-data\peer1\, peer2\, etc."

} catch {
    Write-Host "❌ Test failed with error: $_" -ForegroundColor Red
    exit 1
}
