# Run as Administrator
$NewMTU = 1260
Write-Host "Setting MTU to $NewMTU on active physical Ethernet and Wi-Fi adapters..."

# Broadened filter to catch Ethernet and Wi-Fi adapters
$adapters = Get-NetAdapter | Where-Object {
    $_.Status -eq 'Up' -and
    $_.HardwareInterface -eq $true -and
    ($_.InterfaceDescription -match 'Wireless|Wi-Fi|WiFi|Ethernet|LAN|Intel|Realtek')
}

if (-not $adapters) {
    Write-Warning "No matching active physical Ethernet or Wi-Fi adapters found."
    exit
}

foreach ($adapter in $adapters) {
    $alias = $adapter.Name
    $ipv4Ifaces = Get-NetIPInterface -InterfaceAlias $alias -AddressFamily IPv4

    foreach ($iface in $ipv4Ifaces) {
        Write-Host "`nInterface: $alias"
        Write-Host "Current MTU: $($iface.NlMtu)"

        if ($iface.NlMtu -ne $NewMTU) {
            try {
                netsh interface ipv4 set subinterface "$alias" mtu=$NewMTU store=persistent | Out-Null
                Write-Host "MTU set to $NewMTU for interface: $alias"
            } catch {
                Write-Warning ("Failed to set MTU for " + $alias + ": " + $_.Exception.Message)
            }
        } else {
            Write-Host "MTU already set to $NewMTU for interface: $alias"
        }
    }
}

# Final MTU status
Write-Host "`n--- Final MTU Settings (IPv4 Only) ---"
Get-NetIPInterface -AddressFamily IPv4 | Where-Object {
    $adapters.Name -contains $_.InterfaceAlias
} | Select-Object InterfaceAlias, NlMtu | Format-Table -AutoSize
