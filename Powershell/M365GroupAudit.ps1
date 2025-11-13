<#
=============================================================================================
Name:           Microsoft 365 Group Report (Pivot-Friendly)
Description:    Exports Microsoft 365 groups, owners, and members in a clean format for pivot tables
Version:        3.0
=============================================================================================
#>

Param 
( 
    [Parameter(Mandatory = $false)] 
    [string]$GroupIDsFile,
    [switch]$DistributionList, 
    [switch]$Security, 
    [switch]$MailEnabledSecurity, 
    [Switch]$IsEmpty, 
    [Int]$MinGroupMembersCount
) 

# Output file paths
$ExportCSV = ".\M365Group-PivotReport_$((Get-Date -format yyyy-MM-dd_hh-mm-tt)).csv"
$ExportSummaryCSV = ".\M365Group-SummaryReport_$((Get-Date -format yyyy-MM-dd_hh-mm-tt)).csv"

Function Get-Members {
    param($Group)

    $DisplayName = $Group.DisplayName
    $EmailAddress = $Group.Mail
    $GroupType = if ($Group.GroupTypes) { $Group.GroupTypes -join "," } else { "Security" }
    $ObjectId = $Group.Id

    Write-Progress -Activity "Processing Group: $DisplayName"

    # Get members
    $Members = Get-MgGroupMember -GroupId $ObjectId -All
    $MembersCount = $Members.Count

    # Get owners
    $Owners = Get-MgGroupOwner -GroupId $ObjectId -All
    $OwnerNames = ($Owners | ForEach-Object { $_.AdditionalProperties.displayName }) -join "; "
    $OwnerEmails = ($Owners | ForEach-Object { $_.AdditionalProperties.mail }) -join "; "

    # Apply filters
    if ($Security.IsPresent -and ($Group.SecurityEnabled -ne $true)) { return }
    if ($DistributionList.IsPresent -and ($Group.MailEnabled -ne $true)) { return }
    if ($MailEnabledSecurity.IsPresent -and ($Group.MailEnabled -ne $true -or $Group.SecurityEnabled -ne $true)) { return }
    if ($MinGroupMembersCount -and ($MembersCount -lt $MinGroupMembersCount)) { return }

    # Add owners to pivot-friendly report
    foreach ($Owner in $Owners) {
        $OwnerName = $Owner.AdditionalProperties.displayName
        $OwnerEmail = $Owner.AdditionalProperties.mail
        if ([string]::IsNullOrEmpty($OwnerEmail)) { $OwnerEmail = "-" }

        $OwnerResult = [PSCustomObject]@{
            GroupName = $DisplayName
            Role      = "Owner"
            Name      = $OwnerName
            Email     = $OwnerEmail
        }
        $OwnerResult | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
    }

    # Add members to pivot-friendly report
    if ($MembersCount -eq 0) {
        $Result = [PSCustomObject]@{
            GroupName = $DisplayName
            Role      = "Member"
            Name      = "No Members"
            Email     = "-"
        }
        $Result | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
    } else {
        foreach ($Member in $Members) {
            $MemberName = $Member.AdditionalProperties.displayName
            $MemberEmail = $Member.AdditionalProperties.mail
            if ([string]::IsNullOrEmpty($MemberEmail)) { $MemberEmail = "-" }

            $Result = [PSCustomObject]@{
                GroupName = $DisplayName
                Role      = "Member"
                Name      = $MemberName
                Email     = $MemberEmail
            }
            $Result | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
        }
    }

    # Summary report
    $Summary = [PSCustomObject]@{
        DisplayName        = $DisplayName
        EmailAddress       = $EmailAddress
        GroupType          = $GroupType
        GroupMembersCount  = $MembersCount
        Owners             = $OwnerNames
        OwnerEmails        = $OwnerEmails
    }
    $Summary | Export-Csv -Path $ExportSummaryCSV -NoTypeInformation -Append
}

Function Main {
    # Connect to Microsoft Graph
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "Group.Read.All","Directory.Read.All"

    # Get groups
    if ($GroupIDsFile) {
        $GroupIDs = Import-Csv -Path $GroupIDsFile
        foreach ($item in $GroupIDs) {
            $Group = Get-MgGroup -GroupId $item.DisplayName
            Get-Members -Group $Group
        }
    } else {
        $Groups = Get-MgGroup -All
        foreach ($Group in $Groups) {
            Get-Members -Group $Group
        }
    }

    Write-Host "`nScript executed successfully."
    Write-Host "Pivot-friendly detailed report: $ExportCSV"
    Write-Host "Summary report: $ExportSummaryCSV"
}

Main
