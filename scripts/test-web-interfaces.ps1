# Test NostrGator Web Interfaces
# Automated testing of web services

Write-Host "=== NostrGator Web Interface Test ===" -ForegroundColor Cyan
Write-Host ""

$services = @(
    @{ Name = "LNbits Wallet"; URL = "http://localhost:5000"; Description = "Lightning wallet web interface" },
    @{ Name = "Blossom File Server"; URL = "http://localhost:3000"; Description = "NIP-96 file storage server" },
    @{ Name = "Content Discovery"; URL = "http://localhost:7080"; Description = "Nostr content discovery service" },
    @{ Name = "Security Monitor"; URL = "http://localhost:7081"; Description = "Security monitoring dashboard" }
)

foreach ($service in $services) {
    Write-Host "Testing $($service.Name)..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Uri $service.URL -Method GET -TimeoutSec 5 -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Host "  [OK] $($service.Name) is responding" -ForegroundColor Green
            Write-Host "  URL: $($service.URL)" -ForegroundColor White
            Write-Host "  Description: $($service.Description)" -ForegroundColor Gray
            
            # Check for specific content
            if ($service.Name -eq "LNbits Wallet" -and $response.Content -match "LNbits") {
                Write-Host "  [OK] LNbits interface detected" -ForegroundColor Green
            }
        } else {
            Write-Host "  [WARN] $($service.Name) returned status: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [FAIL] $($service.Name) is not accessible: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "Web Interface Test Complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "To open interfaces in browser:" -ForegroundColor Yellow
Write-Host "  Start-Process 'http://localhost:5000'  # LNbits Wallet" -ForegroundColor White
Write-Host "  Start-Process 'http://localhost:3000'  # Blossom File Server" -ForegroundColor White
