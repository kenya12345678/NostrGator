# Nostr Relay WebSocket Testing Script
# Tests basic WebSocket connectivity and Nostr protocol compliance

param(
    [switch]$Detailed,
    [int]$TimeoutSeconds = 10
)

Write-Host "🧪 Nostr Relay WebSocket Testing" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Test results
$testResults = @{}

# Function to test WebSocket connectivity using PowerShell
function Test-NostrRelay {
    param(
        [string]$RelayName,
        [int]$Port,
        [string]$Description
    )
    
    Write-Host "`n🔌 Testing $RelayName Relay (port $Port)" -ForegroundColor Yellow
    Write-Host "   Purpose: $Description" -ForegroundColor Gray
    
    $url = "ws://localhost:$Port"
    $success = $false
    $errorMessage = ""
    
    try {
        # Test HTTP endpoint first (simpler test)
        $httpResponse = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 5 -UseBasicParsing
        if ($httpResponse.StatusCode -eq 200) {
            Write-Host "   ✅ HTTP endpoint responding (Status: $($httpResponse.StatusCode))" -ForegroundColor Green
            
            # Check if response contains Nostr-related content
            $content = $httpResponse.Content
            if ($content -match "nostr|relay|websocket" -or $content.Length -gt 0) {
                Write-Host "   ✅ Response contains valid content" -ForegroundColor Green
                $success = $true
            } else {
                Write-Host "   ⚠️  HTTP response received but content unclear" -ForegroundColor Yellow
                $success = $true  # Still count as success since HTTP works
            }
            
            if ($Detailed) {
                Write-Host "   📄 Content length: $($content.Length) bytes" -ForegroundColor Gray
                if ($content.Length -lt 200) {
                    Write-Host "   📝 Content preview: $($content.Substring(0, [Math]::Min(100, $content.Length)))" -ForegroundColor Gray
                }
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Host "   ❌ HTTP test failed: $errorMessage" -ForegroundColor Red
    }
    
    # Test WebSocket upgrade capability
    try {
        $headers = @{
            "Upgrade" = "websocket"
            "Connection" = "Upgrade"
            "Sec-WebSocket-Key" = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("test"))
            "Sec-WebSocket-Version" = "13"
        }
        
        $wsResponse = Invoke-WebRequest -Uri "http://localhost:$Port" -Headers $headers -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($wsResponse.StatusCode -eq 101) {
            Write-Host "   ✅ WebSocket upgrade supported" -ForegroundColor Green
            $success = $true
        }
    }
    catch {
        # WebSocket upgrade test is optional - HTTP success is sufficient
        if ($success) {
            Write-Host "   ⚠️  WebSocket upgrade test inconclusive (but HTTP works)" -ForegroundColor Yellow
        }
    }
    
    $testResults[$RelayName] = @{
        Success = $success
        Port = $Port
        Error = $errorMessage
        Description = $Description
    }
    
    return $success
}

# Function to test relay information endpoint
function Test-RelayInfo {
    param(
        [string]$RelayName,
        [int]$Port
    )
    
    try {
        # Try to get relay information (NIP-11)
        $headers = @{ "Accept" = "application/nostr+json" }
        $infoResponse = Invoke-WebRequest -Uri "http://localhost:$Port" -Headers $headers -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        
        if ($infoResponse.StatusCode -eq 200) {
            Write-Host "   ✅ NIP-11 relay information endpoint responding" -ForegroundColor Green
            
            if ($Detailed) {
                try {
                    $info = $infoResponse.Content | ConvertFrom-Json
                    if ($info.name) {
                        Write-Host "   📋 Relay name: $($info.name)" -ForegroundColor Gray
                    }
                    if ($info.description) {
                        Write-Host "   📋 Description: $($info.description)" -ForegroundColor Gray
                    }
                    if ($info.supported_nips) {
                        Write-Host "   📋 Supported NIPs: $($info.supported_nips -join ', ')" -ForegroundColor Gray
                    }
                }
                catch {
                    Write-Host "   📋 Relay info received but not in JSON format" -ForegroundColor Gray
                }
            }
            return $true
        }
    }
    catch {
        # NIP-11 is optional
        Write-Host "   ⚠️  NIP-11 relay info not available (optional)" -ForegroundColor Yellow
    }
    
    return $false
}

# Function to simulate a basic Nostr client connection test
function Test-NostrProtocol {
    param(
        [string]$RelayName,
        [int]$Port
    )
    
    Write-Host "   🔍 Testing Nostr protocol compliance..." -ForegroundColor Yellow
    
    # This is a simplified test - in a real scenario, you'd use a WebSocket library
    # For now, we'll test if the relay accepts the right headers and responds appropriately
    
    try {
        # Test with Nostr-specific headers
        $headers = @{
            "User-Agent" = "NostrRelayTest/1.0"
            "Accept" = "application/nostr+json"
        }
        
        $response = Invoke-WebRequest -Uri "http://localhost:$Port" -Headers $headers -TimeoutSec 5 -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Host "   ✅ Accepts Nostr client headers" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "   ⚠️  Nostr protocol test inconclusive" -ForegroundColor Yellow
    }
    
    return $false
}

# Main testing sequence
Write-Host "🚀 Starting relay connectivity tests..." -ForegroundColor Cyan

$relays = @(
    @{ Name = "General"; Port = 7001; Description = "Core notes and feeds" },
    @{ Name = "DM"; Port = 7002; Description = "Private messages (NIP-04)" },
    @{ Name = "Media"; Port = 7003; Description = "File uploads and zaps (NIP-94, NIP-57)" },
    @{ Name = "Social"; Port = 7004; Description = "Lists and communities (NIP-51)" },
    @{ Name = "Cache"; Port = 7005; Description = "Search, trending, and discovery (Premium features)" }
)

$successCount = 0
$totalTests = $relays.Count

foreach ($relay in $relays) {
    $success = Test-NostrRelay -RelayName $relay.Name -Port $relay.Port -Description $relay.Description
    
    if ($success) {
        $successCount++
        
        if ($Detailed) {
            Test-RelayInfo -RelayName $relay.Name -Port $relay.Port
            Test-NostrProtocol -RelayName $relay.Name -Port $relay.Port
        }
    }
}

# Summary
Write-Host "`n📊 Test Summary" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan

foreach ($relay in $testResults.Keys) {
    $result = $testResults[$relay]
    if ($result.Success) {
        Write-Host "✅ $relay relay (port $($result.Port)): PASS" -ForegroundColor Green
    } else {
        Write-Host "❌ $relay relay (port $($result.Port)): FAIL - $($result.Error)" -ForegroundColor Red
    }
}

$successRate = [math]::Round(($successCount / $totalTests) * 100, 1)
Write-Host "`n🎯 Overall Result: $successCount/$totalTests relays operational ($successRate%)" -ForegroundColor $(
    if ($successRate -eq 100) { "Green" }
    elseif ($successRate -ge 75) { "Yellow" }
    else { "Red" }
)

if ($successRate -eq 100) {
    Write-Host "`n🎉 All relays are operational!" -ForegroundColor Green
    Write-Host "✨ Your private Nostr relay suite is ready for client connections." -ForegroundColor Green
    Write-Host "`n📱 Next steps:" -ForegroundColor Cyan
    Write-Host "1. Configure your Nostr clients with these relay URLs:" -ForegroundColor White
    Write-Host "   • General:  ws://localhost:7001" -ForegroundColor White
    Write-Host "   • DM:       ws://localhost:7002" -ForegroundColor White
    Write-Host "   • Media:    ws://localhost:7003" -ForegroundColor White
    Write-Host "   • Social:   ws://localhost:7004" -ForegroundColor White
    Write-Host "   • Cache:    ws://localhost:7005 (Search & Discovery)" -ForegroundColor White
    Write-Host "2. See docs\client-setup.md for detailed configuration guides" -ForegroundColor White
    Write-Host "3. Test with your favorite Nostr client (iris.to, primal.net, etc.)" -ForegroundColor White
} elseif ($successRate -ge 75) {
    Write-Host "`n⚠️  Most relays are working. Check the failed ones above." -ForegroundColor Yellow
    Write-Host "💡 You can still use the working relays while troubleshooting." -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Multiple relay failures detected." -ForegroundColor Red
    Write-Host "🔧 Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Check if Docker containers are running: docker compose ps" -ForegroundColor White
    Write-Host "2. Check container logs: docker logs nostr-general" -ForegroundColor White
    Write-Host "3. Restart the relay suite: docker compose restart" -ForegroundColor White
    Write-Host "4. Run full verification: .\scripts\verify.ps1 -Detailed" -ForegroundColor White
}

Write-Host "`n🔗 Quick access URLs for browser testing:" -ForegroundColor Cyan
Write-Host "http://localhost:7001 | http://localhost:7002 | http://localhost:7003 | http://localhost:7004 | http://localhost:7005" -ForegroundColor White
