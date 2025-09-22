#!/usr/bin/env python3
"""
Nostr Security Monitor Service
Vulnerability tracking and security enhancement monitoring
"""

import asyncio
import json
import logging
import time
import yaml
import requests
import docker
import hashlib
import os
import signal
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Set, Optional
from dataclasses import dataclass
import feedparser
import subprocess

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('security-monitor')

@dataclass
class SecurityAlert:
    """Represents a security alert"""
    id: str
    severity: str
    component: str
    title: str
    description: str
    timestamp: datetime
    source: str
    cve_id: Optional[str] = None
    
class VulnerabilityScanner:
    """Scans for known vulnerabilities"""
    
    def __init__(self, config: dict):
        self.config = config
        self.github_token = os.getenv('GITHUB_TOKEN')  # Optional for higher rate limits
        
    async def check_github_repos(self) -> List[SecurityAlert]:
        """Check GitHub repositories for security advisories"""
        alerts = []
        
        for repo_config in self.config['sources']['github_repos']:
            repo = repo_config['repo']
            
            try:
                # Check for security advisories
                url = f"https://api.github.com/repos/{repo}/security-advisories"
                headers = {}
                if self.github_token:
                    headers['Authorization'] = f"token {self.github_token}"
                    
                response = requests.get(url, headers=headers, timeout=30)
                
                if response.status_code == 200:
                    advisories = response.json()
                    
                    for advisory in advisories:
                        # Check if advisory is recent (last 30 days)
                        published = datetime.fromisoformat(advisory['published_at'].replace('Z', '+00:00'))
                        if (datetime.now().astimezone() - published).days <= 30:
                            
                            alert = SecurityAlert(
                                id=advisory['ghsa_id'],
                                severity=advisory['severity'].lower(),
                                component=repo,
                                title=advisory['summary'],
                                description=advisory['description'],
                                timestamp=published,
                                source='github_advisory',
                                cve_id=advisory.get('cve_id')
                            )
                            alerts.append(alert)
                            
                # Check for new releases
                if repo_config.get('watch_releases', False):
                    releases_url = f"https://api.github.com/repos/{repo}/releases"
                    response = requests.get(releases_url, headers=headers, timeout=30)
                    
                    if response.status_code == 200:
                        releases = response.json()
                        
                        # Check latest release
                        if releases:
                            latest = releases[0]
                            published = datetime.fromisoformat(latest['published_at'].replace('Z', '+00:00'))
                            
                            # If release is within last 7 days, create alert
                            if (datetime.now().astimezone() - published).days <= 7:
                                # Check if it's a security release
                                body = latest.get('body', '').lower()
                                if any(keyword in body for keyword in ['security', 'vulnerability', 'cve', 'fix']):
                                    alert = SecurityAlert(
                                        id=f"release_{latest['id']}",
                                        severity='medium',
                                        component=repo,
                                        title=f"Security Release: {latest['name']}",
                                        description=latest.get('body', ''),
                                        timestamp=published,
                                        source='github_release'
                                    )
                                    alerts.append(alert)
                                    
            except Exception as e:
                logger.error(f"Error checking GitHub repo {repo}: {e}")
                
        return alerts
        
    async def check_cve_databases(self) -> List[SecurityAlert]:
        """Check CVE databases for Nostr-related vulnerabilities"""
        alerts = []
        
        for cve_source in self.config['sources']['cve_sources']:
            try:
                if cve_source['name'] == 'NVD':
                    # Search NVD for Nostr-related CVEs
                    for keyword in cve_source['keywords']:
                        url = f"{cve_source['url']}?keywordSearch={keyword}&resultsPerPage=20"
                        response = requests.get(url, timeout=30)
                        
                        if response.status_code == 200:
                            data = response.json()
                            
                            for vuln in data.get('vulnerabilities', []):
                                cve = vuln['cve']
                                
                                # Check if CVE is recent
                                published = datetime.fromisoformat(cve['published'].replace('Z', '+00:00'))
                                if (datetime.now().astimezone() - published).days <= 30:
                                    
                                    # Get severity
                                    severity = 'unknown'
                                    if 'metrics' in cve and 'cvssMetricV31' in cve['metrics']:
                                        cvss = cve['metrics']['cvssMetricV31'][0]['cvssData']
                                        severity = cvss['baseSeverity'].lower()
                                    
                                    alert = SecurityAlert(
                                        id=cve['id'],
                                        severity=severity,
                                        component='nostr-ecosystem',
                                        title=f"CVE: {cve['id']}",
                                        description=cve['descriptions'][0]['value'],
                                        timestamp=published,
                                        source='nvd',
                                        cve_id=cve['id']
                                    )
                                    alerts.append(alert)
                                    
            except Exception as e:
                logger.error(f"Error checking CVE source {cve_source['name']}: {e}")
                
        return alerts

class ConfigurationMonitor:
    """Monitors configuration files for changes"""
    
    def __init__(self, config: dict):
        self.config = config
        self.baseline_hashes = {}
        self.load_baseline()
        
    def load_baseline(self):
        """Load baseline configuration hashes"""
        for config_file in self.config['rules']['config_drift']['baseline_configs']:
            if os.path.exists(config_file):
                with open(config_file, 'rb') as f:
                    content = f.read()
                    hash_value = hashlib.sha256(content).hexdigest()
                    self.baseline_hashes[config_file] = hash_value
                    
    def check_drift(self) -> List[SecurityAlert]:
        """Check for configuration drift"""
        alerts = []
        
        for config_file, baseline_hash in self.baseline_hashes.items():
            if os.path.exists(config_file):
                with open(config_file, 'rb') as f:
                    content = f.read()
                    current_hash = hashlib.sha256(content).hexdigest()
                    
                    if current_hash != baseline_hash:
                        alert = SecurityAlert(
                            id=f"config_drift_{config_file}",
                            severity='medium',
                            component=config_file,
                            title="Configuration Drift Detected",
                            description=f"Configuration file {config_file} has been modified",
                            timestamp=datetime.now(),
                            source='config_monitor'
                        )
                        alerts.append(alert)
                        
                        # Update baseline
                        self.baseline_hashes[config_file] = current_hash
                        
        return alerts

class ContainerMonitor:
    """Monitors Docker containers for security issues"""
    
    def __init__(self, config: dict):
        self.config = config
        self.docker_client = docker.from_env()
        
    def check_container_security(self) -> List[SecurityAlert]:
        """Check containers for security issues"""
        alerts = []
        
        try:
            containers = self.docker_client.containers.list()
            
            for container in containers:
                # Check for containers running as root
                if container.attrs['Config'].get('User') in [None, '', 'root', '0']:
                    alert = SecurityAlert(
                        id=f"root_container_{container.id}",
                        severity='medium',
                        component=container.name,
                        title="Container Running as Root",
                        description=f"Container {container.name} is running as root user",
                        timestamp=datetime.now(),
                        source='container_monitor'
                    )
                    alerts.append(alert)
                    
                # Check for containers with privileged mode
                if container.attrs['HostConfig'].get('Privileged', False):
                    alert = SecurityAlert(
                        id=f"privileged_container_{container.id}",
                        severity='high',
                        component=container.name,
                        title="Privileged Container Detected",
                        description=f"Container {container.name} is running in privileged mode",
                        timestamp=datetime.now(),
                        source='container_monitor'
                    )
                    alerts.append(alert)
                    
        except Exception as e:
            logger.error(f"Error checking container security: {e}")
            
        return alerts

class SecurityMonitorService:
    """Main security monitoring service"""
    
    def __init__(self, config_path: str):
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
            
        self.vulnerability_scanner = VulnerabilityScanner(self.config)
        self.config_monitor = ConfigurationMonitor(self.config)
        self.container_monitor = ContainerMonitor(self.config)
        
        self.running = False
        self.alerts = []
        self.stats = {
            'total_alerts': 0,
            'critical_alerts': 0,
            'high_alerts': 0,
            'medium_alerts': 0,
            'low_alerts': 0,
            'last_scan': None
        }
        
    async def run_security_scan(self):
        """Run comprehensive security scan"""
        logger.info("Starting security scan")
        
        all_alerts = []
        
        # Check GitHub repositories
        github_alerts = await self.vulnerability_scanner.check_github_repos()
        all_alerts.extend(github_alerts)
        
        # Check CVE databases
        cve_alerts = await self.vulnerability_scanner.check_cve_databases()
        all_alerts.extend(cve_alerts)
        
        # Check configuration drift
        config_alerts = self.config_monitor.check_drift()
        all_alerts.extend(config_alerts)
        
        # Check container security
        container_alerts = self.container_monitor.check_container_security()
        all_alerts.extend(container_alerts)
        
        # Process alerts
        for alert in all_alerts:
            await self.process_alert(alert)
            
        # Update statistics
        self.stats['total_alerts'] = len(self.alerts)
        self.stats['last_scan'] = datetime.now().isoformat()
        
        # Count by severity
        severity_counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0}
        for alert in self.alerts:
            if alert.severity in severity_counts:
                severity_counts[alert.severity] += 1
                
        self.stats.update({
            'critical_alerts': severity_counts['critical'],
            'high_alerts': severity_counts['high'],
            'medium_alerts': severity_counts['medium'],
            'low_alerts': severity_counts['low']
        })
        
        logger.info(f"Security scan complete. Found {len(all_alerts)} new alerts")
        
    async def process_alert(self, alert: SecurityAlert):
        """Process and handle a security alert"""
        # Add to alerts list
        self.alerts.append(alert)
        
        # Log alert
        logger.warning(f"Security Alert [{alert.severity.upper()}]: {alert.title} - {alert.component}")
        
        # Handle automated responses
        if alert.severity in ['critical', 'high']:
            await self.handle_high_severity_alert(alert)
            
    async def handle_high_severity_alert(self, alert: SecurityAlert):
        """Handle high severity alerts with automated responses"""
        automation_config = self.config.get('automation', {})
        
        # Auto-restart containers if enabled
        if automation_config.get('auto_restart', {}).get('enabled', False):
            if alert.component in automation_config['auto_restart']['services']:
                logger.info(f"Auto-restarting service {alert.component} due to security alert")
                try:
                    container = self.container_monitor.docker_client.containers.get(alert.component)
                    container.restart()
                except Exception as e:
                    logger.error(f"Failed to restart container {alert.component}: {e}")
                    
    async def health_check_server(self):
        """Simple health check HTTP server"""
        from aiohttp import web
        
        async def health(request):
            return web.json_response({
                'status': 'healthy' if self.running else 'stopped',
                'stats': self.stats,
                'recent_alerts': [
                    {
                        'severity': alert.severity,
                        'component': alert.component,
                        'title': alert.title,
                        'timestamp': alert.timestamp.isoformat()
                    }
                    for alert in self.alerts[-10:]  # Last 10 alerts
                ]
            })
            
        app = web.Application()
        app.router.add_get('/health', health)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', 8081)
        await site.start()
        logger.info("Health check server started on port 8081")
        
    async def run(self):
        """Main service loop"""
        self.running = True
        self.start_time = time.time()
        
        # Start health check server
        await self.health_check_server()
        
        interval = self.config['service']['check_interval']
        logger.info(f"Security monitor service started (interval: {interval}s)")
        
        while self.running:
            try:
                await self.run_security_scan()
                await asyncio.sleep(interval)
            except Exception as e:
                logger.error(f"Error in security scan: {e}")
                await asyncio.sleep(300)  # Wait 5 minutes before retrying
                
    def stop(self):
        """Stop the service"""
        self.running = False
        logger.info("Security monitor service stopping...")

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
    
    service = SecurityMonitorService(config_path)
    
    try:
        await service.run()
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    finally:
        service.stop()

if __name__ == "__main__":
    asyncio.run(main())
