# --- Blumira install runner ---

# Define paths
$configPath = "$env:ProgramData\Blumira\poshim_config.json"
$poshimPath = "$env:ProgramData\Blumira\poshim.ps1"

# --- REPLACE THIS with your full poshim_config.json content ---
# Embedded poshim_config.json content (JSON string)
$configJson = @'
{
  "version": "0.2",
  "poshim_version": "1.4.3.1",
  "nxlog": {
    "conf_template_url": "https://dl.blumira.com/agent/nxlog.conf.tpl",
    "download_url": "https://dl.blumira.com/agent/files/nxlog-ce-3.2.2329.msi",
    "active_version": "3.2.2329",
    "versions": [
      {
        "version": "3.2.2329.msi",
        "installer_sha256": "015d546d0b1a31cf10a6dd00d36f5e17503eaf45c164f73b6e578970c08da082"
      },
      {
        "version": "3.0.2284.msi",
        "installer_sha256": "e986d0af6c252e1516b37057fb3ff4e0caecc706b371c9637c562d9eddfc400f"
      },
      {
        "version": "2.11.2190",
        "installer_sha256": "413972D1769D406FB6A8D67EF951F3353F7392543EA537BD93EBE41B990C7A98",
        "program_sha256": "9C3D58B87AB25975AFCBD1F3194A25A496898F3E637CFF1A1345190F11BE380F"
      }
    ],
    "queries": [
      "<Select Path=\"Application\">*</Select>",
      "<Select Path=\"System\">*</Select>",
      "<Select Path=\"Security\">*</Select>",
      "<Select Path=\"Setup\">*</Select>",
      "<Select Path=\"Windows PowerShell\">*</Select>",
      "<Select Path=\"Microsoft-Windows-AppLocker/EXE and DLL\">*</Select>",
      "<Select Path=\"Microsoft-Windows-AppLocker/MSI and Script\">*</Select>",
      "<Select Path=\"Microsoft-Windows-AppLocker/Packaged app-Deployment\">*</Select>",
      "<Select Path=\"Microsoft-Windows-AppLocker/Packaged app-Execution\">*</Select>",
      "<Select Path=\"Microsoft-Windows-LSA/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-NTLM/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-PowerShell/Admin\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Powershell/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-PrintService/Admin\">*</Select>",
      "<Select Path=\"Microsoft-Windows-PrintService/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-TaskScheduler/Operational\">*</Select>",
      "<Select Path=\"Directory Service\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Application-Experience/Program-Compatibility-Assistant\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Application-Experience/Program-Compatibility-Troubleshooter\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Application-Experience/Program-Inventory\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Application-Experience/Program-Telemetry\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Application-Experience/Steps-Recorder\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Bits-Client/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-CertificateServicesClient-Lifecycle-System/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-CodeIntegrity/Operational\">*[System[Provider[@Name='Microsoft-Windows-CodeIntegrity']]]</Select>",
      "<Select Path=\"Microsoft-Windows-GroupPolicy/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Kernel-PnP/Configuration\">*</Select>",
      "<Select Path=\"Microsoft-Windows-NetworkProfile/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-TerminalServices-RDPClient/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-User Profile Service/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-WindowsUpdateClient/Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-WinRM/Operational\">*</Select>",
      "<Select Path=\"Network Isolation Operational\">*</Select>",
      "<Select Path=\"Microsoft-Windows-Sysmon/Operational\">*</Select>",
      "<Select Path=\"Microsoft-IIS-Configuration/Administrative\">*</Select>",
      "<Select Path=\"Microsoft-IIS-Configuration/Operational\">*</Select>",
      "<Select Path=\"Microsoft-IIS-Logging/Logs\">*</Select>",
      "<Select Path=\"Microsoft-AzureADPasswordProtection-DCAgent/Admin\">*</Select>",
      "<Select Path=\"Microsoft-AzureADPasswordProtection-DCAgent/Operational\">*</Select>",
      "<Select Path=\"Microsoft-AzureADPasswordProtection-DCAgent/Trace\">*</Select>",
      "<Select Path=\"Microsoft-AzureADPasswordProtection-ProxyService/Admin\">*</Select>",
      "<Select Path=\"Microsoft-AzureADPasswordProtection-ProxyService/Operational\">*</Select>",
      "<Select Path=\"Microsoft-AzureADPasswordProtection-ProxyService/Trace\">*</Select>"
    ],
    "global_suppress": [
      "<Suppress Path=\"Security\">*[System[(EventID=4689 or EventID=5158 or EventID=5440 or EventID=5444)]]</Suppress>",
      "<Suppress Path=\"Windows PowerShell\">*[System[(EventID=501 or EventID=400 or EventID=600)]]</Suppress>"
    ],
    "drops": [
      "Exec if ($Application =~ /nxlog\\\\nxlog.exe/) drop();",
      "Exec if ($SourceAddress =~ /224.0.0.252/) drop();",
      "Exec if ($SourceAddress =~ /192.168.1.255/) drop();",
      "Exec if ($SourceAddress =~ /224.0.0.1/) drop();",
      "Exec if ($SourceAddress =~ /239.255.255.250/) drop();",
      "Exec if ($DestAddress =~ /224.0.0.22/) drop();",
      "Exec if ($CommandLine =~ /\"C:\\\\Program Files\\\\nxlog\\\\nxlog.exe\" -c \"C:\\\\Program Files\\\\nxlog\\\\conf\\\\nxlog.conf\"/) drop();",
      "Exec if ($EventID == 4202 or $EventID == 4208 or $EventID == 4302 or $EventID == 4304 or $EventID == 5004 or $EventID == 5156 or $EventID == 5157 or $EventID == 4703 or $EventID == 4658 or $EventID == 5152 or $EventID == 5449) drop();",
      "Exec if ($SourceName == 'Microsoft-Windows-Security-Auditing' and $EventID IN (5156, 5157) and $Application =~ /\\\\nxlog\\\\.exe$/i) drop();"
    ],
    "message_format": [
      "Exec $EventTime = integer($EventTime);",
      "Exec $Message = to_json();"
    ],
    "custom_nxlog": {
      "fw_514_syslog": "PEV4dGVuc2lvbiBjc3Zfd2luZG93c19mdz4KICAgIE1vZHVsZSAgICAgICAgICB4bV9jc3YKICAgIEZpZWxkcyAgICAgICAgICBkYXRlLCB0aW1lLCBhY3Rpb24sIHByb3RvY29sLCBzcmMtaXAsIGRzdC1pcCwgc3JjLXBvcnQsIGRzdC1wb3J0LCBzaXplLCB0Y3BmbGFncywgdGNwc3luLCB0Y3BhY2ssIHRjcHdpbiwgaWNtcHR5cGUsIGljbXBjb2RlLCBpbmZvLCBwYXRoLCBwaWQKICAgIEZpZWxkVHlwZXMgICAgICBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcNCiAgICBERWxpbWl0ZXIgICAgICAgICcgJwo8L0V4dGVuc2lvbj4NCjxJbnB1dCBibHVfaWlzX2xvZ3M+DQogICAgTW9kdWxlICAgIGltX2ZpbGUNCiAgICBGaWxlICAgICJDOlxcaW5ldHB1YlxcbG9nc1xcbG9nRmlsZXNcXFczU1ZDMVxcaV9leCoiDQogICAgU2F2ZVBvcyAgIFRSVQ0KICAgIA0KICAgIEV4ZWMgJEhvc3RuYW1lID0gaG9zdG5hbWVfZnFkbigpOw0KICAgIEV4ZWMgaWYgJHJhd19ldmVudCA9fiAvXi8gZHJvcCgpOyAgICAgICAgICAgICBcDQogICAgICB7ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgXA0KICAgICAgICAgICAgIHdzYy0+cGFyc2VfY3N2KCk7ICAgICAgICAgICAgICBcDQogICAgICAgICAgICAgJEV2ZW50VGltZSA9IHBhcnNlZGF0ZSgkZGF0ZSArICIgIiAgKyAkdGltZSk7ICBcDQogICAgICAgICAgICAgJHJhd19ldmVudCA9IHRvX2pzb24oKTsgICAgICAgICAgICAgIFwNCiAgICAgICAgICB9DQo8L0lucHV0Pg0KPE91dHB1dCBibHVfb3V0X2lpcz4NCiAgICBNb2R1bGUgICAgICBvbV91ZGANCiAgICBIb3N0ICAgICAgICAlU0lFTSUNCiAgICBQb3J0ICAgICAgICA1MTQNCiAgICBFeGVjICAgICAgICAkcmF3X2V2ZW50ID0gJ0JMVV9JSVM6ICcgKyAkcmF3X2V2ZW50Ow0KICAgIA0KICAgIEV4ZWMgdG9fc3lzbG9nX2JzZCgpOw0KPC9PdXRwdXQ+DQo8Um91dGUgcm91dGVfaWlzPg0KICAgIFBhdGggYmx1X2lpc19sb2dzID0+IGJsdV9vdXRfaXMNCjw vUm91dGU+"
      ,"iis_514_im_file": "PEV4dGVuc2lvbiB3M2M+DQogICAgTW9kdWxlIHhtX2Nzdg0KDQogICAgRmllbGRzICRkYXRlLCAkdGltZSwgJHMtaXAsICRjcy1tZXRob2QsICRjcy11cmktc3RlbSwgJGNzLXVyaS1xdWVyeSwgJHMtcG9ydCwgJGNzLXVzZXJuYW1lLCAkYy1pcCwgJGNzVXNlci1BZ2VudCwgJGNzUmVmZXJlciAkc2Mtc3RhdHVzLCAkc2Mtc3Vic3RhdHVzLCAkc2Mtd2luMzItc3RhdHVzLCAkdGltZS10YWtlbg0KICAgIEZpZWxkVHlwZXMgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3JpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcsIHN0cmluZywgc3RyaW5nLCBzdHJpbmcNCiAgICBERWxpbWl0ZXIgICAgICAgICcgJwo8L0V4dGVuc2lvbj4NCjxJbnB1dCBibHVfaWlzX2xvZ3M+DQogICAgTW9kdWxlICAgIGltX2ZpbGUNCiAgICBGaWxlICAgICJDOlxcaW5ldHB1YlxcbG9nc1xcbG9nRmlsZXNcXFczU1ZDMVxcaV9leCoiDQogICAgU2F2ZVBvcyAgIFRSVQ0KICAgIA0KICAgIEV4ZWMgJEhvc3RuYW1lID0gaG9zdG5hbWVfZnFkbigpOw0KICAgIEV4ZWMgaWYgJHJhd19ldmVudCA9fiAvXi8gZHJvcCgpOyAgICAgICAgICAgICBcDQogICAgICB7ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgXA0KICAgICAgICAgICAgIHdzYy0+cGFyc2VfY3N2KCk7ICAgICAgICAgICAgICBcDQogICAgICAgICAgICAgJEV2ZW50VGltZSA9IHBhcnNlZGF0ZSgkZGF0ZSArICIgIiAgKyAkdGltZSk7ICBcDQogICAgICAgICAgICAgJHJhd19ldmVudCA9IHRvX2pzb24oKTsgICAgICAgICAgICAgIFwNCiAgICAgICAgICB9DQo8L0lucHV0Pg0KPE91dHB1dCBibHVfb3V0X2lpcz4NCiAgICBNb2R1bGUgICAgICBvbV91ZGANCiAgICBIb3N0ICAgICAgICAlU0lFTSUNCiAgICBQb3J0ICAgICAgICA1MTQNCiAgICBFeGVjICAgICAgICAkcmF3X2V2ZW50ID0gJ0JMVV9JSVM6ICcgKyAkcmF3X2V2ZW50Ow0KICAgIA0KICAgIEV4ZWMgdG9fc3lzbG9nX2JzZCgpOw0KPC9PdXRwdXQ+DQo8Um91dGUgcm91dGVfaWlzPg0KICAgIFBhdGggYmx1X2lpc19sb2dzID0+IGJsdV9vdXRfaXMNCjw vUm91dGU+"
    }
  },
  "sysmon": {
    "conf_url": "https://dl.blumira.com/agent/configurations/15.14_sysmonconfig.xml",
    "download_url": "https://dl.blumira.com/agent/files/Sysmon_15.14.zip",
    "active_version": "15.14",
    "versions": [
      {
        "version": "15.14",
        "installer_sha256": "900a7bbf67b3c0e0c2109e3fb14a534a90f55f326d625a332bdd3c7d95d44c04",
        "program_sha256": "39b094613132377bc236f4ad940a3e02c544f86347c0179a9425edc1bd3b85cd"
      },
      {
        "version": "14.16",
        "installer_sha256": "49aa66974dbd685412d66f4b30f98d008570807e868a005c93919abbb31435a2",
        "program_sha256": "8d4fc2c9352dad893d63ca30829b35c935e304c2fd0be83e7daebbe59a558694"
      },
      {
        "version": "14.13",
        "installer_sha256": "23b123ce3400b938e6a7d29dd5ba6f54772c4cde6796ef760b6572df7f7a34f6",
        "program_sha256": "3267279461be7397ef6e2afe61f9396e42475577f8c76648dbcae1b831b6fd3e"
      },
      {
        "version": "13.34",
        "installer_sha256": "8dae201834b2a49a307e661eef005cb8aa732615e2527aa858e28760fbf55737",
        "program_sha256": "373061d73b6743651050749dba958090a954939109fc51dd27e548b0d71cd75c"
      },
      {
        "version": "13.23",
        "installer_sha256": "85BD77B8F0133B6BC164A1C1E9D8BE676D57E4E469EE17F87EBD91735FE6C1BC",
        "program_sha256": "82B16D5247BE31D9BDDEB07DC716DD5D7A50F233807519037E88D8279CE85033"
      },
      {
        "version": "13.30",
        "installer_sha256": "884D9C3FF18E93CED87459545A67335859E59763DB52972A07300CE0FF5A83BB",
        "program_sha256": "1BD1B9C63016955CA65E022427097EC16B0FEFB65F10BF51D25F0455BBBB5FB6"
      },
      {
        "version": "13.33",
        "installer_sha256": "04D17192E881DC18DA55031E2C65E70D0CD8623D5B92B317BD6A7D5F9D716FF1",
        "program_sha256": "41898226E9B974148C174DE56F6312E0C3609FF9A1D3B88F15653BA7CA00AB9B"
      },
      {
        "version": "12.01",
        "installer_sha256": "2A26852770327F8A6E7A66D9EB204588D92B677495CEB9533288B374E8C00E16",
        "program_sha256": "E78DD880C0E397CD99121FBB23B9BEE0F60F5B0E4A58F59E3C1A184C1E7F3EBE"
      }
    ]
  },
  "default_tags": [
    "poshim",
    "blumira"
  ]
}
'@
# --- END REPLACE ---

# --- REPLACE THIS ENTIRE BLOCK with your full poshim.ps1 script contents ---
<#  
.SYNOPSIS  
    Blumira PoSHim Endpoint Visibility Shim - Agent Installer

.DESCRIPTION
    Blumira PoSHim automatically generates configurations for NXLog based on the Windows
    host plus a configuration files. Optionally PoSHim can be used for installing Sysmon
    and selecting additional Event Viewer logs on the fly. By default if the Firewall is
    enabled on the host PoSHim will automatically drop the log file collector.

.EXAMPLE
    Refer to docs at https://www.blumira.com/integration/poshim-automated-windows-log-collection-agent/

.NOTES  
    Author     : Matt Warner
    Version    : 1.4.3.1 Exclude WEL Security channel EID 5449
                 1.4.3.0 Adding in nxlog update functionality needs further refinement, updating Sysmon to 15.14
                 1.4.2.0 Reverting to Sysmon 14.13 after 15-20% failure rate due to bug in 14.16, 14.15 and 14.14 skipped due to priv esc vuln
                 1.4.1.0 Updating Sysmon (14.16) and NXlog (3.2.2329)
                 1.2.0.0 Moving to nxlog 3 with new pathing, changing how defender is handled due to how it modifies event log on the fly
                 1.1.1.1 Updating firewall determination logic due to missed logging state. Added 5156 to poshim_config.json for drop.
                 1.1.1.0 Fixing bug where disabled log sources would taint nxlog - enabling disabled
                 1.1.0.0 Updated method for firewall identification and logging
#> 

Set-Alias -Name Blumira-Installer Blumira-Agent
new-module -name BlumiraSensor -scriptblock {
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12"
$ErrorActionPreference= 'silentlycontinue'
$global:silent = $false;
$global:report = $false;
$global:NewInstall = $false;
$global:welcome = @"
______ _     _   ____  ______________  ___  
| ___ \ |   | | | |  \/  |_   _| ___ \/ _ \ 
| |_/ / |   | | | | .  . | | | | |_/ / /_\ \
| ___ \ |   | | | | |\/| | | | |    /|  _  |
| |_/ / |___| |_| | |  | |_| |_| |\ \| | | |
\____/\_____/\___/\_|  |_/\___/\_| \_\_| |_/ 
"@
    Function Log-Message
    {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$LogMessage
    )
    if ( $global:silent -eq $false ) {
        Write-Output ("{0} - {1}" -f (Get-Date -format "o"), $LogMessage)
    }
	}
    Function Log-Error
    {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$LogError
    )
    if ( $global:silent -eq $false ) {
        Write-Host -ForegroundColor Yellow (Get-Date -format "o"), - $LogError
    }
    }
    #Make Sure installer is running in elevated session
    Function Check-Admin(){
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ( $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $false ) {
       Log-Error "You are not running in an elevated session, please run this installer in an elevated or Administrator session."
       Break
       }
    }
    #Used to download required files based on data in the configuration json provided
    Function Download-Or-Copy-File() {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$true,Position=0)]
        [string]$Fileloc
    )
    if ($Fileloc.StartsWith("http")) {
        # Split using backslash (URI)
        $TempFilename = $Fileloc.split('/')[-1]
        $TempFilepath = "$($env:temp)\$($TempFilename)"
        # If a remote file, download to temp
        (new-object System.Net.WebClient).DownloadFile($Fileloc, $TempFilepath)
    } else {
        # Split using forward slash (NTFS)
        $TempFilename = $Fileloc.split('\')[-1]
        $TempFilepath = "$($env:temp)\$($TempFilename)"
        # If a local file (not http/s) copy to local temp
        Copy-Item -Path $Fileloc -Destination $TempFilepath -Force 
    }
    # Return the temp filepath location
    return $TempFilepath
    }
    Function Obtain-File-Contents() {
    Param(
        [parameter(Mandatory=$true,Position=1)]$Filepath
    )
    # Download or Get-Content based on the filepath
    # Used for local storage and/or remote storage of files
    if ( $Filepath.StartsWith("http") ) {
        return (new-object Net.WebClient).DownloadString($Filepath)
    } else {
        return Get-Content -Path $Filepath
    }
}
    Function Install-Configure-Sysmon() {
    # Pull in $Config
    Log-Message "Gathering Sysmon from Config: $($Config.sysmon)"
    # Get the filenames for files to be downloaded
    $Sysmon_Filename = $Config.sysmon.download_url.split('/')[-1]
    $SysmonConf_Filename = $Config.sysmon.conf_url.split('/')[-1]
    # WorkingDirectory override due to Set-Location usage
    if ( $WorkingDirectory ) {
        $Config.sysmon.download_url = $Sysmon_Filename
        $Config.sysmon.conf_url = $SysmonConf_Filename
    }
    # Determine if config is internet or local file path
    # If internet, downloadfile to temp
    # If local, copy to temp from source
    $Sysmon_Installer = Download-Or-Copy-File -Fileloc $Config.sysmon.download_url
    $Sysmon_Configuration = Download-Or-Copy-File -Fileloc $Config.sysmon.conf_url
    # Modify Sysmon config to exclude EID 23
    [xml]$xml = Get-Content $Sysmon_Configuration
        $node = $xml.SelectSingleNode("//FileDelete[@onmatch='include']")
        $newNode = $xml.CreateElement("FileDelete")
        $newNode.SetAttribute("onmatch", "include")
        $node.ParentNode.ReplaceChild($newNode, $node) | Out-Null
        $xml.Save($Sysmon_Configuration)
    # Expand the downloaded zip for install/configure
    # If Win2012 must handle expansion differently
    if ((Get-Host).Version.Major -eq 4) {
        Log-Message "Identified Win2012 R2, loading .NET Zip Assembly."
        [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Sysmon_Installer, "$env:temp\Sysmon")
    } else {
        try {
            Expand-Archive -Force -LiteralPath $Sysmon_Installer -DestinationPath "$env:temp\Sysmon"
        } catch {
            Log-Error "Failed to expand archive for $($Sysmon_Installer)"
            Log-Message "Please send support@blumira.com the details of this OS"
        }
    }
    # TODO: Here is where we call the args definition,
    #       we need to compare the $env:temp\Sysmon\Sysmon64.exe
    #       version and C:\Windows\Sysmon64.exe.
    # Set-Location "$env:temp\$sysmon_fn\Sysmon"
    if (Test-Path "C:\Windows\Sysmon64.exe") {
        # Check for version difference between temp and windows
        $sysmon_temp_version = (Get-Item $env:temp\Sysmon\Sysmon64.exe).VersionInfo.FileVersionRaw
        $sysmon_windows_version = (Get-Item C:\Windows\Sysmon64.exe).VersionInfo.FileVersionRaw
        if ($sysmon_temp_version -eq $sysmon_windows_version) { 
            # Versions match, no need to make any changes to the installed version
            # Reconfigure running sysmon service with latest configuration
            Log-Message "Sysmon on host with matching version, updating to latest configuration."
            $Arguments = "-accepteula -c $Sysmon_Configuration" 
        } else { 
            # Versions do not match, uninstall using C:\Windows\Sysmon64.exe 
            # and then proceed to install fresh from temp.
            Log-Message "Sysmon versions do not match, uninstalling existing Sysmon before reinstall"
            Uninstall-Sysmon
            # Pause before proceeding otherwise it gets really messy
            Start-Sleep -Seconds 5
            $Arguments = "-accepteula -i $Sysmon_Configuration"
        }
    } else {
        # Execute sysmon and install with configuration
        Log-Message "Sysmon not found, installing service with latest configuration"
        $Arguments = "-accepteula -i $Sysmon_Configuration"
    }
    # Execute with prepped argument list
    $sysmon = Start-Process -WorkingDirectory "$env:temp\Sysmon" -FilePath "Sysmon64.exe" -ArgumentList $Arguments -Wait
    if (Test-Path "C:\Windows\Sysmon64.exe") {
        Log-Message "Found Sysmon64.exe in C:\Windows, install successful"
    } else {
        Log-Error "Did not find Sysmon64.exe in C:\Windows, Sysmon failed to install!"
    }
    }
    Function Configure-NXLog() {
    Param(
        [parameter(Mandatory=$true,Position=1)]$Config,
        [parameter(Mandatory=$true,Position=2)]$IP,
        [parameter(Mandatory=$false,Position=3)]$AdditionalLogs,
        [parameter(Mandatory=$false,Position=4)]$NXLogExtras
    )
    Log-Message "NXLog Config: $($Config) | IP: $($IP) | Additional Logs: $($AdditionalLogs) | NXLog Custom Blocks: $($NXLogExtras)"
    if ( $WorkingDirectory ) {
        Log-Message "Trying to find $($Config.nxlog.conf_template_url.split('/')[-1]) in $($WorkingDirectory)"
        $nxlogTpl = Obtain-File-Contents -Filepath $Config.nxlog.conf_template_url.split('/')[-1]
        # Required override for strange posh states - must cast to string
        # Our thanks to the reporter and fix for this!
        Log-Message $($nxlogTpl | out-string)

    } else {
        Log-Message "Gathering nxlog configuration template - $($Config.nxlog.conf_template_url)"
        $nxlogTpl = Obtain-File-Contents -Filepath $Config.nxlog.conf_template_url
    }
    $nxlogCheckConfig = "C:\Program Files\nxlog\conf\nxlog.validate.conf"
    $nxlogConfig = "C:\Program Files\nxlog\conf\nxlog.conf"
    $nxlogQueryTpl = '<Select Path="{PATH}">*</Select>'
    # Format input, strip empty from arrays
    $AdditionalLogs = $AdditionalLogs -split "," | Where-Object {$_}
    $CustomNXLog = $NXLogExtras -split "," | Where-Object {$_}
    # Get event logs
    $eventLogs = Get-WinEvent -ListLog * -EA silentlycontinue
    # Get array of event log names, compare against known-good queries
    $DefaultLogs = $eventLogs.logName| Where {$Config.nxlog.queries -match $_}
    Log-Message "$($DefaultLogs.Length) Default Logs Identified on Host matching PoSHim Configuration"
    # Build out CustomLogs blob from the AdditionalLogs param to combine with Default
    $CustomLogs = @()
    if ( $AdditionalLogs.Length -gt 0 ) {
        foreach ($al in $AdditionalLogs) {
            # Default posh can get weird with empty objects in arrays
            $CustomLogs += $eventLogs.logName | Select-String $al
        }
    }
    Log-Message "$($CustomLogs.Length) Custom Logs Identified from Additional Logs - $($AdditionalLogs)"
    # Combine both the default and custom logs
    # - Also validate that we are not close to 256 log sources
    $ComboLogs = $DefaultLogs + $CustomLogs
    # Check if disabled and and enable if selecting a disabled
    foreach ($log in $ComboLogs) {
        $logSource = Get-WinEvent -ListLog $log
        if ($logSource.isEnabled -eq $true) {
            continue
        } else {
            Log-Message "$($log) is disabled - attempting to enable log source."
            $logSource.isEnabled = $true
            $logSource.MaximumSizeInBytes = 128MB
            $logSource.LogMode = "Circular"
            try{
                $logSource.SaveChanges()
                Log-Message "Saved changed to $($log) - enabled and set to 128MB Circular"
                # Get-WinEvent -ListLog $log | Format-List -Property *
            }catch [System.UnauthorizedAccessException]{
                Log-Error "User does not have permission to enable event log $($log)" 
                Log-Message "Error $($_.Exception.Message)"
            }
        }
    }
    if ( $ComboLogs.Length -gt 200 ) {
        Log-Error "WARNING: You have over 200 log sources selected, wildcard queries may push this to the 256 maximum."
        Log-Message "Currently there are $($ComboLogs.Length) selected."
    } 
    Log-Message "Proceeding with $($ComboLogs.Length) Event Viewer sources being queried by NXLog."
    # Build the actual query structure with the identified logs default only
    $LogQueries = @()
    foreach ($dl in $DefaultLogs) {
        $LogQueries += $nxlogQueryTpl.replace("{PATH}", $dl)
    }
    # Build the actual query structure with the identified logs custom only
    $LogQueriesAL = @()
    foreach ($al in $CustomLogs) {
        $LogQueriesAL += $nxlogQueryTpl.replace("{PATH}", $al)
    }
    # Log-Message $LogQueries
    # Replace the initial {QUERIES} with $LogQueries
    # Join with \ and linebreak + 29 spaces for formatting, add final '\' for suppressions
    $LogQueriesString = $LogQueries -join "\`r`n							"
    $NewNXlogConf = $nxlogTpl.replace("{QUERIES}", ($LogQueriesString + '\'))
    
    # Replace the initial {ALQUERIES} with $LogQueriesAL
    # Join with \ and linebreak + 29 spaces for formatting, add final '\' for suppressions
    $ALLogQueriesString = $LogQueriesAL -join "\`r`n							"
    $NewNXlogConf = $NewNXlogConf.replace("{ALQUERIES}", ($ALLogQueriesString + '\'))
    # Replace Suppressions from nxlog config
    # TODO: Add Custom suppressions
    $SuppressionsString = $Config.nxlog.global_suppress -join "\`r`n							"
    $NewNXlogConf = $NewNXlogConf.replace("{SUPPRESSIONS}", ($SuppressionsString + '\'))
    # Replace Drops from nxlog config, 4 spaces
    # TODO: Add custom drops 
    $DropsString = $Config.nxlog.drops -join "`r`n    "
    $NewNXlogConf = $NewNXlogConf.replace("{DROPS}", $DropsString)
    # Replace formatting from nxlog config
    $FormattingString = $Config.nxlog.message_format -join "`r`n    "
    $NewNXlogConf = $NewNXlogConf.replace("{FORMATTING}", $FormattingString)
    # Replace IP
    $NewNXlogConf = $NewNXlogConf.replace("A.B.C.D", $IP)
    # Update generated file version from PoSHim and when it was generated
    $NewNXlogConf = $NewNXlogConf.replace("{CREATED}", (Get-Date -Format "o"))
    $NewNXlogConf = $NewNXlogConf.replace("{POSHIM_VERSION}", $Config.version)
    # Determine if windows firewall is used, add by default
    if ( Get-NetFirewallProfile -Name Domain | Select "Enabled" | Select-String "True" ) {
        $CustomNXLog += "fw_514_syslog"
        if ( Get-NetFirewallProfile | Format-Table LogFileName ) {
            if ( Get-NetFirewallProfile -Name Domain | Select "LogAllowed" | Select-String "True" ) {
                if ( $FirewallAllow ) {
                    Log-Message "Firewall logging (Allow and Block) already enabled, skipping policy update."
                } else {
                    Log-Message "Determined that -FirewallAllow was NOT passed but allow logs are activated, leaving configuration in place for best-visibility."
                    # If you do not want allowed logging to be enabled run the following command:
                    # Set-NetFirewallProfile -LogFileName %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log -LogMaxSizeKilobytes 4096 -LogBlocked True -LogAllowed False -LogIgnored True
                }
            } else {
                if ( $FirewallAllow ) {
                    Log-Message "Determined that -FirewallAllow was passed but allow firewall logs are not activated yet, reconfiguring netsh profile for Allow and Block."
                    (Set-NetFirewallProfile -LogFileName %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log -LogMaxSizeKilobytes 4096 -LogBlocked True -LogAllowed True -LogIgnored True)
                } else {
                    Log-Message "Firewall logging (Block) already enabled, skipping policy update but enabling logging."
                    (Set-NetFirewallProfile -LogFileName %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log -LogMaxSizeKilobytes 4096 -LogBlocked True -LogAllowed False -LogIgnored False)
                }
            }
        } else {
            Log-Message "Identified active Windows Firewall, enabling logging on the Netsh profile."
            if ( $FirewallAllow ) {
                (Set-NetFirewallProfile -LogFileName %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log -LogMaxSizeKilobytes 4096 -LogBlocked True -LogAllowed True -LogIgnored True)
                LogMessage "Enabled Firewall logging (Allow and Block) for netsh profiles."
            } else {
                (Set-NetFirewallProfile -LogFileName %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log -LogMaxSizeKilobytes 4096 -LogBlocked True -LogAllowed False -LogIgnored False)
                LogMessage "Enabled Firewall logging (Block only) for netsh profiles."
            }
        }
    } else {
        Log-Message "Firewall not enabled on host, skipping Firewall log enable."
    }
    # Determine if any custom nxlog blocks are being used, if so, build payload and replace
    if ( $CustomNXLog -gt 0 ) {
        $CustomBlocks = @()
        $CustomNXLog = $CustomNXLog | select -Unique
        foreach ($cb in $CustomNXLog) {
            try {
                $CustomBlocks += [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($Config.nxlog.custom_nxlog.$cb))
            } catch {
                Log-Message "$($cb) is missing from the poshim.conf file"
            }
        }
        $CustomBlocksString = $CustomBlocks -join "`r`n"
    } else {
        $CustomBlocksString = ""
    }
    $NewNXlogConf = $NewNXlogConf.replace("{CUSTOM_NXLOG}", $CustomBlocksString)
    # Write to Check position for validation
    # TODO: Try to get temp working again with the processor
    $NewNXlogConf | Out-File $nxlogCheckConfig -Encoding ASCII
    $CheckArgs = @('-c', $nxlogCheckConfig, '-v')
    # TODO: Add Validation
    $ValidationResult = & "C:\Program Files\nxlog\nxlog-processor.exe" $CheckArgs
    if ( $validationResult -match "configuration OK" ) {
        # Move config to main position, restart service
        Log-Message "Configuration OK, restarting NXLog now"
        Move-Item -Path $nxlogCheckConfig -Destination $nxlogConfig -Force
        Restart-Service -Name "nxlog"
    } else {
        Log-Error "Failed Validation Result: $($ValidationResult)"
        Log-Message "Review configuration at $($nxlogCheckConfig) for errors."
        Log-Message "Send to support@blumira.com for additional help."
    }
    }
    Function Uninstall-Sysmon() {
        Log-Message "Starting Sysmon Uninstall process"
        # Determine architecture in use
        $x64Path = "C:\Windows\Sysmon64.exe"
        $x86Path = "C:\Windows\Sysmon.exe"
        $sysmonDriverPath = "C:\Windows\SysmonDrv.sys"
        if ( Get-Item $x64Path ) {
            $SysmonPath = $x64Path
        } elseif ( Get-Item $x86Path ) {
            $SysmonPath = $x86Path
        } else {
            Log-Error "Sysmon does not exist in C:\Windows, nothing to remove"
            $SysmonPath = null
        }
        # If $SysmonPath exists, start uninstall process and removal
        if ( $SysmonPath ) {
            Start-Process $SysmonPath -arg "-u"
            Move-Item -Path $SysmonPath -Destination "$($env:TEMP)/$($SysmonPath.split('\')[1]).bluback" -Force
            Log-Message "Removed $($SysmonPath)"
        }
        # Remove leftover driver if exists
        if ( Get-Item $sysmonDriverPath ) {
            Move-Item -Path $sysmonDriverPath -Destination "$($env:TEMP)/$($sysmonDriverPath.split('\')[1]).bluback" -Force
        }
    }
    Function Install-Agent(){
    	#Validate Installation Key
    	if ( $Agent.Length -lt 600 ) {
   	   Log-Error "This Agent key appears invalid $($Agent)"
    	   Log-Message "Reach out to support@blumira.com for additional help."
           try { [console]::bufferwidth = 120 } catch { Log-Message "Unable to set bufferwidth, proceeding."}
    	   Break
    	}
    	#Check if running in Powershell ISE
    	if ($psISE.Length -gt 0 ) {
    	   Log-Error "You appear to be running in PowerShell ISE. This will prevent proper installation, please use a standard powershell session as opposed to the ISE"
    	   try { [console]::bufferwidth = 120 } catch { Log-Message "Unable to set bufferwidth, proceeding."}
    	   Break
    	}
    	#Check for Sysmon
    	$sysmonservice = Get-Service -Name "Sysmon*" -ErrorAction SilentlyContinue
    	if ($sysmonservice.Length -gt 0) {
    	   # Uninstall Sysmon
    	   Log-Message "Sysmon found, uninstalling before adding Blumira Agent"
    	Uninstall-Sysmon
    	}
    	#Check for NXlog
    	$nxlogservice = Get-Service -Name "nxlog" -ErrorAction SilentlyContinue
    	if ($nxlogservice.Length -gt 0) {
    	   # Uninstall NXlog
    	   Log-Message "NXlog found, uninstalling before adding Blumira Agent"
    	   Uninstall-NxLog
    	}
    	#Change Console size to deal with newline constraints
        try { [console]::bufferwidth = 32766 } catch { Log-Message "Unable to set bufferwidth, proceeding."}
    	Log-Message "Preflight checks complete proceeding with install..."
    	#Download Blumira Agent
    	Log-Message "Gathering Blumira Agent from Config: $($Config.agent)"
    	# Get the filename and gather the file
    	$Agent_Filename = $Config.agent.download_url.split('/')[-1]
    	if ( $WorkingDirectory ) {
           $Config.agent.download_url = $Agent_Filename
    	}
    	# Gather the installer from the declared configuration
    	$Agent_Installer = Download-Or-Copy-File -Fileloc $Config.agent.download_url
    	Log-Message "$Agent_Filename"
    	Log-Message "$Agent_Installer"
    	#Set installation Args
    	$Args = @('-i', $Agent)
    	#Begin install process
    	start-process $Agent_Installer $Args
    	#Make Sure service starts running
    	try {
    	   (Get-Service -Name "rphcpsvc").WaitForStatus('Running', '00:00:15')
    	}
    	   catch [System.ServiceProcess.TimeoutException]
    	{
    	   Log-Error "Failed Validation status: Service Error"
    	   Log-Message "Reach out to support@blumira.com for additional help."
    	}
    	#Customize Service Info
    	Sleep 5
    	Set-Service -Name "rphcpsvc" -DisplayName "Blumira Agent" -StartupType Automatic -Status Running -Description "Blumira endpoint security sensor."
    	#Check Install Success
    	Log-Message "Checking Installation"
    	$servicecheck = Get-Service -Name "rphcpsvc"
    	if ($servicecheck.Length -gt 0) {
    	   $servicecheck
    	} else {
           Log-Error "Failed Validation status: Service Error"
	   Log-Message "Reach out to support@blumira.com for additional help."
	   try { [console]::bufferwidth = 120 } catch { Log-Message "Unable to set bufferwidth, proceeding."}
	   Break
    	}
    	Sleep 10
    	$agentinstallcheck = Get-Content C:\Windows\System32\hcp.log | sls "error|no config"
    	if ($agentinstallcheck.Length -gt 0) {
    	   Log-Error "Failed Validation status: Error"
    	   Log-Message "$($agentinstallcheck)"
    	   Log-Message "Reach out to support@blumira.com for additional help."
    	} else {
    	   Log-Message "Installation status: Successful"
    	}
    	#Return to standard console size
    	try { [console]::bufferwidth = 120 } catch { Log-Message "Unable to set bufferwidth, proceeding."}
    	}
    Function Install-NXLog() {
        Log-Message "Gathering NXLog Config: $($Config.nxlog)"
        # Get the filename and gather the file
        $NXLog_Filename = $Config.nxlog.download_url.split('/')[-1]
        if ( $WorkingDirectory ) {
            $Config.nxlog.download_url = $NXLog_Filename
        }
        # Gather the installer from the declared configuration
        $NXLog_Installer = Download-Or-Copy-File -Fileloc $Config.nxlog.download_url
        # Install and check code output
        $Arguments = @(
            "/i $NXLog_Installer"
            "/qn"
        )
        $NXLogInstall = (Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -Passthru).ExitCode
        if ( $NXLogInstall -eq 0 ) {
            Log-Message "Installation status: Successful"
            Return $true
        } else {
            Log-Error "Issue with installation, code: $NXLogInstall"
            Log-Message "Research this code and try again after fixed."
            Return $false
        }
    }
    Function Uninstall-NXlog() {
        Log-Message "Uninstalling NXLog now, gathering uninstall string from registry"
        $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        $NXLogApp = Get-ChildItem -Path $RegPath | Get-ItemProperty | Where-Object {$_.DisplayName -match "nxlog" }
        $uninstallNXLogApp = $NXLogApp.UninstallString -Replace "msiexec.exe","" -Replace "/I","" -Replace "/X",""
        $uninstallNXLogApp = $uninstallNXLogApp.trim()
        Start-Process "msiexec.exe" -arg "/X $uninstallNXLogApp /qb" -Wait
        }
        Function Test-Connection($Sensor,$Port) {
        Log-Message "Testing connection to $Sensor over port $Port";
        if (Test-NetConnection -Port $port -ComputerName $sensor -InformationLevel Quiet) { 
            Log-Message "Successfully connected to Sensor at $($Sensor)!"; 
            Log-Message "Genenerating default configuration with validated Sensor IP at $($Sensor)"; 
        } else { Log-Message "Could not connect to Sensor! Running detailed output..."; 
            Test-NetConnection -Port $port -ComputerName $Sensor -InformationLevel Detailed; 
            Log-Message "Generating default configuration, could not confirm Sensor ($Sensor) Connectivity"; 
        } 
    }
    #Used to download files necessary to allow for local file install distribution with opther RMM tools or custom configurations
    Function Download-Poshim-Locally() {
        # Gather files from config and place in $WorkingDirectory
        Log-Message "Downloading PowerShell script for local use"
        Invoke-WebRequest -Uri "https://dl.blumira.com/agent/poshim.ps1" -Outfile "$($WorkingDirectory)/poshim.ps1"
        Log-Message "Downloading Configuration from $($Configuration)"
        Invoke-WebRequest -Uri $Configuration -Outfile "$($WorkingDirectory)/$($Configuration.split('/')[-1])"
        Log-Message "Downloading NXLog MSI file and NXLog Configuration Template"
        Invoke-WebRequest -Uri $Config.nxlog.download_url -Outfile "$($WorkingDirectory)/$($Config.nxlog.download_url.split('/')[-1])"
        Invoke-WebRequest -Uri $Config.nxlog.conf_template_url -Outfile "$($WorkingDirectory)/$($Config.nxlog.conf_template_url.split('/')[-1])"
        # Sysmon gather
        Log-Message "Downloading Sysmon Installation file and Configuration"
        Invoke-WebRequest -Uri $Config.sysmon.download_url -Outfile "$($WorkingDirectory)/$($Config.sysmon.download_url.split('/')[-1])"
        Invoke-WebRequest -Uri $Config.sysmon.conf_url -Outfile "$($WorkingDirectory)/$($Config.sysmon.conf_url.split('/')[-1])"
        # Blumira Agent gather
        Log-Message "Downloading Blumira Agent file"
        Invoke-WebRequest -Uri $Config.agent.download_url -Outfile "$($WorkingDirectory)/$($Config.agent.download_url.split('/')[-1])"
    }
    Function Write-Event-Agent-State() {
        Param(
            [parameter(Mandatory=$true,Position=1)]$Config
        )
        $EventLogSource = "BlumiraAgent"
        # Define messages to be sent
        $InitialEventLogMessage = "Poshim Blumira Agent running at $(Get-Date -format "o")"
        $NewInstallMessage = "New NXLog Install Completed at $(Get-Date -format "o")"
        $SysmonVersionMessage = "Version $($Config.sysmon.active_version)"
        $NXlogVersionMessage = "Version $($Config.nxlog.active_version)"
        $PoshimVersionMessage = "Version $($Config.poshim_version)"
        if ( $Sysmon ) {
            $UpdateMessage = "NXLog and Sysmon configurations updated and services restarted at $(Get-Date -format "o")"
            $UninstallMessage = "NXLog and Sysmon uninstalled on this host at $(Get-Date -format "o")"
        } else {
            $UpdateMessage = "NXLog configuration updated and service restarted at $(Get-Date -format "o")"
            $UninstallMessage = "NXLog uninstalled on this host at $(Get-Date -format "o")"
        }
        # Determine if event source exists
        if ( (Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application).pschildname | Select-String $EventLogSource ) {
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10000 -EntryType Information -Message $InitialEventLogMessage
        } else {
            New-EventLog -Source $EventLogSource -LogName Application
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10000 -EntryType Information -Message $InitialEventLogMessage
        }
        # Determine if new or update, log out
        if ( $global:NewInstall -and $Install ) {
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10001 -EntryType Information -Message $NewInstallMessage
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10004 -EntryType Information -Message "$SysmonVersionMessage installed at $(Get-Date -format "o")"
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10004 -EntryType Information -Message "$NXlogVersionMessage installed at $(Get-Date -format "o")"
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10004 -EntryType Information -Message "$PoshimVersionMessage installed at $(Get-Date -format "o")"
        } elseif ($global:NewInstall -eq $false -and $Install) {
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10002 -EntryType Information -Message  $UpdateMessage
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10005 -EntryType Information -Message "Sysmon updated to $SysmonVersionMessage at $(Get-Date -format "o")"
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10005 -EntryType Information -Message "NXLog updated to $NXlogVersionMessage at $(Get-Date -format "o")"
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10005 -EntryType Information -Message "PoSHim updated to $PoshimVersionMessage at $(Get-Date -format "o")"
        }
        if ( $global:NewInstall -eq $false -and $Uninstall) {
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10003 -EntryType Information -Message $UninstallMessage
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10006 -EntryType Information -Message "$SysmonVersionMessage was uninstalled at $(Get-Date -format "o")"
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10006 -EntryType Information -Message "$NXlogVersionMessage was uninstalled at $(Get-Date -format "o")"
            Write-EventLog -LogName "Application" -Source $EventLogSource -EventID 10006 -EntryType Information -Message "$PoshimVersionMessage was uninstalled at $(Get-Date -format "o")"
        }
    }
    Function Blumira-Agent() {
    Param(
        [parameter(Mandatory=$false)][String]$Configuration = "https://dl.blumira.com/agent/poshim_config.json",
        [parameter(Mandatory=$false)][String]$Sensor,
        [parameter(Mandatory=$false)][String]$Agent,
        [parameter(Mandatory=$false)][String]$WorkingDirectory,
        [parameter(Mandatory=$false)][Int]$Port = 514,
        [parameter(Mandatory=$false)][Switch]$Sysmon = $true,
        [parameter(Mandatory=$false)][Switch]$NoSysmon,
        [parameter(Mandatory=$false)][String]$AdditionalLogs,
        [parameter(Mandatory=$false)][String]$NXLogExtras,
        [parameter(Mandatory=$false)][Switch]$Install = $false,
        [parameter(Mandatory=$false)][Switch]$Uninstall = $false,
        [parameter(Mandatory=$false)][Switch]$Download = $false,
        [parameter(Mandatory=$false)][Switch]$Report = $false,
        [parameter(Mandatory=$false)][Switch]$FirewallAllow,
        [parameter(Mandatory=$false)][Switch]$Silent
    )
    # Set globals
    $global:silent = $Silent
    $global:report = $Report
    # Set context if passed in for local runs
    if ( $WorkingDirectory ) {
        Set-Location $WorkingDirectory
    }
    # Check if http/s or file-based and gather Configuration
    $Config = Obtain-File-Contents -Filepath $Configuration | ConvertFrom-Json
    # Configuration obtained, proceed
    Log-Message "Blumira: PoSHim - Endpoint Visibility Shim"
    Log-Message "PoSHim Setup $(Get-Date -Format "o")";
    # Log-Message "For more information and help - <link>.blumira.com"
    Log-Message "Completed Sensor test, proceeding."
    if ( $Install ) {
        Log-Message "Running Install (or Update/Maintain) Mode"
	Check-Admin
        if ( $Sensor ) {
            Log-Message "Sensor IP identified in initial run, setting up for IP $Sensor."
            Test-Connection $Sensor $Port;
        } else {
            Log-Error "You passed -Install but did not pass -Sensor <ip>"
            Break
        }
        # If -Sysmon install it first, NXLog will need to hook it in Event Viewer anyways
        # Check if Sysmon install requested
        if ( $NoSysmon -ne $true ) {
            Log-Message "Installing or updating Sysmon now"
            Install-Configure-Sysmon
            Log-Message "Completed installing and/or updating Sysmon"
        }
        # Check for NXLog, catch the service get error and set $false
        try {
            $nxlogProc = Get-Service -Name nxlog | Where-Object {$_.Status -eq "Running"}
            # Check to see if this is nxlog 2 or 3, if 2 we should be installing net new
            if (Test-Path -Path "C:\Program Files (x86)\nxlog\nxlog.exe") {
                Log-Message "NXLog 2.x detected, flagging to install NXLog 3.x and remove 2.x"
                $nxlogProc = $false
            }
        } catch {
            $nxlogProc = $false
        }
        # If nxlog is already installed and running, update both config and nxlog.
        if ( $nxlogProc ) {
            Log-Message "NXLog already installed."
            # TODO: Need to add in a check for the versions.
            # Quick and dirty fix right here for having it just by default remove nxlog and redo it
            Uninstall-NXlog
            $status = Install-NXLog
            if ( $status -eq $true ) {
                Configure-NXLog -Config $Config -IP $Sensor -AdditionalLogs $AdditionalLogs -NXLogExtras $NXLogExtras
                Log-Message "Installation of NXLog has completed."
                Write-Event-Agent-State -Config $Config
            } else {
                Log-Error "The installation appears to have failed, review your configuration."
            }
            Write-Event-Agent-State -Config $Config
        } else {
            Log-Message "NXLog not found, installing NXLog now."
            $global:NewInstall = $true
            $status = Install-NXLog
            if ( $status -eq $true ) {
                Configure-NXLog -Config $Config -IP $Sensor -AdditionalLogs $AdditionalLogs -NXLogExtras $NXLogExtras
                Log-Message "Installation of NXLog has completed."
                Write-Event-Agent-State -Config $Config
            } else {
                Log-Error "The installation appears to have failed, review your configuration."
            }
        }
        Log-Message "Completed Blumira PoSHim run at $(Get-Date -format "o")"
    }
    if ( $Agent ) {
	Check-Admin
    	Log-Message "Installing Blumira Agent"
    	Install-Agent
    }
    if ( $Uninstall ) {
        Log-Message "Running Uninstall mode, cleaning up Poshim"
	Check-Admin
        if ( $NoSysmon -ne $true ) {
            Uninstall-Sysmon
        }
        #Check for NXlog
        $nxlogservice = Get-Service -Name "nxlog" -ErrorAction SilentlyContinue
        if ($nxlogservice.Length -gt 0) {
        # Uninstall NXlog
        Uninstall-NXLog
        Log-Message "Successfully uninstalled NXLog"
        Log-Message "Completed Blumira PoSHim cleanup at $(Get-Date -format "o")"
        } else {
        Log-Error "Nxlog not found if trying to Uninstall the Blumira Agent this needs to be done through the Blumira Device managment page."
        }
    }
    if ( $Download ) {
        if ( $WorkingDirectory ) {
            Download-Poshim-Locally
        } else {
            Log-Error "You indicated -Download but did not pass -WorkingDirectory where the files will be placed."
        }
    }
    }

    export-modulemember -function 'Blumira-Agent';
}
# --- END REPLACE ---

# Ensure Blumira directory exists
$blumiraDir = Split-Path -Path $configPath -Parent
if (-not (Test-Path -Path $blumiraDir)) {
    New-Item -Path $blumiraDir -ItemType Directory -Force | Out-Null
}

# Write poshim_config.json
$configJson | Out-File -FilePath $configPath -Encoding UTF8 -Force

# Write poshim.ps1 script file
$poshimScriptContent | Out-File -FilePath $poshimPath -Encoding UTF8 -Force

# Dot-source poshim.ps1 to import functions
try {
    . $poshimPath
} catch {
    Write-Error "Failed to load poshim.ps1: $_"
    exit 1
}

# Validate Blumira-Installer function availability
if (-not (Get-Command Blumira-Installer -ErrorAction SilentlyContinue)) {
    Write-Error "Blumira-Installer function is not defined after loading poshim.ps1"
    exit 2
}

# --- REPLACE THIS with your actual Blumira agent token ---
$agentToken = "INSERT TOKEN HERE"
# --- END REPLACE ---

# Run Blumira-Installer
try {
    Blumira-Installer -Configuration $configPath -Agent $agentToken
    Write-Host "Blumira agent installed successfully."
} catch {
    Write-Error "Blumira installation failed: $_"
    exit 3
}

