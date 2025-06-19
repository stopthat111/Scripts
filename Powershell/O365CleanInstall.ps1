$ODTDir = "C:\Temp\ODT"
$ODTExePath = "$ODTDir\setup.exe"
$ConfigXml = "$ODTDir\OfficeConfig.xml"
$ODTDownloadUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe"

# Prepare folder
if (!(Test-Path $ODTDir)) {
    New-Item -Path $ODTDir -ItemType Directory -Force | Out-Null
}

# Download the ODT bootstrapper
Write-Output "Downloading Office Deployment Tool..."
Invoke-WebRequest -Uri $ODTDownloadUrl -OutFile $ODTExePath

# Create XML config
@"
<Configuration>
  <Add OfficeClientEdition='64' Channel='Current'>
    <Product ID='O365ProPlusRetail'>
      <Language ID='en-us' />
      <ExcludeApp ID='Lync' />
    </Product>
  </Add>
  <Display Level='None' AcceptEULA='TRUE' />
  <Property Name='FORCEAPPSHUTDOWN' Value='TRUE' />
</Configuration>
"@ | Out-File -FilePath $ConfigXml -Encoding UTF8

# Uninstall existing Office
Write-Output "Uninstalling existing Office..."
Get-WmiObject -Class Win32_Product | Where-Object {
    $_.Name -match 'Microsoft Office' -or $_.Name -match 'Click-to-Run'
} | ForEach-Object {
    Write-Output "Uninstalling $($_.Name)"
    $_.Uninstall()
}

Start-Sleep -Seconds 15

# Run Office installation directly (no extraction)
Write-Output "Installing Office 365..."
Start-Process -FilePath $ODTExePath -ArgumentList "/configure `"$ConfigXml`"" -Wait

# Cleanup
Write-Output "Cleaning up installation files..."
Remove-Item -Path $ODTDir -Recurse -Force
Write-Output "Installation complete."
