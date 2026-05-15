<#
.SYNOPSIS
    Lists servers (computer objects) that belong to a specified Active Directory group.

.DESCRIPTION
    This script retrieves all computer objects that are members of the specified Active Directory
    group and displays their details. The script reports for each computer:
    - Computer Name
    - Operating System
    - Account Status (Enabled/Disabled)
    - Last Logon Date
    - IPv4 Address
    - DNS Host Name
    - Distinguished Name

    By default, only direct members are listed. Use -Recurse to include members of nested groups.
    Use -ServerOnly to filter results to Windows Server operating systems only.
    Use -OutputPath to export the results to a CSV file.

.PARAMETER GroupName
    The name of the Active Directory group to query. This parameter is mandatory.

.PARAMETER Recurse
    If specified, includes computer objects from nested groups recursively.

.PARAMETER ServerOnly
    If specified, only returns computers running Windows Server operating systems
    (OperatingSystem matches '*Server*').

.PARAMETER OutputPath
    If specified, exports the results to a CSV file in the given directory.

.EXAMPLE
    .\Get-ADGroupServers.ps1 -GroupName "Production Servers"
    Lists all computer objects directly in the 'Production Servers' group.

.EXAMPLE
    .\Get-ADGroupServers.ps1 -GroupName "Production Servers" -Recurse
    Lists all computer objects in the group, including members of nested groups.

.EXAMPLE
    .\Get-ADGroupServers.ps1 -GroupName "All Computers" -ServerOnly
    Lists only Windows Server computers in the group.

.EXAMPLE
    .\Get-ADGroupServers.ps1 -GroupName "Production Servers" -Recurse -OutputPath "C:\Reports"
    Lists all servers recursively and exports the results to a CSV file.

.NOTES
    Requirements:
    - Windows PowerShell 5.1+ or PowerShell 7+
    - Active Directory PowerShell module (RSAT)
    - Read permissions to Active Directory

    Installation (if ActiveDirectory module is missing):
    Windows 10/11:
        Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

    Windows Server:
        Install-WindowsFeature -Name RSAT-AD-PowerShell

    Author: Generated for Active Directory auditing
    Version: 1.0
    Date: 2026-05-15
#>

#Requires -Modules ActiveDirectory

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Recurse,

    [Parameter(Mandatory = $false)]
    [switch]$ServerOnly,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

#region Helper Function

function Get-ComputersFromGroup {
    <#
    .SYNOPSIS
        Retrieves computer objects from an AD group, optionally recursing into nested groups.

    .PARAMETER GroupDN
        The Distinguished Name of the group to process.

    .PARAMETER ProcessedGroups
        Hashtable of already-processed group DNs to prevent infinite loops in circular group structures.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupDN,

        [Parameter(Mandatory = $false)]
        [hashtable]$ProcessedGroups = @{}
    )

    # Guard against circular group membership
    if ($ProcessedGroups.ContainsKey($GroupDN)) {
        Write-Verbose "Group '$GroupDN' already processed, skipping."
        return
    }
    $ProcessedGroups[$GroupDN] = $true

    try {
        $members = Get-ADGroupMember -Identity $GroupDN -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to retrieve members of group '$GroupDN': $($_.Exception.Message)"
        return
    }

    foreach ($member in $members) {
        if ($member.objectClass -eq 'computer') {
            try {
                $computer = Get-ADComputer -Identity $member.DistinguishedName `
                    -Properties OperatingSystem, Enabled, LastLogonDate, IPv4Address, DNSHostName `
                    -ErrorAction Stop

                [PSCustomObject]@{
                    Name              = $computer.Name
                    OperatingSystem   = $computer.OperatingSystem
                    Enabled           = $computer.Enabled
                    LastLogonDate     = if ($computer.LastLogonDate) { $computer.LastLogonDate } else { 'Never' }
                    IPv4Address       = $computer.IPv4Address
                    DNSHostName       = $computer.DNSHostName
                    DistinguishedName = $computer.DistinguishedName
                }
            }
            catch {
                Write-Warning "Failed to retrieve details for computer '$($member.Name)': $($_.Exception.Message)"
            }
        }
        elseif ($member.objectClass -eq 'group' -and $Recurse) {
            Write-Verbose "Recursing into nested group: $($member.Name)"
            Get-ComputersFromGroup -GroupDN $member.DistinguishedName -ProcessedGroups $ProcessedGroups -Verbose:$VerbosePreference
        }
    }
}

#endregion

#region Main

try {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " AD Group Servers Report" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""

    # Ensure the ActiveDirectory module is loaded
    if (-not (Get-Module -Name ActiveDirectory)) {
        Write-Host "Loading ActiveDirectory module..." -ForegroundColor Yellow
        Import-Module ActiveDirectory -ErrorAction Stop
    }

    Write-Host "Group     : $GroupName" -ForegroundColor White
    Write-Host "Recurse   : $Recurse" -ForegroundColor White
    Write-Host "ServerOnly: $ServerOnly" -ForegroundColor White
    if ($OutputPath) {
        Write-Host "Output    : $OutputPath" -ForegroundColor White
    }
    Write-Host ""

    # Verify the group exists
    Write-Host "Verifying group..." -ForegroundColor Yellow
    $targetGroup = Get-ADGroup -Identity $GroupName -ErrorAction Stop
    Write-Host "✓ Group found: $($targetGroup.DistinguishedName)" -ForegroundColor Green
    Write-Host ""

    # Retrieve computers
    Write-Host "Retrieving computer objects$(if ($Recurse) { ' (recursive)' })..." -ForegroundColor Yellow
    $computers = @(Get-ComputersFromGroup -GroupDN $targetGroup.DistinguishedName -Verbose:$VerbosePreference)

    if ($computers.Count -eq 0) {
        Write-Host "⚠ No computer objects found in the group." -ForegroundColor Yellow
        exit 0
    }

    # Optional: filter to server OS only
    if ($ServerOnly) {
        $computers = @($computers | Where-Object { $_.OperatingSystem -like '*Server*' })
        if ($computers.Count -eq 0) {
            Write-Host "⚠ No Windows Server computers found in the group." -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Host "✓ Found $($computers.Count) computer(s)." -ForegroundColor Green
    Write-Host ""

    # Display results
    $computers | Sort-Object Name | Format-Table -AutoSize -Property Name, OperatingSystem, Enabled, LastLogonDate, IPv4Address

    # Optional: CSV export
    if ($OutputPath) {
        if (-not (Test-Path -Path $OutputPath -PathType Container)) {
            throw "Output directory '$OutputPath' does not exist. Create the directory first."
        }

        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $safeName  = $GroupName -replace '[^A-Za-z0-9_-]', '_'
        $csvFile   = Join-Path -Path $OutputPath -ChildPath "ADGroupServers_${safeName}_${timestamp}.csv"

        $computers | Sort-Object Name | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Host "✓ Results exported to: $csvFile" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#endregion
