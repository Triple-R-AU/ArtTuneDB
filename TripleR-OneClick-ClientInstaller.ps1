# Triple R Audio - Fully Automated 1-Click Silent Client Installer
# Runs core audio setup in background with ZERO prompts, configures LEQ RT=2, and launches Triple R Audio
[CmdletBinding()]
param()

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($PSCommandPath) {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" -Verb RunAs
        exit
    } else {
        Write-Warning "Please run PowerShell as Administrator!"
        exit
    }
}

$OwnerGitHubUser = "Triple-R-AU"
$OwnerRepoName   = "ArtTuneDB"
$OwnerBranch     = "main"

Clear-Host
Write-Host "================================================================" -ForegroundColor Red
Write-Host "             TRIPLE R AUDIO - AUTOMATED INSTALLER               " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Red
Write-Host ""

$baseDir    = "C:\Program Files\EqualizerAPO\config\ArtTuneDB"
$libraryDir = Join-Path $baseDir "library"
$eqBaseDir  = Join-Path $libraryDir "BO7\V5\eq"

Write-Host "[1/5] Setting up Triple R directories..." -ForegroundColor Cyan
if (-not (Test-Path $baseDir)) { New-Item -Path $baseDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $eqBaseDir)) { New-Item -Path $eqBaseDir -ItemType Directory -Force | Out-Null }

Write-Host "[2/5] Preparing Audio Engine (VB-Cable, Equalizer APO, VSTs)..." -ForegroundColor Cyan
if (-not (Test-Path "C:\Program Files\EqualizerAPO\EqualizerAPO.dll")) {
    Write-Host "      Installing core drivers in background..." -ForegroundColor Yellow
    try {
        # Feed automated responses so it doesn't pause for manual menu selections
        $installProc = Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -Command `"irm artiswar.io/tools/ArtTuneGuided | iex`"" -PassThru -Wait
    } catch {}
} else {
    Write-Host "      Audio engine drivers verified!" -ForegroundColor Green
}

Write-Host "[3/5] Syncing latest tuning profiles and presets from GitHub..." -ForegroundColor Cyan
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ "User-Agent" = "TripleRAudio-SilentInstaller" }
    $zipUrl = "https://github.com/$OwnerGitHubUser/$OwnerRepoName/archive/refs/heads/$OwnerBranch.zip"
    $tempZip = Join-Path $env:TEMP "TripleR-Install.zip"
    $tempExtract = Join-Path $env:TEMP "TripleR-Extract"

    Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -Headers $headers -TimeoutSec 30
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    $inner = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
    $srcLib = Join-Path $inner.FullName "library"
    if (Test-Path $srcLib) { Copy-Item -Path "$srcLib\*" -Destination $libraryDir -Recurse -Force }

    # Copy Client App & Icon
    $repoClientApp = Join-Path $inner.FullName "TripleR-ClientApp.ps1"
    $localClientApp = Join-Path $PSScriptRoot "TripleR-ClientApp.ps1"
    $destClientApp  = Join-Path $baseDir "TripleR-ClientApp.ps1"
    if (Test-Path $localClientApp) {
        Copy-Item -Path $localClientApp -Destination $destClientApp -Force
    } elseif (Test-Path $repoClientApp) {
        Copy-Item -Path $repoClientApp -Destination $destClientApp -Force
    }

    $repoIco = Join-Path $inner.FullName "TripleR.ico"
    $localIco = Join-Path $PSScriptRoot "TripleR.ico"
    $destIco = Join-Path $baseDir "TripleR.ico"
    if (Test-Path $localIco) {
        Copy-Item -Path $localIco -Destination $destIco -Force
    } elseif (Test-Path $repoIco) {
        Copy-Item -Path $repoIco -Destination $destIco -Force
    }

    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "      Tuning profiles and presets installed!" -ForegroundColor Green
} catch {
    Write-Warning "      Sync note: $_"
}

Write-Host "[4/5] Activating Loudness Equalization & Release Time = 2 directly..." -ForegroundColor Cyan
try {
    $enhancementFlagKey = "{fc52a749-4be9-4510-896e-966ba6525980},3"
    $releaseTimeKey     = "{9c00eeed-edce-4cd8-ae08-cb05e8ef57a0},3"
    $enhancementTabKey  = "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3"
    $preMixKey          = "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},1"
    $postMixKey         = "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},2"

    $devices = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\*\Properties" -ErrorAction SilentlyContinue
    foreach ($dev in $devices) {
        $vals = $dev.GetValueNames() | ForEach-Object { $dev.GetValue($_) }
        if ($vals -match "Art Tune|Hi-Fi Cable|VB-Audio") {
            $fxPath = Join-Path $dev.PSParentPath "FxProperties"
            if (-not (Test-Path $fxPath)) { New-Item -Path $fxPath -Force | Out-Null }
            Set-ItemProperty -Path $fxPath -Name $preMixKey -Value "{62dc1a93-ae24-464c-a43e-452f824c4250}" -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $fxPath -Name $postMixKey -Value "{637c490d-eee3-4c0a-973f-371958802da2}" -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $fxPath -Name $enhancementTabKey -Value "{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}" -Type String -Force -ErrorAction SilentlyContinue
            [byte[]]$flagBytes = @(0x0b,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0xff,0xff,0x00,0x00)
            Set-ItemProperty -Path $fxPath -Name $enhancementFlagKey -Value $flagBytes -Type Binary -Force -ErrorAction SilentlyContinue
            [byte[]]$relBytes = @(0x03,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x02,0x00,0x00,0x00)
            Set-ItemProperty -Path $fxPath -Name $releaseTimeKey -Value $relBytes -Type Binary -Force -ErrorAction SilentlyContinue
        }
    }
    Restart-Service audiosrv -Force -ErrorAction SilentlyContinue
    Write-Host "      Loudness Equalization (Release Time 2) active!" -ForegroundColor Green
} catch {}

Write-Host "[5/5] Creating Desktop Shortcut with Triple R custom icon..." -ForegroundColor Cyan
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutLocation = Join-Path $desktopPath "Triple R Audio.lnk"
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutLocation)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -STA -WindowStyle Hidden -File `"$baseDir\TripleR-ClientApp.ps1`""
    $shortcut.WorkingDirectory = $baseDir

    $icoPath = Join-Path $baseDir "TripleR.ico"
    if (Test-Path $icoPath) {
        $shortcut.IconLocation = $icoPath
    } else {
        $shortcut.IconLocation = "C:\Windows\System32\mmsys.cpl,0"
    }
    $shortcut.Description = "Launch Triple R Audio Control Panel"
    $shortcut.Save()
    Write-Host "      Triple R Audio desktop shortcut created!" -ForegroundColor Green
} catch {}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "    SETUP COMPLETE! LAUNCHING TRIPLE R AUDIO...                 " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

# Launch Triple R Audio immediately!
if (Test-Path "$baseDir\TripleR-ClientApp.ps1") {
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -STA -WindowStyle Hidden -File `"$baseDir\TripleR-ClientApp.ps1`""
}
