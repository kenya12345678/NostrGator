# NostrGator Lightning Wallet Setup Wizard
# Guides users through initial wallet setup and configuration

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipBackupConfig,
    
    [Parameter(Mandatory=$false)]
    [switch]$QuickSetup
)

# Colors for output
$colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "White"
    Prompt = "Magenta"
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "Info")
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Show-WelcomeScreen {
    Clear-Host
    Write-ColorOutput "⚡ NOSTRGATOR LIGHTNING WALLET SETUP WIZARD" "Header"
    Write-ColorOutput "=" * 60 "Header"
    Write-ColorOutput ""
    Write-ColorOutput "Welcome to NostrGator's sovereign Lightning wallet setup!" "Info"
    Write-ColorOutput ""
    Write-ColorOutput "This wizard will help you:" "Info"
    Write-ColorOutput "• Configure your Lightning Network node (LND)" "Info"
    Write-ColorOutput "• Set up LNbits web interface with Nostr Wallet Connect" "Info"
    Write-ColorOutput "• Configure nuclear-proof backup system" "Info"
    Write-ColorOutput "• Set up intelligent notifications" "Info"
    Write-ColorOutput "• Generate funding instructions for your wallet" "Info"
    Write-ColorOutput ""
    Write-ColorOutput "IMPORTANT: This will create a HOT Lightning wallet for daily use." "Warning"
    Write-ColorOutput "For large amounts, consider a separate cold storage solution." "Warning"
    Write-ColorOutput ""
    
    if (-not $QuickSetup) {
        $continue = Read-Host "Press Enter to continue or 'q' to quit"
        if ($continue -eq 'q') {
            Write-ColorOutput "Setup cancelled." "Warning"
            exit 0
        }
    }
}

function Test-Prerequisites {
    Write-ColorOutput "`n🔍 Checking Prerequisites..." "Header"
    
    $allGood = $true
    
    # Check Docker
    try {
        $dockerVersion = docker --version
        Write-ColorOutput "✅ Docker: $dockerVersion" "Success"
    } catch {
        Write-ColorOutput "❌ Docker not found. Please install Docker Desktop." "Error"
        $allGood = $false
    }
    
    # Check Docker Compose
    try {
        $composeVersion = docker compose version
        Write-ColorOutput "✅ Docker Compose: $composeVersion" "Success"
    } catch {
        Write-ColorOutput "❌ Docker Compose not found." "Error"
        $allGood = $false
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Write-ColorOutput "✅ PowerShell: $($PSVersionTable.PSVersion)" "Success"
    } else {
        Write-ColorOutput "❌ PowerShell 5.0+ required." "Error"
        $allGood = $false
    }
    
    # Check available disk space
    $freeSpace = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"} | Select-Object -ExpandProperty FreeSpace
    $freeSpaceGB = [math]::Round($freeSpace / 1GB, 2)
    
    if ($freeSpaceGB -gt 10) {
        Write-ColorOutput "✅ Disk Space: $freeSpaceGB GB available" "Success"
    } else {
        Write-ColorOutput "⚠️  Disk Space: Only $freeSpaceGB GB available (10GB+ recommended)" "Warning"
    }
    
    if (-not $allGood) {
        Write-ColorOutput "`nPlease fix the issues above before continuing." "Error"
        exit 1
    }
    
    Write-ColorOutput "`n✅ All prerequisites met!" "Success"
}

function Configure-BackupSettings {
    if ($SkipBackupConfig) {
        Write-ColorOutput "`n⏭️  Skipping backup configuration (using defaults)" "Info"
        return
    }
    
    Write-ColorOutput "`n💾 Backup Configuration" "Header"
    Write-ColorOutput "Configure your nuclear-proof backup system:" "Info"
    Write-ColorOutput ""
    
    # Backup password
    Write-ColorOutput "Set a strong password for backup encryption:" "Prompt"
    Write-ColorOutput "(This will encrypt all your backup files)" "Info"
    $backupPassword = Read-Host "Backup Password" -AsSecureString
    $backupPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($backupPassword))
    
    # Seed password (separate from backup password)
    Write-ColorOutput "`nSet a separate password for seed phrase encryption:" "Prompt"
    Write-ColorOutput "(This provides extra security for your wallet seed)" "Info"
    $seedPassword = Read-Host "Seed Password" -AsSecureString
    $seedPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seedPassword))
    
    # Update .env file with passwords
    $envPath = ".\.env"
    if (Test-Path $envPath) {
        $envContent = Get-Content $envPath
        $envContent = $envContent -replace "BACKUP_ENCRYPTION_PASSWORD=.*", "BACKUP_ENCRYPTION_PASSWORD=$backupPasswordText"
        $envContent = $envContent -replace "BACKUP_SEED_PASSWORD=.*", "BACKUP_SEED_PASSWORD=$seedPasswordText"
        Set-Content -Path $envPath -Value $envContent
        Write-ColorOutput "✅ Backup passwords configured" "Success"
    }
    
    # Backup locations
    Write-ColorOutput "`nBackup Storage Locations:" "Info"
    Write-ColorOutput "1. Local encrypted storage (always enabled)" "Info"
    Write-ColorOutput "2. Windows user profile backup folder" "Info"
    Write-ColorOutput "3. Cloud sync (OneDrive/Google Drive if available)" "Info"
    Write-ColorOutput "4. External drive detection" "Info"
    Write-ColorOutput ""
    Write-ColorOutput "All locations will be used automatically for maximum redundancy." "Success"
}

function Configure-Notifications {
    Write-ColorOutput "`n🔔 Notification Configuration" "Header"
    Write-ColorOutput "Choose your notification preferences:" "Info"
    Write-ColorOutput ""
    Write-ColorOutput "1. ALL - All events (transactions, health, security)" "Info"
    Write-ColorOutput "2. CRITICAL_ONLY - Only critical alerts (recommended)" "Info"
    Write-ColorOutput "3. WALLET_ONLY - Only Lightning wallet events" "Info"
    Write-ColorOutput "4. SECURITY_ONLY - Only security alerts" "Info"
    Write-ColorOutput "5. NONE - No notifications" "Info"
    Write-ColorOutput ""
    
    if ($QuickSetup) {
        $notificationChoice = "2"
        Write-ColorOutput "Quick setup: Using CRITICAL_ONLY notifications" "Info"
    } else {
        $notificationChoice = Read-Host "Enter choice (1-5) [default: 2]"
        if ([string]::IsNullOrEmpty($notificationChoice)) { $notificationChoice = "2" }
    }
    
    $notificationLevels = @{
        "1" = "ALL"
        "2" = "CRITICAL_ONLY"
        "3" = "WALLET_ONLY"
        "4" = "SECURITY_ONLY"
        "5" = "NONE"
    }
    
    $selectedLevel = $notificationLevels[$notificationChoice]
    if ($selectedLevel) {
        # Update notification config
        $configPath = ".\configs\notifications\config.yml"
        if (Test-Path $configPath) {
            $configContent = Get-Content $configPath -Raw
            $configContent = $configContent -replace 'level:\s*"[^"]*"', "level: `"$selectedLevel`""
            Set-Content -Path $configPath -Value $configContent
            Write-ColorOutput "✅ Notifications set to: $selectedLevel" "Success"
        }
    }
}

function Start-Services {
    Write-ColorOutput "`n🚀 Starting NostrGator Services..." "Header"
    
    # Pull latest images
    Write-ColorOutput "Pulling latest Docker images..." "Info"
    docker compose pull
    
    # Start services
    Write-ColorOutput "Starting all services..." "Info"
    docker compose up -d
    
    # Wait for services to start
    Write-ColorOutput "Waiting for services to initialize..." "Info"
    Start-Sleep -Seconds 30
    
    # Check service status
    Write-ColorOutput "`nChecking service status..." "Info"
    $services = @("nostrgator-lnd", "nostrgator-lnbits", "nostrgator-blossom")
    
    foreach ($service in $services) {
        try {
            $status = docker inspect $service --format '{{.State.Status}}' 2>$null
            if ($status -eq "running") {
                Write-ColorOutput "✅ $service is running" "Success"
            } else {
                Write-ColorOutput "⚠️  $service status: $status" "Warning"
            }
        } catch {
            Write-ColorOutput "❌ $service not found" "Error"
        }
    }
}

function Show-FundingInstructions {
    Write-ColorOutput "`n💰 WALLET FUNDING INSTRUCTIONS" "Header"
    Write-ColorOutput "=" * 50 "Header"
    Write-ColorOutput ""
    Write-ColorOutput "Your Lightning wallet is now running! Here's how to fund it:" "Info"
    Write-ColorOutput ""
    
    Write-ColorOutput "🌐 Access your wallet:" "Success"
    Write-ColorOutput "• LNbits Web Interface: http://localhost:5000" "Info"
    Write-ColorOutput "• Create a wallet and get your on-chain deposit address" "Info"
    Write-ColorOutput ""
    
    Write-ColorOutput "💳 From Coinbase:" "Success"
    Write-ColorOutput "1. Open Coinbase app/website" "Info"
    Write-ColorOutput "2. Go to your Bitcoin wallet" "Info"
    Write-ColorOutput "3. Click 'Send' and paste your LND on-chain address" "Info"
    Write-ColorOutput "4. Send your desired amount (wait for confirmations)" "Info"
    Write-ColorOutput ""
    
    Write-ColorOutput "💳 From Robinhood:" "Success"
    Write-ColorOutput "1. Open Robinhood app" "Info"
    Write-ColorOutput "2. Go to your Bitcoin holdings" "Info"
    Write-ColorOutput "3. Click 'Transfer' -> 'Withdraw'" "Info"
    Write-ColorOutput "4. Paste your LND on-chain address and send" "Info"
    Write-ColorOutput ""
    
    Write-ColorOutput "⚡ Other funding options:" "Success"
    Write-ColorOutput "• Strike: ACH -> Bitcoin -> Lightning" "Info"
    Write-ColorOutput "• Cash App: Buy Bitcoin -> Withdraw to your address" "Info"
    Write-ColorOutput "• River, Kraken, Swan: Exchange -> On-chain withdrawal" "Info"
    Write-ColorOutput ""
    
    Write-ColorOutput "🔗 Opening channels:" "Success"
    Write-ColorOutput "• After on-chain funds arrive, open Lightning channels" "Info"
    Write-ColorOutput "• Use LNbits interface or enable autopilot in LND" "Info"
    Write-ColorOutput "• Recommended: Start with 2-3 channels of 100k-500k sats each" "Info"
    Write-ColorOutput ""
    
    Write-ColorOutput "📱 Connect to Nostr clients:" "Success"
    Write-ColorOutput "• Generate NWC (Nostr Wallet Connect) token in LNbits" "Info"
    Write-ColorOutput "• Add token to Damus, Amethyst, Primal, or other NWC-compatible clients" "Info"
    Write-ColorOutput "• Set your lud16 address for receiving zaps" "Info"
}

function Show-CompletionSummary {
    Write-ColorOutput "`n🎉 SETUP COMPLETE!" "Header"
    Write-ColorOutput "=" * 40 "Header"
    Write-ColorOutput ""
    Write-ColorOutput "NostrGator is now fully operational with:" "Success"
    Write-ColorOutput ""
    Write-ColorOutput "⚡ Lightning Network node (LND)" "Success"
    Write-ColorOutput "🌐 Web wallet interface (LNbits)" "Success"
    Write-ColorOutput "📁 File storage server (Blossom)" "Success"
    Write-ColorOutput "💾 Nuclear-proof backup system" "Success"
    Write-ColorOutput "🔔 Intelligent notifications" "Success"
    Write-ColorOutput "🛡️  Security monitoring" "Success"
    Write-ColorOutput ""
    
    Write-ColorOutput "Next steps:" "Info"
    Write-ColorOutput "1. Fund your wallet using the instructions above" "Info"
    Write-ColorOutput "2. Open Lightning channels for instant payments" "Info"
    Write-ColorOutput "3. Connect your Nostr clients with NWC tokens" "Info"
    Write-ColorOutput "4. Monitor your infrastructure with: .\scripts\monitor.ps1" "Info"
    Write-ColorOutput ""
    
    Write-ColorOutput "Important files to backup separately:" "Warning"
    Write-ColorOutput "• Your 24-word seed phrase (when generated)" "Warning"
    Write-ColorOutput "• LND macaroons and TLS certificates" "Warning"
    Write-ColorOutput "• This entire NostrGator directory" "Warning"
    Write-ColorOutput ""
    
    Write-ColorOutput "Support and documentation:" "Info"
    Write-ColorOutput "• README.md - Complete setup guide" "Info"
    Write-ColorOutput "• COMPREHENSIVE-DEPLOYMENT-GUIDE.md - Advanced configuration" "Info"
    Write-ColorOutput "• GitHub repository - Updates and community support" "Info"
}

# Main execution
try {
    Show-WelcomeScreen
    Test-Prerequisites
    Configure-BackupSettings
    Configure-Notifications
    Start-Services
    Show-FundingInstructions
    Show-CompletionSummary
    
    Write-ColorOutput "`n🚀 NostrGator setup completed successfully!" "Success"
    Write-ColorOutput "Run '.\scripts\monitor.ps1' to view your infrastructure dashboard." "Info"
    
} catch {
    Write-ColorOutput "`n❌ Setup failed: $_" "Error"
    Write-ColorOutput "Please check the error above and try again." "Error"
    exit 1
}
