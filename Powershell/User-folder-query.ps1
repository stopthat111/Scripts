# Get all directories in C:\Users with verbose output
$folders = Get-ChildItem -Path 'C:\Users' -Directory | ForEach-Object {
    [PSCustomObject]@{
        Name           = $_.Name
        FullPath       = $_.FullName
        Created        = $_.CreationTime
        LastModified   = $_.LastWriteTime
    }
}

# Output results as formatted table
$folders | Format-Table -AutoSize | Out-String
