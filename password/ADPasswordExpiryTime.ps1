<#
.SYNOPSIS
Retrieves the Active Directory user password expiry time and other related properties.

.DESCRIPTION
This script fetches the Active Directory user specified by the environment variable 'UserName' and retrieves the properties 
'msDS-UserPasswordExpiryTimeComputed', 'PasswordLastSet', and 'CannotChangePassword'. It then selects and formats the output 
to display the user's name, password expiry date, and the last time the password was set.

.PARAMETER UserName
The username of the Active Directory user, provided through the environment variable $Env:UserName.

.OUTPUTS
System.Object
A custom object with the following properties:
- Name: The name of the user.
- ExpiryDate: The date and time when the user's password will expire, converted from the 'msDS-UserPasswordExpiryTimeComputed' property.
- PasswordLastSet: The date and time when the user's password was last set.

.EXAMPLE
# Example usage:
# Ensure the environment variable 'UserName' is set to the desired AD user.
$Env:UserName = "jdoe"
.\ADPasswordExpiryTime.ps1

#>

Get-ADUser $Env:UserName -Properties msDS-UserPasswordExpiryTimeComputed, PasswordLastSet, CannotChangePassword | select Name, @{Name="ExpiryDate";Expression={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")}}, PasswordLastSet