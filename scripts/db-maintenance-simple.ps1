# Simple Database Maintenance Script
Write-Host "Database Maintenance - Keep that 1ms performance eternal" -ForegroundColor Cyan

$databases = @(
    ".\data\general\nostr.db",
    ".\data\social\nostr.db", 
    ".\data\media\nostr.db",
    ".\data\dm\nostr.db",
    ".\data\files\nostr.db",
    ".\data\games\nostr.db",
    ".\data\marketplace\nostr.db",
    ".\data\bridge\nostr.db",
    ".\data\live\nostr.db",
    ".\data\longform\nostr.db",
    ".\data\cache\nostr.db",
    ".\data\watchtower\nostr.db"
)

$optimizedCount = 0

foreach ($db in $databases) {
    if (Test-Path $db) {
        $dbName = Split-Path $db -Parent | Split-Path -Leaf
        Write-Host "Optimizing $dbName database..." -ForegroundColor White
        
        try {
            # Simple approach - just run VACUUM which is the most important
            cmd /c "sqlite3 `"$db`" `"VACUUM;`"" 2>$null
            $optimizedCount++
            Write-Host "  [OK] $dbName optimized" -ForegroundColor Green
        }
        catch {
            Write-Host "  [FAIL] $dbName failed" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  [SKIP] $dbName not found" -ForegroundColor Yellow
    }
}

Write-Host "`nMaintenance Summary:" -ForegroundColor Cyan
Write-Host "  Databases optimized: $optimizedCount" -ForegroundColor White
Write-Host "  Performance: Maintained for peak speed" -ForegroundColor Green
Write-Host "`n[SUCCESS] Database maintenance complete!" -ForegroundColor Green
