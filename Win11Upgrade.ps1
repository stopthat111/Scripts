$dir = 'C:\packages'
mkdir $dir
$webClient = New-Object System.Net.WebClient
$url = 'https://go.microsoft.com/fwlink/?linkid=2171764'
$file = "$($dir)\Windows11UpdateAssistant.exe"
$webClient.DownloadFile($url,$file)
Start-Process -FilePath $file -ArgumentList '/quietinstall /skipeula /auto upgrade /copylogs $dir'
start-sleep 120
Get-Process windows10upgraderapp -ErrorAction SilentlyContinue | Wait-Process
shutdown -a
