
<#
.SYNOPSIS
Gets Windows Event Log entries from selected logs.

.DESCRIPTION
The script retrieves events primarily with Get-WinEvent and
uses Get-EventLog as a fallback when needed. Results can be shown
as a table, returned as raw objects, or exported to a CSV file.

.PARAMETER LogName
The log name to query. Default is System.

.PARAMETER Newest
Number of newest events to retrieve. Allowed range is 1-5000.

.PARAMETER Level
Optional filter for event level. Allowed values:
Critical, Error, Warning, Information, Verbose.

.PARAMETER OutFile
Optional CSV file path. If provided, results are exported as CSV.
The destination directory is created if it does not exist.

.PARAMETER ListLogs
Lists available logs and exits.

.PARAMETER Raw
Returns events as raw objects without formatted table output.

.EXAMPLE
.\Get-EventLogReport.ps1
Gets the 30 newest events from the System log.

.EXAMPLE
.\Get-EventLogReport.ps1 -LogName Application -Newest 100 -Level Error,Warning
Gets the 100 newest Error and Warning events from the Application log.

.EXAMPLE
.\Get-EventLogReport.ps1 -LogName Security -Newest 50 -OutFile .\out\security.csv
Gets the 50 newest events from the Security log and exports them to CSV.

.EXAMPLE
.\Get-EventLogReport.ps1 -ListLogs
Lists available logs.
#>

[CmdletBinding()]
param(
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$LogName = 'System',

	[Parameter()]
	[ValidateRange(1, 5000)]
	[int]$Newest = 30,

	[Parameter()]
	[ValidateSet('Critical', 'Error', 'Warning', 'Information', 'Verbose')]
	[string[]]$Level,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$OutFile,

	[Parameter()]
	[switch]$ListLogs,

	[Parameter()]
	[switch]$Raw
)

$ErrorActionPreference = 'Stop'

$levelMap = @{
	Critical    = 1
	Error       = 2
	Warning     = 3
	Information = 4
	Verbose     = 5
}

if ($ListLogs) {
	try {
		Get-WinEvent -ListLog * |
			Sort-Object -Property LogName |
			Select-Object LogName, RecordCount, IsEnabled, LogMode, MaximumSizeInBytes |
			Format-Table -AutoSize
	}
	catch {
		Write-Warning "Get-WinEvent log listing failed. Falling back to classic logs. Error: $($_.Exception.Message)"
		Get-EventLog -List |
			Sort-Object -Property Log |
			Format-Table -Property Log, Entries, MaximumKilobytes, OverflowAction -AutoSize
	}

	return
}

$filter = @{ LogName = $LogName }
if ($Level) {
	$filter.Level = @($Level | ForEach-Object { $levelMap[$_] })
}

try {
	$events = Get-WinEvent -FilterHashtable $filter -MaxEvents $Newest
}
catch {
	Write-Warning "Get-WinEvent failed for log '$LogName'. Falling back to Get-EventLog. Error: $($_.Exception.Message)"
	$events = Get-EventLog -LogName $LogName -Newest $Newest

	if ($Level) {
		$events = $events | Where-Object { $Level -contains $_.EntryType.ToString() }
	}
}

if (-not $events) {
	Write-Host "No events found in '$LogName'."
	return
}

if ($Raw) {
	$events
	return
}


$output = $events |
	Select-Object @(
		@{ Name = 'Time'; Expression = { if ($_.TimeCreated) { $_.TimeCreated } else { $_.TimeGenerated } } },
		@{ Name = 'Level'; Expression = { if ($_.LevelDisplayName) { $_.LevelDisplayName } else { $_.EntryType } } },
		@{ Name = 'Source'; Expression = { if ($_.ProviderName) { $_.ProviderName } else { $_.Source } } },
		@{ Name = 'EventId'; Expression = { if ($_.Id) { $_.Id } else { $_.EventID } } },
		@{ Name = 'Message'; Expression = {
				$msg = if ($_.Message) { $_.Message } else { '' }
				$singleLine = ($msg -replace '\r?\n', ' ').Trim()
				if ($singleLine.Length -gt 120) { $singleLine.Substring(0, 120) + '...' } else { $singleLine }
			} }
	)

if ($OutFile) {
	$directory = Split-Path -Path $OutFile -Parent
	if ($directory -and -not (Test-Path -LiteralPath $directory)) {
		New-Item -ItemType Directory -Path $directory -Force | Out-Null
	}

	$output | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
	Write-Host "Exported $($output.Count) event(s) to '$OutFile'."
}

$output |
	Format-Table -AutoSize