<#
.SYNOPSIS
    Bootstraps a developer machine with essential tools and PowerShell modules.

.DESCRIPTION
    Installs required software packages via Windows Package Manager (winget) and PowerShell modules
    needed for Azure development and infrastructure as code work. This script sets up Visual Studio Code,
    Bicep, Git, Azure CLI, and Microsoft Graph PowerShell modules.

.NOTES
    - Requires Windows Package Manager (winget) to be installed
    - Requires administrative privileges for some module installations
    - User must have appropriate permissions for winget and PowerShell module installation
    - Execution policy must allow script execution (RemoteSigned or less restrictive)

.EXAMPLE
    .\DeveloperBootstrap.ps1

.REMARKS
    Commented out git configuration commands are provided as reference.
    Configure git user identity and SSH keys manually after running this script:
    - git config --global user.name "Firstname Lastname"
    - git config --global user.email "firstname.lastname@domain.com"
    - ssh-keygen -t ed25519 -C "firstname.lastname@domain.com"
#>

winget install --id=Microsoft.VisualStudioCode -e --accept-source-agreements --scope user
winget install --id=Microsoft.Bicep -e --accept-source-agreements --scope user
winget install --id=Git.Git -e --accept-package-agreements --accept-source-agreements --scope user
winget install --exact --id Microsoft.AzureCLI --scope user
Install-Module Az -Scope AllUsers
(Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser)
Install-Module Microsoft.Graph -Scope AllUsers
Install-Module Microsoft.Graph.Beta -Scope AllUsers


# git config --global user.name "Fistname Lastname"
# git config --global user.email "firstname.lastname@domain.com"
# ssh-keygen -t ed25519 -C "firstname.lastname@domain.com"