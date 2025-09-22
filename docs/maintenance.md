# NostrGator Maintenance Guide

## Overview
This guide covers routine maintenance, monitoring, backup procedures, and troubleshooting for your NostrGator infrastructure including the professional file server.

## Daily Operations

### Health Monitoring
```powershell
# Quick health check
docker compose ps

# Detailed verification
.\scripts\verify.ps1

# Check resource usage
docker stats --no-stream
```

### Log Monitoring
```powershell
# View recent logs for all services
docker compose logs --tail=20

# Monitor specific relay
docker logs nostr-general --tail=50 -f

# Check for errors
docker compose logs | Select-String "ERROR|WARN"
```

## Weekly Maintenance

### 1. Backup Data
```powershell
# Create compressed backup
.\scripts\backup.ps1 -Compress -Verify

# Verify backup integrity
.\scripts\backup.ps1 -Verify -BackupPath ".\backups\latest"
```

### 2. Update Images
```powershell
# Pull latest relay images
docker compose pull

# Restart with new images
docker compose up -d
```

### 3. Database Maintenance
```powershell
# Check database sizes
Get-ChildItem .\data\*\*.db | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB,2)}}

# SQLite auto-vacuum runs automatically via WAL mode
# Manual vacuum if needed (stops services temporarily):
# docker compose stop
# sqlite3 .\data\general\nostr.db "VACUUM;"
# docker compose start
```

## Monthly Maintenance

### 1. Performance Review
```powershell
# Check container resource usage over time
docker stats --no-stream

# Review log file sizes
Get-ChildItem .\data\*\*.db* | Measure-Object -Property Length -Sum

# Check event counts (requires SQLite)
# sqlite3 .\data\general\nostr.db "SELECT COUNT(*) FROM event;"
```

### 2. Security Updates
```powershell
# Update Docker Desktop
# Check for nostr-rs-relay updates
docker pull scsibug/nostr-rs-relay:latest

# Review and rotate logs
docker system prune -f
```

### 3. Configuration Review
- Review relay configurations for optimization
- Check whitelist settings
- Verify backup procedures
- Test disaster recovery

## Backup Procedures

### Automated Backup
```powershell
# Daily backup (add to Windows Task Scheduler)
.\scripts\backup.ps1 -Compress -BackupPath "D:\NostrBackups"

# Weekly full backup with verification
.\scripts\backup.ps1 -Compress -Verify -BackupPath "\\NetworkDrive\NostrBackups"
```

### Manual Backup
```powershell
# Stop services for consistent backup
docker compose stop

# Copy data directories
Copy-Item -Path ".\data" -Destination ".\backup-$(Get-Date -Format 'yyyyMMdd')" -Recurse

# Restart services
docker compose start
```

### Backup Retention Policy
- **Daily backups**: Keep 7 days
- **Weekly backups**: Keep 4 weeks  
- **Monthly backups**: Keep 12 months
- **Yearly backups**: Keep indefinitely

### Backup Storage Locations
1. **Local**: `.\backups\` (for quick recovery)
2. **External Drive**: For offline protection
3. **Network Storage**: For redundancy
4. **Cloud Storage**: For disaster recovery (encrypt first!)

## 📁 File Server Maintenance

### **NostrCheck File Server Monitoring**
```powershell
# Check file server status
curl http://localhost:7006/api/v1/health

# View file server logs
docker logs nostr-files --tail 50

# Monitor file storage usage
docker exec nostr-files du -sh /app/uploads
```

### **File Server Backup**
```powershell
# Backup uploaded files (included in main backup)
Copy-Item -Path ".\data\files" -Destination ".\backup-files-$(Get-Date -Format 'yyyyMMdd')" -Recurse

# Backup file server database
docker exec nostr-files sqlite3 /app/data/nostrcheck.db ".backup /app/data/nostrcheck-backup.db"
```

### **File Server Cleanup**
```powershell
# Clean up old temporary files
docker exec nostr-files find /app/uploads -name "*.tmp" -mtime +1 -delete

# Check for orphaned files (files without database entries)
docker exec nostr-files node /app/scripts/cleanup-orphaned.js

# Compress old files (if enabled)
docker exec nostr-files node /app/scripts/compress-old-files.js
```

### **File Server Configuration Updates**
```powershell
# Update file server settings
# Edit: configs/files/nostrcheck.env
# Then restart:
docker compose restart file-server

# View current configuration
docker exec nostr-files cat /app/.env
```

## Disaster Recovery

### Complete System Recovery
```powershell
# 1. Fresh installation
git clone <your-backup-repo> nostr-relay-suite-recovery
cd nostr-relay-suite-recovery

# 2. Restore from backup
.\scripts\backup.ps1 -Restore -RestoreFrom "path\to\backup.zip"

# 3. Verify restoration
.\scripts\verify.ps1 -Detailed

# 4. Test client connectivity
.\scripts\test-relays.ps1
```

### Partial Recovery (Single Relay)
```powershell
# Stop specific service
docker compose stop nostr-general

# Restore specific data
Copy-Item -Path "backup\data\general" -Destination ".\data\general" -Recurse -Force

# Restart service
docker compose start nostr-general
```

### Configuration Recovery
```powershell
# Restore configurations only
Copy-Item -Path "backup\configs" -Destination ".\configs" -Recurse -Force
Copy-Item -Path "backup\.env" -Destination ".\.env" -Force
Copy-Item -Path "backup\docker-compose.yml" -Destination ".\docker-compose.yml" -Force

# Restart all services
docker compose restart
```

## Monitoring and Alerting

### Key Metrics to Monitor
1. **Container Health**: All containers running and healthy
2. **Disk Usage**: Data directory growth rate
3. **Memory Usage**: Should stay under 256MB per container
4. **Network Connectivity**: All ports responding
5. **Database Integrity**: No corruption errors in logs

### Simple Monitoring Script
```powershell
# Create monitoring.ps1
$issues = @()

# Check container health
$containers = docker compose ps --format json | ConvertFrom-Json
foreach ($container in $containers) {
    if ($container.State -ne "running") {
        $issues += "Container $($container.Name) is not running"
    }
}

# Check disk space
$dataSize = (Get-ChildItem .\data -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
if ($dataSize -gt 10) {  # Alert if over 10GB
    $issues += "Data directory is large: $([math]::Round($dataSize,2)) GB"
}

# Check port connectivity
$ports = @(7001, 7002, 7003, 7004)
foreach ($port in $ports) {
    try {
        $null = Invoke-WebRequest "http://localhost:$port" -TimeoutSec 2 -UseBasicParsing
    } catch {
        $issues += "Port $port not responding"
    }
}

# Report issues
if ($issues.Count -gt 0) {
    Write-Host "⚠️ Issues detected:" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
} else {
    Write-Host "✅ All systems operational" -ForegroundColor Green
}
```

## Performance Optimization

### Database Optimization
- **WAL Mode**: Already enabled for better performance
- **Pragma Settings**: Optimized in config files
- **Regular Vacuuming**: Automated via configuration

### Memory Optimization
```powershell
# Check memory usage
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Adjust memory limits if needed (in docker-compose.yml)
# mem_limit: 512m  # Increase if needed
```

### Network Optimization
- **Localhost Only**: Reduces network overhead
- **Connection Limits**: Set appropriately in configs
- **Rate Limiting**: Prevents abuse

## Troubleshooting Common Issues

### Container Won't Start
```powershell
# Check logs
docker logs nostr-general

# Common fixes:
# 1. Port conflict - change ports in docker-compose.yml
# 2. Permission issue - check data directory permissions
# 3. Config error - validate config.toml syntax
```

### High Memory Usage
```powershell
# Check which container is using memory
docker stats --no-stream

# Solutions:
# 1. Reduce max_connections in config
# 2. Increase memory limit in docker-compose.yml
# 3. Restart containers: docker compose restart
```

### Database Corruption
```powershell
# Stop affected service
docker compose stop nostr-general

# Check database integrity
sqlite3 .\data\general\nostr.db "PRAGMA integrity_check;"

# If corrupted, restore from backup
.\scripts\backup.ps1 -Restore -RestoreFrom "latest-backup.zip"
```

### Slow Performance
```powershell
# Check system resources
Get-Process docker* | Select-Object ProcessName, CPU, WorkingSet

# Optimize:
# 1. Reduce relay connections in clients
# 2. Check Windows Defender exclusions
# 3. Move data to SSD if on HDD
# 4. Increase Docker Desktop resources
```

## Security Maintenance

### Regular Security Tasks
1. **Update Docker Desktop** monthly
2. **Review access logs** for unusual activity
3. **Verify whitelist settings** are current
4. **Check for unauthorized containers**: `docker ps -a`
5. **Review firewall settings** for localhost access only

### Security Monitoring
```powershell
# Check for unauthorized access attempts
docker compose logs | Select-String "unauthorized|denied|failed"

# Verify only whitelisted pubkeys in configs
Select-String -Path "configs\*\*.toml" -Pattern "pubkey_whitelist"

# Check network bindings (should only be 127.0.0.1)
netstat -an | findstr ":700"
```

## Automation with Windows Task Scheduler

### Daily Backup Task
1. Open Task Scheduler
2. Create Basic Task: "Nostr Daily Backup"
3. Trigger: Daily at 2:00 AM
4. Action: Start Program
   - Program: `powershell.exe`
   - Arguments: `-File "C:\path\to\nostr-relay-suite\scripts\backup.ps1" -Compress`

### Weekly Health Check
1. Create Basic Task: "Nostr Health Check"
2. Trigger: Weekly on Sunday at 6:00 AM
3. Action: Start Program
   - Program: `powershell.exe`
   - Arguments: `-File "C:\path\to\nostr-relay-suite\scripts\verify.ps1" -Detailed`

This maintenance guide ensures your private Nostr relay suite remains secure, performant, and reliable for long-term use.
