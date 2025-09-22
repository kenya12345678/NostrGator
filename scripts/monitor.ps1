# Enhanced Nostr Relay Suite Monitoring Script
# Real-time monitoring with performance metrics and alerting

param(
    [switch]$Continuous,
    [int]$RefreshInterval = 30,
    [switch]$Detailed,
    [switch]$Export
)

$ErrorActionPreference = "Continue"

# Color scheme
$colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colorValue = $colors[$Color]
    if (-not $colorValue) { $colorValue = "White" }
    Write-Host $Message -ForegroundColor $colorValue
}

function Get-ContainerMetrics {
    param([string]$ContainerName)
    
    try {
        $stats = docker stats $ContainerName --no-stream --format "table {{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Select-Object -Skip 1
        if ($stats) {
            $parts = $stats -split ","
            return @{
                CPU = $parts[0]
                Memory = $parts[1]
                Network = $parts[2]
                Disk = $parts[3]
            }
        }
    }
    catch {
        return @{
            CPU = "N/A"
            Memory = "N/A"
            Network = "N/A"
            Disk = "N/A"
        }
    }
}

function Get-RelayStatus {
    $relays = @{
        "General" = @{ Port = 7001; Container = "nostr-general" }
        "DM" = @{ Port = 7002; Container = "nostr-dm" }
        "Media" = @{ Port = 7003; Container = "nostr-media" }
        "Social" = @{ Port = 7004; Container = "nostr-social" }
        "Cache" = @{ Port = 7005; Container = "nostr-cache" }
        "Files" = @{ Port = 7006; Container = "nostr-files" }
        "LongForm" = @{ Port = 7007; Container = "nostr-longform" }
        "Live" = @{ Port = 7008; Container = "nostr-live" }
        "Marketplace" = @{ Port = 7009; Container = "nostr-marketplace" }
        "Games" = @{ Port = 7010; Container = "nostr-games" }
        "Bridge" = @{ Port = 7011; Container = "nostr-bridge" }
        "LND" = @{ Port = 10009; Container = "nostrgator-lnd" }
        "LNbits" = @{ Port = 5000; Container = "nostrgator-lnbits" }
        "Blossom" = @{ Port = 3000; Container = "nostrgator-blossom" }
        "Backup" = @{ Port = 0; Container = "nostrgator-backup-manager" }
        "Notifications" = @{ Port = 7083; Container = "nostrgator-notifications" }
        "ContentDiscovery" = @{ Port = 7080; Container = "nostr-content-discovery" }
        "SecurityMonitor" = @{ Port = 7081; Container = "nostr-security-monitor" }
    }
    
    $status = @{}
    
    foreach ($relay in $relays.Keys) {
        $port = $relays[$relay].Port
        $container = $relays[$relay].Container
        
        # Container status
        try {
            $containerStatus = docker inspect $container --format '{{.State.Status}}' 2>$null
            $healthStatus = docker inspect $container --format '{{.State.Health.Status}}' 2>$null
        }
        catch {
            $containerStatus = "not found"
            $healthStatus = "unknown"
        }
        
        # HTTP response test
        $httpStatus = "Unknown"
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$port" -TimeoutSec 3 -UseBasicParsing
            $httpStatus = $response.StatusCode
        }
        catch {
            $httpStatus = "Failed"
        }
        
        # Performance metrics
        $metrics = Get-ContainerMetrics -ContainerName $container
        
        $status[$relay] = @{
            Port = $port
            Container = $containerStatus
            Health = $healthStatus
            HTTP = $httpStatus
            Metrics = $metrics
        }
    }
    
    return $status
}

function Show-Dashboard {
    param($Status)
    
    Clear-Host
    Write-ColorOutput "⚡ NOSTRGATOR - SOVEREIGN NOSTR + LIGHTNING INFRASTRUCTURE" "Header"
    Write-ColorOutput "=" * 70 "Header"
    Write-ColorOutput "Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Info"
    Write-ColorOutput ""
    
    # Overall status
    $totalRelays = $Status.Count
    $healthyRelays = ($Status.Values | Where-Object { $_.Container -eq "running" -and $_.HTTP -eq 200 }).Count
    $healthPercentage = [math]::Round(($healthyRelays / $totalRelays) * 100, 1)
    
    Write-ColorOutput "📊 OVERALL STATUS" "Header"
    Write-ColorOutput "Healthy Relays: $healthyRelays/$totalRelays ($healthPercentage%%)" $(
        if ($healthPercentage -eq 100) { "Success" }
        elseif ($healthPercentage -ge 80) { "Warning" }
        else { "Error" }
    )
    Write-ColorOutput ""
    
    # Individual relay status
    Write-ColorOutput "🔍 RELAY STATUS DETAILS" "Header"
    Write-ColorOutput ("{0,-8} {1,-6} {2,-10} {3,-8} {4,-8} {5,-15} {6,-15}" -f "Relay", "Port", "Container", "Health", "HTTP", "CPU", "Memory") "Info"
    Write-ColorOutput "-" * 70 "Info"
    
    foreach ($relay in $Status.Keys | Sort-Object) {
        $s = $Status[$relay]
        
        $containerColor = switch ($s.Container) {
            "running" { "Success" }
            default { "Error" }
        }
        
        $httpColor = switch ($s.HTTP) {
            200 { "Success" }
            "Failed" { "Error" }
            default { "Warning" }
        }
        
        Write-Host ("{0,-8}" -f $relay) -NoNewline
        Write-Host (" {0,-6}" -f $s.Port) -NoNewline
        Write-Host (" {0,-10}" -f $s.Container) -ForegroundColor $colors[$containerColor] -NoNewline
        Write-Host (" {0,-8}" -f $s.Health) -NoNewline
        Write-Host (" {0,-8}" -f $s.HTTP) -ForegroundColor $colors[$httpColor] -NoNewline
        Write-Host (" {0,-15}" -f $s.Metrics.CPU) -NoNewline
        Write-Host (" {0,-15}" -f $s.Metrics.Memory)
    }
    
    Write-ColorOutput ""
    
    # System services status
    Write-ColorOutput "🛠️  SYSTEM SERVICES" "Header"
    
    # Watchtower status
    try {
        $watchtowerStatus = docker inspect nostr-watchtower --format '{{.State.Status}}' 2>$null
        $watchtowerColor = if ($watchtowerStatus -eq "running") { "Success" } else { "Error" }
        Write-Host "Watchtower (Auto-Updates): " -NoNewline
        Write-ColorOutput $watchtowerStatus $watchtowerColor
    }
    catch {
        Write-ColorOutput "Watchtower (Auto-Updates): Not Found" "Error"
    }
    
    # Health monitor status
    try {
        $monitorStatus = docker inspect nostr-health-monitor --format '{{.State.Status}}' 2>$null
        $monitorColor = if ($monitorStatus -eq "running") { "Success" } else { "Error" }
        Write-Host "Health Monitor: " -NoNewline
        Write-ColorOutput $monitorStatus $monitorColor
    }
    catch {
        Write-ColorOutput "Health Monitor: Not Found" "Warning"
    }

    # Content Discovery status
    try {
        $cdStatus = docker inspect nostr-content-discovery --format '{{.State.Status}}' 2>$null
        $cdColor = if ($cdStatus -eq "running") { "Success" } else { "Error" }
        $cdHttp = ""
        try { $cdResp = Invoke-WebRequest -Uri "http://localhost:7080/health" -TimeoutSec 3 -UseBasicParsing; $cdHttp = $cdResp.StatusCode } catch { $cdHttp = "Failed" }
        Write-Host "Content Discovery: " -NoNewline
        Write-ColorOutput "$cdStatus (HTTP: $cdHttp)" $cdColor
    }
    catch {
        Write-ColorOutput "Content Discovery: Not Found" "Warning"
    }

    # Security Monitor status
    try {
        $smStatus = docker inspect nostr-security-monitor --format '{{.State.Status}}' 2>$null
        $smColor = if ($smStatus -eq "running") { "Success" } else { "Error" }
        $smHttp = ""
        try { $smResp = Invoke-WebRequest -Uri "http://localhost:7081/health" -TimeoutSec 3 -UseBasicParsing; $smHttp = $smResp.StatusCode } catch { $smHttp = "Failed" }
        Write-Host "Security Monitor: " -NoNewline
        Write-ColorOutput "$smStatus (HTTP: $smHttp)" $smColor
    }
    catch {
        Write-ColorOutput "Security Monitor: Not Found" "Warning"
    }

    Write-ColorOutput ""
    
    # Quick actions
    Write-ColorOutput "🔧 QUICK ACTIONS" "Header"
    Write-ColorOutput "• View logs: docker logs [container-name]" "Info"
    Write-ColorOutput "• Restart relay: docker restart [container-name]" "Info"
    Write-ColorOutput "• Full verification: .\scripts\verify.ps1 -Detailed" "Info"
    Write-ColorOutput "• Health dashboard: http://localhost:3001" "Info"
    
    if ($Continuous) {
        Write-ColorOutput ""
        Write-ColorOutput "Press Ctrl+C to stop monitoring..." "Warning"
    }
}

function Export-StatusReport {
    param($Status)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportPath = "monitoring_report_$timestamp.json"
    
    $report = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        RelayStatus = $Status
        SystemInfo = @{
            DockerVersion = (docker --version)
            ComposeVersion = (docker compose version)
        }
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-ColorOutput "Status report exported to: $reportPath" "Success"
}

# Main execution
do {
    $status = Get-RelayStatus
    Show-Dashboard -Status $status
    
    if ($Export) {
        Export-StatusReport -Status $status
    }
    
    if ($Continuous) {
        Start-Sleep -Seconds $RefreshInterval
    }
} while ($Continuous)

if (-not $Continuous) {
    Write-ColorOutput ""
    Write-ColorOutput "💡 TIP: Use -Continuous for real-time monitoring" "Info"
    Write-ColorOutput "💡 TIP: Use -Export to save status report" "Info"
}
