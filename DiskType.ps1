# Get the physical disks
$disks = Get-PhysicalDisk

# Loop through each disk and output the media type (HDD or SSD)
foreach ($disk in $disks) {
    $mediaType = $disk.MediaType

    # Determine if it's HDD or SSD
    if ($mediaType -eq 'HDD') {
        $diskType = "HDD"
    } elseif ($mediaType -eq 'SSD') {
        $diskType = "SSD"
    } else {
        $diskType = "Unknown"
    }
    
    if ($diskType -eq 'HDD') { Ninja-Property-Set -Name hddsdd -Value "HDD" }
      elseif ($diskType -eq 'SSD') { Ninja-Property-Set -Name hddsdd -Value "SSD" }

    # Output the result
    Write-Host "$diskType"
}
