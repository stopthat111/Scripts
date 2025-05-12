# Initiates a full reset of the Windows PC without prompting
# This will remove all personal files, applications, and settings

# Enable the Reset on Next Boot
New-Item -Path "HKLM:\System\Setup\Status\SysprepStatus" -Name "CleanupState" -Value 2 -Force
New-Item -Path "HKLM:\System\Setup\Status\SysprepStatus" -Name "SysprepCleanupRequired" -Value 1 -Force

# Set the system to enter OOBE (Out of Box Experience) mode on next boot
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State /v ImageState /d "IMAGE_STATE_UNDEPLOYABLE" /f
reg add HKLM\SYSTEM\Setup /v CmdLine /d "oobe\Bddrun.exe" /f
reg add HKLM\SYSTEM\Setup /v OOBEInProgress /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\Setup /v SystemSetupInProgress /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\Setup /v SetupType /t REG_DWORD /d 2 /f

# Trigger a reboot for the reset to take effect
Restart-Computer -Force
