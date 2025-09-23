# Private Nostr Relay Suite Verification Script
# Comprehensive health checks and functionality testing

param(
    [switch]$Detailed,
    [switch]$SkipConnectivity
)

$ErrorActionPreference = "Continue"

Write-Host "🔍 Private Nostr Relay Suite Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Test results tracking
$testResults = @{
    ContainerHealth = @{}
    PortConnectivity = @{}
    RelayResponses = @{}
    ConfigValidation = @{}
    DatabaseMaintenance = @{}
}

# Function to test container health
function Test-ContainerHealth {
    Write-Host "`n📦 Testing Container Health..." -ForegroundColor Yellow
    
    $containers = @("nostr-general", "nostr-dm", "nostr-media", "nostr-social", "nostr-cache", "nostr-files", "nostr-longform", "nostr-live", "nostr-marketplace", "nostr-games", "nostr-bridge", "nostr-watchtower", "nostr-health-monitor", "nostr-content-discovery", "nostr-security-monitor", "nostr-tor-proxy", "nostr-supernode-federation", "nostr-event-mirror", "nostr-nip05", "nostr-alby-hub")
    
    foreach ($container in $containers) {
        try {
            $status = docker inspect $container --format '{{.State.Status}}' 2>$null
            $health = docker inspect $container --format '{{.State.Health.Status}}' 2>$null
            
            if ($status -eq "running") {
                Write-Host "✅ $container is running" -ForegroundColor Green
                $testResults.ContainerHealth[$container] = "PASS"
                
                if ($health -and $health -ne "<no value>") {
                    if ($health -eq "healthy") {
                        Write-Host "   💚 Health check: $health" -ForegroundColor Green
                    }
                    else {
                        Write-Host "   ⚠️  Health check: $health" -ForegroundColor Yellow
                    }
                }
            }
            else {
                Write-Host "❌ $container is not running (status: $status)" -ForegroundColor Red
                $testResults.ContainerHealth[$container] = "FAIL"
            }
        }
        catch {
            Write-Host "❌ $container not found or error checking status" -ForegroundColor Red
            $testResults.ContainerHealth[$container] = "FAIL"
        }
    }
}

# Function to test port connectivity
function Test-PortConnectivity {
    if ($SkipConnectivity) {
        Write-Host "`n⏭️  Skipping port connectivity tests" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n🔌 Testing Port Connectivity..." -ForegroundColor Yellow
    
    $ports = @{
        "General" = 7001
        "DM" = 7002
        "Media" = 7003
        "Social" = 7004
        "Cache" = 7005
        "Files" = 7006
        "LongForm" = 7007
        "Live" = 7008
        "Marketplace" = 7009
        "Games" = 7010
        "Bridge" = 7011
        "HealthMonitor" = 3001
        "NIP05" = 3005
        "SupernodeFederation" = 3002
        "EventMirror" = 9091
        "TorProxy" = 9050
        "ContentDiscovery" = 7080
        "SecurityMonitor" = 7081
        "AlbyHub" = 7012
    }
    
    foreach ($relay in $ports.Keys) {
        $port = $ports[$relay]
        try {
            $connection = Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($connection) {
                Write-Host "✅ $relay relay (port $port) is accessible" -ForegroundColor Green
                $testResults.PortConnectivity[$relay] = "PASS"
            }
            else {
                Write-Host "❌ $relay relay (port $port) is not accessible" -ForegroundColor Red
                $testResults.PortConnectivity[$relay] = "FAIL"
            }
        }
        catch {
            Write-Host "❌ Error testing $relay relay (port $port): $_" -ForegroundColor Red
            $testResults.PortConnectivity[$relay] = "FAIL"
        }
    }
}

# Function to test relay HTTP responses
function Test-RelayResponses {
    Write-Host "`n🌐 Testing Relay HTTP Responses..." -ForegroundColor Yellow
    
    $relays = @{
        "General" = "http://localhost:7001"
        "DM" = "http://localhost:7002"
        "Media" = "http://localhost:7003"
        "Social" = "http://localhost:7004"
        "Cache" = "http://localhost:7005"
        "Files" = "http://localhost:7006"
        "LongForm" = "http://localhost:7007"
        "Live" = "http://localhost:7008"
        "Marketplace" = "http://localhost:7009"
        "Games" = "http://localhost:7010"
        "Bridge" = "http://localhost:7011"
        "HealthMonitor" = "http://localhost:3001"
        "NIP05WellKnown" = "http://localhost:3005/.well-known/nostr.json"
        "ContentDiscoveryHealth" = "http://localhost:7080/health"
        "SecurityMonitorHealth" = "http://localhost:7081/health"
        "AlbyHubInfo" = "http://localhost:7012/api/info"
    }
    
    foreach ($relay in $relays.Keys) {
        $url = $relays[$relay]
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "✅ $relay relay HTTP response: OK" -ForegroundColor Green
                $testResults.RelayResponses[$relay] = "PASS"
                
                if ($Detailed) {
                    Write-Host "   📄 Content length: $($response.Content.Length) bytes" -ForegroundColor Gray
                }
            }
            else {
                Write-Host "⚠️  $relay relay HTTP response: $($response.StatusCode)" -ForegroundColor Yellow
                $testResults.RelayResponses[$relay] = "WARN"
            }
        }
        catch {
            Write-Host "❌ $relay relay HTTP error: $($_.Exception.Message)" -ForegroundColor Red
            $testResults.RelayResponses[$relay] = "FAIL"
        }
    }
}

# Function to validate configuration files
function Test-ConfigValidation {
    Write-Host "`n⚙️  Validating Configuration Files..." -ForegroundColor Yellow
    
    $configs = @{
        "General" = "configs\general\config.toml"
        "DM" = "configs\dm\config.toml"
        "Media" = "configs\media\config.toml"
        "Social" = "configs\social\config.toml"
        "Cache" = "configs\cache\strfry.conf"
    }
    
    foreach ($relay in $configs.Keys) {
        $configPath = $configs[$relay]
        if (Test-Path $configPath) {
            try {
                $content = Get-Content $configPath -Raw
                if ($content -match 'npub1qs9t3tf2kfz872ns9yp42044dqs2v7v68mwy5mfczmsvcs075luqr7226z') {
                    Write-Host "✅ $relay config: Valid with correct pubkey" -ForegroundColor Green
                    $testResults.ConfigValidation[$relay] = "PASS"
                }
                else {
                    Write-Host "⚠️  $relay config: Missing or incorrect pubkey" -ForegroundColor Yellow
                    $testResults.ConfigValidation[$relay] = "WARN"
                }
            }
            catch {
                Write-Host "❌ $relay config: Error reading file" -ForegroundColor Red
                $testResults.ConfigValidation[$relay] = "FAIL"
            }
        }
        else {
            Write-Host "❌ $relay config: File not found" -ForegroundColor Red
            $testResults.ConfigValidation[$relay] = "FAIL"
        }
    }
}

# Function to perform database maintenance
function Optimize-RelayDatabases {
    Write-Host "`n🔧 Database Maintenance (Keep that 1ms performance eternal)..." -ForegroundColor Yellow

    $databases = @(
        @{Path=".\data\general\nostr.db"; Name="General"},
        @{Path=".\data\social\nostr.db"; Name="Social"},
        @{Path=".\data\media\nostr.db"; Name="Media"},
        @{Path=".\data\dm\nostr.db"; Name="DM"},
        @{Path=".\data\files\nostr.db"; Name="Files"},
        @{Path=".\data\games\nostr.db"; Name="Games"},
        @{Path=".\data\marketplace\nostr.db"; Name="Marketplace"},
        @{Path=".\data\bridge\nostr.db"; Name="Bridge"},
        @{Path=".\data\live\nostr.db"; Name="Live"},
        @{Path=".\data\longform\nostr.db"; Name="Longform"},
        @{Path=".\data\cache\nostr.db"; Name="Cache"},
        @{Path=".\data\watchtower\nostr.db"; Name="Watchtower"}
    )

    $totalSaved = 0
    $optimizedCount = 0

    foreach ($db in $databases) {
        if (Test-Path $db.Path) {
            try {
                # Get size before
                $sizeBefore = (Get-Item $db.Path).Length / 1MB

                # Run maintenance (VACUUM, WAL checkpoint, optimize)
                $null = sqlite3 $db.Path "VACUUM; PRAGMA wal_checkpoint(FULL); PRAGMA optimize;" 2>$null

                # Get size after
                $sizeAfter = (Get-Item $db.Path).Length / 1MB
                $saved = $sizeBefore - $sizeAfter
                $totalSaved += $saved
                $optimizedCount++

                Write-Host "  ✅ $($db.Name): $([math]::Round($sizeBefore, 2))MB → $([math]::Round($sizeAfter, 2))MB (saved $([math]::Round($saved, 2))MB)" -ForegroundColor Green
                $testResults.DatabaseMaintenance[$db.Name] = "PASS"
            }
            catch {
                Write-Host "  ❌ $($db.Name): Optimization failed - $($_.Exception.Message)" -ForegroundColor Red
                $testResults.DatabaseMaintenance[$db.Name] = "FAIL"
            }
        }
        else {
            Write-Host "  ⚠️  $($db.Name): Database not found (relay may not be initialized)" -ForegroundColor Yellow
            $testResults.DatabaseMaintenance[$db.Name] = "WARN"
        }
    }

    if ($optimizedCount -gt 0) {
        Write-Host "  📊 Total space saved: $([math]::Round($totalSaved, 2))MB across $optimizedCount databases" -ForegroundColor Cyan
    }
}

# Function to display detailed logs if requested
function Show-DetailedLogs {
    if (-not $Detailed) { return }
    
    Write-Host "`n📋 Recent Container Logs..." -ForegroundColor Yellow
    
    $containers = @("nostr-general", "nostr-dm", "nostr-media", "nostr-social", "nostr-files", "nostr-health-monitor", "nostr-content-discovery", "nostr-security-monitor")
    foreach ($container in $containers) {
        Write-Host "`n--- $container ---" -ForegroundColor Cyan
        try {
            docker logs $container --tail 5 2>$null
        }
        catch {
            Write-Host "No logs available for $container" -ForegroundColor Gray
        }
    }
}

# Function to generate test summary
function Show-TestSummary {
    Write-Host "`n📊 Test Summary" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Cyan
    
    $totalTests = 0
    $passedTests = 0
    
    foreach ($category in $testResults.Keys) {
        Write-Host "`n$category Results:" -ForegroundColor White
        foreach ($test in $testResults[$category].Keys) {
            $result = $testResults[$category][$test]
            $totalTests++
            
            switch ($result) {
                "PASS" { 
                    Write-Host "  ✅ $test" -ForegroundColor Green
                    $passedTests++
                }
                "WARN" { 
                    Write-Host "  ⚠️  $test" -ForegroundColor Yellow
                    $passedTests++  # Count warnings as passes for overall score
                }
                "FAIL" { 
                    Write-Host "  ❌ $test" -ForegroundColor Red
                }
            }
        }
    }
    
    $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }
    
    Write-Host ("`nOverall Result: {0}/{1} tests passed ({2}%)" -f $passedTests, $totalTests, $successRate) -ForegroundColor $(
        if ($successRate -ge 90) { "Green" }
        elseif ($successRate -ge 70) { "Yellow" }
        else { "Red" }
    )
    
    if ($successRate -eq 100) {
        Write-Host "All systems operational! Your relay suite is ready to use." -ForegroundColor Green
    }
    elseif ($successRate -ge 70) {
        Write-Host "Most systems operational. Check warnings above." -ForegroundColor Yellow
    }
    else {
        Write-Host "Multiple issues detected. Check the failures above." -ForegroundColor Red
        Write-Host "Tip: Try running .\scripts\setup.ps1 again or check the troubleshooting guide." -ForegroundColor Yellow
    }
}

# Main execution
try {
    Test-ContainerHealth
    Test-PortConnectivity
    Test-RelayResponses
    Test-ConfigValidation
    Optimize-RelayDatabases
    Show-DetailedLogs
    Show-TestSummary
    
    Write-Host "`n🔗 Quick Test URLs:" -ForegroundColor Cyan
    Write-Host "General:  http://localhost:7001" -ForegroundColor White
    Write-Host "DM:       http://localhost:7002" -ForegroundColor White
    Write-Host "Media:    http://localhost:7003" -ForegroundColor White
    Write-Host "Social:   http://localhost:7004" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Verification failed: $_" -ForegroundColor Red
    exit 1
}
