# NostrGator Lightning Wallet Setup
# Simple setup script for LND wallet

Write-Host "=== NostrGator Lightning Wallet Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if LND is running
Write-Host "Checking LND status..." -ForegroundColor Yellow
$lndStatus = docker inspect nostrgator-lnd --format '{{.State.Status}}' 2>$null

if ($lndStatus -ne "running") {
    Write-Host "ERROR: LND is not running. Please start it first:" -ForegroundColor Red
    Write-Host "  docker compose up -d nostrgator-lnd" -ForegroundColor White
    exit 1
}

Write-Host "LND is running!" -ForegroundColor Green
Write-Host ""

# Check if wallet already exists
Write-Host "Checking wallet status..." -ForegroundColor Yellow
$walletInfo = docker exec nostrgator-lnd lncli getinfo 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Wallet already exists and is unlocked!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Wallet Information:" -ForegroundColor Yellow
    Write-Host $walletInfo
    exit 0
}

# Wallet needs to be created
Write-Host "Wallet needs to be created or unlocked." -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANT SECURITY NOTES:" -ForegroundColor Red
Write-Host "1. Write down your seed phrase on paper" -ForegroundColor White
Write-Host "2. Store it in a secure location" -ForegroundColor White
Write-Host "3. Never share your seed phrase with anyone" -ForegroundColor White
Write-Host "4. This is your ONLY way to recover your funds" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Do you want to create a new wallet? (y/N)"
if ($choice -ne "y" -and $choice -ne "Y") {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Creating new wallet..." -ForegroundColor Yellow
Write-Host "Follow the prompts to set a password and save your seed phrase." -ForegroundColor White
Write-Host ""

# Create wallet interactively
docker exec -it nostrgator-lnd lncli create

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Wallet created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Fund your wallet by sending Bitcoin to your on-chain address" -ForegroundColor White
    Write-Host "2. Open Lightning channels to start receiving payments" -ForegroundColor White
    Write-Host "3. Configure LNbits at http://localhost:5000" -ForegroundColor White
    Write-Host ""
    Write-Host "Useful commands:" -ForegroundColor Yellow
    Write-Host "  Get wallet info: docker exec nostrgator-lnd lncli getinfo" -ForegroundColor White
    Write-Host "  Get new address: docker exec nostrgator-lnd lncli newaddress p2wkh" -ForegroundColor White
    Write-Host "  Check balance: docker exec nostrgator-lnd lncli walletbalance" -ForegroundColor White
} else {
    Write-Host "Wallet creation failed. Please check the logs:" -ForegroundColor Red
    Write-Host "  docker logs nostrgator-lnd" -ForegroundColor White
}
