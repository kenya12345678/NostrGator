#!/usr/bin/env python3
"""
NostrGator 3D Visualization Dashboard
Real-time trust web visualization with D3.js and Three.js
"""

import asyncio
import json
import time
import logging
from aiohttp import web, WSMsgType
from typing import Dict, List, Set
import math
import random

class VisualizationServer:
    """3D visualization server for supernode federation"""
    
    def __init__(self, federation_engine):
        self.federation_engine = federation_engine
        self.websocket_connections: Set[web.WebSocketResponse] = set()
        self.logger = logging.getLogger('visualization_server')
        
    async def start_server(self):
        """Start the visualization web server"""
        app = web.Application()

        # Add CORS middleware
        async def cors_middleware(request, handler):
            response = await handler(request)
            response.headers['Access-Control-Allow-Origin'] = '*'
            response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
            response.headers['Access-Control-Allow-Headers'] = '*'
            return response

        app.middlewares.append(cors_middleware)

        # Static files
        app.router.add_get('/', self.dashboard_handler)
        app.router.add_get('/api/graph-data', self.graph_data_handler)
        app.router.add_get('/api/metrics', self.metrics_handler)
        app.router.add_get('/ws', self.websocket_handler)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', 3003)
        await site.start()

        self.logger.info("3D Visualization Dashboard started on port 3003")
        
        # Start broadcasting updates
        asyncio.create_task(self.broadcast_updates())
        
    async def dashboard_handler(self, request):
        """Serve the main dashboard HTML"""
        html_content = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NostrGator Supernode Federation - 3D Trust Web</title>
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #0a0a0a;
            color: #00ff88;
            font-family: 'Courier New', monospace;
            overflow: hidden;
        }
        
        #container {
            position: relative;
            width: 100vw;
            height: 100vh;
        }
        
        #info-panel {
            position: absolute;
            top: 20px;
            left: 20px;
            background: rgba(0, 0, 0, 0.8);
            border: 1px solid #00ff88;
            padding: 20px;
            border-radius: 5px;
            z-index: 1000;
            max-width: 300px;
        }
        
        .metric {
            margin: 10px 0;
            display: flex;
            justify-content: space-between;
        }
        
        .metric-label {
            color: #888;
        }
        
        .metric-value {
            color: #00ff88;
            font-weight: bold;
        }
        
        #status {
            color: #ff6b35;
            font-weight: bold;
            margin-bottom: 15px;
        }
        
        .trust-high { color: #00ff88; }
        .trust-medium { color: #ffaa00; }
        .trust-low { color: #ff4444; }
        
        #legend {
            position: absolute;
            bottom: 20px;
            left: 20px;
            background: rgba(0, 0, 0, 0.8);
            border: 1px solid #00ff88;
            padding: 15px;
            border-radius: 5px;
            z-index: 1000;
        }
        
        .legend-item {
            margin: 5px 0;
            display: flex;
            align-items: center;
        }
        
        .legend-color {
            width: 20px;
            height: 20px;
            margin-right: 10px;
            border-radius: 50%;
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="info-panel">
            <div id="status">🚀 NostrGator Federation LIVE</div>
            <div class="metric">
                <span class="metric-label">Total Peers:</span>
                <span class="metric-value" id="peer-count">0</span>
            </div>
            <div class="metric">
                <span class="metric-label">Trusted Peers:</span>
                <span class="metric-value" id="trusted-count">0</span>
            </div>
            <div class="metric">
                <span class="metric-label">Avg Latency:</span>
                <span class="metric-value" id="avg-latency">0ms</span>
            </div>
            <div class="metric">
                <span class="metric-label">Trust Score:</span>
                <span class="metric-value" id="trust-score">0</span>
            </div>
            <div class="metric">
                <span class="metric-label">Federation Events:</span>
                <span class="metric-value" id="fed-events">0</span>
            </div>
        </div>
        
        <div id="legend">
            <div class="legend-item">
                <div class="legend-color" style="background: #00ff88;"></div>
                <span>High Trust (3+ endorsements)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color" style="background: #ffaa00;"></div>
                <span>Medium Trust (1-2 endorsements)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color" style="background: #ff4444;"></div>
                <span>Low Trust (0 endorsements)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color" style="background: #ff6b35;"></div>
                <span>Your NostrGator Node</span>
            </div>
        </div>
    </div>

    <script>
        // 3D Visualization with Three.js
        let scene, camera, renderer, nodes = [], edges = [];
        let ws;
        
        function init() {
            // Scene setup
            scene = new THREE.Scene();
            scene.background = new THREE.Color(0x0a0a0a);
            
            // Camera
            camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
            camera.position.z = 50;
            
            // Renderer
            renderer = new THREE.WebGLRenderer({ antialias: true });
            renderer.setSize(window.innerWidth, window.innerHeight);
            document.getElementById('container').appendChild(renderer.domElement);
            
            // Lighting
            const ambientLight = new THREE.AmbientLight(0x404040, 0.6);
            scene.add(ambientLight);
            
            const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
            directionalLight.position.set(50, 50, 50);
            scene.add(directionalLight);
            
            // WebSocket connection
            connectWebSocket();
            
            // Animation loop
            animate();
        }
        
        function connectWebSocket() {
            ws = new WebSocket(`ws://${window.location.host}/ws`);
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                updateVisualization(data);
            };
            
            ws.onclose = function() {
                setTimeout(connectWebSocket, 5000); // Reconnect after 5 seconds
            };
        }
        
        function updateVisualization(data) {
            // Clear existing nodes and edges
            nodes.forEach(node => scene.remove(node));
            edges.forEach(edge => scene.remove(edge));
            nodes = [];
            edges = [];
            
            // Update metrics
            document.getElementById('peer-count').textContent = data.peer_count || 0;
            document.getElementById('trusted-count').textContent = data.trusted_count || 0;
            document.getElementById('avg-latency').textContent = `${Math.round(data.avg_latency || 0)}ms`;
            document.getElementById('trust-score').textContent = data.total_trust || 0;
            document.getElementById('fed-events').textContent = data.federation_events || 0;
            
            // Create nodes
            if (data.peers) {
                const peerList = Object.values(data.peers);
                peerList.forEach((peer, index) => {
                    createNode(peer, index, peerList.length);
                });
                
                // Create edges (trust relationships)
                createTrustEdges(peerList);
            }
        }
        
        function createNode(peer, index, total) {
            // Position nodes in a circle
            const angle = (index / total) * Math.PI * 2;
            const radius = 20;
            const x = Math.cos(angle) * radius;
            const y = Math.sin(angle) * radius;
            const z = (Math.random() - 0.5) * 10;
            
            // Node color based on trust score
            let color = 0xff4444; // Low trust (red)
            if (peer.trust_score >= 3) color = 0x00ff88; // High trust (green)
            else if (peer.trust_score >= 1) color = 0xffaa00; // Medium trust (orange)
            
            // Special color for your node
            if (peer.is_self) color = 0xff6b35;
            
            // Create sphere
            const geometry = new THREE.SphereGeometry(peer.trust_score + 1, 16, 16);
            const material = new THREE.MeshPhongMaterial({ color: color });
            const sphere = new THREE.Mesh(geometry, material);
            
            sphere.position.set(x, y, z);
            sphere.userData = peer;
            
            // Add pulsing animation for active nodes
            if (peer.last_seen && (Date.now() / 1000 - peer.last_seen) < 120) {
                sphere.scale.setScalar(1.2);
            }
            
            scene.add(sphere);
            nodes.push(sphere);
        }
        
        function createTrustEdges(peers) {
            // Create edges between trusted peers
            for (let i = 0; i < peers.length; i++) {
                for (let j = i + 1; j < peers.length; j++) {
                    const peer1 = peers[i];
                    const peer2 = peers[j];
                    
                    // Create edge if both have decent trust scores
                    if (peer1.trust_score > 0 && peer2.trust_score > 0) {
                        createEdge(nodes[i], nodes[j], peer1.trust_score + peer2.trust_score);
                    }
                }
            }
        }
        
        function createEdge(node1, node2, strength) {
            const geometry = new THREE.BufferGeometry().setFromPoints([
                node1.position,
                node2.position
            ]);
            
            const opacity = Math.min(strength / 10, 0.8);
            const material = new THREE.LineBasicMaterial({ 
                color: 0x00ff88, 
                opacity: opacity,
                transparent: true
            });
            
            const line = new THREE.Line(geometry, material);
            scene.add(line);
            edges.push(line);
        }
        
        function animate() {
            requestAnimationFrame(animate);
            
            // Rotate the entire scene slowly
            scene.rotation.y += 0.005;
            
            // Pulse nodes
            nodes.forEach((node, index) => {
                const time = Date.now() * 0.001;
                const pulse = 1 + Math.sin(time * 2 + index) * 0.1;
                node.scale.setScalar(pulse);
            });
            
            renderer.render(scene, camera);
        }
        
        // Handle window resize
        window.addEventListener('resize', function() {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });
        
        // Initialize
        init();
    </script>
</body>
</html>
        """
        return web.Response(text=html_content, content_type='text/html')
    
    async def graph_data_handler(self, request):
        """Return current graph data for visualization"""
        peers_data = {}
        
        # Add your own node
        peers_data['self'] = {
            'relay_url': 'ws://localhost:7777',
            'trust_score': 10,
            'latency_ms': 0,
            'last_seen': time.time(),
            'is_self': True,
            'features': ['content-discovery', 'security-monitor', 'tor-proxy', 'federation']
        }
        
        # Add discovered peers
        if hasattr(self.federation_engine, 'peers'):
            for peer_id, peer in self.federation_engine.peers.items():
                peers_data[peer_id] = {
                    'relay_url': peer.relay_url,
                    'trust_score': peer.trust_score,
                    'latency_ms': peer.latency_ms,
                    'last_seen': peer.last_seen,
                    'features': peer.features,
                    'geo_hint': peer.geo_hint,
                    'endorsements_count': len(peer.endorsements),
                    'is_self': False
                }
        
        # Calculate metrics
        total_peers = len(peers_data) - 1  # Exclude self
        trusted_peers = len([p for p in peers_data.values() if p['trust_score'] >= 3 and not p.get('is_self')])
        avg_latency = sum(p['latency_ms'] for p in peers_data.values() if not p.get('is_self')) / max(total_peers, 1)
        total_trust = sum(p['trust_score'] for p in peers_data.values())
        
        return web.json_response({
            'peers': peers_data,
            'peer_count': total_peers,
            'trusted_count': trusted_peers,
            'avg_latency': avg_latency,
            'total_trust': total_trust,
            'federation_events': getattr(self.federation_engine, 'event_count', 0),
            'timestamp': time.time()
        })
    
    async def metrics_handler(self, request):
        """Return federation metrics"""
        return web.json_response({
            'status': 'operational',
            'federation_enabled': True,
            'visualization_active': True,
            'websocket_connections': len(self.websocket_connections)
        })
    
    async def websocket_handler(self, request):
        """WebSocket handler for real-time updates"""
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        
        self.websocket_connections.add(ws)
        self.logger.info(f"WebSocket connected. Total connections: {len(self.websocket_connections)}")
        
        try:
            async for msg in ws:
                if msg.type == WSMsgType.ERROR:
                    self.logger.error(f'WebSocket error: {ws.exception()}')
        finally:
            self.websocket_connections.discard(ws)
            self.logger.info(f"WebSocket disconnected. Total connections: {len(self.websocket_connections)}")
        
        return ws
    
    async def broadcast_updates(self):
        """Broadcast real-time updates to all connected clients"""
        while True:
            try:
                if self.websocket_connections:
                    # Get current graph data
                    graph_data = await self.get_graph_data()
                    message = json.dumps(graph_data)
                    
                    # Send to all connected clients
                    disconnected = set()
                    for ws in self.websocket_connections:
                        try:
                            await ws.send_str(message)
                        except Exception as e:
                            self.logger.warning(f"Failed to send to WebSocket: {e}")
                            disconnected.add(ws)
                    
                    # Remove disconnected clients
                    self.websocket_connections -= disconnected
                
                await asyncio.sleep(5)  # Update every 5 seconds
                
            except Exception as e:
                self.logger.error(f"Broadcast error: {e}")
                await asyncio.sleep(10)
    
    async def get_graph_data(self):
        """Get current graph data (same as graph_data_handler but for internal use)"""
        peers_data = {}
        
        # Add your own node
        peers_data['self'] = {
            'relay_url': 'ws://localhost:7777',
            'trust_score': 10,
            'latency_ms': 0,
            'last_seen': time.time(),
            'is_self': True,
            'features': ['content-discovery', 'security-monitor', 'tor-proxy', 'federation']
        }
        
        # Add discovered peers
        if hasattr(self.federation_engine, 'peers'):
            for peer_id, peer in self.federation_engine.peers.items():
                peers_data[peer_id] = {
                    'relay_url': peer.relay_url,
                    'trust_score': peer.trust_score,
                    'latency_ms': peer.latency_ms,
                    'last_seen': peer.last_seen,
                    'features': peer.features,
                    'geo_hint': peer.geo_hint,
                    'endorsements_count': len(peer.endorsements),
                    'is_self': False
                }
        
        # Calculate metrics
        total_peers = len(peers_data) - 1
        trusted_peers = len([p for p in peers_data.values() if p['trust_score'] >= 3 and not p.get('is_self')])
        avg_latency = sum(p['latency_ms'] for p in peers_data.values() if not p.get('is_self')) / max(total_peers, 1)
        total_trust = sum(p['trust_score'] for p in peers_data.values())
        
        return {
            'peers': peers_data,
            'peer_count': total_peers,
            'trusted_count': trusted_peers,
            'avg_latency': avg_latency,
            'total_trust': total_trust,
            'federation_events': getattr(self.federation_engine, 'event_count', 0),
            'timestamp': time.time()
        }
