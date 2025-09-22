# Security Guide for Private Nostr Relay Suite

## Security Overview

Your private Nostr relay suite implements multiple layers of security to protect your data and ensure only authorized access to your relays.

## Security Architecture

### Network Security
- **Localhost Binding**: All relays bind only to `127.0.0.1` (localhost)
- **No External Access**: Impossible to access from outside your machine
- **Port Isolation**: Uses non-standard ports (7001-7004) to avoid conflicts
- **No TLS Required**: Localhost traffic doesn't need encryption

### Access Control
- **Public Key Whitelisting**: Only your npub can publish events
- **No Anonymous Access**: All write operations require authentication
- **Read Access**: Currently open for localhost (can be restricted if needed)

### Data Protection
- **Local Storage**: All data remains on your machine
- **SQLite Security**: Database files protected by filesystem permissions
- **No Cloud Dependencies**: Zero external data transmission
- **Backup Encryption**: Recommended for backup files

## Your Credentials Security

### Public Key (npub)
- **Location**: Used in relay configurations for whitelisting
- **Safety**: Safe to share publicly (it's meant to be public)
- **Purpose**: Identifies you on the Nostr network
- **Your Key**: `npub1qs9t3tf2kfz872ns9yp42044dqs2v7v68mwy5mfczmsvcs075luqr7226z`

### Private Key (nsec) - CRITICAL SECURITY
- **Location**: NEVER in configuration files - only in Nostr clients
- **Storage**: Keep in password manager or hardware wallet
- **Sharing**: NEVER share with anyone
- **Usage**: Only enter in trusted Nostr clients for signing
- **Your Key**: `nsec1v6vchas4d0ajz3xtc994rw454dlqtd5u4r58rr2e8jw6qm56m4vqx34x30`

⚠️ **CRITICAL**: If someone gets your private key, they can impersonate you on Nostr!

## Configuration Security

### Environment Variables (.env file)
```
# SECURE: Only contains public key
NOSTR_PUBKEY=npub1qs9t3tf2kfz872ns9yp42044dqs2v7v68mwy5mfczmsvcs075luqr7226z

# NEVER PUT PRIVATE KEY HERE!
# NEVER PUT: NOSTR_PRIVKEY=nsec1...
```

### Relay Configurations
- **Whitelisting**: Only your pubkey can write events
- **Rate Limiting**: Prevents abuse and DoS attacks
- **Connection Limits**: Restricts concurrent connections
- **Event Size Limits**: Prevents oversized event attacks

### Docker Security
- **User Namespaces**: Containers run with limited privileges
- **Network Isolation**: Custom Docker network for relay communication
- **Volume Permissions**: Data directories have restricted access
- **Resource Limits**: Memory and CPU limits prevent resource exhaustion

## File System Security

### Directory Permissions
```powershell
# Recommended permissions (run as Administrator)
icacls ".\data" /grant:r "Users:(OI)(CI)F" /T
icacls ".\configs" /grant:r "Users:(OI)(CI)R" /T
icacls ".\.env" /grant:r "Users:R"
```

### Sensitive Files
- **`.env`**: Contains public key only (safe)
- **`configs/*.toml`**: Contains public key only (safe)
- **`data/*`**: Contains relay databases (protect from unauthorized access)
- **`backups/*`**: Contains full system backup (encrypt for storage)

## Network Security

### Firewall Configuration
```powershell
# Windows Firewall - ensure these rules exist
# Allow Docker Desktop
# Allow localhost traffic (should be default)

# Verify no external binding
netstat -an | findstr ":700" | findstr "0.0.0.0"
# Should return nothing (only 127.0.0.1 bindings allowed)
```

### Port Security
- **7001-7004**: Only bound to localhost
- **No External Exposure**: Ports not accessible from network
- **Docker Internal**: Container-to-container communication secured

## Client Security

### Trusted Clients Only
- **iris.to**: Web-based, open source, generally trusted
- **primal.net**: Established Nostr client with good reputation
- **Damus**: iOS client, open source, well-reviewed
- **Amethyst**: Android client, open source, community-trusted

### Client Configuration Security
```
# SECURE: Use localhost URLs
ws://localhost:7001

# INSECURE: Never use external IPs
# ws://192.168.1.100:7001  ❌
# ws://your-external-ip:7001  ❌
```

### Private Key Handling in Clients
- **Browser Extension Wallets**: Alby, nos2x (recommended)
- **Built-in Storage**: Only in trusted clients
- **Copy/Paste**: Minimize exposure time
- **Screenshots**: Never screenshot private keys

## Backup Security

### Backup Encryption
```powershell
# Encrypt backups before storing externally
# Using 7-Zip with password protection
7z a -p"YourStrongPassword" backup-encrypted.7z .\backups\latest-backup\

# Or use Windows built-in encryption
cipher /e .\backups\
```

### Backup Storage Locations
1. **Local**: `.\backups\` (convenient but single point of failure)
2. **External Drive**: Encrypted, offline storage
3. **Network Storage**: Encrypted, access-controlled
4. **Cloud Storage**: Encrypted before upload, strong passwords

### Backup Verification
```powershell
# Always verify backup integrity
.\scripts\backup.ps1 -Verify -BackupPath "path\to\backup"

# Test restoration periodically
.\scripts\backup.ps1 -Restore -RestoreFrom "test-backup.zip"
```

## Monitoring and Auditing

### Security Monitoring
```powershell
# Check for unauthorized access attempts
docker compose logs | Select-String "unauthorized|denied|failed|error"

# Monitor unusual activity
docker compose logs | Select-String "rate.*limit|too.*many|blocked"

# Check configuration integrity
Get-FileHash .\configs\*\*.toml
```

### Regular Security Checks
```powershell
# Weekly security audit script
$securityIssues = @()

# Check for external bindings
$externalBindings = netstat -an | findstr ":700" | findstr "0.0.0.0"
if ($externalBindings) {
    $securityIssues += "External port bindings detected"
}

# Check for unauthorized containers
$containers = docker ps --format "{{.Names}}"
$authorized = @("nostr-general", "nostr-dm", "nostr-media", "nostr-social")
foreach ($container in $containers) {
    if ($container -notlike "nostr-*" -and $container -notin $authorized) {
        $securityIssues += "Unauthorized container: $container"
    }
}

# Check file permissions
$envFile = Get-Acl ".\.env"
if ($envFile.Access | Where-Object { $_.IdentityReference -like "*Everyone*" -and $_.FileSystemRights -like "*FullControl*" }) {
    $securityIssues += ".env file has overly permissive permissions"
}

# Report issues
if ($securityIssues) {
    Write-Host "⚠️ Security Issues Detected:" -ForegroundColor Red
    $securityIssues | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
} else {
    Write-Host "✅ Security audit passed" -ForegroundColor Green
}
```

## Incident Response

### Suspected Compromise
1. **Immediate Actions**:
   ```powershell
   # Stop all relays
   docker compose down
   
   # Backup current state for analysis
   Copy-Item .\data .\incident-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss') -Recurse
   
   # Check logs for suspicious activity
   docker compose logs > incident-logs.txt
   ```

2. **Investigation**:
   - Review logs for unauthorized access
   - Check for unusual event patterns
   - Verify configuration file integrity
   - Scan for malware

3. **Recovery**:
   ```powershell
   # Restore from known good backup
   .\scripts\backup.ps1 -Restore -RestoreFrom "last-known-good-backup.zip"
   
   # Regenerate keys if necessary (extreme case)
   # Update all client configurations
   ```

### Key Compromise
If your private key is compromised:

1. **Immediate**: Stop using the compromised key
2. **Generate New**: Create new Nostr key pair
3. **Update Configs**: Replace npub in all relay configurations
4. **Notify Network**: Post from new key about the compromise
5. **Revoke Old**: Use NIP-09 deletion events if supported

## Best Practices

### Daily Operations
- Never enter private key in untrusted applications
- Use localhost URLs only in client configurations
- Monitor relay logs for unusual activity
- Keep Docker Desktop updated

### Weekly Maintenance
- Create encrypted backups
- Review security logs
- Check for software updates
- Verify configuration integrity

### Monthly Reviews
- Audit client access patterns
- Review backup procedures
- Update security documentation
- Test incident response procedures

### Emergency Procedures
- Have offline backup of private key
- Know how to quickly shut down relays
- Maintain list of trusted recovery contacts
- Keep incident response checklist updated

## Compliance and Privacy

### Data Residency
- All data remains on your local machine
- No third-party data processing
- Full control over data retention
- GDPR compliance through local storage

### Privacy Protection
- No external logging or analytics
- No data sharing with third parties
- Encrypted DM support (NIP-04)
- Optional event deletion (NIP-09)

### Audit Trail
- All relay activity logged locally
- Backup creation timestamps
- Configuration change tracking
- Client connection logging

This security guide ensures your private Nostr relay suite maintains the highest security standards while providing the performance and privacy benefits of local infrastructure.
