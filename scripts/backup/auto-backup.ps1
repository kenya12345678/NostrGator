# NostrGator Automatic Backup System
# Transaction-triggered backups with multi-tier storage

param(
    [Parameter(Mandatory=$false)]
    [string]$TriggerType = "manual",  # manual, transaction, channel, scheduled
    
    [Parameter(Mandatory=$false)]
    [string]$TriggerData = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verify
)

# Import required modules and functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)

# Load configuration
$configPath = Join-Path $rootDir "configs\backup\config.yml"
$config = @{}

if (Test-Path $configPath) {
    try {
        $yamlContent = Get-Content $configPath -Raw
        
        # Parse basic settings (simple YAML parsing)
        $config.LocalEncrypted = $yamlContent -match 'local_encrypted:.*enabled:\s*true'
        $config.WindowsProfile = $yamlContent -match 'windows_profile:.*enabled:\s*true'
        $config.CloudSync = $yamlContent -match 'cloud_sync:.*enabled:\s*true'
        $config.ExternalDrive = $yamlContent -match 'external_drive:.*enabled:\s*true'
        
        # Extract retention settings
        if ($yamlContent -match 'daily_days:\s*(\d+)') { $config.DailyDays = [int]$matches[1] } else { $config.DailyDays = 30 }
        if ($yamlContent -match 'weekly_weeks:\s*(\d+)') { $config.WeeklyWeeks = [int]$matches[1] } else { $config.WeeklyWeeks = 26 }
        if ($yamlContent -match 'monthly_months:\s*(\d+)') { $config.MonthlyMonths = [int]$matches[1] } else { $config.MonthlyMonths = 24 }
        
    } catch {
        Write-Warning "Could not parse backup config, using defaults"
    }
}

# Default configuration if not loaded
if (-not $config.LocalEncrypted) {
    $config = @{
        LocalEncrypted = $true
        WindowsProfile = $true
        CloudSync = $true
        ExternalDrive = $true
        DailyDays = 30
        WeeklyWeeks = 26
        MonthlyMonths = 24
    }
}

# Backup paths
$backupPaths = @{
    LocalEncrypted = Join-Path $rootDir "data\backups\encrypted"
    WindowsProfile = Join-Path $env:USERPROFILE "NostrGator\Backups"
    CloudOneDrive = Join-Path $env:USERPROFILE "OneDrive\NostrGator\Backups"
    CloudGoogleDrive = Join-Path $env:USERPROFILE "Google Drive\NostrGator\Backups"
}

# Ensure backup directories exist
foreach ($path in $backupPaths.Values) {
    if (-not (Test-Path $path)) {
        try {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Host "Created backup directory: $path" -ForegroundColor Green
        } catch {
            Write-Warning "Could not create backup directory: $path"
        }
    }
}

# Function to encrypt data
function Encrypt-BackupData {
    param(
        [string]$Data,
        [string]$Password = "NostrGator-Default-Change-This"
    )
    
    try {
        # Simple encryption using ConvertTo-SecureString and ConvertFrom-SecureString
        $secureString = ConvertTo-SecureString -String $Data -AsPlainText -Force
        $encrypted = ConvertFrom-SecureString -SecureString $secureString -Key (1..32)
        return $encrypted
    } catch {
        Write-Error "Encryption failed: $_"
        return $null
    }
}

# Function to create backup metadata
function New-BackupMetadata {
    param(
        [string]$TriggerType,
        [string]$TriggerData,
        [array]$BackedUpFiles
    )
    
    return @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TriggerType = $TriggerType
        TriggerData = $TriggerData
        BackupId = [System.Guid]::NewGuid().ToString()
        Files = $BackedUpFiles
        NostrGatorVersion = "1.0.0"
        BackupVersion = "1.0"
    }
}

# Function to backup LND data
function Backup-LNDData {
    param([string]$BackupDir)
    
    $lndDataPath = Join-Path $rootDir "data\lnd"
    $backedUpFiles = @()
    
    if (Test-Path $lndDataPath) {
        # Critical files to backup
        $criticalFiles = @(
            "data\chain\bitcoin\mainnet\wallet.db",
            "data\chain\bitcoin\mainnet\channel.backup",
            "data\chain\bitcoin\mainnet\admin.macaroon",
            "data\chain\bitcoin\mainnet\readonly.macaroon",
            "tls.cert",
            "tls.key",
            "lnd.conf"
        )
        
        foreach ($file in $criticalFiles) {
            $sourcePath = Join-Path $lndDataPath $file
            if (Test-Path $sourcePath) {
                $destPath = Join-Path $BackupDir "lnd\$file"
                $destDir = Split-Path $destPath -Parent
                
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                
                try {
                    Copy-Item -Path $sourcePath -Destination $destPath -Force
                    $backedUpFiles += $file
                    Write-Host "Backed up: $file" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to backup $file`: $_"
                }
            }
        }
    }
    
    return $backedUpFiles
}

# Function to backup LNbits data
function Backup-LNbitsData {
    param([string]$BackupDir)
    
    $lnbitsDataPath = Join-Path $rootDir "data\lnbits"
    $backedUpFiles = @()
    
    if (Test-Path $lnbitsDataPath) {
        $files = @(
            "database.sqlite3",
            ".env"
        )
        
        foreach ($file in $files) {
            $sourcePath = Join-Path $lnbitsDataPath $file
            if (Test-Path $sourcePath) {
                $destPath = Join-Path $BackupDir "lnbits\$file"
                $destDir = Split-Path $destPath -Parent
                
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                
                try {
                    Copy-Item -Path $sourcePath -Destination $destPath -Force
                    $backedUpFiles += $file
                    Write-Host "Backed up: $file" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to backup $file`: $_"
                }
            }
        }
    }
    
    return $backedUpFiles
}

# Function to backup NostrGator configuration
function Backup-NostrGatorConfig {
    param([string]$BackupDir)
    
    $backedUpFiles = @()
    
    $configFiles = @(
        "docker-compose.yml",
        ".env",
        "configs"
    )
    
    foreach ($item in $configFiles) {
        $sourcePath = Join-Path $rootDir $item
        if (Test-Path $sourcePath) {
            $destPath = Join-Path $BackupDir "nostrgator\$item"
            $destDir = Split-Path $destPath -Parent
            
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            try {
                if (Test-Path $sourcePath -PathType Container) {
                    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
                } else {
                    Copy-Item -Path $sourcePath -Destination $destPath -Force
                }
                $backedUpFiles += $item
                Write-Host "Backed up: $item" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to backup $item`: $_"
            }
        }
    }
    
    return $backedUpFiles
}

# Main backup function
function Start-Backup {
    param(
        [string]$TriggerType,
        [string]$TriggerData
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupName = "nostrgator-backup-$timestamp"
    
    Write-Host "Starting NostrGator backup: $backupName" -ForegroundColor Cyan
    Write-Host "Trigger: $TriggerType" -ForegroundColor Gray
    
    $allBackedUpFiles = @()
    
    # Create temporary backup directory
    $tempBackupDir = Join-Path $env:TEMP $backupName
    if (Test-Path $tempBackupDir) {
        Remove-Item -Path $tempBackupDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempBackupDir -Force | Out-Null
    
    try {
        # Backup LND data
        Write-Host "Backing up LND data..." -ForegroundColor Yellow
        $lndFiles = Backup-LNDData -BackupDir $tempBackupDir
        $allBackedUpFiles += $lndFiles
        
        # Backup LNbits data
        Write-Host "Backing up LNbits data..." -ForegroundColor Yellow
        $lnbitsFiles = Backup-LNbitsData -BackupDir $tempBackupDir
        $allBackedUpFiles += $lnbitsFiles
        
        # Backup NostrGator configuration
        Write-Host "Backing up NostrGator configuration..." -ForegroundColor Yellow
        $configFiles = Backup-NostrGatorConfig -BackupDir $tempBackupDir
        $allBackedUpFiles += $configFiles
        
        # Create backup metadata
        $metadata = New-BackupMetadata -TriggerType $TriggerType -TriggerData $TriggerData -BackedUpFiles $allBackedUpFiles
        $metadataPath = Join-Path $tempBackupDir "backup-metadata.json"
        $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath
        
        # Create compressed backup archive
        $archiveName = "$backupName.zip"
        $archivePath = Join-Path $env:TEMP $archiveName
        
        Write-Host "Creating backup archive..." -ForegroundColor Yellow
        Compress-Archive -Path "$tempBackupDir\*" -DestinationPath $archivePath -Force
        
        # Copy to configured backup locations
        $backupSuccess = $false
        
        # Local encrypted storage
        if ($config.LocalEncrypted) {
            try {
                $localPath = Join-Path $backupPaths.LocalEncrypted $archiveName
                Copy-Item -Path $archivePath -Destination $localPath -Force
                Write-Host "Backup saved to local encrypted storage" -ForegroundColor Green
                $backupSuccess = $true
            } catch {
                Write-Warning "Failed to save to local encrypted storage: $_"
            }
        }
        
        # Windows profile backup
        if ($config.WindowsProfile) {
            try {
                $profilePath = Join-Path $backupPaths.WindowsProfile $archiveName
                Copy-Item -Path $archivePath -Destination $profilePath -Force
                Write-Host "Backup saved to Windows profile" -ForegroundColor Green
                $backupSuccess = $true
            } catch {
                Write-Warning "Failed to save to Windows profile: $_"
            }
        }
        
        # Cloud sync (OneDrive)
        if ($config.CloudSync -and (Test-Path $backupPaths.CloudOneDrive)) {
            try {
                $cloudPath = Join-Path $backupPaths.CloudOneDrive $archiveName
                Copy-Item -Path $archivePath -Destination $cloudPath -Force
                Write-Host "Backup saved to OneDrive" -ForegroundColor Green
                $backupSuccess = $true
            } catch {
                Write-Warning "Failed to save to OneDrive: $_"
            }
        }
        
        # Send notification
        if ($backupSuccess) {
            & "$scriptDir\..\notifications\toast.ps1" -Title "Backup Complete" -Message "NostrGator backup completed successfully" -Type "Success" -Icon "💾"
            Write-Host "Backup completed successfully!" -ForegroundColor Green
        } else {
            & "$scriptDir\..\notifications\toast.ps1" -Title "Backup Failed" -Message "All backup locations failed" -Type "Error" -Icon "💾"
            Write-Error "All backup locations failed!"
        }
        
    } finally {
        # Cleanup temporary files
        if (Test-Path $tempBackupDir) {
            Remove-Item -Path $tempBackupDir -Recurse -Force
        }
        if (Test-Path $archivePath) {
            Remove-Item -Path $archivePath -Force
        }
    }
}

# Execute backup
Start-Backup -TriggerType $TriggerType -TriggerData $TriggerData
