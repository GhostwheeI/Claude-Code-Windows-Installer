# Claude Code Windows Installer (PowerShell)

A single PowerShell script that installs the Claude Code CLI on a fresh 64-bit Windows 10/11 machine. It installs Node.js LTS if missing, installs the Claude CLI globally with npm, and ensures the `claude` command is available in new PowerShell sessions.

## Features

- Detects an existing Node.js installation (requires Node >= 18).
- Downloads and installs Node.js LTS from nodejs.org if needed.
- Installs `@anthropic-ai/claude-code` globally with npm.
- Adds `%APPDATA%\npm` to the user PATH so `claude` resolves.

## Requirements

- Windows 10 or 11 (64-bit)
- Admin PowerShell session
- Internet access to:
  - https://nodejs.org
  - https://registry.npmjs.org

## Quick Start

1. Save the script as `install-claude-code.ps1`.
2. Open **PowerShell as Administrator**.
3. Run:

```powershell
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\install-claude-code.ps1"
```

4. Open a new PowerShell window and run:

```powershell
claude --version
```

If prompted by the CLI, complete login or set your API key.

## What the Script Does

1. Verifies the OS is 64-bit.
2. Ensures TLS 1.2 for downloads.
3. Checks for Node.js >= 18:
   - If missing, it fetches the latest LTS MSI from `nodejs.org` and installs it silently.
4. Verifies `npm` is available.
5. Adds `%APPDATA%\npm` to the **user** PATH (if not already present).
6. Runs `npm install -g @anthropic-ai/claude-code`.
7. Confirms that the `claude` command is available.

## Notes

- The Node.js installer places binaries in `C:\Program Files\nodejs`.
- The `claude` command is installed into `%APPDATA%\npm`.
- PATH changes apply to **new** shells. If `claude` is not found, open a new PowerShell.
- Some npm messages are printed to stderr even on success; the script accounts for that.

## Troubleshooting

### `npm is not available on PATH`
- Close and reopen PowerShell to reload PATH.
- Verify Node is installed: `node -v`.

### `Claude command not found on PATH`
- Make sure `%APPDATA%\npm` is on your user PATH.
- Open a new PowerShell session and try again.

### Download or install failures
- Verify you can reach `https://nodejs.org` and `https://registry.npmjs.org`.
- Check if a proxy or antivirus is blocking downloads.
- Re-run the script from an elevated PowerShell.

## Uninstall

To remove Claude Code:

```powershell
npm uninstall -g @anthropic-ai/claude-code
```

To remove Node.js:
- Open **Apps & Features** and uninstall **Node.js**.

To remove PATH entry (optional):
- Remove `%APPDATA%\npm` from your user PATH.

## Security Considerations

- The script downloads Node.js from the official site and installs it silently.
- The CLI is fetched from the public npm registry.
- Review the script before running in restricted environments.

## License

Specify your license here (MIT/Apache-2.0/etc.).

---

**Script:** `install-claude-code.ps1`
