# NostrGator Client Configuration Guide

## Overview
This guide shows how to configure popular Nostr clients to use your NostrGator infrastructure with professional file hosting, alongside public relays for optimal performance and privacy.

## Your Private Relay URLs
- **General Relay**: `ws://localhost:7001` (Core notes and feeds)
- **DM Relay**: `ws://localhost:7002` (Private messages)
- **Media Relay**: `ws://localhost:7003` (File uploads and zaps)
- **Social Relay**: `ws://localhost:7004` (Lists and communities)
- **Cache Relay**: `ws://localhost:7005` (High-performance cache)

## Professional File Server
- **Web Dashboard**: `http://localhost:7006` (Management interface)
- **NIP-96 Upload**: Automatic in supported clients
- **Blossom Upload**: Modern protocol support
- **Public Gallery**: `http://localhost:7006/gallery`

## Your Credentials
- **Public Key (npub)**: `npub1example1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdef`
- **Private Key (nsec)**: `nsec1example1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdef`

⚠️ **SECURITY WARNING**: Replace with your actual keys! Only enter your private key (nsec) in trusted Nostr clients. Never share it or put it in configuration files!

## Client Configuration

### iris.to (Web/Desktop)
1. **Access Settings**:
   - Go to [iris.to](https://iris.to)
   - Click Settings (gear icon) → Keys
   - Import your private key if not already done

2. **Configure Relays**:
   - Go to Settings → Network → Relays
   - Add your private relays as **both read and write**:
     ```
ws://localhost:7001  ✓ Read ✓ Write  (General)
     ws://localhost:7002  ✓ Read ✓ Write  (DMs)
     ws://localhost:7003  ✓ Read ✓ Write  (Media)
     ws://localhost:7004  ✓ Read ✓ Write  (Social)
```

3. **Recommended Public Relays** (keep for discovery):
   ```
wss://relay.damus.io        ✓ Read ✓ Write
   wss://nos.lol               ✓ Read ✓ Write
   wss://relay.nostr.band      ✓ Read ✗ Write
   wss://nostr.wine            ✓ Read ✗ Write
```

4. **Optimize Settings**:
   - Settings → Privacy → Enable "Publish to all write relays"
   - Settings → Performance → Set "Max connections" to 8-10

### primal.net (Web/Mobile)
1. **Setup Account**:
   - Go to [primal.net](https://primal.net)
   - Import your nsec key in Settings → Account

2. **Add Private Relays**:
   - Settings → Relays → Add Relay
   - Add each private relay with both read/write enabled
   - Set private relays as "Priority" relays

3. **Configure Relay Strategy**:
   - Primary: Your private relays (fastest, most reliable)
   - Secondary: Public relays (for discovery and backup)

### Damus (iOS)
1. **Import Key**: Settings → Account → Import private key
2. **Add Relays**: Settings → Relays → Add each private relay
3. **Enable Local Network**: iOS Settings → Damus → Local Network (ON)

### Amethyst (Android)
1. **Setup**: Import nsec in Settings → Security
2. **Relays**: Settings → Relays → Add private relays
3. **Network**: Allow local network access in Android settings

## Relay Usage Strategy

### Optimal Configuration
- **Write Priority**: Private relays first, then select public relays
- **Read Strategy**: Private relays for speed, public for discovery
- **DM Strategy**: Use DM relay exclusively for private messages
- **Media Strategy**: Use media relay for uploads, general for metadata

### Performance Tips
1. **Connection Limits**: Don't exceed 10-12 total relay connections
2. **Latency**: Private relays will be much faster (1-5ms vs 100-500ms)
3. **Reliability**: Private relays are under your control (99.9% uptime)
4. **Privacy**: Private relays don't log or share your data

## Testing Your Setup

### Basic Connectivity Test
1. Open your Nostr client
2. Check relay status - all private relays should show "Connected"
3. Post a test note - should appear instantly on private relays

### DM Test
1. Send a DM to yourself or a friend
2. Verify it appears quickly (should be near-instant)
3. Check that DMs are encrypted (NIP-04)

### Media Test
1. Upload an image or file
2. Verify metadata is stored on media relay
3. Test zap functionality (will be mock/local)

## Troubleshooting

### Common Issues

**"Relay not connecting"**
- Ensure your relay suite is running: `docker compose ps`
- Check Windows Firewall isn't blocking localhost connections
- Verify correct URLs (ws:// not wss:// for local)

**"Events not publishing"**
- Check if your pubkey is whitelisted in relay configs
- Verify client has both read AND write permissions
- Try publishing to just one relay first

**"Slow performance"**
- Reduce total relay connections to 8-10
- Prioritize private relays over public ones
- Check Docker resource allocation

**"DMs not working"**
- Ensure DM relay is connected and writable
- Verify NIP-04 encryption is enabled in client
- Check that both sender and receiver use compatible clients

### Diagnostic Commands
```powershell
# Check relay status
docker compose ps

# Test relay connectivity
Test-NetConnection localhost -Port 7001

# View relay logs
docker logs nostr-general --tail 20

# Run full verification
.\scripts\verify.ps1 -Detailed
```

## Advanced Configuration

### Relay Specialization
- **General**: All public notes, replies, reactions
- **DM**: Private messages only (NIP-04)
- **Media**: File metadata, zap receipts (NIP-94, NIP-57)
- **Social**: Follow lists, mute lists, communities (NIP-51)

### Backup Strategy
- Private relays backup your data locally
- Public relays provide redundancy and discovery
- Regular backups: `.\scripts\backup.ps1 -Compress`

### Privacy Considerations
- Private relays see all your activity (but it's YOUR server)
- Public relays provide plausible deniability
- Consider using Tor for public relay connections

## Integration with Existing Relays

Your private relay suite is designed to **complement**, not replace, your existing public relay usage:

1. **Primary Storage**: Private relays store everything locally
2. **Discovery**: Public relays help you find new content and users  
3. **Redundancy**: Events published to both private and public relays
4. **Performance**: Private relays provide instant access to your data

This hybrid approach gives you the best of both worlds: privacy, performance, and connectivity to the broader Nostr network.

## 📁 File Upload Configuration

### **NIP-96 Compatible Clients**
Your NostrGator file server supports both NIP-96 and Blossom protocols:

**Clients with NIP-96 Support:**
- **Amethyst** (Android): Auto-detects NIP-96 servers
- **Nostrudel** (Web): Good NIP-96 support
- **Coracle** (Web): Basic NIP-96 support
- **Damus** (iOS): Limited NIP-96 support

**Configuration Steps:**
1. **Access file server settings** in your client
2. **Add NIP-96 server**: `http://localhost:7006`
3. **Enable automatic uploads** for images/videos
4. **Test upload** - files will be stored locally and served fast

### **Manual File Management**
**Web Dashboard**: `http://localhost:7006`
- Upload files directly through web interface
- Manage your file gallery
- View upload statistics
- Configure file retention policies

**API Endpoints:**
- **Upload**: `POST http://localhost:7006/api/v1/upload`
- **Download**: `GET http://localhost:7006/api/v1/files/{filename}`
- **Gallery**: `http://localhost:7006/gallery`

### **File Upload Benefits**
- **Lightning Fast**: Local storage = instant uploads/downloads
- **Privacy**: Your files never leave your machine
- **No Limits**: Upload as much as your disk space allows
- **Professional**: Full web interface for file management
- **Standards Compliant**: NIP-96 and Blossom protocol support
/scripts/* scripts/
rm -rf temp

# 5. Create data directories
mkdir -p data/{general,dm,media,social,cache,longform,live,marketplace,games,bridge,files,federation,mirror,nip05}
```

### **Service Management**

#### **Linux (systemd)**
```bash
# Create service template
sudo tee /etc/systemd/system/nostrgator@.service > /dev/null <<EOF
[Unit]
Description=NostrGator %i Relay
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/nostrgator
ExecStart=$HOME/nostrgator/bin/nostr-rs-relay --config configs/%i/config.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable services
for service in general dm media social cache longform live marketplace games bridge; do
    sudo systemctl enable nostrgator@$service
    sudo systemctl start nostrgator@$service
done
```

#### **macOS (launchd)**
```bash
# Create service template
for service in general dm media social cache longform live marketplace games bridge; do
    tee ~/Library/LaunchAgents/com.nostrgator.$service.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nostrgator.$service</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/nostrgator/bin/nostr-rs-relay</string>
        <string>--config</string>
        <string>$HOME/nostrgator/configs/$service/config.toml</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$HOME/nostrgator</string>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

    launchctl load ~/Library/LaunchAgents/com.nostrgator.$service.plist
done
```

#### **Windows (NSSM)**
```powershell
# Download NSSM from https://nssm.cc/download
# Extract to C:\nssm

# Install services
$services = @("general", "dm", "media", "social", "cache", "longform", "live", "marketplace", "games", "bridge")
foreach ($service in $services) {
    C:\nssm\nssm.exe install "NostrGator-$service" "C:\nostrgator\bin\nostr-rs-relay.exe"
    C:\nssm\nssm.exe set "NostrGator-$service" Parameters "--config C:\nostrgator\configs\$service\config.toml"
    C:\nssm\nssm.exe set "NostrGator-$service" AppDirectory "C:\nostrgator"
    C:\nssm\nssm.exe start "NostrGator-$service"
}
```

---

## 🔍 Verification

### **Test Core Functionality**
```bash
# Test relay connectivity
curl -H "Accept: application/nostr+json" http://localhost:7001

# Test WebSocket (requires wscat: npm install -g wscat)
wscat -c ws://localhost:7001

# Test all ports
for port in 7001 7002 7003 7004 7005 7007 7008 7009 7010 7011; do
    echo "Testing port $port..."
    curl -s --connect-timeout 2 http://localhost:$port && echo " ✅" || echo " ❌"
done
```

### **Monitor Services**
```bash
# Docker deployment
docker compose ps
docker compose logs --tail=20

# Native deployment (Linux)
systemctl status nostrgator@general
journalctl -u nostrgator@general -f

# Native deployment (macOS)
launchctl list | grep nostrgator

# Native deployment (Windows)
Get-Service NostrGator-*
```

---

## 🎛️ Configuration

### **Environment Variables**
Key settings in `.env`:
```bash
# Your Nostr public key (required)
NOSTR_PUBKEY=npub1your_public_key_here

# Relay settings
RELAY_NAME="Your NostrGator"
RELAY_DESCRIPTION="Personal Nostr infrastructure"

# Security
ENABLE_WHITELIST=true
REQUIRE_AUTH=false

# Federation
ENABLE_SUPERNODE_FED=true
TOR_PROXY_ENABLED=true
```

### **NostrCheck File Server Configuration**
The professional file server uses `configs/files/nostrcheck.env`:
```bash
# File Server Settings
DOMAIN=localhost:7006
MAX_FILE_SIZE=104857600  # 100MB
ALLOWED_FILE_TYPES=image/jpeg,image/png,image/gif,video/mp4,audio/mp3

# Protocol Support
NIP96_ENABLED=true
BLOSSOM_ENABLED=true
NIP05_ENABLED=true

# Features
ENABLE_PUBLIC_UPLOAD=true
ENABLE_PUBLIC_GALLERY=true
ENABLE_AI_MODERATION=false  # Optional AI content filtering
```

### **Port Configuration**
Default ports (customizable in `.env`):
- **7001**: General Relay
- **7002**: DM Relay
- **7003**: Media Relay
- **7004**: Social Relay
- **7005**: Cache Relay
- **7006**: NostrCheck File Server (NIP-96 & Blossom)
- **7007-7011**: Specialized relays
- **9090**: Prometheus metrics
- **3005**: NIP-05 service

---

## 🔧 Maintenance

### **Updates**
```bash
# Docker deployment
docker compose pull
docker compose up -d

# Native deployment
cd ~/nostr-rs-relay
git pull
cargo build --release
cp target/release/nostr-rs-relay ~/nostrgator/bin/
# Restart services
```

### **Backups**
```bash
# Docker deployment
./scripts/backup.ps1  # Windows
./scripts/backup.sh   # Linux/macOS

# Native deployment
tar -czf nostrgator-backup-$(date +%Y%m%d).tar.gz ~/nostrgator/data
```

### **Database Maintenance**
```bash
# Optimize SQLite databases
for db in ~/nostrgator/data/*/*.db; do
    sqlite3 "$db" "VACUUM; PRAGMA optimize;"
done
```

---

## 🆘 Troubleshooting

### **Common Issues**

**Port conflicts:**
```bash
# Find what's using a port
netstat -tulpn | grep :7001  # Linux
lsof -i :7001               # macOS
netstat -ano | findstr :7001 # Windows
```

**Permission issues:**
```bash
# Fix permissions (Linux/macOS)
chmod -R 755 ~/nostrgator/data
chown -R $USER:$USER ~/nostrgator
```

**Service won't start:**
```bash
# Check logs
journalctl -u nostrgator@general -f  # Linux
launchctl log show --predicate 'subsystem contains "nostrgator"' --last 1h  # macOS
Get-EventLog -LogName Application -Source "NostrGator-*" -Newest 10  # Windows
```

### **Performance Tuning**
```bash
# Increase file descriptor limits (Linux)
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network settings
echo "net.core.somaxconn = 65536" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## 🎯 Next Steps

1. **Choose deployment method** (Docker recommended for beginners)
2. **Configure your environment** with your Nostr public key
3. **Start services** and verify connectivity
4. **Configure Nostr clients** with relay URLs
5. **Set up monitoring** and backups
6. **Join the community** for support and updates

---

**Ready to deploy your sovereign Nostr infrastructure!** 🚀

For detailed platform-specific instructions, see:
- **Docker**: This guide's Docker section
- **Native**: `docs/native-installation.md`
- **Client Setup**: `docs/client-setup.md`
- **Troubleshooting**: `docs/troubleshooting.md`
