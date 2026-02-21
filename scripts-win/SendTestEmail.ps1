<#
.SYNOPSIS
Sends a test email using SMTP with configurable server settings and optional authentication.

.DESCRIPTION
This script sends a simple test email to verify SMTP connectivity and configuration. 
It supports both anonymous and authenticated SMTP connections, with SSL enabled automatically 
when using credentials. The email includes a timestamp in both subject and body.

.PARAMETER SmtpServer
The SMTP server hostname or IP address to use for sending the email.

.PARAMETER From
The sender's email address that will appear in the "From" field.

.PARAMETER To
The recipient's email address where the test email will be sent.

.PARAMETER Port
The SMTP server port number. Defaults to 25 if not specified.

.PARAMETER UseCredentials
Switch parameter that enables SMTP authentication. When specified, prompts for credentials 
and automatically enables SSL encryption.

.EXAMPLE
.\SendTestEmail.ps1 -SmtpServer "mail.example.com" -From "test@example.com" -To "recipient@example.com"

Sends a test email using anonymous SMTP on the default port 25.

.EXAMPLE
.\SendTestEmail.ps1 -SmtpServer "smtp.gmail.com" -Port 587 -From "sender@gmail.com" -To "recipient@gmail.com" -UseCredentials

Sends a test email using Gmail SMTP with authentication on port 587.

.NOTES
- When UseCredentials is specified, SSL is automatically enabled
- The script properly disposes of mail objects in the finally block
- Timestamps are included in both subject and body for verification
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SmtpServer,
    
    [Parameter(Mandatory=$true)]
    [string]$From,
    
    [Parameter(Mandatory=$true)]
    [string]$To,
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 25,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseCredentials
)

try {
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $From
    $mailMessage.To.Add($To)
    $mailMessage.Subject = "Test email - $(Get-Date)"
    $mailMessage.Body = "This is a test email sent from PowerShell at $(Get-Date)"
    
    $smtpClient = New-Object System.Net.Mail.SmtpClient($SmtpServer, $Port)
    
     if ($UseCredentials) {
        $credential = Get-Credential -Message "Enter SMTP credentials"
        $smtpClient.Credentials = $credential
        $smtpClient.EnableSsl = $true
    }
    
    Write-Host "Sending email..." -ForegroundColor Yellow
    $smtpClient.Send($mailMessage)
    Write-Host "Email sent successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to send email: $($_.Exception.Message)"
}
finally {
    if ($mailMessage) { $mailMessage.Dispose() }
    if ($smtpClient) { $smtpClient.Dispose() }
} 
