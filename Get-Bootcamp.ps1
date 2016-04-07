# Rewrite from Python to PowerShell - Requires PowerShell v3 or greater
# 16/4/7 - Removd DMG2IMG components, removed plist as we can take arguments instead, preparing for ability to pass ProductID as an array
# To do: Add logging, include fallback in case BITS is not installed: https://blog.jourdant.me/3-ways-to-download-files-with-powershell/
[CmdletBinding()]
Param(
    [string]$Model = (Get-WmiObject -Class Win32_ComputerSystem).Model,
    [switch]$Install,
    [string]$OutputDir = "$env:TEMP",
    [switch]$KeepFiles,
    [array]$ProductId,
    [string]$Mst,
    [string]$SUCATALOG_URL = 'http://swscan.apple.com/content/catalogs/others/index-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog',
    [string]$SEVENZIP_URL = 'http://7-zip.org/a/7z1514-x64.msi'
)

# Create Output Directory if it does not exist
if (!(Test-Path $OutputDir)) { New-Item -Path $OutputDir -ItemType Directory -Force }

# Check if 7zip 15.14 is installed. If not, download and install it.
$7z = "$env:ProgramFiles\7-Zip\7z.exe"
if (Test-Path $7z) { $7zInstalled = $true; [decimal]$7zVersion = (Get-ItemProperty $7z).VersionInfo.FileVersion }
if ($7zVersion -lt 15.14) {
    Start-BitsTransfer -Source $SEVENZIP_URL -Destination "$OutputDir\$($SEVENZIP_URL.Split('/')[-1])" -ErrorAction Stop
    Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $OutputDir\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait -Verbose
}

# Read data from sucatalog and find all Bootcamp ESD's
[xml]$sucatalog = Invoke-WebRequest -Uri $SUCATALOG_URL -Method Get -ErrorAction Stop
$sucatalog.plist.dict.dict.dict | Where-Object { $_.String -match "Bootcamp" } | ForEach-Object {
    # Search dist files to find supported models, using regex match to find models in dist files - stole regex from brigadier's source
    $SupportedModels = [regex]::Matches((Invoke-RestMethod -Uri ($_.dict | Where-Object { $_.Key -match "English" }).String).InnerXml,"([a-zA-Z]{4,12}[1-9]{1,2}\,[1-6])").Value
    if ($SupportedModels -contains $Model) { 
        $version = [regex]::Match(($_.dict | Where-Object { $_.Key -match "English" }).String,"(\d{3}-\d{5})").Value
        Write-Output "Found supported ESD: $Version"
        [array]$bootcamplist += $_ 
    }
}
if ($bootcamplist.Length -gt 1) { 
    Write-Output "Found more than 1 supported Bootcamp ESD. Selecting newest based on posted date"
    $bootcamplist | ForEach-Object { 
        if ($_.date -gt $latestdate) { 
            $latestdate = $_.date
            $download = $_.array.dict.string | Where-Object { $_ -match '.pkg' }
        }
    }
} else { $download = $bootcamplist.array.dict.string | Where-Object { $_ -match '.pkg' }}

# Download the BootCamp ESD
Start-BitsTransfer -Source $download -Destination "$OutputDir\BootCampESD.pkg" -ErrorAction Stop
if (Test-Path -Path "$OutputDir\BootCampESD.pkg") {
    # Extract the bootcamp installer
    Invoke-Command -ScriptBlock { 
        cmd /c $7z -o"$OutputDir" -y e "$OutputDir\BootCampESD.pkg"
        cmd /c $7z -o"$OutputDir" -y e "$OutputDir\Payload~"
        # If just downloading, put the extracted installers on the desktop
        if ($Install) { cmd /c $7z -o"$OutputDir" -y x "$OutputDir\WindowsSupport.dmg" } else { if ($OutputDir -eq "$env:TEMP") { cmd /c $7z -o"$env:USERPROFILE\Desktop\$version" -y x "$OutputDir\WindowsSupport.dmg" }}
    }
} else { Write-Output "BootCampESD.pkg could not be found"; exit } 

# Uninstall 7zip if we installed it
if ($7zInstalled -ne $true) { Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/x $OutputDir\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait }

# Testing for iMac14,1 issue with Realtek Audio driver hanging the installation
#"Bootcamp","Drivers" | ForEach-Object { if (Test-Path -Path "$OutputDir\$_") { (Get-ChildItem -Path "$OutputDir\$_" -Recurse -Include RealtekSetup.exe -ErrorAction SilentlyContinue).FullName }} | Move-Item -Destination $OutputDir

# Find Bootcamp.msi and install matching based on OS architecture
[array]$BootCampMSI = "Bootcamp","Drivers" | ForEach-Object { if (Test-Path -Path "$OutputDir\$_") { (Get-ChildItem -Path "$OutputDir\$_" -Recurse -Include BootCamp*.msi).FullName }}
if ($BootCampMSI.Length -gt 1) {
    # Check OS architecture and install correct version
    if ((Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture -eq "64-bit") { 
        $BootCampMSI = $BootCampMSI | Where-Object { $_ -match "64" }
    } else {
        $BootCampMSI = $BootCampMSI | Where-Object { $_ -notmatch "64" }
    }
}

# Install Bootcamp and use MST if specified (I uploaded one that I had to use to fix the latest ESD on an iMac14,1)
if ($Install) { 
    if ($mst -ne "") { 
        Copy-Item -Path $Mst -Destination $($BootCampMSI.TrimEnd("\BootCamp.msi"))
        Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $BootCampMSI TRANSFORMS=$($Mst.Split('\')[-1]) /qb- /norestart /l*v $env:SystemDrive\BootcampInstall.log" -Verbose -Wait 
    } else { Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $BootCampMSI /qb- /norestart /l*v $env:SystemDrive\BootcampInstall.log" -Verbose -Wait }
} else { exit }

# Clean up
if ($KeepFiles) { exit } else { Remove-Item -Path "$OutputDir\*" -Recurse -Force -ErrorAction SilentlyContinue }