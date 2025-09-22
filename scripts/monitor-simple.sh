#!/bin/bash
# NostrGator Simple Monitoring Script (Linux/macOS)
# ================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Service names to monitor
SERVICES=(
    "nostr-general"
    "nostr-dm"
    "nostr-media"
    "nostr-social"
    "nostr-cache"
    "nostr-files"
    "nostr-longform"
    "nostr-live"
    "nostr-marketplace"
    "nostr-games"
    "nostr-bridge"
    "nostr-content-discovery"
    "nostr-security-monitor"
    "nostr-health-monitor"
    "nostr-watchtower"
    "nostr-tor-proxy"
    "nostr-supernode-federation"
    "nostr-event-mirror"
    "nostr-nip05"
)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    NostrGator Status Monitor${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running!${NC}"
    echo "Please start Docker Desktop and try again."
    exit 1
fi

echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Check service status
echo -e "${CYAN}📊 Service Status:${NC}"
echo "----------------------------------------"

RUNNING_COUNT=0
TOTAL_COUNT=${#SERVICES[@]}

for service in "${SERVICES[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "^$service$"; then
        STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^$service" | awk '{print $2}')
        if [[ $STATUS == "Up" ]]; then
            echo -e "  ${GREEN}✅ $service${NC} - Running"
            ((RUNNING_COUNT++))
        else
            echo -e "  ${YELLOW}⚠️  $service${NC} - $STATUS"
        fi
    else
        echo -e "  ${RED}❌ $service${NC} - Not running"
    fi
done

echo ""
echo -e "${CYAN}📈 Summary: ${RUNNING_COUNT}/${TOTAL_COUNT} services running${NC}"
echo ""

# Check key endpoints
echo -e "${CYAN}🔗 Key Endpoints:${NC}"
echo "----------------------------------------"
echo -e "  ${GREEN}Core Relays:${NC}"
echo -e "    - General Relay: ws://localhost:7001"
echo -e "    - Social Relay: ws://localhost:7004"
echo -e "    - Cache Relay: ws://localhost:7005"
echo ""
echo -e "  ${YELLOW}Management Interfaces:${NC}"
echo -e "    - Prometheus Web UI: http://localhost:9090"
echo -e "    - Event Mirror Metrics: http://localhost:9091/metrics"
echo -e "    - NIP-05 Service: http://localhost:3005"
echo ""

# Quick connectivity test
echo -e "${CYAN}🔍 Quick Connectivity Test:${NC}"
echo "----------------------------------------"

# Test core relays
PORTS=(7001 7004 7005 9090 3005)
PORT_NAMES=("General Relay" "Social Relay" "Cache Relay" "Prometheus" "NIP-05")

for i in "${!PORTS[@]}"; do
    PORT=${PORTS[$i]}
    NAME=${PORT_NAMES[$i]}
    
    if curl -s --connect-timeout 2 "http://localhost:$PORT" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ $NAME${NC} (port $PORT) - Responding"
    else
        echo -e "  ${RED}❌ $NAME${NC} (port $PORT) - Not responding"
    fi
done

echo ""

# Resource usage
echo -e "${CYAN}💾 Resource Usage:${NC}"
echo "----------------------------------------"

if command -v docker >/dev/null 2>&1; then
    TOTAL_MEM=$(docker stats --no-stream --format "table {{.MemUsage}}" | grep -v "MEM" | awk -F'/' '{sum += $1} END {print sum "MB"}' 2>/dev/null || echo "N/A")
    CONTAINER_COUNT=$(docker ps -q | wc -l)
    
    echo -e "  ${GREEN}Memory Usage:${NC} $TOTAL_MEM"
    echo -e "  ${GREEN}Active Containers:${NC} $CONTAINER_COUNT"
fi

echo ""

# Recent logs check
echo -e "${CYAN}📋 Recent Activity:${NC}"
echo "----------------------------------------"

# Check for any recent errors in logs
if docker compose logs --tail=10 2>/dev/null | grep -i error >/dev/null; then
    echo -e "  ${YELLOW}⚠️  Recent errors found in logs${NC}"
    echo -e "     Run: ${BLUE}docker compose logs --tail=50${NC} for details"
else
    echo -e "  ${GREEN}✅ No recent errors detected${NC}"
fi

echo ""

# Recommendations
if [ $RUNNING_COUNT -lt $TOTAL_COUNT ]; then
    echo -e "${YELLOW}💡 Recommendations:${NC}"
    echo "----------------------------------------"
    echo -e "  • Some services are not running"
    echo -e "  • Run: ${BLUE}docker compose up -d${NC} to start all services"
    echo -e "  • Check logs: ${BLUE}docker compose logs --tail=50${NC}"
    echo ""
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}NostrGator monitoring complete!${NC}"
echo -e "${BLUE}========================================${NC}"

# Exit with error code if not all services are running
if [ $RUNNING_COUNT -lt $TOTAL_COUNT ]; then
    exit 1
fi
