<#
.SYNOPSIS
Retrieves and exports a list of users who have not signed in within the last 90 days.

.DESCRIPTION
This script connects to Microsoft Graph with the required scopes, retrieves users who have not signed in within the last 90 days, and exports the selected user information to a CSV file.

.EXAMPLE
.\LastSignInDateTime.ps1
This example runs the script and exports the list of inactive users to "inactive_users.csv".

.NOTES
Ensure you have the necessary permissions to access Microsoft Graph API and the required modules installed.
#>

Connect-MgGraph -Scopes "User.Read.All", "AuditLog.Read.All"
$date = [DateTime]::Today.AddDays(-90)
$users = Get-MGUser  -Filter "signInActivity/lastSignInDateTime le $($date.ToUniversalTime().ToString("yyyy-MM-ddThh:mm:ssZ"))" -Select Id, userPrincipalName, mail, signInActivity, companyName, accountEnabled
$selectedUsers = $users | SELECT ID, mail, userprincipalname, companyName, accountEnabled, @{N="lastSignInDateTime"; e={$_.signInActivity.lastSignInDateTime}}
$selectedUsers | Export-Csv -Path "inactive_users.csv" -NoTypeInformation