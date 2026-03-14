# Get the last 5 system boots and who performed them
Write-Host "Searching for the last 5 system boots..." -ForegroundColor Green
Write-Host ""

# Get boot events from Event Log
$bootEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ID = 6005, 6006, 6009, 1074
} -MaxEvents 50 | Where-Object {
    $_.Id -eq 6005 -or $_.Id -eq 6009
} | Select-Object -First 5

if ($bootEvents) {
    Write-Host "Last 5 system boots:" -ForegroundColor Yellow
    Write-Host "=" * 60

    foreach ($event in $bootEvents) {
        $timeCreated = $event.TimeCreated
        $eventId = $event.Id
        
        # Find who initiated the boot
        $initiatedBy = "System"
        
        # Try to find the user who caused the boot by looking for shutdown/restart events
        $shutdownEvent = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ID = 1074
            StartTime = $timeCreated.AddMinutes(-10)
            EndTime = $timeCreated.AddMinutes(10)
        } -MaxEvents 1 -ErrorAction SilentlyContinue
        
        if ($shutdownEvent) {
            # Parse username from message
            $message = $shutdownEvent.Message
            if ($message -match "user (.+?) has") {
                $initiatedBy = $matches[1]
            } elseif ($message -match "by user (.+?)\.") {
                $initiatedBy = $matches[1]
            } elseif ($message -match "käyttäjä (.+?) on") {
                $initiatedBy = $matches[1]
            }
        }
        
        # Display information
        Write-Host "Boot Time:    " -NoNewline
        Write-Host "$($timeCreated.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
        Write-Host "Initiated by: " -NoNewline  
        Write-Host "$initiatedBy" -ForegroundColor White
        Write-Host "Event ID:     $eventId"
        Write-Host "-" * 40
    }
} else {
    Write-Host "No boot events found." -ForegroundColor Red
}

# Also get current system uptime
Write-Host ""
Write-Host "Current system uptime:" -ForegroundColor Yellow
$uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$lastBootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Write-Host "System booted: " -NoNewline
Write-Host "$($lastBootTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"