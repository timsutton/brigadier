[CmdletBinding()]
Param(
    [string]$Model = (Get-WmiObject -Class Win32_ComputerSystem).Model,
    [switch]$Install,
    [string]$OutputDir = "$env:TEMP",
    [switch]$KeepFiles,
    [array]$ProductId,
    [string]$SUCATALOG_URL = 'http://swscan.apple.com/content/catalogs/others/index-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog',
    [string]$SEVENZIP_URL = 'http://www.7-zip.org/a/7z1604-x64.msi'
)

# Disable Invoke-WebRequest progress bar to speed up download due to bug
$ProgressPreference = "SilentlyContinue"

# Create Output Directory if it does not exist
if (!(Test-Path $OutputDir)) { New-Item -Path $OutputDir -ItemType Directory -Force }

# Check if at least 7zip 15.14 is installed. If not, download and install it.
$7z = "$env:ProgramFiles\7-Zip\7z.exe"
if (Test-Path $7z) { $7zInstalled = $true }
if ([version](Get-ItemProperty $7z).VersionInfo.FileVersion -lt 15.14) {
    Invoke-WebRequest -Uri $SEVENZIP_URL -OutFile "$OutputDir\$($SEVENZIP_URL.Split('/')[-1])" -ErrorAction Stop
    Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $OutputDir\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait -Verbose
}

# Read data from sucatalog and find all Bootcamp ESD's
[xml]$sucatalog = Invoke-WebRequest -Uri $SUCATALOG_URL -Method Get -ErrorAction Stop
$sucatalog.plist.dict.dict.dict | Where-Object { $_.String -match "Bootcamp" } | ForEach-Object {
    # Search dist files to find supported models, using regex match to find models in dist files - stole regex from brigadier's source
    $modelRegex = "([a-zA-Z]{4,12}[1-9]{1,2}\,[1-6])"
    $distURL = ($_.dict | Where-Object { $_.Key -match "English" }).String
    $distXML = (Invoke-RestMethod -Uri $distURL).InnerXml
    $SupportedModels = [regex]::Matches($distXML,$modelRegex).Value
    if ($SupportedModels -contains $Model) { 
        $version = [regex]::Match($distURL,"(\d{3}-\d{5})").Value
        Write-Output "Found supported ESD: $Version"
        [array]$bootcamplist += $_ 
    }
}
if ($bootcamplist.Length -gt 1) { 
    Write-warning "Found more than 1 supported Bootcamp ESD. Selecting newest based on posted date which may not always be correct"
}
$esd = $bootcamplist | Sort-Object -Property Date | Select-Object -Last 1
# Build a hash table of the package's properties from the XML
$package = $esd.array.dict.selectnodes('key') | ForEach-Object {@{$($_.'#text') = $($_.nextsibling.'#text')}}
$package += @{'ESDVersion' = $Version}
$download = $package.URL

# Download the BootCamp ESD
Start-BitsTransfer -Source $download -Destination "$OutputDir\BootCampESD.pkg" -ErrorAction Stop
if (Test-Path -Path "$OutputDir\BootCampESD.pkg") {
    # Extract the bootcamp installer
    Invoke-Command -ScriptBlock { 
        & $7z -o"$OutputDir" -y e "$OutputDir\BootCampESD.pkg"
        & $7z -o"$OutputDir" -y e "$OutputDir\Payload~"
        # If just downloading, put the extracted installers on the desktop
        if ($Install) {
            & $7z -o"$OutputDir" -y x "$OutputDir\WindowsSupport.dmg"
        }
        else {
            if ($OutputDir -eq "$env:TEMP") { & $7z -o"$env:USERPROFILE\Desktop\$version" -y x "$OutputDir\WindowsSupport.dmg" } else { & $7z -o"$OutputDir" -y x "$OutputDir\WindowsSupport.dmg" }
        }
    }
    }
else { Write-Warning "BootCampESD.pkg could not be found"; exit }

# Uninstall 7zip if we installed it
if ($7zInstalled -ne $true) { Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/x $OutputDir\$($SEVENZIP_URL.Split('/')[-1]) /qb- /norestart" -Wait }

# Install Bootcamp and use MST if specified (I uploaded one that I had to use to fix the latest ESD on an iMac14,1)
if ($Install) { 
    # Install Bootcamp
    $scaction = New-ScheduledTaskAction -Execute "msiexec.exe" -Argument "/i $OutputDir\Bootcamp\Drivers\Apple\BootCamp.msi /qn /norestart"
    $sctrigger = New-ScheduledTaskTrigger -At ((Get-Date).AddSeconds(15)) -Once
    $scprincipal = New-ScheduledTaskPrincipal "SYSTEM" -RunLevel Highest
    $scsettings = New-ScheduledTaskSettingsSet
    $sctask = New-ScheduledTask -Action $scaction -Principal $scprincipal -Trigger $sctrigger -Settings $scsettings
    Register-ScheduledTask "Install Bootcamp" -InputObject $sctask -User "SYSTEM"
    do { Write-Output "Sleeping 20 seconds"; Start-Sleep -Seconds 20 } while (Get-Process -Name "msiexec" -ErrorAction SilentlyContinue)
}
else { exit }

# Clean up
if ($KeepFiles) { exit } else { Remove-Item -Path "$OutputDir\*" -Recurse -Force -ErrorAction SilentlyContinue }
