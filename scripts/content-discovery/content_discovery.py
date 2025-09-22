#!/usr/bin/env python3
"""
Nostr Content Discovery Service
Intelligent content caching from public Nostr relays with quality filtering
"""

import asyncio
import json
import logging
import time
import yaml
import websockets
import aiohttp
from datetime import datetime, timedelta
from typing import Dict, List, Set, Optional
import hashlib
import os
import signal
import sys
from dataclasses import dataclass
from collections import defaultdict

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('content-discovery')

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
    
    @classmethod
    def from_dict(cls, data: dict):
        return cls(**data)
    
    def to_dict(self) -> dict:
        return {
            'id': self.id,
            'pubkey': self.pubkey,
            'created_at': self.created_at,
            'kind': self.kind,
            'tags': self.tags,
            'content': self.content,
            'sig': self.sig
        }

class ContentFilter:
    """Content quality and spam filtering"""
    
    def __init__(self, config: dict):
        self.config = config
        self.blacklisted_words = set(config.get('blacklisted_words', []))
        self.blacklisted_domains = set(config.get('blacklisted_domains', []))
        self.min_reactions = config.get('min_reactions', 5)
        self.max_content_length = config.get('max_content_length', 10000)
        
    def is_quality_content(self, event: NostrEvent, metadata: dict = None) -> bool:
        """Check if content meets quality standards"""
        
        # Content length check
        if len(event.content) > self.max_content_length:
            return False
            
        # Spam word detection
        content_lower = event.content.lower()
        for word in self.blacklisted_words:
            if word.lower() in content_lower:
                logger.debug(f"Filtered event {event.id}: contains blacklisted word '{word}'")
                return False
                
        # Domain blacklist check
        for domain in self.blacklisted_domains:
            if domain in event.content:
                logger.debug(f"Filtered event {event.id}: contains blacklisted domain '{domain}'")
                return False
                
        # Engagement check (if metadata available)
        if metadata:
            reactions = metadata.get('reactions', 0)
            if reactions < self.min_reactions:
                return False
                
        return True

class RelayConnection:
    """Manages connection to a Nostr relay"""
    
    def __init__(self, url: str, config: dict):
        self.url = url
        self.config = config
        self.websocket = None
        self.subscription_id = None
        
    async def connect(self):
        """Connect to the relay"""
        try:
            self.websocket = await websockets.connect(self.url)
            logger.info(f"Connected to relay: {self.url}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to {self.url}: {e}")
            return False
            
    async def disconnect(self):
        """Disconnect from the relay"""
        if self.websocket:
            await self.websocket.close()
            self.websocket = None
            
    async def subscribe(self, filters: List[dict]) -> str:
        """Subscribe to events with filters"""
        if not self.websocket:
            return None
            
        sub_id = f"content_discovery_{int(time.time())}"
        subscription = ["REQ", sub_id] + filters
        
        try:
            await self.websocket.send(json.dumps(subscription))
            self.subscription_id = sub_id
            logger.info(f"Subscribed to {self.url} with filters: {filters}")
            return sub_id
        except Exception as e:
            logger.error(f"Failed to subscribe to {self.url}: {e}")
            return None
            
    async def get_events(self, limit: int = 100) -> List[NostrEvent]:
        """Get events from subscription"""
        events = []
        
        if not self.websocket:
            return events
            
        try:
            # Set a timeout for receiving events
            timeout = 30  # 30 seconds
            start_time = time.time()
            
            while len(events) < limit and (time.time() - start_time) < timeout:
                try:
                    message = await asyncio.wait_for(self.websocket.recv(), timeout=5)
                    data = json.loads(message)
                    
                    if data[0] == "EVENT" and data[1] == self.subscription_id:
                        event = NostrEvent.from_dict(data[2])
                        events.append(event)
                    elif data[0] == "EOSE":  # End of stored events
                        break
                        
                except asyncio.TimeoutError:
                    continue
                    
        except Exception as e:
            logger.error(f"Error receiving events from {self.url}: {e}")
            
        logger.info(f"Received {len(events)} events from {self.url}")
        return events

class ContentDiscoveryService:
    """Main content discovery service"""
    
    def __init__(self, config_path: str):
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
            
        self.content_filter = ContentFilter(self.config['filters'])
        self.running = False
        self.stats = {
            'events_discovered': 0,
            'events_filtered': 0,
            'events_cached': 0,
            'last_run': None
        }
        
    async def discover_content(self):
        """Main content discovery loop"""
        logger.info("Starting content discovery cycle")
        
        source_relays = self.config['source_relays']
        target_relays = self.config['target_relays']
        
        # Create filters for recent content
        now = int(time.time())
        since = now - (self.config['filters']['max_age_hours'] * 3600)
        
        filters = [
            {
                "kinds": [0, 1, 3, 7, 30023, 1063],  # Various content types
                "since": since,
                "limit": 500
            }
        ]
        
        all_events = []
        
        # Connect to source relays and gather content
        for relay_config in source_relays:
            relay = RelayConnection(relay_config['url'], relay_config)
            
            if await relay.connect():
                try:
                    await relay.subscribe(filters)
                    events = await relay.get_events(relay_config.get('max_events', 100))
                    
                    # Filter events
                    for event in events:
                        self.stats['events_discovered'] += 1
                        
                        if self.content_filter.is_quality_content(event):
                            all_events.append(event)
                        else:
                            self.stats['events_filtered'] += 1
                            
                finally:
                    await relay.disconnect()
                    
        # Route events to appropriate target relays
        await self.route_events(all_events)
        
        self.stats['last_run'] = datetime.now().isoformat()
        logger.info(f"Discovery cycle complete. Discovered: {len(all_events)} quality events")
        
    async def route_events(self, events: List[NostrEvent]):
        """Route events to appropriate target relays"""
        routing = self.config['content_routing']
        
        for event in events:
            kind_key = f"kind_{event.kind}"
            
            if kind_key in routing:
                targets = routing[kind_key]['targets']
                
                for target_name in targets:
                    if target_name in self.config['target_relays']:
                        target_config = self.config['target_relays'][target_name]
                        await self.send_to_relay(event, target_config['url'])
                        
    async def send_to_relay(self, event: NostrEvent, relay_url: str):
        """Send event to target relay"""
        try:
            async with websockets.connect(relay_url) as websocket:
                event_message = ["EVENT", event.to_dict()]
                await websocket.send(json.dumps(event_message))
                
                # Wait for OK response
                response = await asyncio.wait_for(websocket.recv(), timeout=5)
                data = json.loads(response)
                
                if data[0] == "OK" and data[2]:
                    self.stats['events_cached'] += 1
                    logger.debug(f"Successfully cached event {event.id} to {relay_url}")
                else:
                    logger.warning(f"Failed to cache event {event.id} to {relay_url}: {data[3] if len(data) > 3 else 'Unknown error'}")
                    
        except Exception as e:
            logger.error(f"Error sending event to {relay_url}: {e}")
            
    async def health_check_server(self):
        """Simple health check HTTP server"""
        from aiohttp import web
        
        async def health(request):
            return web.json_response({
                'status': 'healthy' if self.running else 'stopped',
                'stats': self.stats,
                'uptime': time.time() - self.start_time if hasattr(self, 'start_time') else 0
            })
            
        app = web.Application()
        app.router.add_get('/health', health)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', 8080)
        await site.start()
        logger.info("Health check server started on port 8080")
        
    async def run(self):
        """Main service loop"""
        self.running = True
        self.start_time = time.time()
        
        # Start health check server
        await self.health_check_server()
        
        interval = self.config['service']['interval']
        logger.info(f"Content discovery service started (interval: {interval}s)")
        
        while self.running:
            try:
                await self.discover_content()
                await asyncio.sleep(interval)
            except Exception as e:
                logger.error(f"Error in discovery cycle: {e}")
                await asyncio.sleep(60)  # Wait 1 minute before retrying
                
    def stop(self):
        """Stop the service"""
        self.running = False
        logger.info("Content discovery service stopping...")

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    sys.exit(0)

async def main():
    """Main entry point"""
    config_path = os.getenv('CONFIG_PATH', '/app/config/config.yml')
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    service = ContentDiscoveryService(config_path)
    
    try:
        await service.run()
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    finally:
        service.stop()

if __name__ == "__main__":
    asyncio.run(main())
