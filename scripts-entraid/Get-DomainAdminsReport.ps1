<#
.SYNOPSIS
    Lists Active Directory Domain Admins group members, including memberships through nested groups.

.DESCRIPTION
    This script recursively examines Active Directory group members and identifies all users
    who belong to the group either directly or through nested groups. The script reports for each user:
    - Username (SamAccountName)
    - Display Name
    - Membership Path (how the user obtained permissions)
    - Account Status (Enabled/Disabled)
    - Last Logon Date
    
    Results are exported to a CSV file with a timestamp.

.PARAMETER GroupName
    The name of the Active Directory group whose members should be listed.
    Default: "Domain Admins"

.PARAMETER OutputPath
    The directory where the CSV report will be saved.
    Default: Current directory

.EXAMPLE
    .\Get-DomainAdminsReport.ps1
    Lists Domain Admins group members and saves the report to the current directory.

.EXAMPLE
    .\Get-DomainAdminsReport.ps1 -GroupName "Enterprise Admins" -OutputPath "C:\Reports"
    Lists Enterprise Admins group members and saves the report to C:\Reports directory.

.EXAMPLE
    .\Get-DomainAdminsReport.ps1 -GroupName "Schema Admins"
    Lists Schema Admins group members.

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
    Date: 2026-03-03
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$GroupName = "Domain Admins",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Get-Location).Path
)

#Requires -Modules ActiveDirectory

# Function for recursive group membership examination
function Get-ADGroupMemberRecursive {
    <#
    .SYNOPSIS
        Retrieves group members recursively, including nested groups.
    
    .PARAMETER GroupName
        The group name or Distinguished Name
    
    .PARAMETER MembershipPath
        The membership path string (used in recursion)
    
    .PARAMETER ProcessedGroups
        Hashtable of already processed groups (prevents infinite loops)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        
        [Parameter(Mandatory = $false)]
        [string]$MembershipPath = "Direct",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$ProcessedGroups = @{}
    )
    
    try {
        # Get the group
        $group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
        
        # Check if the group has already been processed (prevents infinite loops)
        if ($ProcessedGroups.ContainsKey($group.DistinguishedName)) {
            Write-Verbose "Group '$($group.Name)' has already been processed, skipping."
            return
        }
        
        # Mark the group as processed
        $ProcessedGroups[$group.DistinguishedName] = $true
        
        # Get the group members
        $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction Stop
        
        foreach ($member in $members) {
            if ($member.objectClass -eq 'user') {
                # User found - get additional details
                try {
                    $user = Get-ADUser -Identity $member.DistinguishedName -Properties DisplayName, Enabled, LastLogonDate -ErrorAction Stop
                    
                    # Create membership path
                    $currentPath = if ($MembershipPath -eq "Direct") {
                        "Direct"
                    } else {
                        "$MembershipPath → $($group.Name)"
                    }
                    
                    # Return user details
                    [PSCustomObject]@{
                        Username        = $user.SamAccountName
                        DisplayName     = $user.DisplayName
                        MembershipPath  = $currentPath
                        AccountEnabled  = $user.Enabled
                        LastLogonDate   = if ($user.LastLogonDate) { $user.LastLogonDate } else { "Never" }
                        DistinguishedName = $user.DistinguishedName
                    }
                }
                catch {
                    Write-Warning "Error retrieving user details: $($member.Name) - $_"
                }
            }
            elseif ($member.objectClass -eq 'group') {
                # Nested group found - process recursively
                Write-Verbose "Processing nested group: $($member.Name)"
                
                $nestedPath = if ($MembershipPath -eq "Direct") {
                    $group.Name
                } else {
                    "$MembershipPath → $($group.Name)"
                }
                
                Get-ADGroupMemberRecursive -GroupName $member.DistinguishedName -MembershipPath $nestedPath -ProcessedGroups $ProcessedGroups
            }
        }
    }
    catch {
        Write-Error "Error processing group '$GroupName': $_"
    }
}

# Main program
try {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " Domain Admins Report" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if ActiveDirectory module is loaded
    if (-not (Get-Module -Name ActiveDirectory)) {
        Write-Host "Loading ActiveDirectory module..." -ForegroundColor Yellow
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    
    Write-Host "Group: $GroupName" -ForegroundColor White
    Write-Host "Output directory: $OutputPath" -ForegroundColor White
    Write-Host ""
    
    # Check if the group exists
    Write-Host "Verifying group existence..." -ForegroundColor Yellow
    $targetGroup = Get-ADGroup -Identity $GroupName -ErrorAction Stop
    Write-Host "✓ Group found: $($targetGroup.DistinguishedName)" -ForegroundColor Green
    Write-Host ""
    
    # Collect all members recursively
    Write-Host "Retrieving members recursively..." -ForegroundColor Yellow
    $allMembers = @(Get-ADGroupMemberRecursive -GroupName $GroupName -Verbose:$VerbosePreference)
    
    if ($allMembers.Count -eq 0) {
        Write-Host "⚠ The group has no members." -ForegroundColor Yellow
        return
    }
    
    # Remove duplicates (same user can be in multiple nested groups)
    Write-Host "Found a total of $($allMembers.Count) memberships (including duplicates)." -ForegroundColor White
    
    # Group by users and combine membership paths
    $uniqueMembers = $allMembers | Group-Object -Property Username | ForEach-Object {
        $user = $_.Group[0]
        $paths = ($_.Group | Select-Object -ExpandProperty MembershipPath | Sort-Object -Unique) -join "; "
        
        [PSCustomObject]@{
            Username        = $user.Username
            DisplayName     = $user.DisplayName
            MembershipPath  = $paths
            AccountEnabled  = $user.AccountEnabled
            LastLogonDate   = $user.LastLogonDate
        }
    }
    
    Write-Host "Unique users: $($uniqueMembers.Count)" -ForegroundColor White
    Write-Host ""
    
    # Create filename with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $sanitizedGroupName = $GroupName -replace '[\\/:*?"<>|]', '_'
    $fileName = "${sanitizedGroupName}_Report_${timestamp}.csv"
    $fullPath = Join-Path -Path $OutputPath -ChildPath $fileName
    
    # Export to CSV file
    Write-Host "Exporting to file: $fullPath" -ForegroundColor Yellow
    $uniqueMembers | Export-Csv -Path $fullPath -NoTypeInformation -Encoding UTF8
    
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host "✓ Report complete!" -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "File: $fullPath" -ForegroundColor White
    Write-Host "Total users: $($uniqueMembers.Count)" -ForegroundColor White
    Write-Host ""
    
    # Display summary
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  - Active accounts: $(($uniqueMembers | Where-Object { $_.AccountEnabled -eq $true }).Count)" -ForegroundColor White
    Write-Host "  - Disabled accounts: $(($uniqueMembers | Where-Object { $_.AccountEnabled -eq $false }).Count)" -ForegroundColor White
    Write-Host "  - Direct memberships: $(($uniqueMembers | Where-Object { $_.MembershipPath -eq 'Direct' }).Count)" -ForegroundColor White
    Write-Host "  - Through nested groups: $(($uniqueMembers | Where-Object { $_.MembershipPath -ne 'Direct' }).Count)" -ForegroundColor White
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Red
    Write-Host "✗ Error" -ForegroundColor Red
    Write-Host "===============================================" -ForegroundColor Red
    Write-Host ""
    
    if ($_.Exception.Message -like "*Unable to find a default server*") {
        Write-Host "Error: Unable to connect to Active Directory server." -ForegroundColor Red
        Write-Host "Ensure the machine is joined to the domain and has network connectivity to a domain controller." -ForegroundColor Yellow
    }
    elseif ($_.Exception.Message -like "*Cannot find an object with identity*") {
        Write-Host "Error: Group '$GroupName' was not found in Active Directory." -ForegroundColor Red
        Write-Host "Check the group name and try again." -ForegroundColor Yellow
    }
    elseif ($_.Exception.Message -like "*Access is denied*") {
        Write-Host "Error: Insufficient permissions." -ForegroundColor Red
        Write-Host "You need read permissions to Active Directory to run this script." -ForegroundColor Yellow
    }
    else {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Full error message:" -ForegroundColor Gray
    Write-Host $_.Exception.ToString() -ForegroundColor Gray
    
    exit 1
}
