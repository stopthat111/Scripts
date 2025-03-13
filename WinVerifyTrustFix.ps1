try {
    # Ensure the registry paths exist
    if ((Test-Path -LiteralPath "HKLM:\Software\Microsoft\Cryptography\Wintrust") -ne $true) {
        New-Item -Path "HKLM:\Software\Microsoft\Cryptography\Wintrust" -Force -ErrorAction Stop
    }
    if ((Test-Path -LiteralPath "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust") -ne $true) {
        New-Item -Path "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust" -Force -ErrorAction Stop
    }

    # Create the Config key if it doesn't exist
    if ((Test-Path -LiteralPath "HKLM:\Software\Microsoft\Cryptography\Wintrust\Config") -ne $true) {
        New-Item -Path "HKLM:\Software\Microsoft\Cryptography\Wintrust\Config" -Force -ErrorAction Stop
    }
    if ((Test-Path -LiteralPath "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config") -ne $true) {
        New-Item -Path "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" -Force -ErrorAction Stop
    }

    # Add the registry properties
    New-ItemProperty -LiteralPath 'HKLM:\Software\Microsoft\Cryptography\Wintrust\Config' -Name 'EnableCertPaddingCheck' -Value 1 -PropertyType DWord -Force -ErrorAction Stop
    New-ItemProperty -LiteralPath 'HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config' -Name 'EnableCertPaddingCheck' -Value 1 -PropertyType DWord -Force -ErrorAction Stop

    Write-Host "Registry changes applied successfully."
} catch {
    Write-Host "Error occurred: $_"
}
