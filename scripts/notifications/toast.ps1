# NostrGator Windows Toast Notification Handler
# Sends Windows 10/11 toast notifications for system events

param(
    [Parameter(Mandatory=$true)]
    [string]$Title,
    
    [Parameter(Mandatory=$true)]
    [string]$Message,
    
    [Parameter(Mandatory=$false)]
    [string]$Type = "Info",  # Info, Warning, Error, Success
    
    [Parameter(Mandatory=$false)]
    [string]$Icon = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Persist,
    
    [Parameter(Mandatory=$false)]
    [switch]$Silent
)

# Import required modules
try {
    Import-Module BurntToast -ErrorAction Stop
} catch {
    Write-Host "Installing BurntToast module for notifications..." -ForegroundColor Yellow
    Install-Module -Name BurntToast -Force -Scope CurrentUser
    Import-Module BurntToast
}

# Load configuration
$configPath = Join-Path $PSScriptRoot "..\..\configs\notifications\config.yml"
$config = @{}

if (Test-Path $configPath) {
    try {
        # Simple YAML parsing for our config
        $yamlContent = Get-Content $configPath -Raw
        
        # Extract notification level
        if ($yamlContent -match 'level:\s*"([^"]+)"') {
            $config.Level = $matches[1]
        } else {
            $config.Level = "CRITICAL_ONLY"
        }
        
        # Extract quiet hours
        if ($yamlContent -match 'enabled:\s*true' -and $yamlContent -match 'start:\s*"([^"]+)"' -and $yamlContent -match 'end:\s*"([^"]+)"') {
            $config.QuietHours = @{
                Enabled = $true
                Start = $matches[1]
                End = $matches[2]
            }
        } else {
            $config.QuietHours = @{ Enabled = $false }
        }
        
        # Extract sound settings
        $config.Sound = $yamlContent -match 'sound:.*enabled:\s*true'
        
    } catch {
        Write-Warning "Could not parse notification config, using defaults"
        $config = @{
            Level = "CRITICAL_ONLY"
            QuietHours = @{ Enabled = $false }
            Sound = $true
        }
    }
} else {
    # Default configuration
    $config = @{
        Level = "CRITICAL_ONLY"
        QuietHours = @{ Enabled = $false }
        Sound = $true
    }
}

# Check if notifications are disabled
if ($config.Level -eq "NONE") {
    Write-Host "Notifications disabled in config" -ForegroundColor Gray
    exit 0
}

# Check quiet hours
if ($config.QuietHours.Enabled) {
    $currentTime = Get-Date
    $startTime = [DateTime]::ParseExact($config.QuietHours.Start, "HH:mm", $null)
    $endTime = [DateTime]::ParseExact($config.QuietHours.End, "HH:mm", $null)
    
    # Handle overnight quiet hours (e.g., 22:00 to 07:00)
    if ($startTime -gt $endTime) {
        $isQuietTime = ($currentTime.TimeOfDay -ge $startTime.TimeOfDay) -or ($currentTime.TimeOfDay -le $endTime.TimeOfDay)
    } else {
        $isQuietTime = ($currentTime.TimeOfDay -ge $startTime.TimeOfDay) -and ($currentTime.TimeOfDay -le $endTime.TimeOfDay)
    }
    
    if ($isQuietTime -and $Type -ne "Error") {
        Write-Host "Quiet hours active, skipping notification" -ForegroundColor Gray
        exit 0
    }
}

# Check notification level filtering
$shouldNotify = $false
switch ($config.Level) {
    "ALL" { $shouldNotify = $true }
    "CRITICAL_ONLY" { $shouldNotify = ($Type -eq "Error" -or $Type -eq "Warning") }
    "WALLET_ONLY" { $shouldNotify = ($Title -match "Lightning|Wallet|Transaction|Channel") }
    "SECURITY_ONLY" { $shouldNotify = ($Title -match "Security|Auth|Backup|Alert") }
    default { $shouldNotify = $true }
}

if (-not $shouldNotify) {
    Write-Host "Notification filtered by level: $($config.Level)" -ForegroundColor Gray
    exit 0
}

# Determine icon based on type
$iconPath = ""
switch ($Type) {
    "Success" { 
        $iconPath = "ms-appx:///Assets/success.png"
        if (-not $Icon) { $Icon = "✅" }
    }
    "Warning" { 
        $iconPath = "ms-appx:///Assets/warning.png"
        if (-not $Icon) { $Icon = "⚠️" }
    }
    "Error" { 
        $iconPath = "ms-appx:///Assets/error.png"
        if (-not $Icon) { $Icon = "❌" }
    }
    default { 
        $iconPath = "ms-appx:///Assets/info.png"
        if (-not $Icon) { $Icon = "ℹ️" }
    }
}

# Prepare notification parameters
$toastParams = @{
    Text = @($Title, $Message)
    AppLogo = $iconPath
    Silent = $Silent.IsPresent -or (-not $config.Sound)
}

# Add persistence if requested
if ($Persist.IsPresent) {
    $toastParams.ExpirationTime = (Get-Date).AddHours(24)
}

# Add action buttons for critical notifications
if ($Type -eq "Error" -or $Type -eq "Warning") {
    $toastParams.Button = @(
        New-BTButton -Content "View Logs" -Arguments "logs"
        New-BTButton -Content "Dismiss" -Arguments "dismiss"
    )
}

# Send the notification
try {
    New-BurntToastNotification @toastParams
    
    # Log the notification
    $logEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Type = $Type
        Title = $Title
        Message = $Message
        Sent = $true
    }
    
    $logPath = Join-Path $PSScriptRoot "..\..\data\logs\notifications.log"
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $logEntry | ConvertTo-Json -Compress | Add-Content -Path $logPath
    
    Write-Host "Notification sent: $Title" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to send notification: $_"
    
    # Log the failure
    $logEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Type = $Type
        Title = $Title
        Message = $Message
        Sent = $false
        Error = $_.Exception.Message
    }
    
    $logPath = Join-Path $PSScriptRoot "..\..\data\logs\notifications.log"
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $logEntry | ConvertTo-Json -Compress | Add-Content -Path $logPath
    
    exit 1
}

# Example usage:
# .\toast.ps1 -Title "Lightning Transaction" -Message "Received 1000 sats" -Type "Success" -Icon "⚡"
# .\toast.ps1 -Title "Relay Offline" -Message "General relay is not responding" -Type "Error" -Persist
# .\toast.ps1 -Title "Backup Complete" -Message "All wallet data backed up successfully" -Type "Success" -Silent
