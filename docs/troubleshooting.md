# NostrGator Troubleshooting Guide

## Quick Diagnostics

### First Steps for Any Issue
```powershell
# 1. Check container status
docker compose ps

# 2. Test connectivity
curl -s -w "General: %{http_code} | " http://localhost:7001 -o nul

# 3. Check recent logs
docker compose logs --tail=20

# 4. Run verification
.\scripts\verify.ps1
```

## Common Issues and Solutions

### 1. Containers Not Starting

**Symptoms:**
- `docker compose ps` shows containers as "Exited" or "Restarting"
- Error messages during `docker compose up`

**Diagnostic Commands:**
```powershell
# Check specific container logs
docker logs nostr-general --tail=50

# Check Docker daemon status
docker version

# Check system resources
docker system df
```

**Common Causes & Solutions:**

**Port Conflicts:**
```
Error: "bind: address already in use"
```
**Solution:**
```powershell
# Find what's using the port
netstat -ano | findstr :7001

# Kill the process or change ports in docker-compose.yml
# Edit ports: "127.0.0.1:7005:8080" instead of "127.0.0.1:7001:8080"
```

**Permission Issues:**
```
Error: "permission denied" or "access denied"
```
**Solution:**
```powershell
# Run PowerShell as Administrator
# Or check data directory permissions
icacls .\data /grant Everyone:F /T
```

**Insufficient Resources:**
```
Error: "cannot allocate memory" or "no space left"
```
**Solution:**
```powershell
# Check Docker Desktop resources (Settings > Resources)
# Increase memory allocation to 4GB+
# Clean up Docker: docker system prune -f
```

### 2. Relay Not Responding

**Symptoms:**
- HTTP requests timeout or return errors
- Nostr clients can't connect
- `curl http://localhost:7001` fails

**Diagnostic Steps:**
```powershell
# Test each port individually
Test-NetConnection localhost -Port 7001
Test-NetConnection localhost -Port 7002
Test-NetConnection localhost -Port 7003
Test-NetConnection localhost -Port 7004

# Check if containers are healthy
docker inspect nostr-general --format='{{.State.Health.Status}}'
```

**Solutions:**

**Container Unhealthy:**
```powershell
# Restart specific container
docker restart nostr-general

# Or restart all
docker compose restart
```

**Network Issues:**
```powershell
# Check Windows Firewall
# Allow Docker Desktop through firewall
# Ensure localhost (127.0.0.1) is not blocked
```

**Configuration Errors:**
```powershell
# Validate config syntax
Get-Content .\configs\general\config.toml | Select-String "error"

# Reset to default config if needed
# Copy from backup or recreate
```

### 3. Database Issues

**Symptoms:**
- "database is locked" errors
- "database disk image is malformed"
- Slow query performance

**Diagnostic Commands:**
```powershell
# Check database file sizes
Get-ChildItem .\data\*\*.db | Select-Object Name, Length

# Check for corruption (requires sqlite3)
# sqlite3 .\data\general\nostr.db "PRAGMA integrity_check;"
```

**Solutions:**

**Database Locked:**
```powershell
# Stop all containers
docker compose stop

# Wait 30 seconds for locks to clear
Start-Sleep 30

# Restart
docker compose start
```

**Database Corruption:**
```powershell
# Stop affected service
docker compose stop nostr-general

# Restore from backup
.\scripts\backup.ps1 -Restore -RestoreFrom ".\backups\latest-backup"

# Or delete and recreate (loses data)
# Remove-Item .\data\general\*.db* -Force
# docker compose start nostr-general
```

### 4. Client Connection Issues

**Symptoms:**
- Nostr clients show "disconnected" or "failed to connect"
- Events not publishing or syncing
- Slow response times

**Diagnostic Steps:**
```powershell
# Test WebSocket connectivity
# Use browser dev tools: new WebSocket('ws://localhost:7001')

# Check relay response
curl -H "Accept: application/nostr+json" http://localhost:7001

# Verify client configuration
# Ensure URLs are ws://localhost:XXXX (not wss://)
```

**Solutions:**

**Wrong Protocol:**
- Use `ws://` not `wss://` for local connections
- Ensure port numbers match (7001, 7002, 7003, 7004)

**Whitelist Issues:**
```powershell
# Check if your pubkey is in whitelist
Select-String -Path "configs\*\*.toml" -Pattern "npub1qs9t3tf2kfz872ns9yp42044dqs2v7v68mwy5mfczmsvcs075luqr7226z"

# Temporarily disable whitelist for testing
# Comment out pubkey_whitelist lines in config files
# Restart containers
```

**Rate Limiting:**
```powershell
# Check logs for rate limit messages
docker logs nostr-general | Select-String "rate"

# Increase limits in config.toml:
# messages_per_sec = 200
# max_subscriptions = 50
```

### 5. Performance Issues

**Symptoms:**
- Slow event publishing/retrieval
- High CPU or memory usage
- Timeouts in client applications

**Diagnostic Commands:**
```powershell
# Monitor resource usage
docker stats --no-stream

# Check system performance
Get-Process docker* | Select-Object ProcessName, CPU, WorkingSet

# Check database sizes
Get-ChildItem .\data -Recurse | Measure-Object -Property Length -Sum
```

**Solutions:**

**High Memory Usage:**
```powershell
# Increase memory limits in docker-compose.yml
# mem_limit: 512m

# Or reduce connections in config.toml
# max_conn = 50
# max_conn_per_ip = 5
```

**Slow Database:**
```powershell
# Enable WAL mode (should already be enabled)
# Check pragma settings in config.toml

# Consider moving data to SSD
# Stop containers, move .\data to SSD, create symlink
```

**Network Latency:**
```powershell
# Ensure using localhost, not external IP
# Check Windows Defender real-time protection exclusions
# Add Docker Desktop and workspace folder to exclusions
```

## Error Code Reference

### Docker Compose Errors

**Exit Code 125:** Container configuration error
```powershell
# Check docker-compose.yml syntax
docker compose config

# Validate port mappings and volume mounts
```

**Exit Code 126:** Permission denied
```powershell
# Run as Administrator
# Check file permissions on configs and data directories
```

**Exit Code 127:** Command not found
```powershell
# Update Docker Desktop
# Pull latest images: docker compose pull
```

### Nostr Relay Errors

**"Please use a Nostr client to connect"**
- **Status:** Normal - relay is working correctly
- **Action:** This is the expected HTTP response

**"Connection refused"**
- **Cause:** Container not running or port blocked
- **Solution:** Check `docker compose ps` and firewall settings

**"WebSocket upgrade failed"**
- **Cause:** Proxy or firewall interference
- **Solution:** Ensure direct localhost connection

## Recovery Procedures

### Emergency Recovery
```powershell
# 1. Stop everything
docker compose down

# 2. Backup current state (if possible)
Copy-Item .\data .\emergency-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss') -Recurse

# 3. Reset to known good state
.\scripts\backup.ps1 -Restore -RestoreFrom ".\backups\latest-good-backup"

# 4. Start fresh
docker compose up -d

# 5. Verify
.\scripts\verify.ps1
```

### Partial Recovery (Single Relay)
```powershell
# Stop specific relay
docker compose stop nostr-general

# Clear its data
Remove-Item .\data\general\* -Force

# Restart (will recreate database)
docker compose start nostr-general

# Check logs
docker logs nostr-general --tail=20
```

### Configuration Reset
```powershell
# Backup current configs
Copy-Item .\configs .\configs-backup-$(Get-Date -Format 'yyyyMMdd') -Recurse

# Restore from backup or recreate
# See setup documentation for config recreation
```

## Prevention Best Practices

### Regular Maintenance
1. **Weekly backups:** `.\scripts\backup.ps1 -Compress`
2. **Monthly updates:** `docker compose pull && docker compose up -d`
3. **Log monitoring:** Check for errors weekly
4. **Resource monitoring:** Ensure adequate disk space and memory

### Monitoring Setup
```powershell
# Create simple monitoring script
# Add to Windows Task Scheduler (daily)
$issues = @()

# Check containers
$containers = docker compose ps --format json | ConvertFrom-Json
foreach ($c in $containers) {
    if ($c.State -ne "running") {
        $issues += "Container $($c.Name) not running"
    }
}

# Check connectivity
$ports = @(7001,7002,7003,7004)
foreach ($port in $ports) {
    try {
        Invoke-WebRequest "http://localhost:$port" -TimeoutSec 3 -UseBasicParsing | Out-Null
    } catch {
        $issues += "Port $port not responding"
    }
}

# Alert if issues found
if ($issues) {
    # Send email, write to event log, or create alert file
    $issues | Out-File ".\relay-issues-$(Get-Date -Format 'yyyyMMdd').txt"
}
```

### Security Monitoring
```powershell
# Check for unauthorized access attempts
docker compose logs | Select-String "unauthorized|denied|failed" | Out-File ".\security-log.txt"

# Verify configurations haven't changed
Get-FileHash .\configs\*\*.toml | Export-Csv ".\config-hashes.csv"
```

## Getting Help

### Information to Collect
When seeking help, gather this information:

```powershell
# System info
"Docker Version: $(docker --version)"
"OS: $((Get-WmiObject Win32_OperatingSystem).Caption)"
"PowerShell: $($PSVersionTable.PSVersion)"

# Container status
docker compose ps

# Recent logs
docker compose logs --tail=50

# Configuration check
docker compose config

# Resource usage
docker stats --no-stream
```

### Log Locations
- **Container logs:** `docker logs <container-name>`
- **Compose logs:** `docker compose logs`
- **System logs:** Windows Event Viewer > Applications and Services > Docker Desktop

### Useful Commands for Support
```powershell
# Generate diagnostic report
.\scripts\verify.ps1 -Detailed > diagnostic-report.txt

# Export configuration (remove sensitive data first)
docker compose config > current-config.yml

# Check network connectivity
Test-NetConnection localhost -Port 7001 -InformationLevel Detailed
```

## 📁 File Server Troubleshooting

### **File Server Not Responding**

**Symptoms:**
- `http://localhost:7006` not accessible
- File uploads failing in clients
- NostrCheck dashboard not loading

**Diagnostic Commands:**
```powershell
# Check file server status
docker logs nostr-files --tail 20

# Test file server health
curl http://localhost:7006/api/v1/health

# Check port binding
netstat -an | findstr :7006
```

**Solutions:**
```powershell
# Restart file server
docker compose restart file-server

# Check configuration
docker exec nostr-files cat /app/.env

# Verify file permissions
docker exec nostr-files ls -la /app/uploads
```

### **File Uploads Failing**

**Symptoms:**
- Upload button not working in clients
- "Upload failed" errors
- Files not appearing in gallery

**Diagnostic Steps:**
```powershell
# Check upload directory permissions
docker exec nostr-files ls -la /app/uploads

# Test manual upload
curl -X POST -F "file=@test.jpg" http://localhost:7006/api/v1/upload

# Check file server logs during upload
docker logs nostr-files -f
```

**Solutions:**
```powershell
# Fix upload directory permissions
docker exec nostr-files chmod 755 /app/uploads

# Increase file size limit (edit configs/files/nostrcheck.env)
MAX_FILE_SIZE=209715200  # 200MB

# Restart after config changes
docker compose restart file-server
```

### **NIP-96 Discovery Issues**

**Symptoms:**
- Clients not auto-detecting file server
- Manual file server configuration required

**Diagnostic Commands:**
```powershell
# Test NIP-96 discovery endpoint
curl http://localhost:7006/.well-known/nostr/nip96

# Check if endpoint returns valid JSON
curl -s http://localhost:7006/.well-known/nostr/nip96 | jq .
```

**Solutions:**
```powershell
# Verify NIP-96 is enabled in config
# configs/files/nostrcheck.env should have:
NIP96_ENABLED=true

# Restart file server
docker compose restart file-server
```

### **File Server Database Issues**

**Symptoms:**
- Files upload but don't appear in gallery
- User registration failing
- Database errors in logs

**Diagnostic Commands:**
```powershell
# Check database file
docker exec nostr-files ls -la /app/data/nostrcheck.db

# Test database connectivity
docker exec nostr-files sqlite3 /app/data/nostrcheck.db ".tables"
```

**Solutions:**
```powershell
# Backup and recreate database
docker exec nostr-files cp /app/data/nostrcheck.db /app/data/nostrcheck.db.backup
docker compose restart file-server

# Check database integrity
docker exec nostr-files sqlite3 /app/data/nostrcheck.db "PRAGMA integrity_check;"
```

---

This troubleshooting guide covers the most common issues you'll encounter with your NostrGator infrastructure. Keep it handy for quick reference during any problems.
