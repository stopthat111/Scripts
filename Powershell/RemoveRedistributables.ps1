# List of Redistributables to be uninstalled
$redistributables = @(
    "Microsoft Visual C++ 2003 Redistributable",
    "Microsoft Visual C++ 2005 ATL Update kb973923 - x64 8.0.50727.4053",
    "Microsoft Visual C++ 2005 ATL Update kb973923 - x86 8.0.50727.4053",
    "Microsoft Visual C++ 2005 Redistributable 8.0.50727.42",
    "Microsoft Visual C++ 2005 Redistributable SP1 8.0.56336",
    "Microsoft Visual C++ 2005 Redistributable 8.0.59193",
    "Microsoft Visual C++ 2005 Redistributable (8.0.61001)",
    "Microsoft Visual C++ 2005 Redistributable (x64) 8.0.50727.42",
    "Microsoft Visual C++ 2005 Redistributable (x64) SP1 8.0.56336",
    "Microsoft Visual C++ 2005 Redistributable (x64) 8.0.59192",
    "Microsoft Visual C++ 2005 Redistributable (x64) 8.0.61000",
    "Microsoft Visual C++ 2008 ATL Update kb973924 - x64 9.0.30729.4148",
    "Microsoft Visual C++ 2008 ATL Update kb973924 - x86 9.0.30729.4148",
    "Microsoft Visual C++ 2008 Redistributable - x64 9.0.30411",
    "Microsoft Visual C++ 2008 Redistributable - x64 9.0.30729.17",
    "Microsoft Visual C++ 2008 Redistributable SP1 - x64 9.0.30729.17",
    "Microsoft Visual C++ 2008 Redistributable - x64 9.0.30729.4048",
    "Microsoft Visual C++ 2008 Redistributable - x64 9.0.30729.4148",
    "Microsoft Visual C++ 2008 Redistributable - x64 9.0.30729.6161",
    "Microsoft Visual C++ 2008 Redistributable - x86 9.0.21022.218",
    "Microsoft Visual C++ 2008 Redistributable - x86 9.0.21022",
    "Microsoft Visual C++ 2008 Redistributable - x86 9.0.30411",
    "Microsoft Visual C++ 2008 Redistributable - x86 9.0.30729.17",
    "Microsoft Visual C++ 2008 Redistributable SP1 - x86 9.0.30729.17",
    "Microsoft Visual C++ 2008 Redistributable - x86 9.0.30729.4148",
    "Microsoft Visual C++ 2008 Redistributable - x86 9.0.30729.4974",
    "Microsoft Visual C++ 2010 x64 Redistributable - 10.0.30319",
    "Microsoft Visual C++ 2010 x64 Redistributable SP1 - 10.0.40219",
    "Microsoft Visual C++ 2010 x86 Redistributable - 10.0.30319",
    "Microsoft Visual C++ 2010 x86 Redistributable SP1 - 10.0.40219",
    "Microsoft Visual C++ 2012 Redistributable (x64) - 11.0.50727",
    "Microsoft Visual C++ 2012 Redistributable (x64) - 11.0.61030",
    "Microsoft Visual C++ 2012 Redistributable (x86) - 11.0.50727",
    "Microsoft Visual C++ 2012 Redistributable (x86) - 11.0.61030",
    "Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.21005",
    "Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.40660",
    "Microsoft Visual C++ 2013 Redistributable (x86) - 12.0.21005",
    "Microsoft Visual C++ 2013 Redistributable (x86) - 12.0.40649"
)

# Function to uninstall a program
function Uninstall-Program {
    param (
        [string]$programName
    )
    $program = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE '%$programName%'"
    
    if ($program) {
        $program | ForEach-Object {
            Write-Host "Uninstalling $($_.Name)..."
            $_.Uninstall() | Out-Null
            Write-Host "$($_.Name) has been uninstalled."
        }
    } else {
        Write-Host "$programName not found."
    }
}

# Iterate through the list and uninstall each Redistributable
foreach ($redistributable in $redistributables) {
    Uninstall-Program $redistributable
}
