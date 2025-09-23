# NostrGator Alby Hub Configuration

## Overview
Alby Hub provides self-hosted Lightning wallet functionality with Nostr Wallet Connect (NWC) support.

## Access
- **Web UI**: http://localhost:7012
- **API**: http://localhost:7012/api/info

## Initial Setup
1. Start NostrGator: `docker compose up -d`
2. Access Alby Hub at http://localhost:7012
3. Create a new wallet with a strong password
4. Your seed phrase will be encrypted and stored locally
5. Configure Lightning node connection (embedded LDK or external)

## Nostr Wallet Connect (NWC)
- Alby Hub automatically connects to your local NostrGator relays
- Primary relay: ws://localhost:7001 (General relay)
- Backup relays: ws://localhost:7004 (Social), ws://localhost:7002 (DM)
- Generate NWC connection strings in the Alby Hub UI
- Use these in Nostr clients like Damus, Amethyst, etc.

## Features
- ✅ Self-hosted Lightning wallet
- ✅ Nostr Wallet Connect support
- ✅ Local relay integration
- ✅ Encrypted seed storage
- ✅ Web-based management UI
- ✅ Lightning address support
- ✅ Invoice generation and payment
- ✅ Channel management
- ✅ Backup and recovery

## Security
- All data stored locally in `./data/alby-hub/`
- Seed phrase encrypted with your password
- No external dependencies for core functionality
- Localhost-only binding for security

## Backup
Your wallet data is stored in `./data/alby-hub/` and should be backed up regularly.
The most critical file is your encrypted seed - never lose your password!

## Integration with NostrGator
Alby Hub is configured to use your local NostrGator relays for NWC, providing:
- Complete privacy (no external relay dependencies)
- Low latency (local network)
- High reliability (your own infrastructure)
- Full sovereignty (no third-party services)
