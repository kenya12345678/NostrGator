# ⚡ Lightning Wallet Setup Guide

## 🎯 Overview
NostrGator includes **Alby Hub**, a self-hosted Lightning wallet with full Nostr Wallet Connect (NWC) support. This guide shows you how to set up and integrate Lightning payments with your Nostr experience.

## 🚀 Quick Start

### 1. Access Alby Hub
After starting NostrGator, open your browser to:
```
http://localhost:7012
```

### 2. Initial Setup
1. **Create New Wallet**: Click "Create New Wallet"
2. **Set Password**: Choose a strong password (this encrypts your seed)
3. **Save Seed Phrase**: Write down your 12-word seed phrase securely
4. **Confirm Seed**: Verify you've saved it correctly

### 3. Lightning Node Configuration
Choose your Lightning backend:

**Option A: Embedded LDK (Recommended for beginners)**
- ✅ No external dependencies
- ✅ Automatic channel management
- ✅ Built-in Lightning Service Provider (LSP)
- ⚠️ Limited to smaller amounts initially

**Option B: External Lightning Node**
- Connect to your own LND, CLN, or other Lightning node
- Requires existing Lightning infrastructure
- Full control over channels and liquidity

## 🔗 Nostr Wallet Connect (NWC) Setup

### Generate NWC Connection String
1. **In Alby Hub**: Go to "Apps" → "Nostr Wallet Connect"
2. **Create Connection**: Click "Create New Connection"
3. **Set Permissions**: Choose what the connection can do:
   - `pay_invoice` - Send payments
   - `get_balance` - Check balance
   - `make_invoice` - Create invoices
   - `lookup_invoice` - Check payment status
4. **Copy Connection String**: Save the `nostr+walletconnect://` string

### Configure Nostr Clients

**Damus (iOS):**
1. Settings → Wallet → Nostr Wallet Connect
2. Paste your NWC connection string
3. Test with a small zap

**Amethyst (Android):**
1. Settings → Zaps → Wallet Connect
2. Add your NWC connection string
3. Enable zaps in posts

**Primal (Web/Mobile):**
1. Settings → Lightning → Connect Wallet
2. Choose "Nostr Wallet Connect"
3. Enter your connection string

**iris.to (Web):**
1. Settings → Lightning Wallet
2. Select "Nostr Wallet Connect"
3. Paste connection string

## 💰 Funding Your Wallet

### Lightning Network
1. **Generate Invoice**: In Alby Hub, click "Receive"
2. **Set Amount**: Enter sats amount
3. **Share Invoice**: Copy the Lightning invoice
4. **Pay from External**: Use another Lightning wallet to pay

### On-Chain Bitcoin
1. **Get Address**: Click "Receive" → "On-chain"
2. **Send Bitcoin**: From any Bitcoin wallet
3. **Auto-Swap**: Alby Hub automatically opens Lightning channels

### Lightning Address
1. **Configure**: Set up your Lightning address (e.g., you@yourdomain.com)
2. **Receive**: Others can send to your Lightning address
3. **Integration**: Works with Nostr profiles and zap addresses

## 🔧 Advanced Configuration

### Channel Management
- **Automatic**: Let Alby Hub manage channels via LSP
- **Manual**: Open channels to specific nodes
- **Liquidity**: Monitor inbound/outbound capacity

### Backup and Recovery
- **Seed Phrase**: Your 12-word seed recovers everything
- **Channel Backups**: Automatically saved to your data directory
- **Export Data**: Regular backups of wallet state

### Security Settings
- **Password Protection**: Required for all operations
- **Connection Limits**: Restrict NWC permissions
- **Spending Limits**: Set maximum amounts per connection

## 🛠️ Integration with NostrGator Services

### Relay Integration
Alby Hub automatically connects to your local NostrGator relays:
- **Primary**: `ws://localhost:7001` (General relay)
- **Backup**: `ws://localhost:7004` (Social relay)
- **DM**: `ws://localhost:7002` (Private messages)

### File Server Integration
- **Paid Uploads**: Charge sats for file uploads
- **Premium Features**: Lightning-gated content access
- **Automatic Payments**: Seamless file hosting payments

### NIP-05 Integration
- **Lightning Address**: Use your NIP-05 domain for Lightning
- **Verification**: Link your Lightning address to your Nostr identity

## 🆘 Troubleshooting

### Common Issues

**"Wallet not connecting"**
- Check Alby Hub is running: `docker ps | grep alby-hub`
- Verify port 7012 is accessible: `curl http://localhost:7012/api/info`
- Restart service: `docker restart nostr-alby-hub`

**"NWC connection failed"**
- Regenerate connection string in Alby Hub
- Check permissions are correctly set
- Verify client supports NWC

**"Payments failing"**
- Check Lightning channel liquidity
- Verify invoice amounts are within limits
- Ensure sufficient balance

### Logs and Debugging
```bash
# Check Alby Hub logs
docker logs nostr-alby-hub --tail=50

# Check container status
docker inspect nostr-alby-hub

# Restart if needed
docker restart nostr-alby-hub
```

## 🔒 Security Best Practices

1. **Seed Phrase Security**
   - Store offline in multiple secure locations
   - Never share or store digitally
   - Test recovery process

2. **Password Security**
   - Use strong, unique password
   - Consider password manager
   - Enable 2FA if available

3. **Connection Management**
   - Limit NWC permissions to minimum needed
   - Regularly review active connections
   - Revoke unused connections

4. **Amount Limits**
   - Set reasonable spending limits
   - Start with small amounts for testing
   - Monitor transaction history

## 📚 Additional Resources

- **Alby Hub Documentation**: https://guides.getalby.com/
- **Lightning Network Basics**: https://lightning.network/
- **Nostr Wallet Connect Spec**: https://nips.nostr.com/47
- **NostrGator Support**: GitHub Issues and Discussions

---

**Your Lightning wallet is now ready for sovereign Nostr payments!** ⚡🚀
