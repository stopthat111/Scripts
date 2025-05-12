# Install AzureAD module if not already installed
if (-not (Get-Module -Name AzureAD -ErrorAction SilentlyContinue)) {
    Install-Module -Name AzureAD -Force -AllowClobber
}

# Import AzureAD module
Import-Module AzureAD

# Define credentials (replace placeholders)
$adminUsername = "admin@yourdomain.onmicrosoft.com"
$adminPassword = ConvertTo-SecureString "YourAdminPassword" -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)

# Connect to Azure AD
Connect-AzureAD -Credential $creds

# Join the computer to Azure AD
Add-AzureADDeviceRegisteredOwner -DeviceId "{YourDeviceId}" -ObjectId "{UserObjectId}"
