#                  AxonASP Caddy Module Build Script
#
# AxonASP Server - Caddy Module
# Copyright (C) 2026 G3pix Ltda. All rights reserved.
#
# Developed by Lucas Guimarães - G3pix Ltda
# Contact: https://g3pix.com.br
# Project URL: https://g3pix.com.br/axonasp
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Attribution Notice:
# If this software is used in other projects, the name "AxonASP Server"
# must be cited in the documentation or "About" section.
#
# Contribution Policy:
# Modifications to the core source code of AxonASP Server must be
# made available under this same license terms.
#

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("windows", "linux", "darwin", "all")]
    [string]$Platform = "windows",

    [Parameter(Mandatory = $false)]
    [ValidateSet("amd64", "arm64", "386", "all")]
    [string]$Architecture = "amd64",

    [Parameter(Mandatory = $false)]
    [switch]$Clean,

    [Parameter(Mandatory = $false)]
    [switch]$Test,

    [Parameter(Mandatory = $false)]
    [string]$Tags = ""
)

# --- AUTOMATIC VERSION CONFIGURATION ---
$Major = "2"
$Minor = "3"
$Patch = "0"
$Revision = "0"

try {
    $GitTag = git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -eq 0 -and $GitTag -match '^v?(\d+)\.(\d+)\.(\d+)$') {
        $Major = $matches[1]
        $Minor = $matches[2]
        $Patch = $matches[3]
    }
    else {
        $GitCount = git rev-list --count HEAD 2>$null
        if ($LASTEXITCODE -eq 0) { $Patch = $GitCount.Trim() }
    }

    $GitHash = git rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0) { $Revision = $GitHash.Trim() }
}
catch {
    Write-Warning "Git not found or not a valid repository. Using default versioning."
}

$FullVersion = "$Major.$Minor.$Patch.$Revision"

# Normalize Go build tags
$NormalizedTags = ($Tags -replace '[,;]+', ' ').Trim()

# Color output functions
function Write-Success { param([string]$Message); Write-Host $Message -ForegroundColor Green }
function Write-Info { param([string]$Message); Write-Host $Message -ForegroundColor Cyan }
function Write-Err { param([string]$Message); Write-Host $Message -ForegroundColor Red }
function Write-Warn { param([string]$Message); Write-Host $Message -ForegroundColor Yellow }

# Script header
Write-Host ""
Write-Host "=======================================================" -ForegroundColor Magenta
Write-Host "  G3Pix AxonASP Caddy Module Build Script" -ForegroundColor White
Write-Host "  Version: $FullVersion" -ForegroundColor Cyan
if ($NormalizedTags) {
    Write-Host "  Build Tags: $NormalizedTags" -ForegroundColor Yellow
}
Write-Host "=======================================================" -ForegroundColor Magenta
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$ParentDir = (Get-Item "..").FullName

# Clean previous builds
if ($Clean) {
    Write-Info "Cleaning previous builds..."
    Remove-Item -Path "caddy.exe" -ErrorAction SilentlyContinue
    Remove-Item -Path "caddy" -ErrorAction SilentlyContinue
    Remove-Item -Path "caddy-*" -ErrorAction SilentlyContinue
    Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "Cleaned."
    Write-Host ""
}

# Find or install xcaddy
$XcaddyCmd = Get-Command xcaddy -ErrorAction SilentlyContinue
$XcaddyExec = "xcaddy"

if (-not $XcaddyCmd) {
    $GoPath = & go env GOPATH 2>$null
    if ($GoPath) {
        $Candidate = Join-Path $GoPath "bin\xcaddy.exe"
        if (Test-Path $Candidate) {
            $XcaddyExec = $Candidate
            $XcaddyCmd = $true
        }
    }
}

if (-not $XcaddyCmd) {
    Write-Info "xcaddy not found. Installing xcaddy..."
    & go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to install xcaddy. Ensure Go is installed."
        exit 1
    }
    $GoPath = & go env GOPATH 2>$null
    if ($GoPath) {
        $Candidate = Join-Path $GoPath "bin\xcaddy.exe"
        if (Test-Path $Candidate) {
            $XcaddyExec = $Candidate
        }
    }
}

function Build-Binary {
    param(
        [string]$TargetOS,
        [string]$TargetArch,
        [string]$OutputName,
        [string]$Label
    )

    $env:GOOS = $TargetOS
    $env:GOARCH = $TargetArch
    $env:CGO_ENABLED = "0"

    $Extension = if ($TargetOS -eq "windows") { ".exe" } else { "" }
    $OutputFile = "${OutputName}${Extension}"

    $OutputDir = Split-Path -Parent $OutputFile
    if ($OutputDir -and -not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    }

    # xcaddy resolves the Caddy core and every transitive dependency. The only
    # override required here is the local checkout of the runtime module, since
    # replace directives of dependency modules are ignored by the Go toolchain.
    $BuildArgs = @(
        "build",
        "--output", $OutputFile,
        "--with", "g3pix.com.br/axonasp/caddy=.",
        "--replace", "g3pix.com.br/axonasp/v2=$ParentDir"
    )

    Write-Info "Building $Label ($TargetOS/$TargetArch) -> $OutputFile ..."

    $Output = & $XcaddyExec @BuildArgs 2>&1

    if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputFile)) {
        $Size = [math]::Round((Get-Item $OutputFile).Length / 1MB, 2)
        Write-Success "  [OK] $OutputFile ($Size MB)"

        # Populate root convenience binaries for standard targets
        if ($TargetOS -eq "windows" -and $TargetArch -eq "amd64" -and -not (Test-Path "caddy.exe")) {
            Copy-Item $OutputFile -Destination "caddy.exe" -Force -ErrorAction SilentlyContinue
        }
        if ($TargetOS -eq "linux" -and $TargetArch -eq "amd64") {
            Copy-Item $OutputFile -Destination "caddy-linux-amd64" -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path "caddy")) {
                Copy-Item $OutputFile -Destination "caddy" -Force -ErrorAction SilentlyContinue
            }
        }
        return $true
    }
    else {
        Write-Err "  [FAIL] $Label ($TargetOS/$TargetArch)"
        if ($Output) { Write-Host $Output }
        return $false
    }
}

$BuildSuccess = $true

# --- Fix, format and generate before any build pass ---
Write-Info "Fixing source..."
go fix ./... | Out-Null

Write-Info "Formatting source..."
gofmt -w . | Out-Null

Write-Info "Running go generate..."
go generate ./... | Out-Null
Write-Host ""

function Get-Architectures {
    param([string]$OS, [string]$ArchInput)

    if ($ArchInput -eq "all") {
        if ($OS -eq "darwin") {
            return @("amd64", "arm64")
        }
        return @("amd64", "arm64", "386")
    }
    return @($ArchInput)
}

function Run-Platform {
    param([string]$OS, [string]$ArchInput)

    $ArchList = Get-Architectures $OS $ArchInput

    foreach ($Arch in $ArchList) {
        if ($OS -eq "darwin" -and $Arch -eq "386") {
            Write-Warn "Skipping darwin/386 (unsupported by Go runtime)"
            continue
        }

        Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " Building Caddy for $OS/$Arch" -ForegroundColor Yellow
        Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray

        $outName = "build/$OS-$Arch/caddy"
        if ($OS -eq "windows" -and $Platform -eq "windows" -and $Arch -eq "amd64") {
            $outName = "caddy"
        }
        elseif ($OS -eq "linux" -and $Platform -eq "linux" -and $Arch -eq "amd64") {
            $outName = "caddy"
        }

        $ok = Build-Binary -TargetOS $OS -TargetArch $Arch -OutputName $outName -Label "AxonASP Caddy Server"
        $script:BuildSuccess = $script:BuildSuccess -and $ok
        Write-Host ""
    }
}

if ($Platform -eq "windows" -or $Platform -eq "all") { Run-Platform "windows" $Architecture }
if ($Platform -eq "linux" -or $Platform -eq "all") { Run-Platform "linux"   $Architecture }
if ($Platform -eq "darwin" -or $Platform -eq "all") { Run-Platform "darwin"  $Architecture }

# Clean up build environment variables
Remove-Item Env:\GOOS -ErrorAction SilentlyContinue
Remove-Item Env:\GOARCH -ErrorAction SilentlyContinue
Remove-Item Env:\CGO_ENABLED -ErrorAction SilentlyContinue

# --- Tests ---
if ($Test) {
    Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " Running Tests" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    Write-Info "Running go test ./..."
    $TestOutput = go test ./... 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Success "[OK] All tests passed"
    }
    else {
        Write-Err "[FAIL] Some tests failed"
        Write-Host $TestOutput
        $BuildSuccess = $false
    }
    Write-Host ""
}

# --- Summary ---
Write-Host "=======================================================" -ForegroundColor Magenta

if ($BuildSuccess) {
    Write-Success "  BUILD SUCCESSFUL  (v$FullVersion)"
    Write-Host ""
    Write-Host "  Executables:" -ForegroundColor White

    @("caddy.exe", "caddy", "caddy-linux-amd64") | ForEach-Object {
        if (Test-Path $_) { Write-Host "    - $_" -ForegroundColor Cyan }
    }

    if (Test-Path "build") {
        Get-ChildItem -Path "build" -Recurse -File | ForEach-Object {
            Write-Host "    - $($_.FullName.Replace($ScriptDir+'\',''))" -ForegroundColor Cyan
        }
    }

    Write-Host ""
    Write-Host "  Quick Start:" -ForegroundColor White
    Write-Host "    Run Server (Windows) : .\caddy.exe run --config .\Caddyfile" -ForegroundColor Gray
    Write-Host "    Run Server (Linux)   : ./caddy run --config ./Caddyfile" -ForegroundColor Gray
    Write-Host "    Run with launcher    : .\run_caddy.ps1" -ForegroundColor Gray
}
else {
    Write-Err "  BUILD FAILED!"
    Write-Host ""
    Write-Host "  Check the error messages above for details." -ForegroundColor Yellow
}

Write-Host "=======================================================" -ForegroundColor Magenta
Write-Host ""

exit $(if ($BuildSuccess) { 0 } else { 1 })
