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