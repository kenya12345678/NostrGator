# NostrGator Lightning Wallet Testing Guide

## 🧪 Safe Testing Strategy (No Real Bitcoin Risk)

### 1. Testnet Configuration (ALREADY CONFIGURED)
Your LND is now configured for Bitcoin testnet - completely safe for testing!

**Testnet Benefits:**
- ✅ Free testnet Bitcoin from faucets
- ✅ All Lightning functionality works identically
- ✅ Zero financial risk
- ✅ Reset anytime without loss

### 2. Get Free Testnet Bitcoin
```bash
# Testnet faucets (free Bitcoin for testing):
# https://testnet-faucet.mempool.co/
# https://bitcoinfaucet.uo1.net/
# https://testnet.help/en/btcfaucet/testnet
```

### 3. Testing Workflow
1. **Restart with testnet config:**
   ```powershell
   docker restart nostrgator-lnd
   ```

2. **Create testnet wallet:**
   ```powershell
   .\scripts\setup-wallet-simple.ps1
   ```

3. **Get testnet address:**
   ```powershell
   docker exec nostrgator-lnd lncli newaddress p2wkh
   ```

4. **Fund from faucet** → Use address from step 3

5. **Test Lightning channels:**
   ```powershell
   # Connect to testnet Lightning node
   docker exec nostrgator-lnd lncli connect 03...@testnet-node:9735
   
   # Open channel with testnet sats
   docker exec nostrgator-lnd lncli openchannel 03... 100000
   ```

## 🖥️ User Interface Access

### LNbits Wallet (http://localhost:5000)
**Port Choice:** LNbits uses port 5000 (Flask default) for compatibility with existing documentation and tools.

**What you'll see:**
- Web-based Lightning wallet interface
- Create/manage Lightning invoices
- Send/receive payments
- Extensions for Nostr Wallet Connect (NIP-47)

### Blossom File Server (http://localhost:3000)
**Port Choice:** Blossom uses port 3000 (Node.js/Express standard) for NIP-96 compatibility.

**What you'll see:**
- File upload interface
- NIP-96 compliant API endpoints
- Integration with Nostr clients for media uploads

### Access Test
```powershell
# Test LNbits
Start-Process "http://localhost:5000"

# Test Blossom
Start-Process "http://localhost:3000"
```

## 🔗 Nostr Client Integration

### NIP-47 Nostr Wallet Connect
1. **In LNbits:** Enable "Nostr Wallet Connect" extension
2. **Generate connection string** (nostr+walletconnect://...)
3. **In Nostr client:** Paste connection string
4. **Result:** Client can request Lightning payments through your wallet

### NIP-96 File Storage
1. **Configure client** to use: `http://localhost:3000`
2. **Upload media** in client (images, videos)
3. **Files stored locally** on your Blossom server
4. **Shared via Nostr** with file URLs

### Compatible Clients
- **iris.to**: Add relay + configure NIP-96 server
- **primal.net**: Add relay in settings
- **Damus**: Add relay URL
- **Amethyst**: Configure custom relay

## 📱 Practical Usage Examples

### Example 1: Lightning Payment via Nostr
```
1. Open iris.to or primal.net
2. Connect NIP-47 wallet (from LNbits)
3. Someone posts Lightning invoice
4. Click "Pay" → Your wallet handles payment
5. Notification appears on Windows
6. Backup triggered automatically
```

### Example 2: File Upload
```
1. Open Nostr client
2. Configure NIP-96: http://localhost:3000
3. Attach image to post
4. Image uploads to your Blossom server
5. Post includes your file URL
6. Others see image from your server
```

### Example 3: Backup Testing
```
1. Make Lightning payment
2. Check Windows notifications
3. Verify backup created in:
   - data/backups/encrypted/
   - %USERPROFILE%/NostrGator/Backups/
4. Test restore process
```

## 🌐 Relationship to Nostr Ecosystem

### Your Services as Nostr Apps
**These are infrastructure, not apps:**
- **Relays**: Add to client relay lists
- **NIP-96 Server**: Configure in client settings
- **NIP-47 Wallet**: Connect via wallet connect string

### App Directory Submissions
**Don't submit these services directly.** Instead:
1. **Create a client app** that uses your infrastructure
2. **Submit the client app** to directories
3. **Your infrastructure** powers the app behind the scenes

### Integration Points
- **Relay URLs**: `ws://your-domain:7777`, `ws://your-domain:7778`, etc.
- **File Server**: `http://your-domain:3000` (NIP-96)
- **Wallet Connect**: Generated from LNbits extension

## 🔧 Testing Commands

### Wallet Testing
```powershell
# Check wallet status
docker exec nostrgator-lnd lncli getinfo

# Get new address
docker exec nostrgator-lnd lncli newaddress p2wkh

# Check balance
docker exec nostrgator-lnd lncli walletbalance

# List channels
docker exec nostrgator-lnd lncli listchannels
```

### Service Testing
```powershell
# Monitor all services
.\scripts\monitor-simple.ps1

# Test notifications
.\scripts\test-notifications.ps1

# Check logs
docker logs nostrgator-lnd
docker logs nostrgator-lnbits
docker logs nostrgator-blossom
```

### Backup Testing
```powershell
# Manual backup
.\scripts\backup\auto-backup.ps1

# Check backup locations
ls data\backups\encrypted\
ls $env:USERPROFILE\NostrGator\Backups\
```

## 🚀 Next Steps After Testing

1. **Switch back to mainnet** (edit configs/lnd/lnd.conf)
2. **Create production wallet** with real seed phrase
3. **Fund with small amount** for initial testing
4. **Configure domain/SSL** for public access
5. **Add to Nostr client** relay lists

## ⚠️ Security Reminders

- **Testnet only** for initial testing
- **Small amounts** for mainnet testing
- **Backup seed phrase** securely
- **Test restore process** before large amounts
- **Monitor notifications** for security alerts
