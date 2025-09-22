# Simple WebSocket test for Nostr relay
param(
    [string]$Url = "ws://localhost:7005",
    [string]$Message = '["REQ","test",{"kinds":[1],"limit":1}]'
)

Write-Host "Testing WebSocket connection to: $Url" -ForegroundColor Cyan
Write-Host "Sending message: $Message" -ForegroundColor Yellow

try {
    # Test basic HTTP first
    $httpUrl = $Url -replace "ws://", "http://"
    Write-Host "`nTesting HTTP endpoint: $httpUrl" -ForegroundColor Cyan
    
    $response = Invoke-WebRequest -Uri $httpUrl -TimeoutSec 5
    Write-Host "✅ HTTP Response: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Content length: $($response.Content.Length) bytes" -ForegroundColor Gray
    
    # Test WebSocket using .NET
    Write-Host "`nTesting WebSocket connection..." -ForegroundColor Cyan
    
    Add-Type -AssemblyName System.Net.WebSockets
    Add-Type -AssemblyName System.Threading
    
    $uri = [System.Uri]::new($Url)
    $cts = [System.Threading.CancellationTokenSource]::new()
    $ws = [System.Net.WebSockets.ClientWebSocket]::new()
    
    # Connect
    $connectTask = $ws.ConnectAsync($uri, $cts.Token)
    $connectTask.Wait(5000)
    
    if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
        Write-Host "✅ WebSocket connected successfully!" -ForegroundColor Green
        
        # Send message
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Message)
        $buffer = [System.ArraySegment[byte]]::new($bytes)
        $sendTask = $ws.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token)
        $sendTask.Wait(5000)
        
        Write-Host "✅ Message sent successfully!" -ForegroundColor Green
        
        # Try to receive response
        $receiveBuffer = [byte[]]::new(4096)
        $receiveSegment = [System.ArraySegment[byte]]::new($receiveBuffer)
        
        Write-Host "Waiting for response..." -ForegroundColor Yellow
        $receiveTask = $ws.ReceiveAsync($receiveSegment, $cts.Token)
        
        if ($receiveTask.Wait(5000)) {
            $result = $receiveTask.Result
            $responseText = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $result.Count)
            Write-Host "📨 Response: $responseText" -ForegroundColor Magenta
        } else {
            Write-Host "⏰ No response received within timeout" -ForegroundColor Yellow
        }
        
        # Close connection
        $closeTask = $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Test complete", $cts.Token)
        $closeTask.Wait(2000)
        Write-Host "✅ WebSocket closed" -ForegroundColor Green
        
    } else {
        Write-Host "❌ Failed to connect WebSocket. State: $($ws.State)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception)" -ForegroundColor DarkRed
} finally {
    if ($ws) {
        $ws.Dispose()
    }
    if ($cts) {
        $cts.Dispose()
    }
}
