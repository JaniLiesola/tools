$AIHeader = @"
### AI ANALYSIS CONTEXT - DO NOT IGNORE ###
Role: Senior Infrastructure Architect / Senior Technical Consultant.
Task: Analyze the following diagnostic output from a critical server environment.
Instructions: Provide a concise, high-level technical summary. Identify root causes or anomalies (resource exhaustion, service failures, or specific error codes). Skip basic explanations; focus on advanced troubleshooting steps, performance bottlenecks, and architectural impact.
###########################################

"@

Write-Host "--- AIHeader ---" -ForegroundColor Cyan 
Write-Output $AIHeader

Write-Host "--- COMPATIBILITY CHECK ---" -ForegroundColor Cyan
$requiredCommands = @('Get-CimInstance', 'Get-Process', 'Get-WinEvent', 'Get-ChildItem')
$optionalCommands = @('Get-Volume', 'Get-NetTCPConnection', 'Get-HotFix')

$missingRequired = $requiredCommands | Where-Object {
    -not (Get-Command $_ -ErrorAction SilentlyContinue)
}

if ($missingRequired.Count -eq 0) {
    Write-Host "Required commands: OK"
} else {
    Write-Host "Missing required commands: $($missingRequired -join ', ')" -ForegroundColor Yellow
}

$missingOptional = $optionalCommands | Where-Object {
    -not (Get-Command $_ -ErrorAction SilentlyContinue)
}

if ($missingOptional.Count -gt 0) {
    Write-Host "Missing optional commands: $($missingOptional -join ', ')" -ForegroundColor Yellow
}

Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host ""

# Extracts a named value from EventData XML fields.
function Get-EventDataField {
    param(
        [Parameter(Mandatory)]
        $Record,

        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        $xml = [xml]$Record.ToXml()
        $node = $xml.Event.EventData.Data | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
        if ($node) { return [string]$node.'#text' }
    }
    catch {
        return $null
    }

    return $null
}

# Core OS identity and uptime context.
Write-Host "--- OS & UPTIME ---" -ForegroundColor Cyan
$OS = Get-CimInstance Win32_OperatingSystem
$Uptime = (Get-Date) - $OS.LastBootUpTime
Write-Host "Server: $($OS.CSName) | OS: $($OS.Caption) | Uptime: $($Uptime.Days)d $($Uptime.Hours)h"

Write-Host "`n--- DISK STATUS (Logical) ---" -ForegroundColor Cyan
Get-Volume | Where-Object {$_.DriveLetter} | Select-Object DriveLetter, @{Name="Free%";Expression={[math]::Round(($_.SizeRemaining / $_.Size) * 100, 1)}}, @{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining/1GB,2)}} | Format-Table -AutoSize | Out-Host

Write-Host "`n--- TOP 5 PROCESSES (CPU) ---" -ForegroundColor Cyan
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, WorkingSet | Format-Table -AutoSize | Out-Host

Write-Host "`n--- NETWORK: LISTENING PORTS ---" -ForegroundColor Cyan
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess | Sort-Object LocalPort | Select-Object -First 15 | Format-Table -AutoSize | Out-Host

Write-Host "`n--- LOG FILE FRESHNESS ---" -ForegroundColor Cyan
Get-ChildItem -Path C:\Windows\Logs -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10 Name, LastWriteTime | Format-Table -AutoSize | Out-Host

Write-Host "`n--- AUTO-START SERVICES NOT RUNNING ---" -ForegroundColor Cyan
try {
    $stoppedAuto = Get-Service -ErrorAction Stop |
        Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }

    if ($stoppedAuto) {
        $stoppedAuto |
            Select-Object -First 15 Name, DisplayName, StartType, Status |
            Format-Table -AutoSize |
            Out-Host
    }
    else {
        Write-Host "All automatic services are running."
    }
}
catch {
    Write-Host "Could not query service state." -ForegroundColor Yellow
}

Write-Host "`n--- CRITICAL EVENT LOGS (Last 10) ---" -ForegroundColor Cyan
try {
    Get-WinEvent -FilterHashtable @{LogName='System','Application'; Level=1,2} -MaxEvents 10 -ErrorAction SilentlyContinue | Select-Object TimeCreated, LogName, ProviderName, Message | Format-List | Out-Host
} catch {
    Write-Host "No critical events found or access denied."
}

# Reads currently pending software updates via Windows Update API (read-only).
Write-Host "`n--- PENDING UPDATE STATUS ---" -ForegroundColor Cyan
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $pendingSearchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
    $pendingCount = $pendingSearchResult.Updates.Count

    Write-Host "Pending software updates: $pendingCount"

    if ($pendingCount -gt 0) {
        $pendingList = for ($index = 0; $index -lt [Math]::Min(10, $pendingCount); $index++) {
            $item = $pendingSearchResult.Updates.Item($index)
            [pscustomobject]@{
                Title        = $item.Title
                IsDownloaded = $item.IsDownloaded
                RequiresReboot = $item.RebootRequired
            }
        }

        $pendingList | Format-Table -AutoSize | Out-Host
    }
}
catch {
    Write-Host "Could not query pending updates from Windows Update API." -ForegroundColor Yellow
}

# Aggregates common registry-based reboot requirement indicators.
Write-Host "`n--- REBOOT REQUIREMENT ---" -ForegroundColor Cyan
try {
    $rebootSignals = [ordered]@{
        "CBS RebootPending" = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        "Windows Update RebootRequired" = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        "Pending File Rename Operations" = $false
    }

    $sessionManager = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
    if ($sessionManager -and $sessionManager.PendingFileRenameOperations) {
        $rebootSignals["Pending File Rename Operations"] = $true
    }

    $rebootRequired = $rebootSignals.Values -contains $true
    Write-Host "Reboot required: $rebootRequired"
    $rebootSignals.GetEnumerator() | ForEach-Object {
        Write-Host "- $($_.Key): $($_.Value)"
    }
}
catch {
    Write-Host "Could not determine reboot requirement state." -ForegroundColor Yellow
}

# Shows recent boot/restart related events for timeline context.
Write-Host "`n--- RECENT BOOT HISTORY ---" -ForegroundColor Cyan
try {
    $bootEvents = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 6005,6006,6009,1074 } -MaxEvents 80 -ErrorAction Stop |
        Where-Object { $_.Id -in 6005,6009,1074 } |
        Select-Object -First 10 @{Name='TimeCreated';Expression={$_.TimeCreated}},
            @{Name='EventId';Expression={$_.Id}},
            @{Name='Source';Expression={$_.ProviderName}},
            @{Name='Message';Expression={
                $line = (($_.Message -replace "`r?`n", ' ').Trim())
                if ($line.Length -gt 120) { $line.Substring(0, 120) + '...' } else { $line }
            }}

    if ($bootEvents) {
        $bootEvents | Format-Table -AutoSize | Out-Host
    }
    else {
        Write-Host "No recent boot events returned from System log."
    }
}
catch {
    Write-Host "Could not read boot history from System event log." -ForegroundColor Yellow
}

# Shows recently installed updates, with event-log fallback if hotfix query fails.
Write-Host "`n--- LATEST INSTALLED UPDATES ---" -ForegroundColor Cyan
try {
    $hotfixes = Get-HotFix -ErrorAction Stop |
        Sort-Object InstalledOn -Descending |
        Select-Object -First 10 HotFixID, InstalledOn, Description, InstalledBy

    if ($hotfixes) {
        $hotfixes | Format-Table -AutoSize | Out-Host
    }
    else {
        Write-Host "No hotfix entries returned by Get-HotFix."
    }
}
catch {
    Write-Host "Get-HotFix unavailable. Trying Windows Update event history..." -ForegroundColor Yellow
    try {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WindowsUpdateClient'; Id = 19,20,21,43,44 } -MaxEvents 15 -ErrorAction Stop |
            Select-Object TimeCreated, Id, ProviderName, Message |
            Format-List |
            Out-Host
    }
    catch {
        Write-Host "Could not retrieve installed update history from event logs." -ForegroundColor Yellow
    }
}

# Summarizes recent successful and failed interactive login activity.
Write-Host "`n--- RECENT LOGIN ACTIVITY ---" -ForegroundColor Cyan
try {
    $successfulLogons = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4624 } -MaxEvents 200 -ErrorAction Stop |
        ForEach-Object {
            $targetUser = Get-EventDataField -Record $_ -Name 'TargetUserName'
            $targetDomain = Get-EventDataField -Record $_ -Name 'TargetDomainName'
            $ipAddress = Get-EventDataField -Record $_ -Name 'IpAddress'
            $logonType = Get-EventDataField -Record $_ -Name 'LogonType'

            if ($targetUser -and $targetUser -ne 'ANONYMOUS LOGON' -and $targetUser -notlike '*$') {
                [pscustomobject]@{
                    TimeCreated = $_.TimeCreated
                    User        = if ($targetDomain) { "$targetDomain\$targetUser" } else { $targetUser }
                    LogonType   = $logonType
                    SourceIP    = if ($ipAddress) { $ipAddress } else { '-' }
                }
            }
        } |
        Select-Object -First 10

    if ($successfulLogons) {
        Write-Host "Recent successful logons (Event ID 4624):"
        $successfulLogons | Format-Table -AutoSize | Out-Host
    }
    else {
        Write-Host "No successful logons returned from Security log."
    }
}
catch {
    Write-Host "Could not read successful logons from Security log (admin rights may be required)." -ForegroundColor Yellow
}

try {
    $failedLogons = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625 } -MaxEvents 120 -ErrorAction Stop |
        ForEach-Object {
            $targetUser = Get-EventDataField -Record $_ -Name 'TargetUserName'
            $targetDomain = Get-EventDataField -Record $_ -Name 'TargetDomainName'
            $ipAddress = Get-EventDataField -Record $_ -Name 'IpAddress'
            $status = Get-EventDataField -Record $_ -Name 'Status'
            $subStatus = Get-EventDataField -Record $_ -Name 'SubStatus'

            if ($targetUser -and $targetUser -notlike '*$') {
                [pscustomobject]@{
                    TimeCreated = $_.TimeCreated
                    User        = if ($targetDomain) { "$targetDomain\$targetUser" } else { $targetUser }
                    SourceIP    = if ($ipAddress) { $ipAddress } else { '-' }
                    Status      = $status
                    SubStatus   = $subStatus
                }
            }
        } |
        Select-Object -First 10

    if ($failedLogons) {
        Write-Host "`nRecent failed logons (Event ID 4625):"
        $failedLogons | Format-Table -AutoSize | Out-Host
    }
    else {
        Write-Host "`nNo failed logons returned from Security log."
    }
}
catch {
    Write-Host "Could not read failed logons from Security log (admin rights may be required)." -ForegroundColor Yellow
}