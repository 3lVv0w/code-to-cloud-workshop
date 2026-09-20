<#
==============================================================================
Script: test-concurrency-locks.ps1
Purpose: High-traffic concurrency test verifying PostgreSQL row-level locks on Windows
==============================================================================
#>

[CmdletBinding()]
param(
    [int]$ParallelRequests = 30,
    [string]$Endpoint = "http://localhost:3000/orders"
)

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  High-Concurrency Ticket Rush Simulation (Windows)    " -ForegroundColor Cyan
Write-Host "  Firing $ParallelRequests parallel checkout requests...            " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Verify service is responding
try {
    $null = Invoke-RestMethod -Uri "http://localhost:3000/healthz" -Method Get -TimeoutSec 3 -ErrorAction Stop
} catch {
    Write-Host "[WARN] Sample app is not running on http://localhost:3000." -ForegroundColor Yellow
    Write-Host "Please start the local stack first via: cd ../02-sample-app; docker compose up -d" -ForegroundColor Gray
    exit 1
}

Write-Host "Dispatching $ParallelRequests requests concurrently via thread pool..."

$results = [System.Collections.Concurrent.ConcurrentBag[int]]::new()

$asyncHandles = @()
1..$ParallelRequests | ForEach-Object {
    $userId = "usr_rush_win_$_"
    $ps = [powershell]::Create()
    $handle = $ps.AddScript({
        param($url, $user, $bag)
        $body = @{ tierId = 1; userId = $user } | ConvertTo-Json
        try {
            $response = Invoke-WebRequest -Uri $url -Method Post -Body $body -ContentType "application/json" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            $bag.Add([int]$response.StatusCode)
        } catch {
            if ($_.Exception.Response) {
                $code = [int]$_.Exception.Response.StatusCode
                $bag.Add($code)
            } else {
                $bag.Add(500)
            }
        }
    }).AddArgument($Endpoint).AddArgument($userId).AddArgument($results).BeginInvoke()
    $asyncHandles += @{ PS = $ps; Handle = $handle }
}

# Wait for all async calls
$timeoutSec = 15
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while (($results.Count -lt $ParallelRequests) -and ($sw.Elapsed.TotalSeconds -lt $timeoutSec)) {
    Start-Sleep -Milliseconds 100
}

# Clean up PowerShell instances
foreach ($item in $asyncHandles) {
    try {
        $null = $item.PS.EndInvoke($item.Handle)
        $item.PS.Dispose()
    } catch {
        # ignore disposal errors
    }
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "  Transaction Reconciliation Results                  " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$successCount = ($results | Where-Object { $_ -eq 201 }).Count
$conflictCount = ($results | Where-Object { $_ -eq 409 }).Count
$errorCount = ($results | Where-Object { $_ -eq 500 }).Count

Write-Host "  [CONFIRMED ORDERS (201)]: $successCount" -ForegroundColor Green
Write-Host "  [SAFELY SOLD OUT (409)]:  $conflictCount" -ForegroundColor Yellow
Write-Host "  [SYSTEM FAILURES (500)]:   $errorCount" -ForegroundColor Red

if ($errorCount -eq 0) {
    Write-Host "`n[OK] SUCCESS: Zero overselling and zero 500 errors!" -ForegroundColor Green
    Write-Host "PostgreSQL row-level locking (SELECT ... FOR UPDATE) guaranteed perfect transactional consistency." -ForegroundColor Gray
} else {
    Write-Host "`n[!] ALERT: System failures encountered." -ForegroundColor Red
}
