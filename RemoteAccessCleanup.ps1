# List of remote access tools to uninstall and their registry display names
$appsToUninstall = @(
    @{ "Name" = "UltraVNC"; "RegistryKey" = "UltraVNC" },
    @{ "Name" = "TightVNC"; "RegistryKey" = "TightVNC" },
    @{ "Name" = "GoToMyPC"; "RegistryKey" = "GoToMyPC" },
    @{ "Name" = "TeamViewer"; "RegistryKey" = "TeamViewer" },
    @{ "Name" = "AnyDesk"; "RegistryKey" = "AnyDesk" },
    @{ "Name" = "LogMeIn"; "RegistryKey" = "LogMeIn" },
    @{ "Name" = "Chrome Remote Desktop"; "RegistryKey" = "Chrome Remote Desktop" },
    @{ "Name" = "RemotePC"; "RegistryKey" = "RemotePC" },
    @{ "Name" = "Splashtop"; "RegistryKey" = "Splashtop" },
    @{ "Name" = "Ammyy Admin"; "RegistryKey" = "Ammyy Admin" }
)

# Function to uninstall an application by its registry uninstall entry
function Uninstall-App {
    param (
        [string]$displayName
    )

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $registryPaths) {
        $subKeys = Get-ChildItem -Path $path | Where-Object {
            (Get-ItemProperty -Path $_.PSPath).DisplayName -like "*$displayName*"
        }

        foreach ($subKey in $subKeys) {
            $appDetails = Get-ItemProperty -Path $subKey.PSPath
            if ($appDetails -and $appDetails.UninstallString) {
                Write-Output "Attempting to uninstall $displayName..."
                
                try {
                    # Use the UninstallString to uninstall
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$($appDetails.UninstallString) /quiet /norestart" -Wait
                    Write-Output "$displayName uninstalled successfully."
                }
                catch {
                    Write-Output "Failed to uninstall $displayName. Error: $_"
                }

                return
            }
        }
    }

    Write-Output "$displayName not found in registry."
}

# Loop through each application and uninstall
foreach ($app in $appsToUninstall) {
    Uninstall-App -displayName $app.RegistryKey
}
