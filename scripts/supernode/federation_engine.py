#!/usr/bin/env python3
"""
NostrGator Supernode Federation Engine
Implements trust-based peer discovery with adaptive heartbeats and routing
"""

import asyncio
import json
import time
import logging
import yaml
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
import aiohttp
import websockets
from prometheus_client import Counter, Histogram, Gauge, start_http_server
from visualization_server import VisualizationServer

# Metrics
PEER_DISCOVERY_COUNTER = Counter('nostrgator_peers_discovered_total', 'Total peers discovered')
HEARTBEAT_LATENCY = Histogram('nostrgator_heartbeat_latency_seconds', 'Heartbeat latency')
TRUST_SCORE_GAUGE = Gauge('nostrgator_peer_trust_score', 'Peer trust scores', ['peer_id'])
FEDERATION_EVENTS = Counter('nostrgator_federation_events_total', 'Federation events', ['event_type'])

@dataclass
class SupernodePeer:
    """Represents a discovered supernode peer"""
    relay_url: str
    pubkey: str
    trust_score: int = 0
    last_seen: float = 0
    latency_ms: float = 0
    endorsements: List[str] = None
    geo_hint: str = ""
    features: List[str] = None
    
    def __post_init__(self):
        if self.endorsements is None:
            self.endorsements = []
        if self.features is None:
            self.features = []

class FederationEngine:
    """Core federation engine for supernode discovery and trust management"""
    
    def __init__(self, config_path: str):
        self.config = self._load_config(config_path)
        self.peers: Dict[str, SupernodePeer] = {}
        self.trust_graph: Dict[str, List[str]] = {}
        self.running = False
        self.event_count = 0
        self.visualization_server = VisualizationServer(self)
        
        # Setup logging
        logging.basicConfig(
            level=getattr(logging, self.config['federation'].get('log_level', 'INFO').upper()),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('federation_engine')
        
    def _load_config(self, config_path: str) -> dict:
        """Load federation configuration"""
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            # Fallback config
            return {
                'federation': {'enabled': True, 'supernode_tag': 'nostrgator-supernode'},
                'discovery': {'public_relays': ['wss://relay.damus.io']},
                'heartbeat': {'interval_seconds': 60, 'timeout_seconds': 10},
                'trust': {'endorsement_decay_days': 7, 'min_endorsers': 3}
            }
    
    async def start(self):
        """Start the federation engine"""
        if not self.config['federation'].get('enabled', False):
            self.logger.info("Federation disabled in config")
            return
            
        self.logger.info("Starting NostrGator Supernode Federation Engine")
        self.running = True
        
        # Start Prometheus metrics server
        start_http_server(9090)
        self.logger.info("Prometheus metrics server started on port 9090")
        
        # Start 3D visualization server
        await self.visualization_server.start_server()

        # Start main tasks
        tasks = [
            self._peer_discovery_loop(),
            self._heartbeat_loop(),
            self._trust_maintenance_loop(),
            self._api_server()
        ]
        
        await asyncio.gather(*tasks)
    
    async def _peer_discovery_loop(self):
        """Continuously discover new supernode peers"""
        while self.running:
            try:
                await self._discover_peers()
                FEDERATION_EVENTS.labels(event_type='discovery_cycle').inc()
                self.event_count += 1
                await asyncio.sleep(300)  # Discovery every 5 minutes
            except Exception as e:
                self.logger.error(f"Peer discovery error: {e}")
                await asyncio.sleep(60)
    
    async def _discover_peers(self):
        """Discover supernode peers via NIP-65 events"""
        public_relays = self.config['discovery']['public_relays']
        supernode_tag = self.config['federation']['supernode_tag']
        
        for relay_url in public_relays:
            try:
                # Simulate WebSocket connection and REQ for supernode events
                # In production: Use proper nostr client library
                self.logger.info(f"Discovering peers on {relay_url}")
                
                # Mock discovery - in production, query for kind 10002 events with supernode tag
                mock_peers = [
                    {
                        'relay_url': 'wss://supernode1.nostrgator.net',
                        'pubkey': 'npub1example1',
                        'features': ['content-discovery', 'security-monitor'],
                        'geo_hint': 'US-WEST'
                    },
                    {
                        'relay_url': 'wss://supernode2.nostrgator.net', 
                        'pubkey': 'npub1example2',
                        'features': ['tor-proxy', 'auto-maintenance'],
                        'geo_hint': 'EU-CENTRAL'
                    }
                ]
                
                for peer_data in mock_peers:
                    peer_id = peer_data['pubkey']
                    if peer_id not in self.peers:
                        peer = SupernodePeer(
                            relay_url=peer_data['relay_url'],
                            pubkey=peer_data['pubkey'],
                            features=peer_data.get('features', []),
                            geo_hint=peer_data.get('geo_hint', ''),
                            last_seen=time.time()
                        )
                        self.peers[peer_id] = peer
                        PEER_DISCOVERY_COUNTER.inc()
                        self.logger.info(f"Discovered new peer: {peer.relay_url}")
                        
            except Exception as e:
                self.logger.error(f"Discovery failed for {relay_url}: {e}")
    
    async def _heartbeat_loop(self):
        """Send adaptive heartbeats to known peers"""
        while self.running:
            try:
                await self._send_heartbeats()
                await asyncio.sleep(self.config['heartbeat']['interval_seconds'])
            except Exception as e:
                self.logger.error(f"Heartbeat error: {e}")
                await asyncio.sleep(30)
    
    async def _send_heartbeats(self):
        """Send smart probes to all known peers"""
        for peer_id, peer in self.peers.items():
            try:
                start_time = time.time()
                
                # Simulate smart probe - in production: WebSocket ping with challenge
                await asyncio.sleep(0.01)  # Mock network delay
                
                latency = (time.time() - start_time) * 1000
                peer.latency_ms = latency
                peer.last_seen = time.time()
                
                HEARTBEAT_LATENCY.observe(latency / 1000)
                TRUST_SCORE_GAUGE.labels(peer_id=peer_id).set(peer.trust_score)
                
                self.logger.debug(f"Heartbeat to {peer.relay_url}: {latency:.1f}ms")
                
            except Exception as e:
                self.logger.warning(f"Heartbeat failed for {peer.relay_url}: {e}")
    
    async def _trust_maintenance_loop(self):
        """Maintain trust scores and endorsement decay"""
        while self.running:
            try:
                await self._update_trust_scores()
                await asyncio.sleep(3600)  # Update trust hourly
            except Exception as e:
                self.logger.error(f"Trust maintenance error: {e}")
                await asyncio.sleep(300)
    
    async def _update_trust_scores(self):
        """Update peer trust scores based on endorsements and behavior"""
        decay_threshold = time.time() - (self.config['trust']['endorsement_decay_days'] * 86400)
        
        for peer_id, peer in self.peers.items():
            # Decay old endorsements
            peer.endorsements = [e for e in peer.endorsements if float(e.split('_')[-1]) > decay_threshold]
            
            # Calculate trust score
            base_score = len(peer.endorsements)
            latency_penalty = max(0, (peer.latency_ms - 100) / 100)  # Penalty for >100ms
            uptime_bonus = 1 if (time.time() - peer.last_seen) < 300 else 0  # Recent activity
            
            peer.trust_score = max(0, base_score - latency_penalty + uptime_bonus)
            
            self.logger.debug(f"Updated trust for {peer.relay_url}: {peer.trust_score}")
    
    async def _api_server(self):
        """HTTP API for federation status and control"""
        from aiohttp import web
        
        app = web.Application()
        app.router.add_get('/health', self._health_handler)
        app.router.add_get('/peers', self._peers_handler)
        app.router.add_get('/federation/status', self._federation_status_handler)
        app.router.add_post('/federation/endorse', self._endorse_peer_handler)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', 3002)
        await site.start()
        
        self.logger.info("Federation API server started on port 3002")
        
        # Keep server running
        while self.running:
            await asyncio.sleep(1)
    
    async def _health_handler(self, request):
        """Health check endpoint"""
        return web.json_response({
            'status': 'healthy',
            'peers_count': len(self.peers),
            'federation_enabled': self.config['federation']['enabled'],
            'uptime': time.time()
        })
    
    async def _peers_handler(self, request):
        """Return discovered peers"""
        peers_data = {}
        for peer_id, peer in self.peers.items():
            peers_data[peer_id] = {
                'relay_url': peer.relay_url,
                'trust_score': peer.trust_score,
                'latency_ms': peer.latency_ms,
                'last_seen': peer.last_seen,
                'features': peer.features,
                'geo_hint': peer.geo_hint,
                'endorsements_count': len(peer.endorsements)
            }
        
        return web.json_response({
            'peers': peers_data,
            'total_count': len(self.peers),
            'timestamp': time.time()
        })
    
    async def _federation_status_handler(self, request):
        """Federation overview"""
        trusted_peers = [p for p in self.peers.values() if p.trust_score >= self.config['trust']['min_endorsers']]
        
        return web.json_response({
            'federation': {
                'enabled': self.config['federation']['enabled'],
                'total_peers': len(self.peers),
                'trusted_peers': len(trusted_peers),
                'avg_latency': sum(p.latency_ms for p in self.peers.values()) / len(self.peers) if self.peers else 0,
                'supernode_tag': self.config['federation']['supernode_tag']
            },
            'trust_graph': {
                'nodes': len(self.peers),
                'edges': sum(len(endorsements) for endorsements in self.trust_graph.values()),
                'min_trust_threshold': self.config['trust']['min_endorsers']
            }
        })
    
    async def _endorse_peer_handler(self, request):
        """Endorse a peer (creates trust relationship)"""
        data = await request.json()
        peer_id = data.get('peer_id')
        
        if peer_id in self.peers:
            endorsement = f"nostrgator_endorsement_{time.time()}"
            self.peers[peer_id].endorsements.append(endorsement)
            FEDERATION_EVENTS.labels(event_type='endorsement').inc()
            
            return web.json_response({
                'status': 'endorsed',
                'peer_id': peer_id,
                'new_trust_score': self.peers[peer_id].trust_score
            })
        else:
            return web.json_response({'error': 'Peer not found'}, status=404)

async def main():
    """Main entry point"""
    config_path = os.environ.get('CONFIG_PATH', '/config/federation.yml')
    
    engine = FederationEngine(config_path)
    await engine.start()

if __name__ == '__main__':
    asyncio.run(main())
