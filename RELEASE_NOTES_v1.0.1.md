# 🚀 NostrGator v1.0.1 - Complete Sovereign Nostr Infrastructure With Lightning Wallet!!! 

## ⚡ Major Update - Lightning Wallet Integration

**NostrGator v1.0.1** introduces **Alby Hub Lightning wallet integration**, making NostrGator the first complete Nostr infrastructure solution with built-in Lightning payments and Nostr Wallet Connect (NWC) support!

## 🆕 What's New in v1.0.1

### **⚡ Lightning Wallet (NEW!)**
- **Alby Hub Integration**: Self-hosted Lightning wallet with full sovereignty
- **Nostr Wallet Connect**: Native NWC support for seamless client integration
- **Web Interface**: Complete wallet management at `http://localhost:7012`
- **Local Relay Integration**: Uses your NostrGator relays for NWC communication
- **Multiple Backends**: Embedded LDK or external Lightning node support
- **Lightning Address**: Configure your own Lightning address for payments

### **📚 Enhanced Documentation**
- **Lightning Wallet Setup Guide**: Comprehensive setup and integration guide
- **Client Integration Examples**: Step-by-step NWC setup for popular clients
- **Native Installation**: Lightning wallet deployment for non-Docker setups
- **Updated Architecture**: All documentation reflects 20-service stack

## ✨ Complete Feature Set

### **🏗️ Complete Architecture - 20 Services** *(Updated from 19)*

#### **Core Nostr Relays (11 Services)**
- **General Relay** (Port 7001): All event types, primary hub
- **DM Relay** (Port 7002): Private messages with NIP-04 encryption  
- **Media Relay** (Port 7003): Images, videos, file metadata
- **Social Relay** (Port 7004): Notes, reactions, social interactions
- **Cache Relay** (Port 7005): High-performance local cache
- **File Server** (Port 7006): Professional NostrCheck-server with NIP-96 & Blossom
- **Long-Form Relay** (Port 7007): Articles, blogs, newsletters
- **Live Events Relay** (Port 7008): Streaming, live activities
- **Marketplace Relay** (Port 7009): Commerce, classified ads
- **Games Relay** (Port 7010): Interactive content, gaming
- **Bridge Relay** (Port 7011): Cross-protocol integration

#### **Advanced Services (9 Services)** *(Updated from 8)*
- **Event Mirroring**: Hybrid sovereignty with public relay backup
- **NIP-05 Service**: DNS identity verification (admin@localhost)
- **Federation Engine**: Peer discovery and trust scoring
- **Tor Proxy**: Anonymous federation via SOCKS5
- **Content Discovery**: Search and content recommendation
- **Security Monitor**: Spam filtering and rate limiting
- **Health Monitor**: System health and performance monitoring
- **Alby Hub**: Self-hosted Lightning wallet with NWC *(NEW!)*
- **Watchtower**: Automated container updates

### **⚡ Lightning Wallet Features**
- **Self-Hosted**: Complete control over your Lightning infrastructure
- **Nostr Wallet Connect**: Generate NWC connection strings for any client
- **Multiple Clients**: Works with Damus, Amethyst, Primal, iris.to, and more
- **Lightning Address**: Receive payments via your Lightning address
- **Channel Management**: Automatic or manual Lightning channel management
- **Backup & Recovery**: Secure seed phrase and channel backup system
- **Local Integration**: Uses your NostrGator relays for maximum privacy

### **📁 Professional File Server**
- **NostrCheck-server**: Enterprise-grade file hosting solution
- **NIP-96 Protocol**: Standard Nostr file uploads with auto-detection
- **Blossom Protocol**: Modern, efficient file storage standard
- **Web Dashboard**: Complete management interface at `http://localhost:7006`
- **Public Gallery**: File showcase at `http://localhost:7006/gallery`
- **Lightning Integration**: Ready for Lightning-gated file access

### **📊 Enterprise Monitoring**
- **Prometheus Metrics**: Industry-standard monitoring and alerting
- **Health Monitoring**: Real-time service health and performance tracking
- **Lightning Metrics**: Monitor wallet performance and channel status
- **Web Interface**: Metrics dashboard at `http://localhost:9090`
- **Custom Metrics**: NostrGator-specific performance indicators

## 🌟 Key Features

### **⚡ Lightning Integration**
- **Complete Sovereignty**: Self-hosted Lightning wallet with no external dependencies
- **Nostr Wallet Connect**: Native NWC support for seamless zapping
- **Client Compatibility**: Works with all major Nostr clients
- **Local Privacy**: All NWC communication uses your local relays
- **Easy Setup**: One-click wallet creation and configuration

### **🔄 Enhanced Sovereignty**
- **Financial Sovereignty**: Control your own Lightning infrastructure
- **Data Sovereignty**: All relay and wallet data stored locally
- **Communication Sovereignty**: Private NWC using local relays
- **Identity Sovereignty**: NIP-05 verification with your domain

### **📦 Production Ready**
- **Proven Technologies**: Built with battle-tested open source components
- **Lightning Ready**: Alby Hub provides enterprise-grade Lightning functionality
- **One-Command Deploy**: Automated setup including Lightning wallet
- **Cross-Platform**: Windows, macOS, and Linux support

## 🛠️ Technical Specifications

### **System Requirements**
- **Memory**: 2GB RAM minimum, 4GB recommended *(unchanged)*
- **Storage**: 5GB free disk space minimum *(unchanged)*
- **Platform**: Windows 10+, macOS 10.15+, Ubuntu 20.04+ *(unchanged)*
- **Docker**: Docker Desktop 20.10+ or Docker Engine 20.10+ *(unchanged)*

### **New Lightning Requirements**
- **Additional Memory**: +512MB for Alby Hub Lightning wallet
- **Network**: Internet connection for Lightning Network operations
- **Ports**: Port 7012 for Lightning wallet web interface

### **Technology Stack** *(Updated)*
- **Relay Software**: nostr-rs-relay (Rust) + strfry (C++)
- **File Server**: nostrcheck-server (TypeScript/Node.js)
- **Lightning Wallet**: Alby Hub (Go) *(NEW!)*
- **Database**: SQLite with WAL mode
- **Monitoring**: Prometheus + custom metrics
- **Orchestration**: Docker Compose

## 📚 Updated Documentation

### **New Guides**
- **docs/lightning-wallet-setup.md**: Complete Lightning wallet setup and NWC integration *(NEW!)*
- **Updated README.md**: Reflects 20-service architecture with Lightning features
- **Updated Setup Scripts**: Include Lightning wallet in monitoring and verification

### **Enhanced Guides**
- **docs/native-installation.md**: Added Alby Hub deployment instructions
- **Environment Configuration**: Added Lightning wallet configuration variables
- **Client Setup**: Updated with NWC integration examples

## 🚀 Installation & Upgrade

### **Fresh Installation**
```bash
# Clone the repository
git clone https://github.com/Grumpified-OGGVCT/NostrGator.git
cd NostrGator

# Copy environment template
cp .env.example .env

# Start all 20 services (including Lightning wallet)
docker compose up -d

# Verify installation
./scripts/verify.ps1  # Windows
./scripts/verify.sh   # Linux/macOS
```

### **Upgrade from v1.0.0**
```bash
# Pull latest changes
git pull origin main

# Update Docker images
docker compose pull

# Restart with new Lightning wallet
docker compose up -d

# Setup Lightning wallet
# Open http://localhost:7012 and follow setup wizard
```

### **Lightning Wallet Setup**
1. **Access Alby Hub**: Open `http://localhost:7012`
2. **Create Wallet**: Set strong password and save seed phrase
3. **Configure Lightning**: Choose embedded LDK or external node
4. **Generate NWC**: Create connection strings for your Nostr clients
5. **Test Payments**: Send/receive small amounts to verify functionality

## 🔮 What's Next

### **Planned Features**
- **Enhanced Lightning Features**: Advanced channel management and routing
- **Payment Integration**: Lightning-gated file uploads and premium features
- **Multi-tenancy Support**: Host multiple domains on one instance
- **Performance Optimizations**: Even faster response times and lower resource usage

### **Community Goals**
- **nostrapps.com Directory**: Submit to official Nostr apps directory
- **Lightning Network Growth**: Contribute to Lightning adoption in Nostr
- **Educational Content**: Lightning and NWC tutorials and best practices

## 🙏 Credits & Attribution

NostrGator v1.0.1 adds Lightning capabilities thanks to:

- **[Alby Hub](https://github.com/getAlby/hub)** by @getAlby - Self-hosted Lightning wallet
- **[nostr-rs-relay](https://github.com/scsibug/nostr-rs-relay)** by @scsibug - Core relay technology
- **[nostrcheck-server](https://github.com/quentintaranpino/nostrcheck-server)** by @quentintaranpino - Professional file server
- **The Lightning Network** - Enabling instant Bitcoin payments
- **The Nostr Protocol** by @fiatjaf and the Nostr community
- **Open Source Community** - All the developers who make this possible

## 📞 Support & Community

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community discussion
- **Lightning Support**: docs/lightning-wallet-setup.md for wallet issues
- **Nostr Community**: Join the broader Nostr ecosystem discussions

## 📄 License

NostrGator remains under the **MIT License**, ensuring it stays free and open source forever.

---

**🎉 Welcome to NostrGator v1.0.1!**

*Now with Lightning wallet integration - Experience complete Nostr and Lightning sovereignty with the most comprehensive infrastructure solution available.*

**Financial freedom meets communication freedom.** ⚡🗽
