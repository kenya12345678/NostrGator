#!/usr/bin/env python3
"""
NostrGator NIP-05 Identity Verification Service
DNS-based identity verification and hosting
"""

import json
import yaml
import time
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NIP05Service:
    def __init__(self, config_path):
        self.config = self.load_config(config_path)
        self.app = Flask(__name__)
        self.identity_cache = {}
        self.verification_cache = {}
        
        # Prometheus metrics
        self.http_requests = Counter('nostrgator_nip05_http_requests_total', 'Total HTTP requests', ['method', 'path'])
        self.nip05_requests = Counter('nostrgator_nip05_requests_total', 'Total NIP-05 requests', ['type'])
        self.nip05_verifications = Counter('nostrgator_nip05_verifications_total', 'Total NIP-05 verifications', ['status', 'domain'])
        self.nip05_errors = Counter('nostrgator_nip05_errors_total', 'Total NIP-05 errors', ['type'])
        
        self.setup_routes()
        logger.info('NostrGator NIP-05 Service initialized')
    
    def load_config(self, config_path):
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as error:
            logger.error(f'Failed to load config: {error}')
            # Fallback config
            return {
                'nip05': {'enabled': True, 'server_enabled': True},
                'server': {
                    'domain': 'localhost',
                    'port': 3005,
                    'identities': {
                        'nostrgator': {
                            'pubkey': 'npub1nostrgator123456789abcdef',
                            'relays': ['ws://localhost:7001', 'ws://localhost:7002']
                        }
                    }
                },
                'verification': {'cache_duration_hours': 24}
            }
    
    def setup_routes(self):
        @self.app.before_request
        def log_request():
            logger.info(f"{request.method} {request.path}")
            self.http_requests.labels(method=request.method, path=request.path).inc()
        
        @self.app.route('/.well-known/nostr.json')
        def well_known():
            return self.handle_well_known()
        
        @self.app.route('/api/verify', methods=['POST'])
        def verify_post():
            return self.handle_verification()
        
        @self.app.route('/api/verify/<identifier>')
        def verify_get(identifier):
            return self.handle_verification_get(identifier)
        
        @self.app.route('/api/identities', methods=['GET', 'POST', 'DELETE'])
        def identities():
            if request.method == 'GET':
                return self.handle_list_identities()
            elif request.method == 'POST':
                return self.handle_create_identity()
            elif request.method == 'DELETE':
                return self.handle_delete_identity()
        
        @self.app.route('/health')
        def health():
            return self.handle_health()
        
        @self.app.route('/metrics')
        def metrics():
            return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}
        
        @self.app.route('/')
        def dashboard():
            return self.handle_dashboard()
    
    def handle_well_known(self):
        try:
            identities = self.config.get('server', {}).get('identities', {})
            names = {}
            relays = {}
            
            # Build NIP-05 response
            for name, identity in identities.items():
                pubkey = identity.get('pubkey', '')
                names[name] = pubkey
                if identity.get('relays'):
                    relays[pubkey] = identity['relays']
            
            response = {'names': names}
            if relays:
                response['relays'] = relays
            
            self.nip05_requests.labels(type='well-known').inc()
            return jsonify(response)
            
        except Exception as error:
            logger.error(f'Well-known endpoint error: {error}')
            self.nip05_errors.labels(type='well-known').inc()
            return jsonify({'error': 'Internal server error'}), 500
    
    def handle_verification(self):
        try:
            data = request.get_json()
            identifier = data.get('identifier')
            
            if not identifier or '@' not in identifier:
                return jsonify({
                    'error': 'Invalid identifier format. Expected: name@domain.com'
                }), 400
            
            verification = self.verify_nip05(identifier)
            self.nip05_requests.labels(type='verification').inc()
            
            return jsonify(verification)
            
        except Exception as error:
            logger.error(f'Verification error: {error}')
            self.nip05_errors.labels(type='verification').inc()
            return jsonify({'error': 'Verification failed'}), 500
    
    def handle_verification_get(self, identifier):
        try:
            verification = self.verify_nip05(identifier)
            return jsonify(verification)
        except Exception as error:
            return jsonify({'error': 'Verification failed'}), 500
    
    def verify_nip05(self, identifier):
        # Check cache first
        cached = self.verification_cache.get(identifier)
        cache_duration = self.config.get('verification', {}).get('cache_duration_hours', 24) * 3600
        if cached and time.time() - cached['timestamp'] < cache_duration:
            return cached['result']
        
        name, domain = identifier.split('@', 1)
        
        try:
            verification = {
                'identifier': identifier,
                'domain': domain,
                'name': name,
                'verified': False,
                'pubkey': None,
                'relays': [],
                'trust_level': 0,
                'verified_at': time.strftime('%Y-%m-%dT%H:%M:%SZ'),
                'error': None
            }
            
            # Local verification
            server_domain = self.config.get('server', {}).get('domain', 'localhost')
            if domain in ['localhost', server_domain]:
                identity = self.config.get('server', {}).get('identities', {}).get(name)
                if identity:
                    verification['verified'] = True
                    verification['pubkey'] = identity.get('pubkey', '')
                    verification['relays'] = identity.get('relays', [])
                    verification['trust_level'] = self.get_trust_level(domain)
            else:
                verification['error'] = 'External domain verification not implemented in demo'
            
            # Cache result
            self.verification_cache[identifier] = {
                'result': verification,
                'timestamp': time.time()
            }
            
            status = 'success' if verification['verified'] else 'failed'
            self.nip05_verifications.labels(status=status, domain=domain).inc()
            
            return verification
            
        except Exception as error:
            verification = {
                'identifier': identifier,
                'domain': domain,
                'name': name,
                'verified': False,
                'error': str(error),
                'verified_at': time.strftime('%Y-%m-%dT%H:%M:%SZ')
            }
            
            self.nip05_verifications.labels(status='error', domain=domain).inc()
            return verification
    
    def get_trust_level(self, domain):
        trusted_domains = self.config.get('verification', {}).get('trusted_domains', [])
        if domain in trusted_domains:
            return self.config.get('verification', {}).get('trust_levels', {}).get('verified_domain', 5)
        
        if '.' in domain:
            return self.config.get('verification', {}).get('trust_levels', {}).get('verified_subdomain', 3)
        
        return self.config.get('verification', {}).get('trust_levels', {}).get('unverified', 0)
    
    def handle_create_identity(self):
        try:
            data = request.get_json()
            name = data.get('name')
            pubkey = data.get('pubkey')
            relays = data.get('relays', [])
            
            if not name or not pubkey:
                return jsonify({'error': 'Name and pubkey required'}), 400
            
            return jsonify({
                'success': True,
                'message': 'Identity created (demo mode - not persisted)',
                'identity': {'name': name, 'pubkey': pubkey, 'relays': relays}
            })
            
        except Exception as error:
            return jsonify({'error': 'Failed to create identity'}), 500
    
    def handle_list_identities(self):
        try:
            identities = self.config.get('server', {}).get('identities', {})
            return jsonify({'identities': identities})
        except Exception as error:
            return jsonify({'error': 'Failed to list identities'}), 500
    
    def handle_delete_identity(self):
        try:
            name = request.args.get('name')
            return jsonify({
                'success': True,
                'message': f'Identity {name} deleted (demo mode - not persisted)'
            })
        except Exception as error:
            return jsonify({'error': 'Failed to delete identity'}), 500
    
    def handle_health(self):
        identities_count = len(self.config.get('server', {}).get('identities', {}))
        return jsonify({
            'status': 'healthy',
            'service': 'NostrGator NIP-05',
            'version': '1.0.0',
            'identities_count': identities_count,
            'cache_size': len(self.verification_cache),
            'uptime': time.time()
        })
    
    def handle_dashboard(self):
        identities = self.config.get('server', {}).get('identities', {})
        domain = self.config.get('server', {}).get('domain', 'localhost')
        
        identity_html = ''
        for name, identity in identities.items():
            identity_html += f'''
                <div class="identity">
                    <strong>{name}@{domain}</strong><br>
                    <small>Pubkey: {identity.get('pubkey', 'N/A')}</small><br>
                    <small>Relays: {len(identity.get('relays', []))}</small>
                </div>
            '''
        
        html = f'''
<!DOCTYPE html>
<html>
<head>
    <title>NostrGator NIP-05 Service</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; background: #0a0a0a; color: #00ff88; }}
        .container {{ max-width: 800px; margin: 0 auto; }}
        .header {{ text-align: center; margin-bottom: 40px; }}
        .section {{ margin: 20px 0; padding: 20px; border: 1px solid #00ff88; border-radius: 5px; }}
        .identity {{ margin: 10px 0; padding: 10px; background: rgba(0, 255, 136, 0.1); }}
        .endpoint {{ font-family: monospace; background: #333; padding: 5px; border-radius: 3px; }}
        a {{ color: #00ff88; }}
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
            <p>📊 Identities: {len(identities)}</p>
            <p>🔍 Cache Size: {len(self.verification_cache)}</p>
        </div>
        
        <div class="section">
            <h2>Well-Known Endpoint</h2>
            <p>Access your NIP-05 identities at:</p>
            <p class="endpoint"><a href="/.well-known/nostr.json">/.well-known/nostr.json</a></p>
        </div>
        
        <div class="section">
            <h2>Hosted Identities</h2>
            {identity_html}
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
</html>'''
        
        return html
    
    def start(self):
        port = self.config.get('server', {}).get('port', 3005)
        logger.info(f'NostrGator NIP-05 Service starting on port {port}')
        logger.info(f'Well-known endpoint: http://localhost:{port}/.well-known/nostr.json')
        logger.info(f'Dashboard: http://localhost:{port}/')
        self.app.run(host='0.0.0.0', port=port, debug=False)

# Start the service
if __name__ == '__main__':
    config_path = os.environ.get('NIP05_CONFIG_PATH', '/config/nip05.yml')
    service = NIP05Service(config_path)
    service.start()
