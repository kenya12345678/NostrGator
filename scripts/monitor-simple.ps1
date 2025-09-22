# NostrGator Simple Monitor Script
# Quick status check for all services

Write-Host "=== NostrGator Status Monitor ===" -ForegroundColor Cyan
Write-Host ""

# Check Docker services
Write-Host "Docker Services:" -ForegroundColor Yellow
$services = @(
    "nostr-general",
    "nostr-social",
    "nostr-media",
    "nostr-dm",
    "nostr-files",
    "nostr-games",
    "nostr-marketplace",
    "nostr-bridge",
    "nostr-live",
    "nostr-longform",
    "nostr-cache",
    "nostr-watchtower",
    "nostr-content-discovery",
    "nostr-security-monitor",
    "nostr-health-monitor",
    "nostr-tor-proxy",
    "nostr-supernode-federation",
    "nostr-event-mirror",
    "nostr-nip05"
)

foreach ($service in $services) {
    try {
        $status = docker inspect $service --format '{{.State.Status}}' 2>$null
        if ($status -eq "running") {
            Write-Host "  [OK] $service" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $service ($status)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [FAIL] $service (not found)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Yellow
Write-Host "  - General Relay: ws://localhost:7777" -ForegroundColor White
Write-Host "  - Social Relay: ws://localhost:7778" -ForegroundColor White
Write-Host "  - Media Relay: ws://localhost:7779" -ForegroundColor White
Write-Host "  - DM Relay: ws://localhost:7780" -ForegroundColor White
Write-Host "  - Files Relay: ws://localhost:7781" -ForegroundColor White
Write-Host "  - Games Relay: ws://localhost:7782" -ForegroundColor White
Write-Host "  - Marketplace Relay: ws://localhost:7783" -ForegroundColor White
Write-Host "  - Bridge Relay: ws://localhost:7784" -ForegroundColor White
Write-Host "  - Live Relay: ws://localhost:7785" -ForegroundColor White
Write-Host "  - Longform Relay: ws://localhost:7786" -ForegroundColor White
Write-Host "  - Cache Relay: ws://localhost:7787" -ForegroundColor White
Write-Host "  - Watchtower Relay: ws://localhost:7788" -ForegroundColor White
Write-Host "  - Content Discovery: http://localhost:7080" -ForegroundColor White
Write-Host "  - Security Monitor: http://localhost:7081" -ForegroundColor White
Write-Host "  - Health Monitor: http://localhost:3001" -ForegroundColor White
Write-Host "  - Tor Proxy (SOCKS5): localhost:9050" -ForegroundColor White
Write-Host "  - Supernode Federation: http://localhost:3002" -ForegroundColor Cyan
Write-Host "  - 3D Trust Web Visualization: http://localhost:3003" -ForegroundColor Magenta
Write-Host "  - Federation Metrics: http://localhost:9090/metrics" -ForegroundColor Cyan
Write-Host "  - Event Mirror Metrics: http://localhost:9091/metrics" -ForegroundColor Cyan
Write-Host "  - NIP-05 Service: http://localhost:3005" -ForegroundColor Yellow
Write-Host "  - Prometheus Web UI: http://localhost:9090" -ForegroundColor Green

Write-Host ""
Write-Host "Quick Commands:" -ForegroundColor Yellow
Write-Host "  - View logs: docker logs [service-name]" -ForegroundColor White
Write-Host "  - Restart service: docker restart [service-name]" -ForegroundColor White
Write-Host "  - Database maintenance: .\scripts\db-maintenance-simple.ps1" -ForegroundColor White
Write-Host "  - Full verification: .\scripts\verify.ps1" -ForegroundColor White
