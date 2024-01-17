<#
.SYNOPSIS
    Fetch and install Boot Camp ESDs with ease.
.DESCRIPTION
    Download and unpack Boot Camp drivers and support software from Apple or your software update servers for specified Mac models.

    Can also install drivers and software if used with the "-Install" parameter.
.EXAMPLE
    brigadier.ps1
    Download and unpack the ESD that applies to current computer's model to the current working directory.

.EXAMPLE
    brigadier.ps1 -Model 'MacBookAir5,2'
    Download and unpack the ESD for a specific model to the current working directory.

.EXAMPLE
    brigadier.ps1 -Install
    Download, unpack, and install drivers for the current computer, deleting the drivers after installation.
.NOTES
    This is a PowerShell port of timsutton's original Python script https://github.com/timsutton/brigadier/
.LINK
    https://github.com/timsutton/brigadier/
#>

[CmdletBinding(DefaultParameterSetName='Download')]
Param(
    # Model identifier to use, defaulting to the current machine's model.
    [Parameter(ParameterSetName='Download')]
    [string]$Model = (Get-CimInstance -Class Win32_ComputerSystem).Model,

    # After the installer is downloaded, perform the install automatically.
    [Parameter(ParameterSetName='Install',
        Mandatory=$true
        )]
    [switch]$Install,

    # Directory to extract installer files to. Defaults to the current directory.
    [string]$OutputDir = $PWD,

    # Keep the files that were downloaded/extracted after installing/
    [Parameter(ParameterSetName='Install')]
    [switch]$KeepFiles,

    # Specify an exact product ID to download.
    [array]$ProductId,

    # URL for software update catalog to use, eg for an intenal Software Update Service or Reposado
    [Alias('SUCATALOG_URL')]
    [string]$CatalogURL = 'https://swscan.apple.com/content/catalogs/others/index-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog',
    
    # URL to download 7-Zip from, if not installed
    [Alias('SEVENZIP_URL')]
    [string]$SevenZipURL = 'https://github.com/ip7z/7zip/releases/download/21.07/7z2107-x64.exe'
)

# Disable Invoke-WebRequest progress bar to speed up download due to bug
$ProgressPreference = "SilentlyContinue"

# Create Output Directory if it does not exist
if (!(Test-Path $OutputDir)) { New-Item -Path $OutputDir -ItemType Directory -Force }

# Check if at least 7zip 15.14 is installed. If not, download and install it.
$7z = "$env:ProgramFiles\7-Zip\7z.exe"
$7zDownload = Join-Path $env:Temp $SevenZipURL.Split('/')[-1]
if (Test-Path $7z) { $7zInstalled = $true }
if ([version](Get-ItemProperty $7z).VersionInfo.FileVersion -lt 15.14) {
    Write-Host "7-Zip not installed, will install and remove."
    Invoke-WebRequest -Uri $SevenZipURL -OutFile $7zDownload -ErrorAction Stop
    Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/i $7zDownload /qb- /norestart" -Wait -Verbose
}

Write-Host "Using model: $Model"

# Read data from sucatalog and find all Bootcamp ESD's
Write-Host "Downloading software update catalog..."
$bootcamplist = @()
[xml]$sucatalog = Invoke-WebRequest -Uri $CatalogURL -Method Get -ErrorAction Stop
$sucatalog.plist.dict.dict.dict | Where-Object { $_.String -match "Bootcamp" } | ForEach-Object {
    # Search dist files to find supported models, using regex match to find models in dist files - stole regex from brigadier's source
    $modelRegex = "([a-zA-Z]{4,12}[1-9]{1,2}\,[1-6])"
    $distURL = ($_.dict | Where-Object { $_.Key -match "English" }).String
    $distXML = (Invoke-RestMethod -Uri $distURL).InnerXml
    $SupportedModels = [regex]::Matches($distXML,$modelRegex).Value
    if ($SupportedModels -contains $Model) {
        $_ | Add-Member -NotePropertyName Version -NotePropertyValue ([regex]::Match($distURL,"(\d{3}-\d{4,5})").Value)
        Write-Output "Found supported ESD: $($_.Version), posted $($_.Date)"
        $bootcamplist += $_
    }
}

if ($ProductId) {
    Write-Host "ProductID specified, filtering Boot Camp ESD selection to match."
    $bootcamplist = $bootcamplist | Where-Object {$_.Version -in $ProductId}
}

if ($bootcamplist.Length -gt 1) {
    Write-Host "Found more than 1 supported Bootcamp ESD. Selecting newest based on posted date which may not always be correct"
} elseif ($bootcamplist.length -eq 0) {
    Write-Warning "Couldn't find a Boot Camp ESD for the model $Model in the given software update catalog."
    exit 1
}

$esd = $bootcamplist | Sort-Object -Property Date | Select-Object -Last 1
# Build a hash table of the package's properties from the XML
$package = $esd.array.dict.selectnodes('key') | ForEach-Object {@{$($_.'#text') = $($_.nextsibling.'#text')}}
$package += @{'ESDVersion' = $($esd.Version)}
Write-Host "Selected $($package.ESDVersion) as it's the most recently posted."

$landingDir = Join-Path $OutputDir "BootCamp-$($package.ESDVersion)"
$workingDir = Join-Path $env:Temp "BootCamp-unpack-$($package.ESDVersion)"
$packagePath = Join-Path $workingDir 'BootCampESD.pkg'
$payloadPath = Join-Path $workingDir 'Payload~'
$dmgPath = Join-Path $workingDir 'WindowsSupport.dmg'

if (Test-Path -PathType Container $landingDir) {
    # Python just deletes the folder
    Write-Warning "Final destination folder $landingDir already exists, please remove it to redownload."
    exit 1
}
if (-not (Test-Path -PathType Container $workingDir)) {mkdir $workingDir > $null}

# Download the BootCamp ESD if required
if (-not (Test-Path -PathType Leaf $packagePath)) {
    Write-Host "Starting download from $($package.URL)"
    Start-BitsTransfer -Source $package.URL -Destination "$packagePath" -ErrorAction Stop
    Write-Host "Download complete"
} else {
    # Not sure what's used for the digest, but we can match size.
    if ((Get-Item $packagePath | Select-Object -ExpandProperty Length) -eq $package.Size) {
        Write-Host "$($package.ESDVersion) already exists at $packagePath, not redownloading."
    } else {
        Write-Warning "A file already exists at $packagePath but does not match $($package.URL), please remove it."
        exit 1
    }
}

# Extract the bootcamp installer
Write-Host "Extracting..."
& $7z -o"$workingDir" -y e "$packagePath"
& $7z -o"$workingDir" -y e "$payloadPath"
if (-not (Test-Path -PathType Container $landingDir)) {mkdir $landingDir > $null}
& $7z -o"$landingDir" -y x "$dmgPath"

# Uninstall 7zip if we installed it
if ($7zInstalled -ne $true) {
    Write-Host "Removing 7-Zip..."
    Start-Process -FilePath $env:SystemRoot\System32\msiexec.exe -ArgumentList "/x $7zDownload /qb- /norestart" -Wait
    Remove-Item $7zDownload
}

# Install Bootcamp and use MST if specified (I uploaded one that I had to use to fix the latest ESD on an iMac14,1)
if ($Install) {
    # Install Bootcamp
    $scaction = New-ScheduledTaskAction -Execute "msiexec.exe" -Argument "/i $landingDir\Bootcamp\Drivers\Apple\BootCamp.msi /qn /norestart"
    $sctrigger = New-ScheduledTaskTrigger -At ((Get-Date).AddSeconds(15)) -Once
    $scprincipal = New-ScheduledTaskPrincipal "SYSTEM" -RunLevel Highest
    $scsettings = New-ScheduledTaskSettingsSet
    $sctask = New-ScheduledTask -Action $scaction -Principal $scprincipal -Trigger $sctrigger -Settings $scsettings
    Register-ScheduledTask "Install Bootcamp" -InputObject $sctask -User "SYSTEM"
    do { Write-Output "Sleeping 20 seconds"; Start-Sleep -Seconds 20 } while (Get-Process -Name "msiexec" -ErrorAction SilentlyContinue)
    if (-not $KeepFiles) { Remove-Item -Path "$landingDir" -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Cleaning up working directory..."
Remove-Item -Path $workingDir -Recurse
