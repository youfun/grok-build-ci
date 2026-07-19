# Install or update grok CLI from youfun/grok-build-ci GitHub Releases.
#
# Usage (PowerShell):
#   irm https://raw.githubusercontent.com/youfun/grok-build-ci/main/install.ps1 | iex
#   .\install.ps1
#   .\install.ps1 -InstallDir "$env:LOCALAPPDATA\grok\bin"
#   .\install.ps1 -Tag latest
#
# Env:
#   GROK_CI_REPO       release repo (default: youfun/grok-build-ci)
#   GROK_INSTALL_DIR   install directory
#   GROK_RELEASE_TAG   release tag (default: latest)

[CmdletBinding()]
param(
    [string]$InstallDir = $(if ($env:GROK_INSTALL_DIR) { $env:GROK_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "grok\bin" }),
    [string]$Repo = $(if ($env:GROK_CI_REPO) { $env:GROK_CI_REPO } else { "youfun/grok-build-ci" }),
    [string]$Tag = $(if ($env:GROK_RELEASE_TAG) { $env:GROK_RELEASE_TAG } else { "latest" })
)

$ErrorActionPreference = "Stop"

function Test-IsArm64 {
    try {
        if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -eq "Arm64") {
            return $true
        }
    } catch {}
    if ($env:PROCESSOR_ARCHITECTURE -match "ARM64") { return $true }
    return $false
}

if (Test-IsArm64) {
    Write-Warning "Windows ARM64 is not published yet; trying x86_64 binary (may need emulation)."
}

$Asset = "grok-windows-x86_64.exe"
$BinName = "grok.exe"
$Url = "https://github.com/$Repo/releases/download/$Tag/$Asset"
$Dest = Join-Path $InstallDir $BinName

Write-Host "Installing grok"
Write-Host "  source : $Repo@$Tag"
Write-Host "  asset  : $Asset"
Write-Host "  dest   : $Dest"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("grok-install-" + [guid]::NewGuid().ToString() + ".exe")
try {
    Write-Host "Downloading $Url"
    # TLS 1.2+
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    } catch {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing

    if (-not (Test-Path $tmp) -or ((Get-Item $tmp).Length -lt 1024)) {
        throw "Download failed or file too small. Check release assets: https://github.com/$Repo/releases"
    }

    Copy-Item -Force -Path $tmp -Destination $Dest
} finally {
    if (Test-Path $tmp) { Remove-Item -Force $tmp }
}

# Add install dir to user PATH if missing
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
$parts = $userPath -split ";" | Where-Object { $_ -ne "" }
if ($parts -notcontains $InstallDir) {
    $newPath = if ($userPath.Trim().Length -eq 0) { $InstallDir } else { "$userPath;$InstallDir" }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$InstallDir;$env:Path"
    Write-Host "Added to user PATH: $InstallDir"
    Write-Host "Open a new terminal for PATH to apply everywhere."
} else {
    Write-Host "PATH already includes $InstallDir"
    if ($env:Path -notlike "*$InstallDir*") {
        $env:Path = "$InstallDir;$env:Path"
    }
}

try {
    $ver = & $Dest --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $ver) {
        Write-Host "Installed: $ver"
    } else {
        Write-Host "Installed binary to $Dest"
    }
} catch {
    Write-Host "Installed binary to $Dest"
}

Write-Host "Done. Run: grok --version"
