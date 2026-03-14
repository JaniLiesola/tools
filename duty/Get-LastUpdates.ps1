# Get the latest Windows updates with descriptions
Write-Host "Searching for the latest Windows updates..." -ForegroundColor Green
Write-Host ""

# Try to use Windows Update COM object first
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateupdateSearcher()
    $historyCount = $searcher.GetTotalHistoryCount()
    
    if ($historyCount -gt 0) {
        $history = $searcher.QueryHistory(0, [Math]::Min(10, $historyCount))
        
        Write-Host "Latest Windows Updates (via Windows Update API):" -ForegroundColor Yellow
        Write-Host "=" * 70
        
        foreach ($update in $history) {
            $installDate = $update.Date
            $title = $update.Title
            $description = $update.Description
            $resultCode = $update.ResultCode
            
            # Convert result code to readable status
            $status = switch ($resultCode) {
                1 { "In Progress" }
                2 { "Succeeded" }
                3 { "Succeeded with Errors" }
                4 { "Failed" }
                5 { "Aborted" }
                default { "Unknown ($resultCode)" }
            }
            
            Write-Host "Install Date: " -NoNewline
            Write-Host "$($installDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
            Write-Host "Status:       " -NoNewline
            $statusColor = if ($status -eq "Succeeded") { "Green" } elseif ($status -eq "Failed") { "Red" } else { "Yellow" }
            Write-Host "$status" -ForegroundColor $statusColor
            Write-Host "Title:        $title" -ForegroundColor White
            if ($description) {
                Write-Host "Description:  $description"
            }
            Write-Host "-" * 50
        }
    }
} catch {
    Write-Host "Unable to access Windows Update API, trying Event Log..." -ForegroundColor Yellow
}

# Fallback to Event Log method
Write-Host ""
Write-Host "Windows Update Events from Event Log:" -ForegroundColor Yellow
Write-Host "=" * 70

# Get Windows Update events from Event Log
$updateEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ProviderName = 'Microsoft-Windows-WindowsUpdateClient'
} -MaxEvents 10 -ErrorAction SilentlyContinue

if ($updateEvents) {
    foreach ($event in $updateEvents) {
        $timeCreated = $event.TimeCreated
        $message = $event.Message
        $eventId = $event.Id
        
        Write-Host "Event Time:   " -NoNewline
        Write-Host "$($timeCreated.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
        Write-Host "Event ID:     $eventId"
        Write-Host "Message:      $message" -ForegroundColor White
        Write-Host "-" * 50
    }
} else {
    # Try alternative Event Log sources
    $alternativeEvents = @(
        @{ LogName = 'Application'; ProviderName = 'Windows Error Reporting' },
        @{ LogName = 'Setup'; ProviderName = '*' }
    )
    
    foreach ($source in $alternativeEvents) {
        try {
            $events = Get-WinEvent -FilterHashtable $source -MaxEvents 5 -ErrorAction SilentlyContinue | 
                      Where-Object { $_.Message -match "update|install|patch" }
            
            if ($events) {
                Write-Host "Found update-related events in $($source.LogName) log:" -ForegroundColor Green
                foreach ($event in $events) {
                    Write-Host "Time: $($event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) - $($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))..."
                }
                break
            }
        } catch {
            continue
        }
    }
}

# Get installed updates using Get-HotFix
Write-Host ""
Write-Host "Installed Hotfixes (Get-HotFix):" -ForegroundColor Yellow
Write-Host "=" * 70

try {
    $hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10
    
    foreach ($hotfix in $hotfixes) {
        $installedDate = if ($hotfix.InstalledOn) { $hotfix.InstalledOn.ToString('yyyy-MM-dd') } else { "Unknown" }
        
        Write-Host "Install Date: " -NoNewline
        Write-Host "$installedDate" -ForegroundColor Cyan
        Write-Host "KB Number:    " -NoNewline
        Write-Host "$($hotfix.HotFixID)" -ForegroundColor White
        Write-Host "Description:  $($hotfix.Description)"
        Write-Host "Installed by: $($hotfix.InstalledBy)"
        Write-Host "-" * 50
    }
} catch {
    Write-Host "Unable to retrieve hotfix information." -ForegroundColor Red
}

Write-Host ""
Write-Host "Update search completed." -ForegroundColor Green