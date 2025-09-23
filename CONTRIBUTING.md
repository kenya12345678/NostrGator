# Contributing to NostrGator

## 🎯 Project Mission

**NostrGator** is a complete sovereign Nostr infrastructure solution designed to provide 100% protocol coverage with complete financial sovereignty. Our mission is to empower individuals and organizations with enterprise-grade Nostr infrastructure that they can own, control, and customize.

### **What NostrGator Provides**
- **20 Specialized Services**: 11 Nostr relays + 9 supporting services
- **Professional File Hosting**: NIP-96 & Blossom protocol support via NostrCheck-server
- **Enterprise Monitoring**: Prometheus metrics and health monitoring
- **Complete Sovereignty**: Local control with global reach via event mirroring
- **Cross-Platform Support**: Docker and native installation on Windows, macOS, Linux
- **Production Ready**: Built with proven open source technologies

### **Our Vision**
To make professional-grade Nostr infrastructure accessible to everyone, from individual users seeking privacy to organizations requiring enterprise-scale decentralized communication.

## 🤝 Community Standards

### **Professional Conduct (Non-Negotiable)**
We maintain a **professional, respectful, and welcoming community** for all contributors. While our maintainer may be "grumpy" in username, our community standards are anything but:

- **Respectful Communication**: Treat all contributors with dignity and respect
- **Constructive Feedback**: Focus on improving the project, not criticizing people
- **Collaborative Problem-Solving**: Work together to find solutions
- **Inclusive Environment**: Welcome contributors of all skill levels and backgrounds
- **Professional Language**: Keep discussions focused and appropriate

### **Zero Tolerance Policy**
**Disruptive behavior will result in immediate blocking.** This includes:
- Personal attacks or harassment
- Discriminatory language or behavior
- Spam or off-topic discussions
- Deliberate disruption of project activities
- Violation of GitHub's Community Guidelines

### **Positive Contribution Culture**
We encourage:
- **Asking Questions**: No question is too basic
- **Sharing Ideas**: Creative solutions and improvements
- **Learning Together**: Helping others learn and grow
- **Quality Focus**: Striving for excellence in all contributions

## 🛠️ How to Contribute

### **Areas Where Contributions Are Welcome**

#### **🔧 Core Development**
- **Relay Optimization**: Performance improvements and bug fixes
- **Service Integration**: New service additions or improvements
- **Configuration Management**: Enhanced setup and deployment tools
- **Cross-Platform Support**: Platform-specific optimizations

#### **📚 Documentation**
- **User Guides**: Client setup, troubleshooting, advanced configuration
- **Developer Documentation**: API documentation, architecture guides
- **Tutorials**: Step-by-step guides for specific use cases
- **Translations**: Multi-language support for global adoption

#### **🧪 Testing & Quality Assurance**
- **Automated Testing**: Unit tests, integration tests, end-to-end tests
- **Performance Testing**: Load testing, benchmarking, optimization
- **Platform Testing**: Cross-platform compatibility verification
- **Security Testing**: Vulnerability assessment and hardening

#### **🎨 User Experience**
- **Installation Improvements**: Simplified setup processes
- **Monitoring Dashboards**: Enhanced metrics and visualization
- **Configuration Tools**: GUI tools for easier management
- **Client Integration**: Better client compatibility and setup guides

#### **🔒 Security & Privacy**
- **Security Audits**: Code review and vulnerability assessment
- **Privacy Enhancements**: Additional anonymity and privacy features
- **Hardening Guides**: Security best practices documentation
- **Compliance**: Regulatory compliance and audit trails

## 📋 GitHub Pull Request Workflow

### **Step 1: Fork the Repository**
```bash
# Click "Fork" on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/NostrGator.git
cd NostrGator

# Add upstream remote
git remote add upstream https://github.com/Grumpified-OGGVCT/NostrGator.git
```

### **Step 2: Create a Feature Branch**
```bash
# Update your main branch
git checkout main
git pull upstream main

# Create a descriptive branch name
git checkout -b feature/your-feature-name
# Examples:
# git checkout -b feature/improve-file-server-performance
# git checkout -b docs/update-client-setup-guide
# git checkout -b fix/relay-connection-timeout
```

### **Step 3: Make Your Changes**
- **Follow our code standards** (see below)
- **Write clear commit messages**
- **Test your changes thoroughly**
- **Update documentation** if needed

### **Step 4: Commit Your Changes**
```bash
# Stage your changes
git add .

# Write a clear, descriptive commit message
git commit -m "feat: improve file server upload performance

- Optimize file chunking for large uploads
- Add progress tracking for better UX
- Update documentation with new limits
- Add tests for upload performance

Closes #123"
```

### **Step 5: Push and Create Pull Request**
```bash
# Push to your fork
git push origin feature/your-feature-name

# Go to GitHub and click "Create Pull Request"
# Fill out the PR template with detailed information
```

### **Step 6: Address Review Feedback**
```bash
# Make requested changes
git add .
git commit -m "address review feedback: update error handling"
git push origin feature/your-feature-name

# PR will automatically update
```

## 📏 Code Standards

### **Code Quality Requirements**
- **Clean Code**: Self-documenting, readable, and maintainable
- **Consistent Style**: Follow existing code patterns and formatting
- **Error Handling**: Robust error handling and graceful degradation
- **Performance**: Consider performance implications of changes
- **Security**: Follow security best practices

### **Testing Requirements**
- **Unit Tests**: Test individual components and functions
- **Integration Tests**: Test service interactions
- **Documentation Tests**: Verify documentation accuracy
- **Manual Testing**: Test changes in real environments

### **Documentation Standards**
- **Code Comments**: Explain complex logic and decisions
- **README Updates**: Update relevant documentation
- **Changelog Entries**: Document user-facing changes
- **API Documentation**: Document any API changes

### **Commit Message Format**
```
type(scope): brief description

Detailed explanation of what and why, not how.
Include any breaking changes or migration notes.

Closes #issue-number
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## 🐛 Issue Reporting

### **Bug Reports**
Use our bug report template and include:
- **Environment**: OS, Docker version, NostrGator version
- **Steps to Reproduce**: Clear, numbered steps
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Logs**: Relevant error messages or logs
- **Screenshots**: If applicable

### **Feature Requests**
Use our feature request template and include:
- **Problem Statement**: What problem does this solve?
- **Proposed Solution**: Your suggested approach
- **Alternatives Considered**: Other options you've thought about
- **Additional Context**: Any other relevant information

### **Security Issues**
**Do not open public issues for security vulnerabilities.**
Email security issues to: [security contact to be added]

## 🚀 Getting Started

### **First-Time Contributors**
1. **Read the documentation**: Start with README.md and DEPLOYMENT.md
2. **Set up your environment**: Follow the installation guide
3. **Look for "good first issue" labels**: These are beginner-friendly
4. **Join discussions**: Participate in issues and discussions
5. **Ask questions**: Don't hesitate to ask for help

### **Development Environment Setup**
```bash
# Clone the repository
git clone https://github.com/Grumpified-OGGVCT/NostrGator.git
cd NostrGator

# Copy environment template
cp .env.example .env

# Start the development environment
docker compose up -d

# Verify everything is working
./scripts/verify.ps1  # Windows
./scripts/verify.sh   # Linux/macOS
```

## 📞 Getting Help

- **GitHub Discussions**: For questions and general discussion
- **GitHub Issues**: For bug reports and feature requests
- **Documentation**: Check docs/ directory for detailed guides
- **Community**: Join the broader Nostr community discussions

## 🎉 Recognition

We value all contributions and will:
- **Credit contributors** in release notes
- **Highlight significant contributions** in project updates
- **Maintain a contributors list** in the repository
- **Celebrate milestones** and achievements together

---

**Thank you for contributing to NostrGator!** Together, we're building the infrastructure for a truly decentralized and sovereign internet. 🚀

*Remember: Great software is built by great communities. Let's make NostrGator both technically excellent and welcoming to all.*
