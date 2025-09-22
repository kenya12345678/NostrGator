---
name: Bug Report
about: Create a report to help us improve NostrGator
title: '[BUG] '
labels: ['bug', 'needs-triage']
assignees: ''
---

## 🐛 Bug Description
A clear and concise description of what the bug is.

## 🔄 Steps to Reproduce
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## ✅ Expected Behavior
A clear and concise description of what you expected to happen.

## ❌ Actual Behavior
A clear and concise description of what actually happened.

## 🖼️ Screenshots
If applicable, add screenshots to help explain your problem.

## 🖥️ Environment
**Desktop/Server:**
- OS: [e.g. Windows 11, Ubuntu 22.04, macOS 13]
- Docker Version: [e.g. 24.0.6]
- NostrGator Version: [e.g. v1.0.0]
- Browser (if applicable): [e.g. Chrome 118, Firefox 119]

**Mobile (if applicable):**
- Device: [e.g. iPhone 14, Samsung Galaxy S23]
- OS: [e.g. iOS 17.1, Android 14]
- Browser: [e.g. Safari, Chrome Mobile]

## 📋 Configuration
**Docker Compose:**
- Are you using the default docker-compose.yml? [Yes/No]
- Any custom environment variables? [List them, excluding sensitive data]

**Services Affected:**
- [ ] General Relay (7001)
- [ ] DM Relay (7002)
- [ ] Media Relay (7003)
- [ ] Social Relay (7004)
- [ ] Cache Relay (7005)
- [ ] File Server (7006)
- [ ] Long-Form Relay (7007)
- [ ] Live Events Relay (7008)
- [ ] Marketplace Relay (7009)
- [ ] Games Relay (7010)
- [ ] Bridge Relay (7011)
- [ ] Event Mirroring
- [ ] NIP-05 Service
- [ ] Federation Engine
- [ ] Monitoring/Prometheus

## 📝 Logs
**Please include relevant logs:**

```bash
# Docker logs (replace 'service-name' with affected service)
docker logs nostr-general --tail 50

# Or for all services
docker compose logs --tail 20
```

**Error Messages:**
```
Paste any error messages here
```

## 🔍 Additional Context
Add any other context about the problem here.

## ✅ Checklist
- [ ] I have read the [troubleshooting guide](docs/troubleshooting.md)
- [ ] I have searched existing issues to avoid duplicates
- [ ] I have included all relevant information above
- [ ] I have tested with the latest version of NostrGator
- [ ] I have included logs and error messages (with sensitive data removed)

## 🤝 Contributing
Would you be interested in contributing a fix for this issue?
- [ ] Yes, I'd like to work on this
- [ ] No, but I'm available for testing
- [ ] No, I just want to report the issue
