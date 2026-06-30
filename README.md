<div align="center">

# Claude Code Windows Installer (PowerShell)
First and Final v1.0

### A professional and robust PowerShell script to install the Claude Code CLI on 64-bit Windows 10/11 machines. It offers multiple installation methods—Native self-contained binary, WinGet, and NPM—and ensures the environment PATH variables are correctly updated.

![version](https://img.shields.io/badge/version-1.0.0-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![platform](https://img.shields.io/badge/platform-Claude-black)
![surface](https://img.shields.io/badge/install-file--based%20(no%20runtime)-lightgrey)

</div>

---

## Features

- **Multiple Installation Modes:**
  - **Native (Recommended):** Downloads and sets up the official self-contained `claude.exe` binary directly from Anthropic's release APIs (no Node.js/NPM required).
  - **WinGet:** Automatically detects and installs Claude Code using the Windows Package Manager (`winget`).
  - **NPM:** Downloads/installs Node.js LTS silently if missing, and installs `@anthropic-ai/claude-code` globally via NPM.
- **Git Dependency Guard:** Scans for Git for Windows (crucial for Claude Code workspace features) and offers to install it dynamically via `winget` if missing.
- **Smart Path Refresh:** Reloads and expands registry PATH variables on the fly without breaking unexpanded system variables (e.g. `%SystemRoot%`).
- **Post-Install Verification:** Automatically runs `claude doctor` to verify CLI health post-installation.
- **Fully Customizable/Future-Proof:** Every aspect of the installation (registry URLs, package IDs, binary names, package scopes, installer arguments) can be overridden at runtime via script parameters.

## Requirements

- Windows 10 or 11 (64-bit)
- PowerShell RunAs Administrator session
- Internet access to download assets

## Quick Start

1. Save the script as `install-claude-code.ps1`.
2. Open **PowerShell as Administrator**.
3. Run the installer in your preferred mode:

### 1. Interactive Menu (Prompted)
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\install-claude-code.ps1" -Interactive
```

### 2. Native Binary Installation (Recommended)
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\install-claude-code.ps1" -Method Native
```

### 3. WinGet Installation
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\install-claude-code.ps1" -Method WinGet
```

### 4. NPM Installation (Classic Node.js flow)
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\install-claude-code.ps1" -Method NPM
```

## Advanced Command Parameters

This installer is completely dynamic and future-proof. You can override parameters without editing the script:

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Method` | String | (Menu / Prompt) | Choice of `Native`, `WinGet`, or `NPM`. |
| `-Interactive` | Switch | `$false` | Explicitly prompt with the interactive installation menu. |
| `-TargetVersion` | String | `latest` | Target version to fetch from the release API. |
| `-DownloadBaseUrl` | String | `https://downloads.claude.ai/claude-code-releases` | Base endpoint URL for official native binaries. |
| `-WinGetPackageId` | String | `Anthropic.ClaudeCode` | Package ID for WinGet installation. |
| `-NpmPackageName` | String | `@anthropic-ai/claude-code` | Package name on NPM registry. |
| `-BinaryName` | String | `claude.exe` | Target executable binary name. |
| `-PlatformOverride` | String | `$null` | Manually specify target platform (e.g., `win32-x64` or `win32-arm64`). |
| `-InstallerArgs` | String[] | `@("install")` | Arguments passed to the native binary installer. |

*Example of a completely custom future installation:*
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\install-claude-code.ps1" -Method Native -DownloadBaseUrl "https://custom.mirror.ai/releases" -BinaryName "claude-new.exe"
```

## What the Script Does

1. **Environment & Security:** Ensures PowerShell runs with Administrative rights and enables TLS 1.2 protocols.
2. **Git Check:** Checks if Git is installed. If missing, it asks if it should install Git automatically via `winget`.
3. **Execution:**
   - **Native:** Pulls the manifest and target version, downloads the executable, verifies its SHA256 checksum, executes it, and cleans up temporary downloads.
   - **WinGet:** Runs silent package installation via winget CLI.
   - **NPM:** Checks Node.js version (requiring >= 18). If missing, fetches and silently installs the Node.js LTS MSI package, registers global npm paths, and executes global package setup.
4. **Validation:** Refreshes PATH settings in the current environment and calls `claude doctor` to confirm.

## Troubleshooting

- **Path issues:** If the `claude` command is not found immediately after installation, close and reopen your PowerShell session.
- **Git error:** If Claude Code complaints about git, run `git --version` to ensure it is configured on your system PATH.

## License

This project is licensed under the MIT License.
