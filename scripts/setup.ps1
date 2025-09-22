# Private Nostr Relay Suite Setup Script
# Automated deployment for Windows with PowerShell

param(
    [switch]$Force,
    [switch]$SkipPull,
    [switch]$Verbose
)

# Set error handling
$ErrorActionPreference = "Stop"

Write-Host "🚀 Private Nostr Relay Suite Setup" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow
    
    # Check Docker
    try {
        $dockerVersion = docker --version
        Write-Host "✅ Docker found: $dockerVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Docker not found or not running" -ForegroundColor Red
        Write-Host "Please install Docker Desktop and ensure it's running" -ForegroundColor Red
        exit 1
    }
    
    # Check Docker Compose
    try {
        $composeVersion = docker compose version
        Write-Host "✅ Docker Compose found: $composeVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Docker Compose not found" -ForegroundColor Red
        exit 1
    }
    
    # Check port availability
    $ports = @(7001, 7002, 7003, 7004, 7005, 7006, 7007, 7008, 7009, 7010, 7011, 3001)
    foreach ($port in $ports) {
        $connection = Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($connection) {
            if (-not $Force) {
                Write-Host "❌ Port $port is already in use" -ForegroundColor Red
                Write-Host "Use -Force to continue anyway or stop the service using port $port" -ForegroundColor Yellow
                exit 1
            }
            else {
                Write-Host "⚠️  Port $port is in use but continuing due to -Force flag" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "✅ Port $port is available" -ForegroundColor Green
        }
    }
}

# Function to pull Docker images
function Get-DockerImages {
    if ($SkipPull) {
        Write-Host "⏭️  Skipping image pull due to -SkipPull flag" -ForegroundColor Yellow
        return
    }
    
    Write-Host "📥 Pulling Docker images..." -ForegroundColor Yellow
    try {
        docker compose pull
        Write-Host "✅ Images pulled successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to pull images: $_" -ForegroundColor Red
        Write-Host "Check your internet connection and try again" -ForegroundColor Yellow
        exit 1
    }
}

# Function to start services
function Start-RelayServices {
    Write-Host "🔄 Starting relay services..." -ForegroundColor Yellow
    
    try {
        if ($Verbose) {
            docker compose up -d --remove-orphans
        }
        else {
            docker compose up -d --remove-orphans 2>$null
        }
        Write-Host "✅ Services started successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to start services: $_" -ForegroundColor Red
        Write-Host "Check docker-compose.yml and try again" -ForegroundColor Yellow
        exit 1
    }
}

# Function to wait for services to be ready
function Wait-ForServices {
    Write-Host "⏳ Waiting for services to be ready..." -ForegroundColor Yellow
    
    $maxAttempts = 30
    $attempt = 0
    $allHealthy = $false
    
    while (-not $allHealthy -and $attempt -lt $maxAttempts) {
        $attempt++
        Start-Sleep -Seconds 2
        
        try {
            $containers = docker compose ps --format json | ConvertFrom-Json
            $healthyCount = 0
            
            foreach ($container in $containers) {
                if ($container.Health -eq "healthy" -or $container.State -eq "running") {
                    $healthyCount++
                }
            }
            
            if ($healthyCount -eq 4) {
                $allHealthy = $true
                Write-Host "✅ All services are healthy" -ForegroundColor Green
            }
            else {
                Write-Host "⏳ $healthyCount/4 services ready (attempt $attempt/$maxAttempts)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "⏳ Checking service health (attempt $attempt/$maxAttempts)" -ForegroundColor Yellow
        }
    }
    
    if (-not $allHealthy) {
        Write-Host "⚠️  Services may not be fully ready, but continuing..." -ForegroundColor Yellow
    }
}

# Function to display service status
function Show-ServiceStatus {
    Write-Host "📊 Service Status:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    try {
        docker compose ps
        
        Write-Host "`n🔗 Relay URLs:" -ForegroundColor Cyan
        Write-Host "General:  ws://localhost:7001" -ForegroundColor White
        Write-Host "DM:       ws://localhost:7002" -ForegroundColor White
        Write-Host "Media:    ws://localhost:7003" -ForegroundColor White
        Write-Host "Social:   ws://localhost:7004" -ForegroundColor White
        
        Write-Host "`n🔑 Your Public Key (for client configuration):" -ForegroundColor Cyan
        Write-Host "npub1qs9t3tf2kfz872ns9yp42044dqs2v7v68mwy5mfczmsvcs075luqr7226z" -ForegroundColor White
        
        Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Run .\scripts\verify.ps1 to test the relays" -ForegroundColor White
        Write-Host "2. Configure your Nostr clients with the relay URLs above" -ForegroundColor White
        Write-Host "3. See docs\client-setup.md for detailed client configuration" -ForegroundColor White
    }
    catch {
        Write-Host "❌ Failed to get service status: $_" -ForegroundColor Red
    }
}

# Main execution
try {
    Test-Prerequisites
    Get-DockerImages
    Start-RelayServices
    Wait-ForServices
    Show-ServiceStatus
    
    Write-Host "`n🎉 Setup completed successfully!" -ForegroundColor Green
    Write-Host "Your private Nostr relay suite is now running." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Setup failed: $_" -ForegroundColor Red
    Write-Host "Check the error messages above and try again." -ForegroundColor Yellow
    exit 1
}
