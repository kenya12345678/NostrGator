#!/usr/bin/env python3
"""
NostrGator Event Mirroring Engine
Hybrid sovereignty: Local control with global reach
"""

import asyncio
import json
import time
import logging
import yaml
import os
import random
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Set
from dataclasses import dataclass
import aiohttp
import websockets
from prometheus_client import Counter, Histogram, Gauge, start_http_server

# Metrics
EVENTS_MIRRORED = Counter('nostrgator_events_mirrored_total', 'Events mirrored', ['direction', 'relay'])
MIRROR_LATENCY = Histogram('nostrgator_mirror_latency_seconds', 'Mirror operation latency')
MIRROR_ERRORS = Counter('nostrgator_mirror_errors_total', 'Mirror errors', ['type', 'relay'])
ACTIVE_MIRRORS = Gauge('nostrgator_active_mirrors', 'Active mirror connections')

@dataclass
class NostrEvent:
    """Represents a Nostr event"""
    id: str
    pubkey: str
    created_at: int
    kind: int
    tags: List[List[str]]
    content: str
    sig: str

class EventMirrorEngine:
    """Core event mirroring engine for hybrid sovereignty"""
    
    def __init__(self, config_path: str):
        self.config = self._load_config(config_path)
        self.local_connections: Dict[str, websockets.WebSocketServerProtocol] = {}
        self.public_connections: Dict[str, websockets.WebSocketServerProtocol] = {}
        self.mirrored_events: Set[str] = set()
        self.running = False
        
        # Setup logging
        logging.basicConfig(
            level=getattr(logging, self.config['monitoring'].get('log_level', 'INFO').upper()),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('mirror_engine')
        
    def _load_config(self, config_path: str) -> dict:
        """Load mirroring configuration"""
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            self.logger.error(f"Failed to load config: {e}")
            # Fallback minimal config
            return {
                'mirroring': {'enabled': True, 'mode': 'hybrid'},
                'local_relays': [],
                'public_relays': [],
                'monitoring': {'log_level': 'INFO'}
            }
    
    async def start(self):
        """Start the event mirroring engine"""
        if not self.config['mirroring'].get('enabled', False):
            self.logger.info("Event mirroring disabled in config")
            return
            
        self.logger.info("Starting NostrGator Event Mirroring Engine")
        self.running = True
        
        # Start Prometheus metrics server
        start_http_server(9091)
        self.logger.info("Mirror metrics server started on port 9091")
        
        # Start main tasks
        tasks = [
            self._connect_to_relays(),
            self._mirror_outbound_loop(),
            self._mirror_inbound_loop(),
            self._cleanup_loop()
        ]
        
        await asyncio.gather(*tasks)
    
    async def _connect_to_relays(self):
        """Establish connections to local and public relays"""
        # Connect to local relays
        for relay in self.config.get('local_relays', []):
            try:
                await self._connect_local_relay(relay)
            except Exception as e:
                self.logger.error(f"Failed to connect to local relay {relay['url']}: {e}")
        
        # Connect to public relays (with Tor if configured)
        for relay in self.config.get('public_relays', []):
            try:
                await self._connect_public_relay(relay)
            except Exception as e:
                self.logger.error(f"Failed to connect to public relay {relay['url']}: {e}")
    
    async def _connect_local_relay(self, relay_config: dict):
        """Connect to a local relay"""
        url = relay_config['url']
        try:
            # For local relays, direct connection
            ws = await websockets.connect(url)
            self.local_connections[relay_config['name']] = ws
            self.logger.info(f"Connected to local relay: {url}")
            ACTIVE_MIRRORS.inc()
            
            # Start listening for events
            asyncio.create_task(self._listen_local_relay(relay_config['name'], ws))
            
        except Exception as e:
            self.logger.error(f"Local relay connection failed {url}: {e}")
            MIRROR_ERRORS.labels(type='connection', relay=relay_config['name']).inc()
    
    async def _connect_public_relay(self, relay_config: dict):
        """Connect to a public relay (potentially through Tor)"""
        url = relay_config['url']
        try:
            # Use Tor proxy if configured
            if self.config.get('privacy', {}).get('use_tor_proxy', False):
                # Note: websockets doesn't directly support SOCKS proxy
                # In production, would need aiohttp-socks or similar
                self.logger.info(f"Connecting to {url} via Tor proxy")
            
            ws = await websockets.connect(url)
            self.public_connections[relay_config['name']] = ws
            self.logger.info(f"Connected to public relay: {url}")
            ACTIVE_MIRRORS.inc()
            
            # Start listening for events
            asyncio.create_task(self._listen_public_relay(relay_config['name'], ws))
            
        except Exception as e:
            self.logger.error(f"Public relay connection failed {url}: {e}")
            MIRROR_ERRORS.labels(type='connection', relay=relay_config['name']).inc()
    
    async def _listen_local_relay(self, relay_name: str, ws):
        """Listen for events from local relay"""
        try:
            async for message in ws:
                try:
                    data = json.loads(message)
                    if data[0] == "EVENT":
                        event = self._parse_event(data[2])
                        if event and self._should_mirror_outbound(event):
                            await self._mirror_event_outbound(event, relay_name)
                except Exception as e:
                    self.logger.error(f"Error processing local event: {e}")
        except Exception as e:
            self.logger.error(f"Local relay listener error {relay_name}: {e}")
            ACTIVE_MIRRORS.dec()
    
    async def _listen_public_relay(self, relay_name: str, ws):
        """Listen for events from public relay"""
        try:
            # Subscribe to filtered events
            subscription = {
                "kinds": [0, 1, 3, 30023],
                "limit": 100
            }
            
            await ws.send(json.dumps(["REQ", f"mirror_{relay_name}", subscription]))
            
            async for message in ws:
                try:
                    data = json.loads(message)
                    if data[0] == "EVENT":
                        event = self._parse_event(data[2])
                        if event and self._should_mirror_inbound(event):
                            await self._mirror_event_inbound(event, relay_name)
                except Exception as e:
                    self.logger.error(f"Error processing public event: {e}")
        except Exception as e:
            self.logger.error(f"Public relay listener error {relay_name}: {e}")
            ACTIVE_MIRRORS.dec()
    
    def _parse_event(self, event_data: dict) -> Optional[NostrEvent]:
        """Parse raw event data into NostrEvent"""
        try:
            return NostrEvent(
                id=event_data['id'],
                pubkey=event_data['pubkey'],
                created_at=event_data['created_at'],
                kind=event_data['kind'],
                tags=event_data['tags'],
                content=event_data['content'],
                sig=event_data['sig']
            )
        except Exception as e:
            self.logger.error(f"Failed to parse event: {e}")
            return None
    
    def _should_mirror_outbound(self, event: NostrEvent) -> bool:
        """Check if event should be mirrored from local to public"""
        # Check if already mirrored
        if event.id in self.mirrored_events:
            return False
        
        # Check outbound filters
        outbound_filters = self.config.get('event_filters', {}).get('outbound', [])
        for filter_rule in outbound_filters:
            if self._event_matches_filter(event, filter_rule):
                return True
        
        return False
    
    def _should_mirror_inbound(self, event: NostrEvent) -> bool:
        """Check if event should be mirrored from public to local"""
        # Check if already mirrored
        if event.id in self.mirrored_events:
            return False
        
        # Check inbound filters
        inbound_filters = self.config.get('event_filters', {}).get('inbound', [])
        for filter_rule in inbound_filters:
            if self._event_matches_filter(event, filter_rule):
                return True
        
        return False
    
    def _event_matches_filter(self, event: NostrEvent, filter_rule: dict) -> bool:
        """Check if event matches a filter rule"""
        # Check kind
        if 'kind' in filter_rule and event.kind != filter_rule['kind']:
            return False
        
        # Check age
        if 'max_age_hours' in filter_rule:
            max_age = filter_rule['max_age_hours'] * 3600
            if time.time() - event.created_at > max_age:
                return False
        
        # Check authors (simplified - in production would check whitelist/follows)
        if 'authors' in filter_rule:
            if filter_rule['authors'] == 'whitelist':
                # Would check against actual whitelist
                return True
        
        # Check tags
        if 'tags' in filter_rule:
            event_tags = [tag[1] for tag in event.tags if len(tag) > 1 and tag[0] == 't']
            if not any(tag in filter_rule['tags'] for tag in event_tags):
                return False
        
        return True
    
    async def _mirror_event_outbound(self, event: NostrEvent, source_relay: str):
        """Mirror event from local to public relays"""
        start_time = time.time()
        
        for relay_name, ws in self.public_connections.items():
            try:
                # Add privacy delay
                if self.config.get('privacy', {}).get('randomize_timing', False):
                    delay = random.uniform(
                        self.config['privacy'].get('min_delay_seconds', 5),
                        self.config['privacy'].get('max_delay_seconds', 30)
                    )
                    await asyncio.sleep(delay)
                
                # Send event
                event_msg = ["EVENT", {
                    "id": event.id,
                    "pubkey": event.pubkey,
                    "created_at": event.created_at,
                    "kind": event.kind,
                    "tags": event.tags,
                    "content": event.content,
                    "sig": event.sig
                }]
                
                await ws.send(json.dumps(event_msg))
                
                EVENTS_MIRRORED.labels(direction='outbound', relay=relay_name).inc()
                self.logger.debug(f"Mirrored event {event.id} to {relay_name}")
                
            except Exception as e:
                self.logger.error(f"Failed to mirror event to {relay_name}: {e}")
                MIRROR_ERRORS.labels(type='mirror', relay=relay_name).inc()
        
        # Track mirrored event
        self.mirrored_events.add(event.id)
        MIRROR_LATENCY.observe(time.time() - start_time)
    
    async def _mirror_event_inbound(self, event: NostrEvent, source_relay: str):
        """Mirror event from public to local relays"""
        start_time = time.time()
        
        for relay_name, ws in self.local_connections.items():
            try:
                # Send event to local relay
                event_msg = ["EVENT", {
                    "id": event.id,
                    "pubkey": event.pubkey,
                    "created_at": event.created_at,
                    "kind": event.kind,
                    "tags": event.tags,
                    "content": event.content,
                    "sig": event.sig
                }]
                
                await ws.send(json.dumps(event_msg))
                
                EVENTS_MIRRORED.labels(direction='inbound', relay=relay_name).inc()
                self.logger.debug(f"Mirrored event {event.id} from {source_relay} to {relay_name}")
                
            except Exception as e:
                self.logger.error(f"Failed to mirror event to local {relay_name}: {e}")
                MIRROR_ERRORS.labels(type='mirror', relay=relay_name).inc()
        
        # Track mirrored event
        self.mirrored_events.add(event.id)
        MIRROR_LATENCY.observe(time.time() - start_time)
    
    async def _mirror_outbound_loop(self):
        """Main outbound mirroring loop"""
        while self.running:
            try:
                # Outbound mirroring is event-driven via listeners
                await asyncio.sleep(60)
            except Exception as e:
                self.logger.error(f"Outbound mirror loop error: {e}")
                await asyncio.sleep(30)
    
    async def _mirror_inbound_loop(self):
        """Main inbound mirroring loop"""
        while self.running:
            try:
                # Inbound mirroring is event-driven via listeners
                await asyncio.sleep(60)
            except Exception as e:
                self.logger.error(f"Inbound mirror loop error: {e}")
                await asyncio.sleep(30)
    
    async def _cleanup_loop(self):
        """Cleanup old mirrored events"""
        while self.running:
            try:
                cleanup_interval = self.config.get('storage', {}).get('cleanup_interval_hours', 24) * 3600
                await asyncio.sleep(cleanup_interval)
                
                # Clean up old mirrored event IDs
                max_events = self.config.get('storage', {}).get('max_mirror_events', 10000)
                if len(self.mirrored_events) > max_events:
                    # Remove oldest events (simplified - would use proper LRU in production)
                    excess = len(self.mirrored_events) - max_events
                    events_to_remove = list(self.mirrored_events)[:excess]
                    for event_id in events_to_remove:
                        self.mirrored_events.discard(event_id)
                    
                    self.logger.info(f"Cleaned up {excess} old mirrored event IDs")
                
            except Exception as e:
                self.logger.error(f"Cleanup loop error: {e}")
                await asyncio.sleep(3600)

async def main():
    """Main entry point"""
    config_path = os.environ.get('MIRROR_CONFIG_PATH', '/config/mirror.yml')
    
    engine = EventMirrorEngine(config_path)
    await engine.start()

if __name__ == '__main__':
    asyncio.run(main())
