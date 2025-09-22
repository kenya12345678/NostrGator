#!/usr/bin/env node
/**
 * NostrGator NIP-05 Identity Verification Service
 * DNS-based identity verification and hosting
 */

const express = require('express');
const rateLimit = require('express-rate-limit');
const cors = require('cors');
const fs = require('fs');
const yaml = require('js-yaml');
const { createPrometheusMetrics } = require('./metrics');

class NIP05Service {
    constructor(configPath) {
        this.config = this.loadConfig(configPath);
        this.app = express();
        this.identityCache = new Map();
        this.verificationCache = new Map();
        this.metrics = createPrometheusMetrics();
        
        this.setupMiddleware();
        this.setupRoutes();
        
        console.log('NostrGator NIP-05 Service initialized');
    }
    
    loadConfig(configPath) {
        try {
            const configFile = fs.readFileSync(configPath, 'utf8');
            return yaml.load(configFile);
        } catch (error) {
            console.error('Failed to load config:', error.message);
            // Fallback config
            return {
                nip05: { enabled: true, server_enabled: true },
                server: { 
                    domain: 'localhost', 
                    port: 3005,
                    identities: {}
                },
                verification: { cache_duration_hours: 24 }
            };
        }
    }
    
    setupMiddleware() {
        this.app.use(cors());
        this.app.use(express.json());
        
        // Request logging
        this.app.use((req, res, next) => {
            console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
            this.metrics.httpRequests.inc({ method: req.method, path: req.path });
            next();
        });
    }
    
    setupRoutes() {
        // Rate limiting for API endpoints
        const apiLimiter = rateLimit({
            windowMs: 15 * 60 * 1000, // 15 minutes
            max: 100, // Limit each IP to 100 requests per windowMs
            message: {
                error: 'Too many requests from this IP, please try again later.',
                retryAfter: '15 minutes'
            },
            standardHeaders: true,
            legacyHeaders: false,
        });

        const verificationLimiter = rateLimit({
            windowMs: 5 * 60 * 1000, // 5 minutes
            max: 20, // Limit verification requests to 20 per 5 minutes
            message: {
                error: 'Too many verification requests, please try again later.',
                retryAfter: '5 minutes'
            },
            standardHeaders: true,
            legacyHeaders: false,
        });

        // NIP-05 well-known endpoint (no rate limiting for discovery)
        this.app.get('/.well-known/nostr.json', this.handleWellKnown.bind(this));

        // Verification API (with rate limiting)
        this.app.post('/api/verify', verificationLimiter, this.handleVerification.bind(this));
        this.app.get('/api/verify/:identifier', verificationLimiter, this.handleVerificationGet.bind(this));
        
        // Identity management (with rate limiting)
        this.app.post('/api/identities', apiLimiter, this.handleCreateIdentity.bind(this));
        this.app.get('/api/identities', apiLimiter, this.handleListIdentities.bind(this));
        this.app.delete('/api/identities/:name', apiLimiter, this.handleDeleteIdentity.bind(this));
        
        // Health and metrics
        this.app.get('/health', this.handleHealth.bind(this));
        this.app.get('/metrics', this.handleMetrics.bind(this));
        
        // Status dashboard
        this.app.get('/', this.handleDashboard.bind(this));
    }
    
    async handleWellKnown(req, res) {
        try {
            const identities = this.config.server.identities || {};
            const names = {};
            const relays = {};
            
            // Build NIP-05 response
            for (const [name, identity] of Object.entries(identities)) {
                // Convert npub to hex if needed
                let pubkey = identity.pubkey;
                if (pubkey.startsWith('npub1')) {
                    // In production, would use proper bech32 decoding
                    pubkey = identity.pubkey; // Simplified for demo
                }
                
                names[name] = pubkey;
                if (identity.relays) {
                    relays[pubkey] = identity.relays;
                }
            }
            
            const response = { names };
            if (Object.keys(relays).length > 0) {
                response.relays = relays;
            }
            
            this.metrics.nip05Requests.inc({ type: 'well-known' });
            res.json(response);
            
        } catch (error) {
            console.error('Well-known endpoint error:', error);
            this.metrics.nip05Errors.inc({ type: 'well-known' });
            res.status(500).json({ error: 'Internal server error' });
        }
    }
    
    async handleVerification(req, res) {
        try {
            const { identifier } = req.body;
            
            if (!identifier || !identifier.includes('@')) {
                return res.status(400).json({ 
                    error: 'Invalid identifier format. Expected: name@domain.com' 
                });
            }
            
            const verification = await this.verifyNIP05(identifier);
            this.metrics.nip05Requests.inc({ type: 'verification' });
            
            res.json(verification);
            
        } catch (error) {
            console.error('Verification error:', error);
            this.metrics.nip05Errors.inc({ type: 'verification' });
            res.status(500).json({ error: 'Verification failed' });
        }
    }
    
    async handleVerificationGet(req, res) {
        try {
            const { identifier } = req.params;
            const verification = await this.verifyNIP05(identifier);
            res.json(verification);
        } catch (error) {
            res.status(500).json({ error: 'Verification failed' });
        }
    }
    
    async verifyNIP05(identifier) {
        // Check cache first
        const cached = this.verificationCache.get(identifier);
        if (cached && Date.now() - cached.timestamp < this.config.verification.cache_duration_hours * 3600000) {
            return cached.result;
        }
        
        const [name, domain] = identifier.split('@');
        
        try {
            // Fetch NIP-05 data from domain
            const url = `https://${domain}/.well-known/nostr.json`;
            
            // In production, would use proper HTTP client with timeout
            const verification = {
                identifier,
                domain,
                name,
                verified: false,
                pubkey: null,
                relays: [],
                trust_level: 0,
                verified_at: new Date().toISOString(),
                error: null
            };
            
            // Simulate verification (in production, would make actual HTTP request)
            if (domain === 'localhost' || domain === this.config.server.domain) {
                // Local verification
                const identity = this.config.server.identities[name];
                if (identity) {
                    verification.verified = true;
                    verification.pubkey = identity.pubkey;
                    verification.relays = identity.relays || [];
                    verification.trust_level = this.getTrustLevel(domain);
                }
            } else {
                // Would verify against actual domain
                verification.error = 'External domain verification not implemented in demo';
            }
            
            // Cache result
            this.verificationCache.set(identifier, {
                result: verification,
                timestamp: Date.now()
            });
            
            if (verification.verified) {
                this.metrics.nip05Verifications.inc({ status: 'success', domain });
            } else {
                this.metrics.nip05Verifications.inc({ status: 'failed', domain });
            }
            
            return verification;
            
        } catch (error) {
            const verification = {
                identifier,
                domain,
                name,
                verified: false,
                error: error.message,
                verified_at: new Date().toISOString()
            };
            
            this.metrics.nip05Verifications.inc({ status: 'error', domain });
            return verification;
        }
    }
    
    getTrustLevel(domain) {
        const trustedDomains = this.config.verification.trusted_domains || [];
        if (trustedDomains.includes(domain)) {
            return this.config.verification.trust_levels.verified_domain || 5;
        }
        
        if (domain.includes('.')) {
            return this.config.verification.trust_levels.verified_subdomain || 3;
        }
        
        return this.config.verification.trust_levels.unverified || 0;
    }
    
    async handleCreateIdentity(req, res) {
        try {
            const { name, pubkey, relays } = req.body;
            
            if (!name || !pubkey) {
                return res.status(400).json({ error: 'Name and pubkey required' });
            }
            
            // In production, would validate pubkey format and save to persistent storage
            const identity = { pubkey, relays: relays || [] };
            
            res.json({ 
                success: true, 
                message: 'Identity created (demo mode - not persisted)',
                identity: { name, ...identity }
            });
            
        } catch (error) {
            res.status(500).json({ error: 'Failed to create identity' });
        }
    }
    
    async handleListIdentities(req, res) {
        try {
            const identities = this.config.server.identities || {};
            res.json({ identities });
        } catch (error) {
            res.status(500).json({ error: 'Failed to list identities' });
        }
    }
    
    async handleDeleteIdentity(req, res) {
        try {
            const { name } = req.params;
            res.json({ 
                success: true, 
                message: `Identity ${name} deleted (demo mode - not persisted)` 
            });
        } catch (error) {
            res.status(500).json({ error: 'Failed to delete identity' });
        }
    }
    
    async handleHealth(req, res) {
        res.json({
            status: 'healthy',
            service: 'NostrGator NIP-05',
            version: '1.0.0',
            identities_count: Object.keys(this.config.server.identities || {}).length,
            cache_size: this.verificationCache.size,
            uptime: process.uptime()
        });
    }
    
    async handleMetrics(req, res) {
        res.set('Content-Type', 'text/plain');
        res.send(await this.metrics.register.metrics());
    }
    
    async handleDashboard(req, res) {
        const html = `
<!DOCTYPE html>
<html>
<head>
    <title>NostrGator NIP-05 Service</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #0a0a0a; color: #00ff88; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .section { margin: 20px 0; padding: 20px; border: 1px solid #00ff88; border-radius: 5px; }
        .identity { margin: 10px 0; padding: 10px; background: rgba(0, 255, 136, 0.1); }
        .endpoint { font-family: monospace; background: #333; padding: 5px; border-radius: 3px; }
        a { color: #00ff88; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🆔 NostrGator NIP-05 Service</h1>
            <p>DNS-based identity verification for Nostr</p>
        </div>
        
        <div class="section">
            <h2>Service Status</h2>
            <p>✅ NIP-05 Server: Active</p>
            <p>✅ Verification Engine: Running</p>
            <p>📊 Identities: ${Object.keys(this.config.server.identities || {}).length}</p>
            <p>🔍 Cache Size: ${this.verificationCache.size}</p>
        </div>
        
        <div class="section">
            <h2>Well-Known Endpoint</h2>
            <p>Access your NIP-05 identities at:</p>
            <p class="endpoint"><a href="/.well-known/nostr.json">/.well-known/nostr.json</a></p>
        </div>
        
        <div class="section">
            <h2>Hosted Identities</h2>
            ${Object.entries(this.config.server.identities || {}).map(([name, identity]) => `
                <div class="identity">
                    <strong>${name}@${this.config.server.domain}</strong><br>
                    <small>Pubkey: ${identity.pubkey}</small><br>
                    <small>Relays: ${(identity.relays || []).length}</small>
                </div>
            `).join('')}
        </div>
        
        <div class="section">
            <h2>API Endpoints</h2>
            <p><strong>POST /api/verify</strong> - Verify NIP-05 identifier</p>
            <p><strong>GET /api/verify/:identifier</strong> - Get verification status</p>
            <p><strong>GET /api/identities</strong> - List hosted identities</p>
            <p><strong>GET /health</strong> - Service health check</p>
            <p><strong>GET /metrics</strong> - Prometheus metrics</p>
        </div>
    </div>
</body>
</html>`;
        
        res.send(html);
    }
    
    start() {
        const port = this.config.server.port || 3005;
        this.app.listen(port, () => {
            console.log(`NostrGator NIP-05 Service running on port ${port}`);
            console.log(`Well-known endpoint: http://localhost:${port}/.well-known/nostr.json`);
            console.log(`Dashboard: http://localhost:${port}/`);
        });
    }
}

// Simple metrics module (inline for demo)
function createPrometheusMetrics() {
    const client = require('prom-client');
    const register = new client.Registry();
    
    const httpRequests = new client.Counter({
        name: 'nostrgator_nip05_http_requests_total',
        help: 'Total HTTP requests',
        labelNames: ['method', 'path'],
        registers: [register]
    });
    
    const nip05Requests = new client.Counter({
        name: 'nostrgator_nip05_requests_total',
        help: 'Total NIP-05 requests',
        labelNames: ['type'],
        registers: [register]
    });
    
    const nip05Verifications = new client.Counter({
        name: 'nostrgator_nip05_verifications_total',
        help: 'Total NIP-05 verifications',
        labelNames: ['status', 'domain'],
        registers: [register]
    });
    
    const nip05Errors = new client.Counter({
        name: 'nostrgator_nip05_errors_total',
        help: 'Total NIP-05 errors',
        labelNames: ['type'],
        registers: [register]
    });
    
    return {
        register,
        httpRequests,
        nip05Requests,
        nip05Verifications,
        nip05Errors
    };
}

// Start the service
const configPath = process.env.NIP05_CONFIG_PATH || '/config/nip05.yml';
const service = new NIP05Service(configPath);
service.start();
