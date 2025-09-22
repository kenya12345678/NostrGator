# Test NostrGator Notification System
# Simple test to verify Windows toast notifications work

Write-Host "=== NostrGator Notification Test ===" -ForegroundColor Cyan
Write-Host ""

# Check if BurntToast module is available
Write-Host "Checking BurntToast module..." -ForegroundColor Yellow

try {
    Import-Module BurntToast -ErrorAction Stop
    Write-Host "BurntToast module loaded successfully!" -ForegroundColor Green
} catch {
    Write-Host "BurntToast module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module BurntToast -Force -Scope CurrentUser
        Import-Module BurntToast
        Write-Host "BurntToast module installed and loaded!" -ForegroundColor Green
    } catch {
        Write-Host "Failed to install BurntToast module. Error: $_" -ForegroundColor Red
        Write-Host "Please install manually: Install-Module BurntToast" -ForegroundColor White
        exit 1
    }
}

Write-Host ""

# Test basic notification
Write-Host "Sending test notification..." -ForegroundColor Yellow

try {
    New-BurntToastNotification -Text "NostrGator Test", "Notification system is working!" -AppLogo "https://via.placeholder.com/64x64/FF6B35/FFFFFF?text=NG"
    Write-Host "Test notification sent successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to send notification. Error: $_" -ForegroundColor Red
}

Write-Host ""

# Test different notification types
Write-Host "Testing different notification types..." -ForegroundColor Yellow

$notifications = @(
    @{ Title = "Lightning Wallet"; Message = "New payment received: 1000 sats"; Type = "Success" },
    @{ Title = "Security Alert"; Message = "Failed login attempt detected"; Type = "Warning" },
    @{ Title = "Backup Status"; Message = "Daily backup completed successfully"; Type = "Info" },
    @{ Title = "System Error"; Message = "Relay connection lost"; Type = "Error" }
)

foreach ($notif in $notifications) {
    try {
        New-BurntToastNotification -Text $notif.Title, $notif.Message -AppLogo "https://via.placeholder.com/64x64/FF6B35/FFFFFF?text=NG"
        Write-Host "  [$($notif.Type)] $($notif.Title) - Sent" -ForegroundColor Green
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "  [$($notif.Type)] $($notif.Title) - Failed: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Notification test completed!" -ForegroundColor Cyan
Write-Host "Check your Windows Action Center to see the notifications." -ForegroundColor White
