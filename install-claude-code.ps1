# ========================================
# Professional PowerShell Script: Claude Code Windows Installer
# Color-coded for operator clarity
# ========================================

#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Native", "WinGet", "NPM")]
    [string]$Method,

    [Parameter()]
    [switch]$Interactive,

    [Parameter()]
    [string]$TargetVersion = "latest",

    [Parameter()]
    [string]$DownloadBaseUrl = "https://downloads.claude.ai/claude-code-releases",

    [Parameter()]
    [string]$WinGetPackageId = "Anthropic.ClaudeCode",

    [Parameter()]
    [string]$NpmPackageName = "@anthropic-ai/claude-code",

    [Parameter()]
    [string]$BinaryName = "claude.exe",

    [Parameter()]
    [string]$PlatformOverride = $null,

    [Parameter()]
    [string[]]$InstallerArgs = @("install")
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info([string]$Message) {
    Write-Host "[INFO] [claude-install] $Message" -ForegroundColor White
}

function Write-Success([string]$Message) {
    Write-Host "[SUCCESS] [claude-install] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "[WARN] [claude-install] $Message" -ForegroundColor Yellow
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $combined = @($machinePath, $userPath) -join ';'
    $env:Path = [Environment]::ExpandEnvironmentVariables($combined)
}

function Get-NodeVersion {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) { return $null }
    try {
        $raw = (& node -v)
        if ($raw -match 'v?(\d+\.\d+\.\d+)') {
            return [version]$Matches[1]
        }
        return $null
    } catch {
        return $null
    }
}

function Check-GitDependency {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Warn "Git is not detected on your PATH."
        Write-Warn "Git for Windows is highly recommended for Claude Code's workspace features."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $response = Read-Host "Would you like to install Git via winget now? (Y/N)"
            if ($response -match '^[yY]') {
                Write-Info "Installing Git via winget..."
                Start-Process winget -ArgumentList "install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements" -Wait
                Refresh-Path
                if (Get-Command git -ErrorAction SilentlyContinue) {
                    Write-Success "Git installed successfully."
                } else {
                    Write-Warn "Git installed but not yet available in this session. You may need to restart PowerShell."
                }
            }
        } else {
            Write-Warn "Please install Git manually from https://git-scm.com/"
        }
    }
}

function Install-Native {
    Write-Info "Starting native binary installation..."
    if (-not [Environment]::Is64BitProcess) {
        throw "Claude Code does not support 32-bit Windows. Please use a 64-bit version of Windows."
    }

    $DOWNLOAD_DIR = Join-Path $env:USERPROFILE ".claude\downloads"
    
    # Resolve platform (respect override if specified)
    if (-not [string]::IsNullOrEmpty($PlatformOverride)) {
        $platform = $PlatformOverride
    } elseif ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        $platform = "win32-arm64"
    } else {
        $platform = "win32-x64"
    }
    
    $null = New-Item -ItemType Directory -Force -Path $DOWNLOAD_DIR
    
    Write-Info "Fetching version metadata from $DownloadBaseUrl/$TargetVersion..."
    try {
        $version = Invoke-RestMethod -Uri "$DownloadBaseUrl/$TargetVersion" -ErrorAction Stop
        if ($version -match '"version":\s*"([^"]+)"') {
            $version = $Matches[1]
        }
        $version = $version.Trim()
    } catch {
        throw "Failed to retrieve version information: $_"
    }
    
    if ($version -notmatch '^\d+\.\d+\.\d+') {
        throw "Failed to get a valid version from downloads endpoint (got: $version)."
    }
    
    Write-Info "Version to install: $version"
    
    try {
        $manifest = Invoke-RestMethod -Uri "$DownloadBaseUrl/$version/manifest.json" -ErrorAction Stop
        $checksum = $manifest.platforms.$platform.checksum
        if (-not $checksum) {
            throw "Platform $platform not found in manifest"
        }
    } catch {
        throw "Failed to retrieve manifest: $_"
    }
    
    $binaryPath = Join-Path $DOWNLOAD_DIR "claude-$version-$platform.exe"
    $downloadUrl = "$DownloadBaseUrl/$version/$platform/$BinaryName"
    Write-Info "Downloading installer binary from $downloadUrl"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $binaryPath -ErrorAction Stop
    } catch {
        if (Test-Path $binaryPath) { Remove-Item -Force $binaryPath }
        throw "Failed to download binary: $_"
    }
    
    Write-Info "Verifying checksum..."
    $actualChecksum = (Get-FileHash -Path $binaryPath -Algorithm SHA256).Hash.ToLower()
    if ($actualChecksum -ne $checksum.ToLower()) {
        Remove-Item -Force $binaryPath
        throw "Checksum verification failed (Expected: $checksum, Got: $actualChecksum)"
    }
    
    # Build arguments dynamically
    $runArgs = @()
    foreach ($arg in $InstallerArgs) {
        $runArgs += $arg
    }
    if ($TargetVersion -and $TargetVersion -ne "latest" -and $InstallerArgs -contains "install" -and $InstallerArgs.Count -eq 1) {
        $runArgs += $TargetVersion
    }
    
    Write-Info "Running native Claude Code setup: $BinaryName $($runArgs -join ' ')..."
    try {
        & $binaryPath $runArgs
        $installExit = $LASTEXITCODE
    } finally {
        Start-Sleep -Seconds 1
        if (Test-Path $binaryPath) {
            Remove-Item -Force $binaryPath -ErrorAction SilentlyContinue
        }
    }
    
    if ($installExit -ne 0) {
        throw "Installation failed with exit code $installExit."
    }
    Write-Success "Native installer completed."
}

function Install-WinGet {
    Write-Info "Starting WinGet installation..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget command not found. Please install Windows Package Manager or choose another method."
    }
    
    Write-Info "Running winget install $WinGetPackageId..."
    Start-Process winget -ArgumentList "install --id $WinGetPackageId -e --accept-source-agreements --accept-package-agreements" -NoNewWindow -Wait
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "winget installation failed with exit code $exitCode."
    }
    Write-Success "WinGet installation completed."
}

function Install-NPM {
    Write-Info "Starting Node.js & NPM installation flow..."
    
    $nodeVersion = Get-NodeVersion
    $needsNode = $true
    if ($nodeVersion -and $nodeVersion.Major -ge 18) {
        Write-Info "Node.js $nodeVersion detected."
        $needsNode = $false
    }
    
    if ($needsNode) {
        Write-Info "Installing Node.js LTS..."
        $index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -Method Get
        $lts = $index | Where-Object { $_.lts -ne $false } | Select-Object -First 1
        if (-not $lts) {
            throw "Failed to locate Node.js LTS build."
        }
        $ver = $lts.version
        $msiUrl = "https://nodejs.org/dist/$ver/node-$ver-x64.msi"
        $msiPath = Join-Path $env:TEMP "node-$ver-x64.msi"
        
        Write-Info "Downloading Node.js LTS installer ($ver)..."
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath
        
        Write-Info "Running Node.js silent installer..."
        $proc = Start-Process msiexec.exe -Wait -ArgumentList @('/i', "`"$msiPath`"", '/qn', '/norestart') -PassThru
        if ($proc.ExitCode -ne 0) {
            throw "Node.js MSI installer exited with code $($proc.ExitCode)"
        }
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        
        Refresh-Path
        $nodeVersion = Get-NodeVersion
        if (-not $nodeVersion) {
            throw "Node.js did not install correctly or is not available on PATH."
        }
        Write-Success "Node.js $nodeVersion installed successfully."
    }
    
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Refresh-Path
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "npm is not available on PATH."
    }
    
    $npmUserBin = Join-Path $env:APPDATA 'npm'
    $prefix = & npm config get prefix -g 2>$null
    if ($prefix) {
        $npmUserBin = $prefix.Trim()
    }
    
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike "*$npmUserBin*") {
        $newUserPath = if ($userPath) { "$userPath;$npmUserBin" } else { $npmUserBin }
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Info "Added $npmUserBin to user PATH."
    }
    
    Refresh-Path
    
    Write-Info "Installing $NpmPackageName globally via npm..."
    $oldNativePref = $null
    if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
        $oldNativePref = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }
    & npm install -g $NpmPackageName
    $npmExit = $LASTEXITCODE
    if ($oldNativePref -ne $null) {
        $PSNativeCommandUseErrorActionPreference = $oldNativePref
    }
    if ($npmExit -ne 0) {
        throw "npm install failed with exit code $npmExit."
    }
    
    Write-Success "NPM installation completed."
}

# Main script logic starts here
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    Write-Warn "Could not set TLS 1.2, continuing with system defaults."
}

# Show interactive menu if selected or if no method specified
if ($Interactive -or ([string]::IsNullOrEmpty($Method) -and -not $MyInvocation.BoundParameters.ContainsKey('Method'))) {
    Write-Host "`n=== Claude Code Windows Installer ===" -ForegroundColor Cyan
    Write-Host "Select an installation method:" -ForegroundColor Gray
    Write-Host "1) Native Binary (Recommended, self-contained, no Node.js required)" -ForegroundColor White
    Write-Host "2) WinGet (Windows Package Manager)" -ForegroundColor White
    Write-Host "3) NPM (Requires Node.js >= 18)" -ForegroundColor White
    Write-Host "Q) Quit" -ForegroundColor Red
    
    do {
        $choice = Read-Host "Enter your choice (1-3 or Q)"
    } while ($choice -notmatch '^[123qQ]$')
    
    if ($choice -match '^[qQ]$') {
        Write-Info "Installation cancelled."
        exit 0
    }
    
    switch ($choice) {
        "1" { $Method = "Native" }
        "2" { $Method = "WinGet" }
        "3" { $Method = "NPM" }
    }
}

Write-Info "Executing installation via method: $Method"

# Ensure Git is installed for a better user experience
Check-GitDependency

# Run selected installation method
switch ($Method) {
    "Native" { Install-Native }
    "WinGet" { Install-WinGet }
    "NPM"    { Install-NPM }
}

# Final path refresh
Refresh-Path

# Run verification / post-install doctor check
if (Get-Command claude -ErrorAction SilentlyContinue) {
    $claudeVersion = & claude --version 2>$null
    Write-Success "Claude Code is successfully installed on PATH!"
    if ($claudeVersion) {
        Write-Info "Detected Version: $claudeVersion"
    }
    
    Write-Info "Running health check (claude doctor)..."
    & claude doctor
} else {
    Write-Warn "Claude command was not immediately found on PATH. Please open a new PowerShell session and run 'claude doctor' to verify."
}
