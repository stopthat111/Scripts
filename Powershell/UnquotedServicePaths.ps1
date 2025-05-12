# Define paths
$logFile = "C:\Temp\UnquotedPathsFixLog.txt"

# Initialize the log file
Write-Output "Log of Changes Made (Unquoted Paths Fix)" > $logFile
Write-Output "Generated on: $(Get-Date)" >> $logFile
Write-Output "`nChanges Made:" >> $logFile

# Function to quote only the executable path if it contains spaces
function Quote-ExecutablePath {
    param ([string]$Path)

    # Skip if already quoted
    if ($Path -match '^".*"$') {
        return $Path
    }

    # Only modify if spaces exist in the executable path (before arguments)
    if ($Path -match '^(.*?\.(exe|bat|cmd|com))(\s+.+)?$') {
        $exePath = $matches[1]
        $arguments = $matches[3]

        if ($exePath -match '\s') {
            return "`"$exePath`"$arguments"
        }
    }

    return $Path
}

# Function to scan and fix unquoted service ImagePaths
function Fix-ServiceImagePaths {
    $serviceKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

    try {
        # Get all service registry keys
        Get-ChildItem -Path $serviceKeyPath -ErrorAction SilentlyContinue | ForEach-Object {
            $serviceName = $_.PSChildName
            $serviceRegPath = "$serviceKeyPath\$serviceName"

            # Retrieve ImagePath
            $imagePath = (Get-ItemProperty -Path $_.PSPath -Name "ImagePath" -ErrorAction SilentlyContinue).ImagePath

            if ($imagePath -is [string] -and ($imagePath -match '\\.*\.(exe|bat|cmd|com)')) {
                $originalPath = $imagePath
                $fixedPath = Quote-ExecutablePath -Path $originalPath

                if ($originalPath -ne $fixedPath) {
                    # Log and display the change
                    $logEntry = "$(Get-Date) - Service: $serviceName`nPath Fixed: $($_.PSPath)\ImagePath`nOld Value: $originalPath`nNew Value: $fixedPath`n"
                    Write-Output $logEntry | Tee-Object -FilePath $logFile -Append

                    # Update the registry value
                    try {
                        Set-ItemProperty -Path $_.PSPath -Name "ImagePath" -Value $fixedPath
                        Write-Host "Updated: $serviceName" -ForegroundColor Green
                    } catch {
                        $errorEntry = "$(Get-Date) - Failed to update: $serviceName`nError: $_`n"
                        Write-Output $errorEntry | Tee-Object -FilePath $logFile -Append
                        Write-Host "Failed to update: $serviceName" -ForegroundColor Red
                    }
                }
            }
        }
    } catch {
        $errorEntry = "$(Get-Date) - Error accessing registry key: $serviceKeyPath`nError: $_`n"
        Write-Output $errorEntry | Tee-Object -FilePath $logFile -Append
        Write-Host "Error accessing registry key: $serviceKeyPath" -ForegroundColor Red
    }
}

# Ensure the log directory exists
if (-not (Test-Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
}

# Run the fix
Write-Host "Scanning HKLM:\SYSTEM\CurrentControlSet\Services ..." -ForegroundColor Cyan
Fix-ServiceImagePaths

Write-Host "Registry scan and fix completed." -ForegroundColor Green
Write-Output "`nScan Completed Successfully" >> $logFile
Write-Output "Log file saved at: $logFile"
