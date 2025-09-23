# 🔧 NostrGator Native Installation Guide

## 🎯 Overview
This guide shows how to run NostrGator **without Docker** on Linux, macOS, and Windows. While Docker is recommended for ease of use, native installation gives you maximum control and performance.

## 📋 Prerequisites by Platform

### **Linux (Ubuntu/Debian)**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl build-essential pkg-config libssl-dev sqlite3 nginx git

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

### **macOS**
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install rust sqlite nginx git python3 node

# Verify installations
rustc --version
sqlite3 --version
nginx -v
```

### **Windows**
```powershell
# Install Rust (download from https://rustup.rs/)
# Or use winget:
winget install Rustlang.Rustup

# Install Git
winget install Git.Git

# Install SQLite (download from https://sqlite.org/download.html)
# Install nginx (download from http://nginx.org/en/download.html)

# Verify installations
rustc --version
git --version
```

## 🏗️ Core Relay Installation

### **1. Clone and Build nostr-rs-relay**
```bash
# Clone the main relay software
git clone https://github.com/scsibug/nostr-rs-relay.git
cd nostr-rs-relay

# Build optimized release
cargo build --release

# The binary will be at: target/release/nostr-rs-relay
```

### **2. Create Directory Structure**
```bash
# Create NostrGator directory
mkdir -p ~/nostrgator/{configs,data,logs,scripts}
cd ~/nostrgator

# Copy the relay binary
cp ~/nostr-rs-relay/target/release/nostr-rs-relay ./

# Create data directories for each relay
mkdir -p data/{general,dm,media,social,cache,longform,live,marketplace,games,bridge}
```

### **3. Configuration Files**
Copy the configuration files from the NostrGator repository:

```bash
# Clone NostrGator configs
git clone https://github.com/yourusername/nostrgator.git temp-nostrgator
cp -r temp-nostrgator/configs/* configs/
rm -rf temp-nostrgator

# Make configs writable
chmod 644 configs/*/*.toml
```

## 🚀 Service Setup by Platform

### **Linux (systemd)**

Create service files for each relay:

```bash
# Create service file for general relay
sudo tee /etc/systemd/system/nostrgator-general.service > /dev/null <<EOF
[Unit]
Description=NostrGator General Relay
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/nostrgator
ExecStart=$HOME/nostrgator/nostr-rs-relay --config configs/general/config.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable nostrgator-general
sudo systemctl start nostrgator-general
```

**Repeat for all 11 relays**, changing the service name and config path.

### **macOS (launchd)**

Create plist files for each relay:

```bash
# Create plist for general relay
tee ~/Library/LaunchAgents/com.nostrgator.general.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nostrgator.general</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/nostrgator/nostr-rs-relay</string>
        <string>--config</string>
        <string>$HOME/nostrgator/configs/general/config.toml</string>
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

# Load and start
launchctl load ~/Library/LaunchAgents/com.nostrgator.general.plist
launchctl start com.nostrgator.general
```

### **Windows (NSSM - Non-Sucking Service Manager)**

```powershell
# Download and install NSSM
# https://nssm.cc/download

# Install general relay as service
nssm install NostrGator-General "C:\nostrgator\nostr-rs-relay.exe"
nssm set NostrGator-General Parameters "--config C:\nostrgator\configs\general\config.toml"
nssm set NostrGator-General AppDirectory "C:\nostrgator"
nssm set NostrGator-General Start SERVICE_AUTO_START

# Start the service
nssm start NostrGator-General
```

## 🔧 Advanced Services Setup

### **Event Mirroring Service**
```bash
# Install Python dependencies
pip3 install websockets prometheus_client pyyaml

# Create mirror service
tee ~/nostrgator/event-mirror.py > /dev/null <<'EOF'
# Copy the event-mirror script from scripts/event-mirror/mirror_engine.py
# Modify paths to use ~/nostrgator/configs/event-mirror/mirror.yml
EOF

# Run as service (Linux systemd example)
sudo tee /etc/systemd/system/nostrgator-mirror.service > /dev/null <<EOF
[Unit]
Description=NostrGator Event Mirror
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/nostrgator
ExecStart=/usr/bin/python3 event-mirror.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

### **NIP-05 Service**
```bash
# Install Node.js dependencies
npm init -y
npm install express cors

# Create NIP-05 service
tee ~/nostrgator/nip05-server.js > /dev/null <<'EOF'
// Copy the NIP-05 server from scripts/nip05/nip05_server.js
// Modify to use local config files
EOF

# Run as service (similar to above)
```

### **Professional File Server (NostrCheck)**
```bash
# Clone and build NostrCheck server
git clone https://github.com/quentintaranpino/nostrcheck-server.git
cd nostrcheck-server

# Install dependencies
npm install

# Build the application
npm run build

# Copy to NostrGator directory
cp -r . ~/nostrgator/nostrcheck-server/
cd ~/nostrgator

# Create configuration
cp configs/files/nostrcheck.env nostrcheck-server/.env

# Create data directories
mkdir -p data/files/{uploads,database}

# Install as service (Linux systemd example)
sudo tee /etc/systemd/system/nostrgator-fileserver.service > /dev/null <<EOF
[Unit]
Description=NostrGator File Server (NostrCheck)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/nostrgator/nostrcheck-server
ExecStart=/usr/bin/node dist/index.js
Environment=NODE_ENV=production
Environment=PORT=7006
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable nostrgator-fileserver
sudo systemctl start nostrgator-fileserver
```

## 📊 Monitoring Setup

### **Prometheus (Optional)**
```bash
# Download Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xzf prometheus-2.45.0.linux-amd64.tar.gz
mv prometheus-2.45.0.linux-amd64 prometheus

# Configure prometheus.yml
tee prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'nostrgator-federation'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'nostrgator-mirror'
    static_configs:
      - targets: ['localhost:9091']
EOF

# Run Prometheus
./prometheus/prometheus --config.file=prometheus/prometheus.yml
```

## 🔧 Management Scripts

### **Linux/macOS Start Script**
```bash
tee ~/nostrgator/start-all.sh > /dev/null <<'EOF'
#!/bin/bash
echo "Starting NostrGator services..."

# Start all relay services
for service in general dm media social cache longform live marketplace games bridge; do
    echo "Starting $service relay..."
    systemctl --user start nostrgator-$service
done

# Start advanced services
systemctl --user start nostrgator-mirror
systemctl --user start nostrgator-nip05

echo "NostrGator started successfully!"
EOF

chmod +x ~/nostrgator/start-all.sh
```

### **Windows Start Script**
```powershell
# Create start-all.ps1
@"
Write-Host "Starting NostrGator services..."

# Start all relay services
$services = @("General", "DM", "Media", "Social", "Cache", "Longform", "Live", "Marketplace", "Games", "Bridge")
foreach ($service in $services) {
    Write-Host "Starting $service relay..."
    Start-Service "NostrGator-$service"
}

Write-Host "NostrGator started successfully!"
"@ | Out-File -FilePath "C:\nostrgator\start-all.ps1" -Encoding UTF8
```

## 🔍 Verification

### **Test Relay Connectivity**
```bash
# Test general relay
curl -H "Accept: application/nostr+json" http://localhost:7001

# Test WebSocket connection
wscat -c ws://localhost:7001

# Check all ports
for port in 7001 7002 7003 7004 7005 7006 7007 7008 7009 7010 7011; do
    echo "Testing port $port..."
    curl -s http://localhost:$port || echo "Port $port not responding"
done
```

## 🚨 Troubleshooting

### **Common Issues**

**Port conflicts:**
```bash
# Check what's using a port
sudo netstat -tulpn | grep :7001
# or
sudo lsof -i :7001
```

**Permission issues:**
```bash
# Fix data directory permissions
chmod -R 755 ~/nostrgator/data
chown -R $USER:$USER ~/nostrgator
```

**Service not starting:**
```bash
# Check service logs (Linux)
journalctl -u nostrgator-general -f

# Check service status
systemctl status nostrgator-general
```

## 📈 Performance Tuning

### **System Limits**
```bash
# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Increase connection limits
echo "net.core.somaxconn = 65536" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### **Database Optimization**
```bash
# Create database maintenance script
tee ~/nostrgator/db-maintenance.sh > /dev/null <<'EOF'
#!/bin/bash
for db in data/*/*.db; do
    echo "Optimizing $db..."
    sqlite3 "$db" "VACUUM; PRAGMA optimize;"
done
EOF

chmod +x ~/nostrgator/db-maintenance.sh

# Add to crontab for daily maintenance
echo "0 2 * * * $HOME/nostrgator/db-maintenance.sh" | crontab -
```

## ⚡ Lightning Wallet Setup (Alby Hub)

### **Download and Install Alby Hub**

**Linux/macOS:**
```bash
# Download latest Alby Hub release
curl -L https://github.com/getAlby/hub/releases/latest/download/alby-hub-linux-amd64.tar.gz -o alby-hub.tar.gz
tar -xzf alby-hub.tar.gz
sudo mv alby-hub /usr/local/bin/

# Create data directory
mkdir -p ~/nostrgator/data/alby-hub

# Create systemd service
sudo tee /etc/systemd/system/alby-hub.service > /dev/null <<EOF
[Unit]
Description=Alby Hub Lightning Wallet
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/nostrgator/data/alby-hub
ExecStart=/usr/local/bin/alby-hub
Environment=PORT=7012
Environment=WORK_DIR=$HOME/nostrgator/data/alby-hub
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl enable alby-hub
sudo systemctl start alby-hub
```

**Windows:**
```powershell
# Download from GitHub releases page
# https://github.com/getAlby/hub/releases/latest

# Extract to C:\nostrgator\alby-hub\
# Create data directory
New-Item -ItemType Directory -Path "C:\nostrgator\data\alby-hub" -Force

# Install as Windows service using NSSM
nssm install AlbyHub "C:\nostrgator\alby-hub\alby-hub.exe"
nssm set AlbyHub AppDirectory "C:\nostrgator\data\alby-hub"
nssm set AlbyHub AppEnvironmentExtra "PORT=7012" "WORK_DIR=C:\nostrgator\data\alby-hub"
nssm start AlbyHub
```

### **Configure Alby Hub**
1. **Access Web Interface**: Open `http://localhost:7012`
2. **Create Wallet**: Set a strong password
3. **Backup Seed**: Save your seed phrase securely
4. **Configure Lightning**: Choose embedded LDK or external node
5. **Generate NWC**: Create Nostr Wallet Connect strings for clients

## 🎯 Next Steps

1. **Start with core relays** (general, dm, media, social, cache)
2. **Test with a Nostr client** using `ws://localhost:7001`
3. **Add advanced services** as needed
4. **Set up monitoring** with Prometheus
5. **Configure backups** for data directories

## 🆘 Getting Help

- **Logs**: Check service logs for error messages
- **Community**: Join GitHub discussions
- **Documentation**: Refer to individual service documentation
- **Docker Alternative**: Consider using Docker if native setup is complex

---

**Native installation gives you maximum control over your NostrGator deployment!** 🚀
