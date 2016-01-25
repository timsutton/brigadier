# Rewrite from Python to PowerShell - Requires PowerShell v3 or greater
# To do: Add more output, add in functions for params like install, product id, etc.
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
    [string]$SEVENZIP_URL = 'http://7-zip.org/a/7z1514-x64.msi'
    # Newer 7zip supports extracting DMG. May add support back if older version of 7z is found in the future.
    #[string]$DMG2IMG_URL = 'http://vu1tur.eu.org/tools/dmg2img-1.6.5-win32.zip'
)

# Script processes too fast, so we have to add a pause to allow params to set up...
Start-Sleep -Seconds 1

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
    Start-BitsTransfer -Source $SEVENZIP_URL -Destination "$OutputDir\$($SEVENZIP_URL.Split('/')[-1])" -ErrorAction Stop -ProxyList $proxyserver -ProxyCredential $proxycreds
    #Invoke-WebRequest -Uri $SEVENZIP_URL -OutFile "$OutputDir\$($SEVENZIP_URL.Split('/')[-1])" -ErrorAction Stop -Proxy $proxyserver -ProxyCredential $proxycreds
    Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $OutputDir\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait -Verbose
} else { $7zInstalled = $true }

# Download Dmg2Img
Start-BitsTransfer -Source $DMG2IMG_URL -Destination "$OutputDir\$($DMG2IMG_URL.Split('/')[-1])" -ErrorAction Stop -ProxyList $proxyserver -ProxyCredential $proxycreds
Invoke-Command -ScriptBlock { cmd /c "$7z" -o"$OutputDir" -y e "$OutputDir\$($DMG2IMG_URL.Split('/')[-1])" }

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
} else { $download = $bootcamplist.array.dict | Select -ExpandProperty String | Where-Object { $_ -match '.pkg' }}

# Download the BootCamp ESD
Start-BitsTransfer -Source $download -Destination "$OutputDir\BootCampESD.pkg" -ErrorAction Stop -ProxyList $proxyserver -ProxyCredential $proxycreds
if (Test-Path -Path "$OutputDir\BootCampESD.pkg") {
    # Extract the bootcamp installer
    Invoke-Command -ScriptBlock { 
        cmd /c $7z -o"$OutputDir" -y e "$OutputDir\BootCampESD.pkg"
        cmd /c $7z -o"$OutputDir" -y e "$OutputDir\Payload~"
        If (!(Test-Path -Path "$OutputDir\BootCamp")) { New-Item -Path "$OutputDir\BootCamp" -ItemType Directory -Force }
        cmd /c $7z -o"$env:SystemDrive" -y x "$OutputDir\WindowsSupport.dmg"
    }
} else { Write-Output "BootCampESD.pkg could not be found"; exit } 

# Convert the DMG to ISO
# Invoke-Command -ScriptBlock { cmd /c "$OutputDir\dmg2img.exe" -v "$OutputDir\WindowsSupport.dmg" "$OutputDir\WindowsSupport.iso" }

# Extract the ISO so we can run the installer
# Invoke-Command -ScriptBlock { cmd /c $7z -o"$OutputDir\Bootcamp" -y x "$OutputDir\WindowsSupport.iso" }

# Uninstall 7zip and remove installer
if ($7zInstalled -ne $true) { 
    Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/x $OutputDir\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait 
    Remove-Item -Path "$OutputDir\$($SEVENZIP_URL.Split('/')[-1])" -Force
}

# Must install Realtek Audio driver before installing Bootcamp. This step simply moves it, but you should install it first, reboot, then run this script
Get-ChildItem -Path "$env:SystemDrive\" | Where-Object { $_.Name -like "BootCamp" -or $_.Name -eq "Drivers" } | Select -ExpandProperty FullName | ForEach-Object { Get-ChildItem -Path $_ -Recurse -Include RealtekSetup.exe | Select -ExpandProperty FullName } | Move-Item -Destination $OutputDir

# Find Bootcamp.msi and install correct one
$BootCampMSI = Get-ChildItem -Path "$env:SystemDrive\" | Where-Object { $_.Name -like "BootCamp" -or $_.Name -eq "Drivers" } | Select -ExpandProperty FullName | ForEach-Object { Get-ChildItem -Path $_ -Recurse -Include BootCamp*.msi | Select -ExpandProperty FullName }
if ($BootCampMSI.Length -gt 1) {
    # Check OS architecture and install correct version
    if ((Get-WmiObject -Class Win32_OperatingSystem | Select -ExpandProperty OSArchitecture) -eq "64-bit") { 
        $BootCampMSI = $BootCampMSI | Where-Object { $_ -match "64" }
    } else {
        $BootCampMSI = $BootCampMSI | Where-Object { $_ -notmatch "64" }
    }
}
# Need to test if Realtek Audio can be installed without reboot and then install Bootcamp or if reboot is required first.
Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $BootCampMSI /qb- /norestart /log $env:SystemRoot\BootcampInstall.log" -Wait

# Clean up
if ($KeepFiles -eq $false) { Remove-Item -Path "$OutputDir\*" -Recurse -Force -ErrorAction SilentlyContinue }