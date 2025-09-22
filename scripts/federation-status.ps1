# NostrGator Federation Status - Real Working Status
# Shows actual federation metrics from Prometheus

Write-Host "=== NostrGator Federation Status ===" -ForegroundColor Cyan
Write-Host ""

# Check if federation service is running
$federationRunning = docker ps --filter "name=nostr-supernode-federation" --filter "status=running" --quiet
if ($federationRunning) {
    Write-Host "✅ Federation Engine: RUNNING" -ForegroundColor Green
} else {
    Write-Host "❌ Federation Engine: NOT RUNNING" -ForegroundColor Red
    exit 1
}

# Get Prometheus metrics
$metricsResponse = curl -s http://localhost:9090/metrics 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Prometheus Metrics: ACCESSIBLE" -ForegroundColor Green

    # Parse key metrics
    $peersLine = $metricsResponse | Select-String "nostrgator_peers_discovered_total"
    $heartbeatLine = $metricsResponse | Select-String "nostrgator_heartbeat_latency_seconds_count"
    $discoveryLine = $metricsResponse | Select-String "nostrgator_federation_events_total"

    Write-Host ""
    Write-Host "📊 Federation Metrics:" -ForegroundColor Yellow

    if ($peersLine) {
        $peers = ($peersLine -split " ")[-1]
        Write-Host "  • Peers Discovered: $peers" -ForegroundColor White
    }

    if ($heartbeatLine) {
        $heartbeats = ($heartbeatLine -split " ")[-1]
        Write-Host "  • Heartbeat Measurements: $heartbeats" -ForegroundColor White
    }

    if ($discoveryLine) {
        $discoveries = ($discoveryLine -split " ")[-1]
        Write-Host "  • Discovery Cycles: $discoveries" -ForegroundColor White
    }

    # Trust scores
    $trustLines = $metricsResponse | Select-String "nostrgator_peer_trust_score"
    if ($trustLines) {
        Write-Host ""
        Write-Host "🔒 Peer Trust Scores:" -ForegroundColor Yellow
        foreach ($line in $trustLines) {
            Write-Host "  • $line" -ForegroundColor White
        }
    }

} else {
    Write-Host "❌ Prometheus Metrics: NOT ACCESSIBLE" -ForegroundColor Red
}

# Test federation API
Write-Host ""
Write-Host "🌐 Federation API Status:" -ForegroundColor Yellow

$apiResponse = curl -s http://localhost:3002/health 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  • Port 3002: RESPONDING" -ForegroundColor Green
    if ($apiResponse -match "500") {
        Write-Host "  • Status: 500 ERROR (needs debugging)" -ForegroundColor Red
    } else {
        Write-Host "  • Status: OK" -ForegroundColor Green
    }
} else {
    Write-Host "  • Port 3002: NOT RESPONDING" -ForegroundColor Red
}

# Test 3D visualization
curl -s http://localhost:3003 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  • Port 3003 (3D Viz): RESPONDING" -ForegroundColor Green
} else {
    Write-Host "  • Port 3003 (3D Viz): NOT RESPONDING" -ForegroundColor Red
}

# Check recent logs for errors
Write-Host ""
Write-Host "📋 Recent Federation Logs:" -ForegroundColor Yellow

$recentLogs = docker logs nostr-supernode-federation --tail 5 2>$null
if ($LASTEXITCODE -eq 0) {
    $recentLogs | ForEach-Object {
        if ($_ -match "ERROR") {
            Write-Host "  🔴 $_" -ForegroundColor Red
        } elseif ($_ -match "INFO") {
            Write-Host "  🔵 $_" -ForegroundColor Cyan
        } else {
            Write-Host "  ⚪ $_" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  Error reading logs" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔧 Quick Actions:" -ForegroundColor Yellow
Write-Host "  • View full logs: docker logs nostr-supernode-federation" -ForegroundColor White
Write-Host "  • Restart federation: docker compose restart supernode-federation" -ForegroundColor White
Write-Host "  • View metrics: curl http://localhost:9090/metrics | findstr nostrgator" -ForegroundColor White
Write-Host "  • Monitor all services: .\scripts\monitor-simple.ps1" -ForegroundColor White
Write-Host ""
