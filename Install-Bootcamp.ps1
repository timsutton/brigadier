# Rewrite from Python to PowerShell - Requires PowerShell v3 or greater
# To do: Set-Location to temp, add more output, add in functions for params like keep files, product id, etc., compile to EXE
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

# Set values from plist - I'm sure there's a better way to do this...
if (Test-Path $PlistPath) {
    [xml]$Plist = Get-Content -Path $PlistPath
    0..($Plist.plist.dict.key.Length - 1) | ForEach-Object {
        if ($Plist.plist.dict.key[$_] -eq "CatalogURL") { $SUCATALOG_URL = $plist.plist.dict.string[$_] }
        if ($Plist.plist.dict.key[$_] -eq "7zipURL") { $SEVENZIP_URL = $plist.plist.dict.string[$_] }
        if ($Plist.plist.dict.key[$_] -eq "Dmg2ImgURL") { $DMG2IMG_URL = $plist.plist.dict.string[$_] }
    }
}

# Check if 7zip is installed. If not, download and install it
$7z = "$env:ProgramFiles\7-Zip\7z.exe"
if (!(Test-Path $7z)) {
    Invoke-WebRequest -Uri $SEVENZIP_URL -OutFile "$env:TEMP\$($SEVENZIP_URL.Split('/')[-1])" -ErrorAction Stop -Proxy $proxyserver -ProxyCredential $proxycreds
    Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $env:TEMP\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait 
} else { $7zInstalled = $true }

# Download Dmg2Img
Invoke-WebRequest -Uri $DMG2IMG_URL -OutFile "$env:TEMP\$($DMG2IMG_URL.Split('/')[-1])" -ErrorAction Stop -Proxy $proxyserver -ProxyCredential $proxycreds
Invoke-Command -ScriptBlock { cmd /c "$7z" -o"$env:TEMP" -y e "$env:TEMP\$($DMG2IMG_URL.Split('/')[-1])" }

# Read data from sucatalog
[xml]$sucatalog = Invoke-WebRequest -Uri $SUCATALOG_URL -Method Get -ErrorAction Stop -Proxy $proxyserver -ProxyCredential $proxycreds
# Find all Bootcamp ESD's
$sucatalog.plist.dict.dict.dict | Where-Object { $_.String -match "Bootcamp" } | ForEach-Object {
    # Search dist files to find supported models, using regex match to find models in dist files - stole regex from brigadier's source
    $SupportedModels = [regex]::Matches((Invoke-RestMethod -Uri ($_.dict | Where-Object { $_.Key -match "English" } | Select -ExpandProperty String)).InnerXml,"([a-zA-Z]{4,12}[1-9]{1,2}\,[1-6])") | Select -ExpandProperty Value
    if ($SupportedModels -contains $Model) { 
        $version = [regex]::Match(($_.dict | Where-Object { $_.Key -match "English" } | Select -ExpandProperty String),"(\d{3}-\d{5})") | Select -ExpandProperty Value
        Write-Output "Found supported ESD: $Version"
        [array]$bootcamplist += $_ 
    }
}
if ($bootcamplist.Length -gt 1) { 
    Write-Output "Found more than 1 supported Bootcamp ESD. Selecting newest based on posted date"
    $bootcamplist | ForEach-Object { 
        if ($_.date -gt $latestdate) { 
            $latestdate = $_.date
            $download = $_.array.dict | Select -ExpandProperty String | Where-Object { $_ -match '.pkg' }
            #$download = $_.string.Replace(".smd",".pkg") - URL matches the .smd but may not always?
        }
    }
} else { $download = $_.array.dict | Select -ExpandProperty String | Where-Object { $_ -match '.pkg' }}

# Download the BootCamp ESD
Invoke-WebRequest -Uri $download -OutFile "$env:TEMP\BootCampESD.pkg" -ErrorAction Stop -Proxy $proxyserver -ProxyCredential $proxycreds
if (Test-Path -Path "$env:TEMP\BootCampESD.pkg") {
    
} else { Write-Output "BootCampESD.pkg could not be found" } # Should see the error from the Invoke-WebRequest, but throwing this in there until I change this to try / catch

# Extract the WindowsSupport.dmg from the PKG
Invoke-Command -ScriptBlock { 
    cmd /c $7z -o"$env:TEMP" -y e "$env:TEMP\BootCampESD.pkg"
    cmd /c $7z -o"$env:TEMP" -y e "$env:TEMP\Payload~"
}

# Convert the DMG to ISO
Invoke-Command -ScriptBlock { cmd /c "$env:TEMP\dmg2img.exe" -v "$env:TEMP\WindowsSupport.dmg" "$env:TEMP\WindowsSupport.iso" }

# Extract the ISO so we can run the installer
If (!(Test-Path -Path "$env:TEMP\BootCamp")) { New-Item -Path "$env:TEMP\BootCamp" -ItemType Directory -Force }
Invoke-Command -ScriptBlock { cmd /c $7z -o"$env:TEMP\Bootcamp" -y x "$env:TEMP\WindowsSupport.iso" }

#Uninstall 7zip and remove installer
if ($7zInstalled -ne $true) { Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/x $env:TEMP\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait }
Remove-Item -Path "$env:TEMP\$($SEVENZIP_URL.Split('/')[-1])" -Force

# Find Bootcamp.msi and install correct one
$BootCampMSI = Get-ChildItem -Path $BootCampPath -Recurse -Include BootCamp*.msi | Select -ExpandProperty FullName
if ($BootCampMSI.Length -gt 1) {
    # Check OS architecture and install correct version
    if ((Get-WmiObject -Class Win32_OperatingSystem | Select -ExpandProperty OSArchitecture) -eq "64-bit") { 
        $BootCampMSI = $BootCampMSI | Where-Object { $_ -match "64" }
    } else {
        $BootCampMSI = $BootCampMSI | Where-Object { $_ -notmatch "64" }
    }
}
Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $BootCampMSI /qb- /norestart /log $env:SystemRoot\BootcampInstall.log" -Wait

# Clean up
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue