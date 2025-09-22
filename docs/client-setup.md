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
