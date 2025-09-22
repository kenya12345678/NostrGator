# Private Nostr Relay Suite Backup Script
# Automated backup and restore procedures

param(
    [string]$BackupPath = ".\backups",
    [switch]$Restore,
    [string]$RestoreFrom,
    [switch]$Compress,
    [switch]$Verify
)

$ErrorActionPreference = "Stop"

# Generate timestamp for backup naming
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupName = "nostr-relay-backup-$timestamp"

Write-Host "💾 Private Nostr Relay Suite Backup Utility" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Function to create backup directory
function New-BackupDirectory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Host "✅ Created backup directory: $Path" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to create backup directory: $_" -ForegroundColor Red
            exit 1
        }
    }
}

# Function to stop services safely
function Stop-RelayServices {
    Write-Host "⏸️  Stopping relay services for backup..." -ForegroundColor Yellow
    
    try {
        docker compose stop
        Start-Sleep -Seconds 5  # Wait for graceful shutdown
        Write-Host "✅ Services stopped successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to stop services: $_" -ForegroundColor Red
        throw
    }
}

# Function to start services
function Start-RelayServices {
    Write-Host "▶️  Starting relay services..." -ForegroundColor Yellow
    
    try {
        docker compose start
        Start-Sleep -Seconds 10  # Wait for startup
        Write-Host "✅ Services started successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to start services: $_" -ForegroundColor Red
        throw
    }
}

# Function to backup data
function Backup-RelayData {
    param([string]$BackupDir)
    
    Write-Host "📦 Backing up relay data..." -ForegroundColor Yellow
    
    $dataDirectories = @("data\general", "data\dm", "data\media", "data\social")
    $configDirectories = @("configs\general", "configs\dm", "configs\media", "configs\social")
    $importantFiles = @("docker-compose.yml", ".env", "README.md")
    
    # Create backup structure
    $fullBackupPath = Join-Path $BackupDir $backupName
    New-Item -ItemType Directory -Path $fullBackupPath -Force | Out-Null
    
    # Backup data directories
    foreach ($dataDir in $dataDirectories) {
        if (Test-Path $dataDir) {
            $targetDir = Join-Path $fullBackupPath $dataDir
            try {
                Copy-Item -Path $dataDir -Destination $targetDir -Recurse -Force
                $size = (Get-ChildItem $dataDir -Recurse | Measure-Object -Property Length -Sum).Sum
                $sizeKB = [math]::Round($size / 1KB, 2)
                Write-Host "✅ Backed up $dataDir ($sizeKB KB)" -ForegroundColor Green
            }
            catch {
                Write-Host "❌ Failed to backup $dataDir : $_" -ForegroundColor Red
                throw
            }
        }
        else {
            Write-Host "⚠️  $dataDir not found, skipping" -ForegroundColor Yellow
        }
    }
    
    # Backup configuration directories
    foreach ($configDir in $configDirectories) {
        if (Test-Path $configDir) {
            $targetDir = Join-Path $fullBackupPath $configDir
            try {
                Copy-Item -Path $configDir -Destination $targetDir -Recurse -Force
                Write-Host "✅ Backed up $configDir" -ForegroundColor Green
            }
            catch {
                Write-Host "❌ Failed to backup $configDir : $_" -ForegroundColor Red
                throw
            }
        }
    }
    
    # Backup important files
    foreach ($file in $importantFiles) {
        if (Test-Path $file) {
            try {
                Copy-Item -Path $file -Destination $fullBackupPath -Force
                Write-Host "✅ Backed up $file" -ForegroundColor Green
            }
            catch {
                Write-Host "❌ Failed to backup $file : $_" -ForegroundColor Red
                throw
            }
        }
    }
    
    # Create backup manifest
    $manifest = @{
        BackupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        BackupName = $backupName
        DataDirectories = $dataDirectories
        ConfigDirectories = $configDirectories
        ImportantFiles = $importantFiles
        BackupSize = (Get-ChildItem $fullBackupPath -Recurse | Measure-Object -Property Length -Sum).Sum
    }
    
    $manifest | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $fullBackupPath "backup-manifest.json") -Encoding UTF8
    
    # Compress if requested
    if ($Compress) {
        Write-Host "🗜️  Compressing backup..." -ForegroundColor Yellow
        $zipPath = "$fullBackupPath.zip"
        try {
            Compress-Archive -Path $fullBackupPath -DestinationPath $zipPath -Force
            Remove-Item -Path $fullBackupPath -Recurse -Force
            Write-Host "✅ Backup compressed to: $zipPath" -ForegroundColor Green
            return $zipPath
        }
        catch {
            Write-Host "❌ Failed to compress backup: $_" -ForegroundColor Red
            throw
        }
    }
    
    return $fullBackupPath
}

# Function to restore data
function Restore-RelayData {
    param([string]$RestorePath)
    
    if (-not (Test-Path $RestorePath)) {
        Write-Host "❌ Restore path not found: $RestorePath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "📥 Restoring relay data from: $RestorePath" -ForegroundColor Yellow
    
    # Extract if it's a zip file
    $workingPath = $RestorePath
    if ($RestorePath.EndsWith(".zip")) {
        Write-Host "📦 Extracting backup archive..." -ForegroundColor Yellow
        $extractPath = $RestorePath.Replace(".zip", "")
        try {
            Expand-Archive -Path $RestorePath -DestinationPath $extractPath -Force
            $workingPath = $extractPath
        }
        catch {
            Write-Host "❌ Failed to extract backup: $_" -ForegroundColor Red
            exit 1
        }
    }
    
    # Verify backup manifest
    $manifestPath = Join-Path $workingPath "backup-manifest.json"
    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath | ConvertFrom-Json
        Write-Host "✅ Backup manifest found - Created: $($manifest.BackupDate)" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  No backup manifest found, proceeding anyway" -ForegroundColor Yellow
    }
    
    # Stop services before restore
    Stop-RelayServices
    
    try {
        # Restore data directories
        $dataDirectories = @("data\general", "data\dm", "data\media", "data\social")
        foreach ($dataDir in $dataDirectories) {
            $sourcePath = Join-Path $workingPath $dataDir
            if (Test-Path $sourcePath) {
                # Backup existing data
                if (Test-Path $dataDir) {
                    $backupExisting = "$dataDir.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    Move-Item -Path $dataDir -Destination $backupExisting
                    Write-Host "📋 Existing $dataDir backed up to $backupExisting" -ForegroundColor Yellow
                }
                
                Copy-Item -Path $sourcePath -Destination $dataDir -Recurse -Force
                Write-Host "✅ Restored $dataDir" -ForegroundColor Green
            }
        }
        
        # Restore configuration directories
        $configDirectories = @("configs\general", "configs\dm", "configs\media", "configs\social")
        foreach ($configDir in $configDirectories) {
            $sourcePath = Join-Path $workingPath $configDir
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $configDir -Recurse -Force
                Write-Host "✅ Restored $configDir" -ForegroundColor Green
            }
        }
        
        Write-Host "✅ Restore completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Restore failed: $_" -ForegroundColor Red
        throw
    }
    finally {
        # Always try to restart services
        Start-RelayServices
    }
}

# Function to verify backup integrity
function Test-BackupIntegrity {
    param([string]$BackupPath)
    
    Write-Host "🔍 Verifying backup integrity..." -ForegroundColor Yellow
    
    $manifestPath = Join-Path $BackupPath "backup-manifest.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Host "❌ Backup manifest not found" -ForegroundColor Red
        return $false
    }
    
    try {
        $manifest = Get-Content $manifestPath | ConvertFrom-Json
        Write-Host "✅ Backup manifest is valid" -ForegroundColor Green
        
        # Check if critical directories exist
        $criticalPaths = @("data\general", "data\dm", "configs\general", "configs\dm")
        foreach ($path in $criticalPaths) {
            $fullPath = Join-Path $BackupPath $path
            if (Test-Path $fullPath) {
                Write-Host "✅ Critical path exists: $path" -ForegroundColor Green
            }
            else {
                Write-Host "❌ Critical path missing: $path" -ForegroundColor Red
                return $false
            }
        }
        
        Write-Host "✅ Backup integrity verified" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Backup integrity check failed: $_" -ForegroundColor Red
        return $false
    }
}

# Main execution
try {
    if ($Restore) {
        if (-not $RestoreFrom) {
            Write-Host "❌ Please specify -RestoreFrom parameter with backup path" -ForegroundColor Red
            exit 1
        }
        Restore-RelayData -RestorePath $RestoreFrom
    }
    else {
        New-BackupDirectory -Path $BackupPath
        Stop-RelayServices
        
        try {
            $backupResult = Backup-RelayData -BackupDir $BackupPath
            
            if ($Verify) {
                $isValid = Test-BackupIntegrity -BackupPath $backupResult
                if (-not $isValid) {
                    Write-Host "⚠️  Backup verification failed" -ForegroundColor Yellow
                }
            }
            
            Write-Host "`n🎉 Backup completed successfully!" -ForegroundColor Green
            Write-Host "📁 Backup location: $backupResult" -ForegroundColor White
            Write-Host "💡 To restore: .\scripts\backup.ps1 -Restore -RestoreFrom '$backupResult'" -ForegroundColor Yellow
        }
        finally {
            Start-RelayServices
        }
    }
}
catch {
    Write-Host "`n❌ Backup operation failed: $_" -ForegroundColor Red
    exit 1
}
