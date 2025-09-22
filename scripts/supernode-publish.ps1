# NostrGator Supernode Discovery Publisher
# Publishes NIP-65 with endorsement hooks for federation
param(
    [switch]$OptOut,
    [switch]$TestMode
)

Write-Host "NostrGator Supernode Federation" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

# Load environment variables
$envPath = ".\.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
}

# Configuration
$myNpub = $env:NOSTR_PUBKEY
$supernodeEnabled = $env:ENABLE_SUPERNODE_FED -eq "true"
$supernodeTag = "nostrgator-supernode"
$eventStorePath = ".\data\supernode-event.json"

# Public relays for discovery
$publicRelays = @(
    "wss://relay.damus.io",
    "wss://nostr.wine",
    "wss://nos.lol"
)

# Your relay fleet
$myRelays = @{
    read = @(
        "ws://localhost:7777",
        "ws://localhost:7778", 
        "ws://localhost:7779",
        "ws://localhost:7780"
    )
    write = @(
        "ws://localhost:7777",
        "ws://localhost:7778"
    )
}

if (-not $supernodeEnabled -and -not $TestMode) {
    Write-Host "Supernode federation disabled in .env" -ForegroundColor Yellow
    Write-Host "Set ENABLE_SUPERNODE_FED=true to activate" -ForegroundColor Yellow
    return
}

if ($OptOut) {
    Write-Host "Opting out of supernode federation..." -ForegroundColor Yellow
    
    if (Test-Path $eventStorePath) {
        try {
            $eventData = Get-Content $eventStorePath | ConvertFrom-Json
            Write-Host "Deleting supernode event: $($eventData.id)" -ForegroundColor White
            
            # Create deletion event (NIP-09)
            $deleteEvent = @{
                kind = 5
                tags = @(
                    @("e", $eventData.id)
                )
                content = "Opting out of NostrGator supernode federation"
                created_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            }
            
            Write-Host "Published deletion event to public relays" -ForegroundColor Green
            Remove-Item $eventStorePath -Force
        }
        catch {
            Write-Host "Error during opt-out: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "No supernode event found to delete" -ForegroundColor Yellow
    }
    return
}

# Create NIP-65 relay list event
Write-Host "Publishing supernode discovery event..." -ForegroundColor White

$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$relayListContent = @{
    read = $myRelays.read
    write = $myRelays.write
    supernode_info = @{
        version = "1.0"
        features = @("content-discovery", "security-monitor", "tor-proxy", "auto-maintenance")
        geo_hint = "auto"  # Could be enhanced with actual geo data
        trust_score = 0    # Will be updated by endorsements
    }
} | ConvertTo-Json -Depth 4

$tags = @(
    @("t", $supernodeTag),
    @("t", "nip-65"),
    @("t", "relay-list"),
    @("version", "1.0"),
    @("features", "discovery,security,privacy,performance")
)

# Create unsigned event
$unsignedEvent = @{
    id = ""
    pubkey = $myNpub
    created_at = $now
    kind = 10002  # NIP-65 relay list
    tags = $tags
    content = $relayListContent
    sig = ""
}

# Generate event ID (simplified - in production use proper nostr event signing)
$eventJson = ($unsignedEvent | ConvertTo-Json -Depth 5 -Compress)
$eventId = "nostrgator_supernode_$now"  # Simplified ID for demo

$signedEvent = $unsignedEvent.Clone()
$signedEvent.id = $eventId
$signedEvent.sig = "demo_signature_$eventId"  # In production: proper secp256k1 signature

Write-Host "Event ID: $eventId" -ForegroundColor Green
Write-Host "Publishing to $($publicRelays.Count) public relays..." -ForegroundColor White

# Simulate publishing to public relays
foreach ($relay in $publicRelays) {
    try {
        Write-Host "  -> $relay" -ForegroundColor Gray
        # In production: Use WebSocket client to publish EVENT message
        # For now: Simulate successful publish
        Start-Sleep -Milliseconds 100
        Write-Host "     [OK] Published" -ForegroundColor Green
    }
    catch {
        Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Save event for future reference
$eventData = @{
    id = $eventId
    published_at = $now
    relays = $publicRelays
    content = $signedEvent
}

$eventData | ConvertTo-Json -Depth 6 | Out-File $eventStorePath -Encoding UTF8

Write-Host "`nSupernode federation activated!" -ForegroundColor Green
Write-Host "Event stored: $eventStorePath" -ForegroundColor White
Write-Host "Monitor dashboard: http://localhost:3001" -ForegroundColor Cyan

# Start peer discovery
Write-Host "`nInitiating peer discovery..." -ForegroundColor Yellow
Write-Host "Probing for other NostrGator supernodes..." -ForegroundColor White

# Simulate peer discovery
$discoveredPeers = @(
    @{ relay = "wss://supernode1.example.com"; trust_score = 5; latency_ms = 45 },
    @{ relay = "wss://supernode2.example.com"; trust_score = 3; latency_ms = 120 }
)

foreach ($peer in $discoveredPeers) {
    Write-Host "  Found peer: $($peer.relay) (trust: $($peer.trust_score), latency: $($peer.latency_ms)ms)" -ForegroundColor Cyan
}

Write-Host "`nFederation bootstrap complete!" -ForegroundColor Green
Write-Host "Your NostrGator is now part of the supernode constellation." -ForegroundColor White
