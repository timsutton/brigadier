# Rewrite from Perl to PowerShell - Requires PowerShell v3 or greater
[CmdletBinding()]
Param(
    [string]$Model = (Get-WmiObject -Class Win32_ComputerSystem | Select -ExpandProperty Model),
    [switch]$Install = $false,
    [string]$OutputDir = "$env:TEMP",
    [switch]$KeepFiles = $false,
    [string]$ProductId,
    [string]$PlistPath = "brigadier.plist",
    [string]$SUCATALOG_URL = 'http://swscan.apple.com/content/catalogs/others/index-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog',
    # 7-Zip MSI (15.14)
    [string]$SEVENZIP_URL = 'http://7-zip.org/a/7z1514-x64.msi',
    # dmg2img zip download from http://vu1tur.eu.org/tools
    [string]$DMG2IMG_URL = 'http://vu1tur.eu.org/tools/dmg2img-1.6.5-win32.zip'
)

# Set values from plist
if (Test-Path $PlistPath) {
    [xml]$Plist = Get-Content -Path $PlistPath
    0..($Plist.plist.dict.key.Length - 1) | ForEach-Object {
        if ($Plist.plist.dict.key[$_] -eq "CatalogURL") { $SUCATALOG_URL = $plist.plist.dict.string[$_] }
        if ($Plist.plist.dict.key[$_] -eq "7zipURL") { $SEVENZIP_URL = $plist.plist.dict.string[$_] }
        if ($Plist.plist.dict.key[$_] -eq "Dmg2ImgURL") { $DMG2IMG_URL = $plist.plist.dict.string[$_] }
    }
}

# Check if 7zip is installed. If not, download and install it
$7zPath = "$env:ProgramFiles\7-Zip\7z.exe"
if (Test-Path $7zPath) {
    $7zInstalled = $true
} else { 
    Invoke-WebRequest -Uri $SEVENZIP_URL -OutFile "$env:TEMP\$($SEVENZIP_URL.Split('/')[-1])" -ErrorAction Stop -Proxy $proxyserver -ProxyCredential $proxycreds
    Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $env:TEMP\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait
}

# Download Dmg2Img
function GetDmg2Img { 
    Invoke-WebRequest -Uri $DMG2IMG_URL -OutFile "$env:TEMP\$($DMG2IMG_URL.Split('/')[-1])" -ErrorAction Stop -Proxy $proxyserver -ProxyCredential $proxycreds
    Invoke-Command -ScriptBlock {cmd /c "$7zPath" -o"$env:TEMP" x "$env:TEMP\$($DMG2IMG_URL.Split('/')[-1])" -y}
}

# Find Bootcamp.msi
$BootCampMSI = Get-ChildItem -Path $BootCampPath -Recurse -Include BootCamp*.msi | Select -ExpandProperty FullName
if ($BootCampMSI.Length -gt 1) { 

} else {  }


# Read data from sucatalog
[xml]$sucatalog = Invoke-WebRequest -Uri $SUCATALOG_URL -Method Get -ErrorAction Stop -Proxy $proxyserver -ProxyCredential $proxycreds
# Find all Bootcamp ESD's
$sucatalog.plist.dict.dict.dict | Where-Object { $_.String -match "Bootcamp" } | ForEach-Object {
    # Get dist file to find supported models, using regex match to find models in dist files
    $SupportedModels = [regex]::Matches((Invoke-RestMethod -Uri ($_.dict | Where-Object { $_.Key -match "English" } | Select -ExpandProperty String)).InnerXml,"([a-zA-Z]{4,12}[1-9]{1,2}\,[1-6])") | Select -ExpandProperty Value
    if ($SupportedModels -contains $Model) { 

    $download = $sucatalog.plist.dict.dict.dict | Where-Object { $_.String -match "Bootcamp" } | ForEach-Object { $_.array.dict | Select -ExpandProperty String | Where-Object { $_ -match ".pkg" }}
    }
}


# Install Bootcamp
Invoke-Command -ScriptBlock { cmd /c "msiexec.exe /i $BootCampMSI /qb- /norestart /log $env:SystemRoot\BootcampInstall.log"

