<#
.SYNOPSIS
    AgentHelper - Manage Coding Agent CLI tools

.DESCRIPTION
    PowerShell script for managing Coding Agent CLI tools with install, update,
    version check, environment validation, and repair capabilities.

    Supports both native Windows tools and WSL-based tools.

.PARAMETER Status
    Show status of all tools (installed version, latest version, update status)

.PARAMETER Install
    Install specified tool(s). Use 'All' to install all tools.
    Valid values: All, ClaudeCode, CopilotCLI, OpenCode, Codex, Aider, CursorCLI, Cline, KiroCLI

.PARAMETER Update
    Update specified tool(s). Use 'All' to update all installed tools.
    Valid values: All, ClaudeCode, CopilotCLI, OpenCode, Codex, Aider, CursorCLI, Cline, KiroCLI

.PARAMETER Repair
    Repair specified tool (uninstall and reinstall)

.PARAMETER Environment
    Show environment report (PATH, env vars, prerequisites)

.PARAMETER UpdatePowerShell
    Update PowerShell to latest version via WinGet

.PARAMETER SetupWSL
    Setup WSL if not installed

.PARAMETER PreferredMethod
    Preferred installation method: WinGet, npm, pip, Native
    Default: WinGet

.PARAMETER Force
    Force operation without confirmation

.PARAMETER OutputFormat
    Output format: Table, Json, Object
    Default: Table

.EXAMPLE
    .\agenthelper.ps1
    Run in interactive mode

.EXAMPLE
    .\agenthelper.ps1 -Status
    Show status of all tools

.EXAMPLE
    .\agenthelper.ps1 -Status -OutputFormat Json
    Show status in JSON format

.EXAMPLE
    .\agenthelper.ps1 -Install ClaudeCode
    Install Claude Code

.EXAMPLE
    .\agenthelper.ps1 -Install All -PreferredMethod WinGet
    Install all tools using WinGet where available

.EXAMPLE
    .\agenthelper.ps1 -Update All
    Update all installed tools

.NOTES
    Version: 1.0.0
    Author: AgentHelper
    Requires: PowerShell 5.1 or later
#>

[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateSet('All', 'ClaudeCode', 'CopilotCLI', 'OpenCode', 'Codex', 'Aider', 'CursorCLI', 'Cline', 'KiroCLI', 'VSCode', 'VSCodeInsiders')]
    [string]$Install,

    [Parameter(ParameterSetName = 'Update')]
    [ValidateSet('All', 'ClaudeCode', 'CopilotCLI', 'OpenCode', 'Codex', 'Aider', 'CursorCLI', 'Cline', 'KiroCLI', 'VSCode', 'VSCodeInsiders')]
    [string]$Update,

    [Parameter(ParameterSetName = 'Repair')]
    [ValidateSet('ClaudeCode', 'CopilotCLI', 'OpenCode', 'Codex', 'Aider', 'CursorCLI', 'Cline', 'KiroCLI', 'VSCode', 'VSCodeInsiders')]
    [string]$Repair,

    [Parameter(ParameterSetName = 'Environment')]
    [switch]$Environment,

    [Parameter(ParameterSetName = 'UpdatePowerShell')]
    [switch]$UpdatePowerShell,

    [Parameter(ParameterSetName = 'SetupWSL')]
    [switch]$SetupWSL,

    [Parameter()]
    [ValidateSet('WinGet', 'npm', 'pip', 'Native')]
    [string]$PreferredMethod = 'WinGet',

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [ValidateSet('Table', 'Json', 'Object')]
    [string]$OutputFormat = 'Table'
)

#region Script Variables

$script:Version = "1.1.0"
$script:LogFile = Join-Path $env:TEMP "agenthelper.log"

#endregion

#region Tool Definitions

$script:ToolDefinitions = @{
    ClaudeCode = @{
        Name = "Claude Code"
        Command = "claude"
        VersionCmd = "claude --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = "claude update"
        RequiresWSL = $false
        VersionSource = @{
            Type = "npm"
            Package = "@anthropic-ai/claude-code"
        }
        InstallMethods = @{
            WinGet = "winget install Anthropic.ClaudeCode --accept-package-agreements --accept-source-agreements"
            Native = 'irm https://claude.ai/install.ps1 | iex'
            npm = "npm install -g @anthropic-ai/claude-code"
        }
        UninstallMethods = @{
            WinGet = "winget uninstall Anthropic.ClaudeCode"
            npm = "npm uninstall -g @anthropic-ai/claude-code"
        }
        EnvVars = @("ANTHROPIC_API_KEY")
    }
    CopilotCLI = @{
        Name = "GitHub Copilot CLI"
        Command = "copilot"
        VersionCmd = "copilot --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = "winget upgrade GitHub.Copilot --accept-package-agreements --accept-source-agreements"
        RequiresWSL = $false
        VersionSource = @{
            Type = "winget"
            PackageId = "GitHub.Copilot"
        }
        InstallMethods = @{
            WinGet = "winget install GitHub.Copilot --accept-package-agreements --accept-source-agreements"
        }
        UninstallMethods = @{
            WinGet = "winget uninstall GitHub.Copilot"
        }
        EnvVars = @("GH_TOKEN", "GITHUB_TOKEN")
    }
    OpenCode = @{
        Name = "OpenCode"
        Command = "opencode"
        VersionCmd = "opencode --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = "winget upgrade SST.opencode --accept-package-agreements --accept-source-agreements"
        RequiresWSL = $false
        VersionSource = @{
            Type = "github"
            Owner = "sst"
            Repo = "opencode"
        }
        InstallMethods = @{
            WinGet = "winget install SST.opencode --accept-package-agreements --accept-source-agreements"
            Scoop = "scoop install opencode"
        }
        UninstallMethods = @{
            WinGet = "winget uninstall SST.opencode"
            Scoop = "scoop uninstall opencode"
        }
        EnvVars = @("ANTHROPIC_API_KEY", "OPENAI_API_KEY")
    }
    Codex = @{
        Name = "OpenAI Codex CLI"
        Command = "codex"
        VersionCmd = "codex --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = "npm install -g @openai/codex@latest"
        RequiresWSL = $false
        VersionSource = @{
            Type = "npm"
            Package = "@openai/codex"
        }
        InstallMethods = @{
            npm = "npm install -g @openai/codex"
        }
        UninstallMethods = @{
            npm = "npm uninstall -g @openai/codex"
        }
        EnvVars = @("OPENAI_API_KEY")
    }
    Aider = @{
        Name = "Aider"
        Command = "aider"
        VersionCmd = "aider --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = "pip install -U aider-chat"
        AltUpdateCmd = "aider --upgrade"
        RequiresWSL = $false
        VersionSource = @{
            Type = "pypi"
            Package = "aider-chat"
        }
        InstallMethods = @{
            pip = "pip install aider-chat"
            Native = 'powershell -c "irm https://aider.chat/install.ps1 | iex"'
        }
        UninstallMethods = @{
            pip = "pip uninstall -y aider-chat"
        }
        EnvVars = @("OPENAI_API_KEY", "ANTHROPIC_API_KEY")
    }
    CursorCLI = @{
        Name = "Cursor CLI"
        Command = "cursor-agent"
        VersionCmd = "cursor-agent --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        RequiresWSL = $true
        VersionSource = @{
            Type = "unknown"
        }
        InstallMethods = @{
            WSL = 'wsl -e bash -c "curl -fsSL https://cursor.com/install | bash"'
        }
        UninstallMethods = @{
            WSL = 'wsl -e bash -c "rm -f ~/.local/bin/cursor-agent"'
        }
    }
    Cline = @{
        Name = "Cline"
        Command = "cline"
        VersionCmd = "cline --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = 'wsl -e bash -c "npm install -g cline@latest"'
        RequiresWSL = $true
        VersionSource = @{
            Type = "npm"
            Package = "cline"
        }
        InstallMethods = @{
            WSL = 'wsl -e bash -c "npm install -g cline"'
        }
        UninstallMethods = @{
            WSL = 'wsl -e bash -c "npm uninstall -g cline"'
        }
    }
    KiroCLI = @{
        Name = "Kiro CLI (Amazon Q)"
        Command = "q"
        VersionCmd = "q --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = 'wsl -e bash -c "q update"'
        RequiresWSL = $true
        VersionSource = @{
            Type = "unknown"
        }
        InstallMethods = @{
            WSL = 'wsl -e bash -c "curl -sSL https://raw.githubusercontent.com/aws/amazon-q-developer-cli/main/install.sh | bash"'
        }
        UninstallMethods = @{
            WSL = 'wsl -e bash -c "q uninstall"'
        }
        EnvVars = @("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY")
    }
    VSCode = @{
        Name = "VS Code"
        Command = "code"
        VersionCmd = "code --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = "winget upgrade Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements"
        RequiresWSL = $false
        VersionSource = @{
            Type = "github"
            Owner = "microsoft"
            Repo = "vscode"
        }
        InstallMethods = @{
            WinGet = "winget install Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements"
        }
        UninstallMethods = @{
            WinGet = "winget uninstall Microsoft.VisualStudioCode"
        }
    }
    VSCodeInsiders = @{
        Name = "VS Code Insiders"
        Command = "code-insiders"
        VersionCmd = "code-insiders --version"
        VersionPattern = '(\d+\.\d+\.\d+)'
        UpdateCmd = "winget upgrade Microsoft.VisualStudioCode.Insiders --accept-package-agreements --accept-source-agreements"
        RequiresWSL = $false
        VersionSource = @{
            Type = "github"
            Owner = "microsoft"
            Repo = "vscode"
        }
        InstallMethods = @{
            WinGet = "winget install Microsoft.VisualStudioCode.Insiders --accept-package-agreements --accept-source-agreements"
        }
        UninstallMethods = @{
            WinGet = "winget uninstall Microsoft.VisualStudioCode.Insiders"
        }
    }
}

#endregion

#region Box-Drawing Characters

$script:BoxChars = @{
    # Rounded corners (for menus)
    TopLeft = '╭'; TopRight = '╮'; BottomLeft = '╰'; BottomRight = '╯'
    # Standard lines
    Horizontal = '─'; Vertical = '│'
    # T-junctions
    TeeRight = '├'; TeeLeft = '┤'; TeeDown = '┬'; TeeUp = '┴'
    Cross = '┼'
    # Table corners (sharp)
    TableTopLeft = '┌'; TableTopRight = '┐'
    TableBottomLeft = '└'; TableBottomRight = '┘'
    # Double-line (for banner)
    DoubleTopLeft = '╔'; DoubleTopRight = '╗'
    DoubleBottomLeft = '╚'; DoubleBottomRight = '╝'
    DoubleHorizontal = '═'; DoubleVertical = '║'
    # Tree structure
    TreeBranch = '├─'; TreeEnd = '└─'; TreeVertical = '│ '
}

$script:StatusSymbols = @{
    OK = @{ Symbol = '✓'; Color = 'Green' }
    UPDATE = @{ Symbol = '↑'; Color = 'Yellow' }
    MISS = @{ Symbol = '✗'; Color = 'Red' }
    WSL_REQUIRED = @{ Symbol = '⚠'; Color = 'DarkYellow' }
    WARN = @{ Symbol = '⚠'; Color = 'Yellow' }
}

$script:MenuIcons = @{
    Refresh = '🔄'
    Install = '📥'
    Update = '⬆️'
    Check = '🔍'
    Repair = '🔧'
    PowerShell = '⬆️'
    WSL = '🐧'
    Exit = '🚪'
    Package = '📦'
    Back = '←'
}

$script:ToolAliases = @{
    'claude' = 'ClaudeCode'
    'copilot' = 'CopilotCLI'
    'opencode' = 'OpenCode'
    'codex' = 'Codex'
    'aider' = 'Aider'
    'cursor' = 'CursorCLI'
    'cline' = 'Cline'
    'kiro' = 'KiroCLI'
    'vscode' = 'VSCode'
    'vscode-insiders' = 'VSCodeInsiders'
}

#endregion

#region UI Helper Functions

function Write-BoxLine {
    param(
        [string]$Left,
        [string]$Fill,
        [string]$Right,
        [int]$Width = 64,
        [ConsoleColor]$Color = [ConsoleColor]::Cyan
    )

    $line = $Left + ($Fill * ($Width - 2)) + $Right
    Write-Host $line -ForegroundColor $Color
}

function Write-BoxText {
    param(
        [string]$Text,
        [string]$Left = $script:BoxChars.Vertical,
        [string]$Right = $script:BoxChars.Vertical,
        [int]$Width = 64,
        [ConsoleColor]$TextColor = [ConsoleColor]::White,
        [ConsoleColor]$BorderColor = [ConsoleColor]::Cyan,
        [switch]$Center
    )

    $innerWidth = $Width - 4  # Account for borders and padding

    if ($Center) {
        $padding = [Math]::Max(0, ($innerWidth - $Text.Length) / 2)
        $leftPad = [Math]::Floor($padding)
        $rightPad = [Math]::Ceiling($padding)
        $paddedText = (" " * $leftPad) + $Text + (" " * $rightPad)
    }
    else {
        $paddedText = $Text.PadRight($innerWidth)
    }

    # Truncate if too long
    if ($paddedText.Length -gt $innerWidth) {
        $paddedText = $paddedText.Substring(0, $innerWidth)
    }

    Write-Host $Left -ForegroundColor $BorderColor -NoNewline
    Write-Host " " -NoNewline
    Write-Host $paddedText -ForegroundColor $TextColor -NoNewline
    Write-Host " " -NoNewline
    Write-Host $Right -ForegroundColor $BorderColor
}

function Write-TableRow {
    param(
        [string[]]$Columns,
        [int[]]$Widths,
        [ConsoleColor[]]$Colors = @(),
        [string]$Separator = $script:BoxChars.Vertical
    )

    Write-Host $Separator -ForegroundColor Cyan -NoNewline

    for ($i = 0; $i -lt $Columns.Count; $i++) {
        $col = $Columns[$i]
        $width = $Widths[$i]
        $color = if ($Colors.Count -gt $i -and $Colors[$i]) { $Colors[$i] } else { [ConsoleColor]::White }

        $paddedCol = " " + $col.PadRight($width - 1)
        if ($paddedCol.Length -gt $width) {
            $paddedCol = $paddedCol.Substring(0, $width)
        }

        Write-Host $paddedCol -ForegroundColor $color -NoNewline
        Write-Host $Separator -ForegroundColor Cyan -NoNewline
    }
    Write-Host ""
}

function Write-TableSeparator {
    param(
        [int[]]$Widths,
        [string]$Left = $script:BoxChars.TeeRight,
        [string]$Right = $script:BoxChars.TeeLeft,
        [string]$Cross = $script:BoxChars.Cross,
        [string]$Fill = $script:BoxChars.Horizontal
    )

    Write-Host $Left -ForegroundColor Cyan -NoNewline

    for ($i = 0; $i -lt $Widths.Count; $i++) {
        Write-Host ($Fill * $Widths[$i]) -ForegroundColor Cyan -NoNewline
        if ($i -lt $Widths.Count - 1) {
            Write-Host $Cross -ForegroundColor Cyan -NoNewline
        }
    }

    Write-Host $Right -ForegroundColor Cyan
}

function Write-SectionHeader {
    param(
        [string]$Title,
        [int]$Width = 64,
        [ConsoleColor]$Color = [ConsoleColor]::Yellow
    )

    Write-BoxLine -Left $script:BoxChars.TeeRight -Fill $script:BoxChars.Horizontal -Right $script:BoxChars.TeeLeft -Width $Width -Color Cyan
    Write-BoxText -Text $Title -Width $Width -TextColor $Color -Center
    Write-BoxLine -Left $script:BoxChars.TeeRight -Fill $script:BoxChars.Horizontal -Right $script:BoxChars.TeeLeft -Width $Width -Color Cyan
}

function Get-StatusDisplay {
    param([string]$Status)

    $info = $script:StatusSymbols[$Status]
    if ($info) {
        return @{
            Text = "$($info.Symbol) $Status"
            Color = $info.Color
        }
    }
    return @{ Text = $Status; Color = 'Gray' }
}

#endregion

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Write-ColorOutput {
    param(
        [string]$Text,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [switch]$NoNewline
    )

    $params = @{
        Object = $Text
        ForegroundColor = $ForegroundColor
    }
    if ($NoNewline) { $params.NoNewline = $true }
    Write-Host @params
}

function Write-StatusLine {
    param(
        [string]$Status,
        [string]$Message
    )

    switch ($Status) {
        'OK'      { Write-ColorOutput "  [OK]     " -ForegroundColor Green -NoNewline }
        'UPDATE'  { Write-ColorOutput "  [UPDATE] " -ForegroundColor Yellow -NoNewline }
        'MISS'    { Write-ColorOutput "  [MISS]   " -ForegroundColor Red -NoNewline }
        'ERROR'   { Write-ColorOutput "  [ERROR]  " -ForegroundColor Red -NoNewline }
        'INFO'    { Write-ColorOutput "  [INFO]   " -ForegroundColor Cyan -NoNewline }
        'WARN'    { Write-ColorOutput "  [WARN]   " -ForegroundColor Yellow -NoNewline }
        default   { Write-ColorOutput "  [    ]   " -NoNewline }
    }
    Write-Host $Message
}

function Test-CommandExists {
    param([string]$Command)

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        # Handle compound commands like "gh copilot"
        $parts = $Command -split ' ', 2
        $exe = $parts[0]

        if (Get-Command $exe -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}

function Test-WSLInstalled {
    try {
        $wslStatus = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-WSLCommandExists {
    param([string]$Command)

    if (-not (Test-WSLInstalled)) {
        return $false
    }

    try {
        $result = wsl -e bash -c "command -v $Command" 2>&1
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Compare-Version {
    param(
        [string]$Installed,
        [string]$Latest
    )

    if ([string]::IsNullOrEmpty($Installed) -or [string]::IsNullOrEmpty($Latest)) {
        return $null
    }

    try {
        $installedParts = $Installed -split '\.' | ForEach-Object { [int]$_ }
        $latestParts = $Latest -split '\.' | ForEach-Object { [int]$_ }

        # Pad arrays to same length
        $maxLen = [Math]::Max($installedParts.Length, $latestParts.Length)
        while ($installedParts.Length -lt $maxLen) { $installedParts += 0 }
        while ($latestParts.Length -lt $maxLen) { $latestParts += 0 }

        for ($i = 0; $i -lt $maxLen; $i++) {
            if ($installedParts[$i] -lt $latestParts[$i]) { return -1 }
            if ($installedParts[$i] -gt $latestParts[$i]) { return 1 }
        }
        return 0
    }
    catch {
        return $null
    }
}

function Test-AdminElevation {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminElevation {
    param([string]$Reason)

    if (Test-AdminElevation) {
        return $true
    }

    Write-ColorOutput "`nAdministrator privileges required: $Reason" -ForegroundColor Yellow
    Write-Host "Please run this script as Administrator."
    return $false
}

#endregion

#region PATH Management Functions

function Refresh-EnvironmentPath {
    <#
    .SYNOPSIS
        Refreshes the PATH environment variable from the registry.
        This is needed after installing tools so they are immediately available.
    #>

    # Get Machine PATH
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')

    # Get User PATH
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')

    # Combine them (Machine first, then User)
    $newPath = @()
    if ($machinePath) { $newPath += $machinePath -split ';' | Where-Object { $_ } }
    if ($userPath) { $newPath += $userPath -split ';' | Where-Object { $_ } }

    # Remove duplicates while preserving order
    $uniquePath = $newPath | Select-Object -Unique

    # Update current session
    $env:PATH = $uniquePath -join ';'

    Write-Log "PATH refreshed with $($uniquePath.Count) entries"
}

function Test-ToolAccessible {
    <#
    .SYNOPSIS
        Tests if a tool is accessible after installation.
        Returns the full path if found, or $null if not accessible.
    #>
    param(
        [string]$Command,
        [switch]$RefreshPath
    )

    if ($RefreshPath) {
        Refresh-EnvironmentPath
    }

    # Handle compound commands like "gh copilot"
    $parts = $Command -split ' ', 2
    $exe = $parts[0]

    try {
        $cmdInfo = Get-Command $exe -ErrorAction SilentlyContinue
        if ($cmdInfo) {
            return $cmdInfo.Source
        }
    }
    catch {
        # Ignore errors
    }

    return $null
}

function Get-CommonToolPaths {
    <#
    .SYNOPSIS
        Returns common installation paths for various package managers.
    #>

    $paths = @()

    # npm global path
    $npmPrefix = $null
    try {
        $npmPrefix = (npm config get prefix 2>$null)
        if ($npmPrefix -and (Test-Path $npmPrefix)) {
            $paths += $npmPrefix
            $paths += Join-Path $npmPrefix 'node_modules\.bin'
        }
    }
    catch { }

    # Python Scripts path
    $pythonPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\Python*\Scripts"
        "$env:APPDATA\Python\Python*\Scripts"
        "$env:LOCALAPPDATA\Packages\PythonSoftwareFoundation*\LocalCache\local-packages\Python*\Scripts"
    )
    foreach ($pattern in $pythonPaths) {
        $resolved = Resolve-Path $pattern -ErrorAction SilentlyContinue
        if ($resolved) {
            $paths += $resolved.Path
        }
    }

    # Scoop shims
    $scoopShims = "$env:USERPROFILE\scoop\shims"
    if (Test-Path $scoopShims) {
        $paths += $scoopShims
    }

    # Local bin (for native installers)
    $localBin = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (Test-Path $localBin) {
        $paths += $localBin
    }

    # Claude Code specific path
    $claudePath = "$env:LOCALAPPDATA\Programs\claude-code"
    if (Test-Path $claudePath) {
        $paths += $claudePath
    }

    return $paths | Where-Object { $_ } | Select-Object -Unique
}

function Add-ToPath {
    <#
    .SYNOPSIS
        Adds a directory to the User PATH if not already present.
    #>
    param(
        [string]$Directory,
        [switch]$Permanent
    )

    if (-not (Test-Path $Directory)) {
        Write-Log "Directory does not exist: $Directory" -Level Warning
        return $false
    }

    # Check if already in PATH
    $currentPath = $env:PATH -split ';'
    if ($currentPath -contains $Directory) {
        Write-Log "Directory already in PATH: $Directory"
        return $true
    }

    # Add to current session
    $env:PATH = "$Directory;$env:PATH"
    Write-Log "Added to session PATH: $Directory"

    if ($Permanent) {
        # Add to User PATH permanently
        $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        $userPathEntries = if ($userPath) { $userPath -split ';' | Where-Object { $_ } } else { @() }

        if ($userPathEntries -notcontains $Directory) {
            $newUserPath = (@($Directory) + $userPathEntries) -join ';'
            [Environment]::SetEnvironmentVariable('PATH', $newUserPath, 'User')
            Write-Log "Added to permanent User PATH: $Directory"
            Write-ColorOutput "  PATH updated: $Directory" -ForegroundColor DarkGray
        }
    }

    return $true
}

function Ensure-ToolInPath {
    <#
    .SYNOPSIS
        Ensures a tool is accessible. If not, tries to find and add its path.
    #>
    param(
        [hashtable]$Tool,
        [switch]$AutoFix
    )

    $command = $Tool.Command
    $parts = $command -split ' ', 2
    $exe = $parts[0]

    # First refresh PATH
    Refresh-EnvironmentPath

    # Check if accessible
    $toolPath = Test-ToolAccessible -Command $command
    if ($toolPath) {
        return @{ Accessible = $true; Path = $toolPath }
    }

    # Tool not found - try to locate it
    Write-ColorOutput "  Tool '$exe' not found in PATH. Searching..." -ForegroundColor Yellow

    # Common locations to search
    $searchPaths = @(
        "$env:LOCALAPPDATA\Programs"
        "$env:PROGRAMFILES"
        "${env:PROGRAMFILES(x86)}"
        "$env:APPDATA"
        "$env:LOCALAPPDATA"
        "$env:USERPROFILE\scoop\apps"
        "$env:USERPROFILE\scoop\shims"
    ) + (Get-CommonToolPaths)

    foreach ($basePath in $searchPaths) {
        if (-not $basePath -or -not (Test-Path $basePath)) { continue }

        # Search for the executable
        $found = Get-ChildItem -Path $basePath -Filter "$exe.exe" -Recurse -ErrorAction SilentlyContinue -Depth 4 | Select-Object -First 1
        if ($found) {
            $exeDir = $found.DirectoryName
            Write-ColorOutput "  Found: $($found.FullName)" -ForegroundColor Green

            if ($AutoFix) {
                Add-ToPath -Directory $exeDir -Permanent
                return @{ Accessible = $true; Path = $found.FullName; Added = $true }
            }
            else {
                Write-ColorOutput "  Please add this path to PATH: $exeDir" -ForegroundColor Yellow
                return @{ Accessible = $false; Path = $found.FullName; SuggestedPath = $exeDir }
            }
        }
    }

    return @{ Accessible = $false; Path = $null }
}

#endregion

#region Version Fetching Functions

function Get-LatestNpmVersion {
    param([string]$Package)

    try {
        $uri = "https://registry.npmjs.org/$Package"
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10 -ErrorAction Stop
        $version = $response.'dist-tags'.latest
        Write-Log "Fetched npm version for $Package : $version"
        return $version
    }
    catch {
        Write-Log "Failed to fetch npm version for $Package : $_" -Level Warning
        return $null
    }
}

function Get-LatestGitHubVersion {
    param(
        [string]$Owner,
        [string]$Repo
    )

    try {
        $uri = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
        $headers = @{
            'Accept' = 'application/vnd.github.v3+json'
            'User-Agent' = 'AgentHelper'
        }

        # Use GitHub token if available
        $token = if ($env:GH_TOKEN) { $env:GH_TOKEN } else { $env:GITHUB_TOKEN }
        if ($token) {
            $headers['Authorization'] = "Bearer $token"
        }

        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 10 -ErrorAction Stop
        $version = $response.tag_name -replace '^v', ''
        Write-Log "Fetched GitHub version for $Owner/$Repo : $version"
        return $version
    }
    catch {
        Write-Log "Failed to fetch GitHub version for $Owner/$Repo : $_" -Level Warning
        return $null
    }
}

function Get-LatestPyPIVersion {
    param([string]$Package)

    try {
        $uri = "https://pypi.org/pypi/$Package/json"
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10 -ErrorAction Stop
        $version = $response.info.version
        Write-Log "Fetched PyPI version for $Package : $version"
        return $version
    }
    catch {
        Write-Log "Failed to fetch PyPI version for $Package : $_" -Level Warning
        return $null
    }
}

function Get-LatestWinGetVersion {
    param([string]$PackageId)

    try {
        $output = winget show $PackageId --versions 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "WinGet failed for $PackageId" -Level Warning
            return $null
        }

        # Parse output: skip header lines, get first version
        $lines = $output -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d|^v\d' }
        if ($lines -and $lines.Count -gt 0) {
            $version = ($lines | Select-Object -First 1) -replace '^v', ''
            Write-Log "Fetched WinGet version for $PackageId : $version"
            return $version
        }

        Write-Log "No version found for WinGet package $PackageId" -Level Warning
        return $null
    }
    catch {
        Write-Log "Failed to fetch WinGet version for $PackageId : $_" -Level Warning
        return $null
    }
}

function Get-LatestVersion {
    param([hashtable]$Tool)

    $source = $Tool.VersionSource

    switch ($source.Type) {
        'npm'    { return Get-LatestNpmVersion -Package $source.Package }
        'github' { return Get-LatestGitHubVersion -Owner $source.Owner -Repo $source.Repo }
        'pypi'   { return Get-LatestPyPIVersion -Package $source.Package }
        'winget' { return Get-LatestWinGetVersion -PackageId $source.PackageId }
        default  { return $null }
    }
}

function Get-InstalledVersion {
    param([hashtable]$Tool)

    $command = $Tool.Command
    $versionCmd = $Tool.VersionCmd
    $pattern = $Tool.VersionPattern

    if ($Tool.RequiresWSL) {
        if (-not (Test-WSLInstalled)) {
            return $null
        }

        try {
            $result = wsl -e bash -c "$versionCmd 2>&1" 2>&1
            $resultString = ($result | Out-String) -join "`n"
            if ($LASTEXITCODE -eq 0 -and $resultString -match $pattern) {
                return $Matches[1]
            }
        }
        catch {
            return $null
        }
        return $null
    }

    # Handle compound commands
    $parts = $command -split ' ', 2
    $exe = $parts[0]

    if (-not (Test-CommandExists $exe)) {
        return $null
    }

    try {
        $result = Invoke-Expression "$versionCmd 2>&1" 2>&1
        # Convert array output to string for proper regex matching
        $resultString = ($result | Out-String) -join "`n"
        if ($resultString -match $pattern) {
            return $Matches[1]
        }
    }
    catch {
        Write-Log "Failed to get version for $($Tool.Name): $_" -Level Warning
    }

    return $null
}

function Get-AllToolStatus {
    $results = @{}

    $wslInstalled = Test-WSLInstalled

    foreach ($key in $script:ToolDefinitions.Keys) {
        $tool = $script:ToolDefinitions[$key]

        $status = @{
            Key = $key
            Name = $tool.Name
            RequiresWSL = $tool.RequiresWSL
            InstalledVersion = $null
            LatestVersion = $null
            Status = 'MISS'
            WSLAvailable = $wslInstalled
        }

        # Skip WSL tools if WSL not installed
        if ($tool.RequiresWSL -and -not $wslInstalled) {
            $status.Status = 'WSL_REQUIRED'
            $results[$key] = $status
            continue
        }

        $status.InstalledVersion = Get-InstalledVersion -Tool $tool
        $status.LatestVersion = Get-LatestVersion -Tool $tool

        if ($status.InstalledVersion) {
            $comparison = Compare-Version -Installed $status.InstalledVersion -Latest $status.LatestVersion

            if ($null -eq $comparison -or $null -eq $status.LatestVersion) {
                $status.Status = 'OK'
            }
            elseif ($comparison -lt 0) {
                $status.Status = 'UPDATE'
            }
            else {
                $status.Status = 'OK'
            }
        }
        else {
            $status.Status = 'MISS'
        }

        $results[$key] = $status
    }

    return $results
}

#endregion

#region Installation Functions

function Test-Prerequisites {
    param([hashtable]$Tool)

    if (-not $Tool.Prerequisites) {
        return $true
    }

    foreach ($prereq in $Tool.Prerequisites) {
        if (-not (Test-CommandExists $prereq)) {
            Write-ColorOutput "Missing prerequisite: $prereq" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

function Get-BestInstallMethod {
    param(
        [hashtable]$Tool,
        [string]$Preferred
    )

    $methods = $Tool.InstallMethods

    # If preferred method exists, use it
    if ($methods.ContainsKey($Preferred)) {
        # Check if the installer tool is available
        switch ($Preferred) {
            'WinGet' { if (Test-CommandExists 'winget') { return $Preferred } }
            'npm'    { if (Test-CommandExists 'npm') { return $Preferred } }
            'pip'    { if (Test-CommandExists 'pip') { return $Preferred } }
            'Native' { return $Preferred }
            'WSL'    { if (Test-WSLInstalled) { return $Preferred } }
        }
    }

    # Fallback order: WinGet -> npm -> pip -> Native -> WSL
    $fallbackOrder = @('WinGet', 'npm', 'pip', 'Native', 'WSL', 'Scoop')

    foreach ($method in $fallbackOrder) {
        if ($methods.ContainsKey($method)) {
            switch ($method) {
                'WinGet' { if (Test-CommandExists 'winget') { return $method } }
                'npm'    { if (Test-CommandExists 'npm') { return $method } }
                'pip'    { if (Test-CommandExists 'pip') { return $method } }
                'Scoop'  { if (Test-CommandExists 'scoop') { return $method } }
                'Native' { return $method }
                'WSL'    { if (Test-WSLInstalled) { return $method } }
            }
        }
    }

    return $null
}

function Install-CodingTool {
    param(
        [string]$ToolKey,
        [string]$PreferredMethod = 'WinGet',
        [switch]$Force
    )

    if (-not $script:ToolDefinitions.ContainsKey($ToolKey)) {
        Write-ColorOutput "Unknown tool: $ToolKey" -ForegroundColor Red
        return $false
    }

    $tool = $script:ToolDefinitions[$ToolKey]
    Write-ColorOutput "`nInstalling $($tool.Name)..." -ForegroundColor Cyan

    # Check WSL requirement
    if ($tool.RequiresWSL -and -not (Test-WSLInstalled)) {
        Write-ColorOutput "This tool requires WSL. Please run with -SetupWSL first." -ForegroundColor Red
        return $false
    }

    # Check prerequisites
    if (-not (Test-Prerequisites -Tool $tool)) {
        Write-ColorOutput "Prerequisites not met for $($tool.Name)" -ForegroundColor Red
        return $false
    }

    # Check if already installed
    $installed = Get-InstalledVersion -Tool $tool
    if ($installed -and -not $Force) {
        Write-ColorOutput "$($tool.Name) is already installed (v$installed)" -ForegroundColor Yellow
        return $true
    }

    # Get best installation method
    $method = Get-BestInstallMethod -Tool $tool -Preferred $PreferredMethod

    if (-not $method) {
        Write-ColorOutput "No available installation method for $($tool.Name)" -ForegroundColor Red
        Write-Host "Please install one of: WinGet, npm, pip, or WSL"
        return $false
    }

    $installCmd = $tool.InstallMethods[$method]
    Write-Host "Using $method method: $installCmd"
    Write-Log "Installing $($tool.Name) via $method"

    try {
        if ($method -eq 'Native' -and $installCmd -match 'irm.*\|.*iex') {
            # Execute web installer
            Invoke-Expression $installCmd
        }
        else {
            # Execute command
            $output = Invoke-Expression $installCmd 2>&1
            Write-Host $output
        }

        # Wait for installation to complete
        Start-Sleep -Seconds 2

        # Refresh PATH to pick up newly installed tools
        Write-Host "Refreshing PATH..."
        Refresh-EnvironmentPath

        # Verify tool is accessible
        $newVersion = Get-InstalledVersion -Tool $tool

        if ($newVersion) {
            Write-ColorOutput "$($tool.Name) v$newVersion installed successfully!" -ForegroundColor Green
            Write-Log "$($tool.Name) v$newVersion installed successfully via $method"

            # Verify tool is in PATH
            if (-not $tool.RequiresWSL) {
                $pathCheck = Ensure-ToolInPath -Tool $tool -AutoFix
                if ($pathCheck.Added) {
                    Write-ColorOutput "  PATH was automatically fixed." -ForegroundColor Green
                }
            }

            return $true
        }
        else {
            # Installation might have succeeded but tool not in PATH
            Write-ColorOutput "Could not determine version. Checking PATH..." -ForegroundColor Yellow

            if (-not $tool.RequiresWSL) {
                $pathCheck = Ensure-ToolInPath -Tool $tool -AutoFix
                if ($pathCheck.Accessible) {
                    Write-ColorOutput "$($tool.Name) is now available!" -ForegroundColor Green
                    return $true
                }
                elseif ($pathCheck.SuggestedPath) {
                    Write-ColorOutput "Please add manually to PATH: $($pathCheck.SuggestedPath)" -ForegroundColor Yellow
                    return $true
                }
            }

            Write-ColorOutput "Installation may have succeeded, but tool is not accessible" -ForegroundColor Yellow
            Write-ColorOutput "Please restart your terminal or add the installation path to PATH." -ForegroundColor Yellow
            return $true
        }
    }
    catch {
        Write-ColorOutput "Installation failed: $_" -ForegroundColor Red
        Write-Log "Installation of $($tool.Name) failed: $_" -Level Error
        return $false
    }
}

function Install-AllTools {
    param(
        [string]$PreferredMethod = 'WinGet',
        [switch]$Force
    )

    $results = @{}
    $nativeTools = $script:ToolDefinitions.Keys | Where-Object { -not $script:ToolDefinitions[$_].RequiresWSL }
    $wslTools = $script:ToolDefinitions.Keys | Where-Object { $script:ToolDefinitions[$_].RequiresWSL }

    Write-ColorOutput "`n=== Installing Native Windows Tools ===" -ForegroundColor Cyan
    foreach ($key in $nativeTools) {
        $results[$key] = Install-CodingTool -ToolKey $key -PreferredMethod $PreferredMethod -Force:$Force
    }

    if (Test-WSLInstalled) {
        Write-ColorOutput "`n=== Installing WSL Tools ===" -ForegroundColor Cyan
        foreach ($key in $wslTools) {
            $results[$key] = Install-CodingTool -ToolKey $key -PreferredMethod 'WSL' -Force:$Force
        }
    }
    else {
        Write-ColorOutput "`nSkipping WSL tools (WSL not installed)" -ForegroundColor Yellow
    }

    return $results
}

#endregion

#region Update Functions

function Update-CodingTool {
    param(
        [string]$ToolKey,
        [switch]$Force
    )

    if (-not $script:ToolDefinitions.ContainsKey($ToolKey)) {
        Write-ColorOutput "Unknown tool: $ToolKey" -ForegroundColor Red
        return $false
    }

    $tool = $script:ToolDefinitions[$ToolKey]
    $installed = Get-InstalledVersion -Tool $tool

    if (-not $installed) {
        Write-ColorOutput "$($tool.Name) is not installed" -ForegroundColor Yellow
        return $false
    }

    Write-ColorOutput "`nUpdating $($tool.Name)..." -ForegroundColor Cyan
    Write-Host "Current version: $installed"

    if (-not $tool.UpdateCmd) {
        Write-ColorOutput "No update command defined for $($tool.Name)" -ForegroundColor Yellow
        return $false
    }

    try {
        Write-Host "Running: $($tool.UpdateCmd)"
        $output = Invoke-Expression $tool.UpdateCmd 2>&1
        Write-Host $output

        Start-Sleep -Seconds 2

        # Refresh PATH after update (some updates might change paths)
        Refresh-EnvironmentPath

        $newVersion = Get-InstalledVersion -Tool $tool

        if ($newVersion -and $newVersion -ne $installed) {
            Write-ColorOutput "$($tool.Name) updated to v$newVersion" -ForegroundColor Green
            Write-Log "$($tool.Name) updated from v$installed to v$newVersion"
        }
        elseif ($newVersion) {
            Write-ColorOutput "$($tool.Name) is already at v$newVersion" -ForegroundColor Green
        }
        else {
            # Version check failed - might be PATH issue
            Write-ColorOutput "Could not determine version. Checking PATH..." -ForegroundColor Yellow
            if (-not $tool.RequiresWSL) {
                $pathCheck = Ensure-ToolInPath -Tool $tool -AutoFix
                if ($pathCheck.Accessible) {
                    Write-ColorOutput "$($tool.Name) is available." -ForegroundColor Green
                }
            }
        }

        return $true
    }
    catch {
        Write-ColorOutput "Update failed: $_" -ForegroundColor Red
        Write-Log "Update of $($tool.Name) failed: $_" -Level Error
        return $false
    }
}

function Update-AllTools {
    param([switch]$Force)

    $results = @{}
    $status = Get-AllToolStatus

    foreach ($key in $status.Keys) {
        $toolStatus = $status[$key]

        if ($toolStatus.InstalledVersion) {
            if ($toolStatus.Status -eq 'UPDATE' -or $Force) {
                $results[$key] = Update-CodingTool -ToolKey $key -Force:$Force
            }
            else {
                Write-ColorOutput "$($toolStatus.Name) is up to date (v$($toolStatus.InstalledVersion))" -ForegroundColor Green
                $results[$key] = $true
            }
        }
    }

    return $results
}

function Update-OutdatedTools {
    $status = Get-AllToolStatus

    # Filter: Installed AND update available
    $outdated = @{}
    foreach ($key in $status.Keys) {
        $toolStatus = $status[$key]
        if ($toolStatus.InstalledVersion -and $toolStatus.Status -eq 'UPDATE') {
            $outdated[$key] = $toolStatus
        }
    }

    if ($outdated.Count -eq 0) {
        Write-ColorOutput "`nAll installed tools are up to date!" -ForegroundColor Green
        return @{}
    }

    # Show what will be updated
    Write-Host ""
    Write-ColorOutput "The following tools have updates available:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($key in $outdated.Keys) {
        $tool = $outdated[$key]
        Write-Host "  $($script:StatusSymbols.UPDATE.Symbol) " -NoNewline -ForegroundColor Yellow
        Write-Host "$($tool.Name): " -NoNewline
        Write-Host "$($tool.InstalledVersion)" -NoNewline -ForegroundColor DarkGray
        Write-Host " -> " -NoNewline
        Write-Host "$($tool.LatestVersion)" -ForegroundColor Green
    }

    Write-Host ""
    $confirm = Read-Host "Proceed with updates? (y/N)"

    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-ColorOutput "Cancelled." -ForegroundColor Yellow
        return @{}
    }

    # Perform updates
    $results = @{}
    foreach ($key in $outdated.Keys) {
        $results[$key] = Update-CodingTool -ToolKey $key
    }

    return $results
}

#endregion

#region Repair Functions

function Repair-ToolInstallation {
    param(
        [string]$ToolKey,
        [string]$PreferredMethod = 'WinGet'
    )

    if (-not $script:ToolDefinitions.ContainsKey($ToolKey)) {
        Write-ColorOutput "Unknown tool: $ToolKey" -ForegroundColor Red
        return $false
    }

    $tool = $script:ToolDefinitions[$ToolKey]
    Write-ColorOutput "`nRepairing $($tool.Name)..." -ForegroundColor Cyan

    # Try to uninstall first
    if ($tool.UninstallMethods) {
        foreach ($method in $tool.UninstallMethods.Keys) {
            $uninstallCmd = $tool.UninstallMethods[$method]
            Write-Host "Uninstalling via $method..."

            try {
                $output = Invoke-Expression $uninstallCmd 2>&1
                Write-Host $output
            }
            catch {
                Write-Log "Uninstall attempt via $method failed: $_" -Level Warning
            }
        }
    }

    Start-Sleep -Seconds 2

    # Reinstall
    return Install-CodingTool -ToolKey $ToolKey -PreferredMethod $PreferredMethod -Force
}

#endregion

#region Environment Functions

function Get-EnvironmentReport {
    $report = @{
        PowerShell = @{
            Version = $PSVersionTable.PSVersion.ToString()
            Edition = $PSVersionTable.PSEdition
        }
        Prerequisites = @{}
        EnvironmentVariables = @{}
        WSL = @{
            Installed = Test-WSLInstalled
        }
        Path = @()
    }

    # Check prerequisites
    $prereqs = @{
        'Node.js' = @{ Command = 'node'; VersionCmd = 'node --version' }
        'npm' = @{ Command = 'npm'; VersionCmd = 'npm --version' }
        'Python' = @{ Command = 'python'; VersionCmd = 'python --version' }
        'pip' = @{ Command = 'pip'; VersionCmd = 'pip --version' }
        'WinGet' = @{ Command = 'winget'; VersionCmd = 'winget --version' }
        'Git' = @{ Command = 'git'; VersionCmd = 'git --version' }
        'GitHub CLI' = @{ Command = 'gh'; VersionCmd = 'gh --version' }
        'Scoop' = @{ Command = 'scoop'; VersionCmd = 'scoop --version' }
    }

    foreach ($name in $prereqs.Keys) {
        $prereq = $prereqs[$name]
        if (Test-CommandExists $prereq.Command) {
            try {
                $version = Invoke-Expression "$($prereq.VersionCmd) 2>&1" | Select-Object -First 1
                $report.Prerequisites[$name] = @{
                    Installed = $true
                    Version = $version -replace '^[vV]', ''
                }
            }
            catch {
                $report.Prerequisites[$name] = @{
                    Installed = $true
                    Version = 'Unknown'
                }
            }
        }
        else {
            $report.Prerequisites[$name] = @{
                Installed = $false
                Version = $null
            }
        }
    }

    # Check environment variables
    $envVars = @(
        'ANTHROPIC_API_KEY',
        'OPENAI_API_KEY',
        'GH_TOKEN',
        'GITHUB_TOKEN',
        'AWS_ACCESS_KEY_ID',
        'AWS_SECRET_ACCESS_KEY'
    )

    foreach ($var in $envVars) {
        $value = [Environment]::GetEnvironmentVariable($var)
        $report.EnvironmentVariables[$var] = @{
            Set = (-not [string]::IsNullOrEmpty($value))
            Masked = if ($value) { $value.Substring(0, [Math]::Min(4, $value.Length)) + '****' } else { $null }
        }
    }

    # Get relevant PATH entries
    $pathEntries = $env:PATH -split ';'
    $relevantPaths = $pathEntries | Where-Object {
        $_ -match 'npm|node|python|pip|scoop|\.local|AppData' -and
        (Test-Path $_ -ErrorAction SilentlyContinue)
    }
    $report.Path = $relevantPaths

    return $report
}

function Show-EnvironmentReport {
    param([hashtable]$Report)

    $width = 64

    Write-Host ""
    # Top border
    Write-BoxLine -Left $script:BoxChars.TopLeft -Fill $script:BoxChars.Horizontal -Right $script:BoxChars.TopRight -Width $width -Color Cyan

    # Title
    Write-BoxText -Text "ENVIRONMENT REPORT" -Width $width -TextColor Yellow -Center

    # PowerShell Section
    Write-BoxLine -Left $script:BoxChars.TeeRight -Fill $script:BoxChars.Horizontal -Right $script:BoxChars.TeeLeft -Width $width -Color Cyan
    Write-BoxText -Text "POWERSHELL" -Width $width -TextColor DarkGray
    Write-BoxText -Text "$($script:BoxChars.TreeBranch) Version: $($Report.PowerShell.Version)" -Width $width
    Write-BoxText -Text "$($script:BoxChars.TreeEnd) Edition: $($Report.PowerShell.Edition)" -Width $width

    # Prerequisites Section
    Write-BoxLine -Left $script:BoxChars.TeeRight -Fill $script:BoxChars.Horizontal -Right $script:BoxChars.TeeLeft -Width $width -Color Cyan
    Write-BoxText -Text "PREREQUISITES" -Width $width -TextColor DarkGray

    $prereqKeys = $Report.Prerequisites.Keys | Sort-Object
    $lastIndex = $prereqKeys.Count - 1
    $index = 0

    foreach ($name in $prereqKeys) {
        $prereq = $Report.Prerequisites[$name]
        $prefix = if ($index -eq $lastIndex) { $script:BoxChars.TreeEnd } else { $script:BoxChars.TreeBranch }

        if ($prereq.Installed) {
            $symbol = $script:StatusSymbols.OK.Symbol
            $color = $script:StatusSymbols.OK.Color
            $versionText = $prereq.Version -replace '^[vV]', '' -replace '\s.*$', ''
            $text = "$prefix $symbol $($name.PadRight(12)) $versionText"
        }
        else {
            $symbol = $script:StatusSymbols.MISS.Symbol
            $color = $script:StatusSymbols.MISS.Color
            $text = "$prefix $symbol $($name.PadRight(12)) Not installed"
        }

        Write-Host $script:BoxChars.Vertical -ForegroundColor Cyan -NoNewline
        Write-Host " " -NoNewline
        Write-Host $prefix -ForegroundColor Cyan -NoNewline
        Write-Host " " -NoNewline
        Write-Host $symbol -ForegroundColor $color -NoNewline
        Write-Host " $($name.PadRight(12))" -NoNewline
        if ($prereq.Installed) {
            $versionText = $prereq.Version -replace '^[vV]', '' -replace '\s.*$', ''
            Write-Host $versionText.PadRight($width - 24) -ForegroundColor White -NoNewline
        }
        else {
            Write-Host "Not installed".PadRight($width - 24) -ForegroundColor Gray -NoNewline
        }
        Write-Host $script:BoxChars.Vertical -ForegroundColor Cyan

        $index++
    }

    # WSL Section
    Write-BoxLine -Left $script:BoxChars.TeeRight -Fill $script:BoxChars.Horizontal -Right $script:BoxChars.TeeLeft -Width $width -Color Cyan
    Write-BoxText -Text "WSL STATUS" -Width $width -TextColor DarkGray

    if ($Report.WSL.Installed) {
        $wslSymbol = $script:StatusSymbols.OK.Symbol
        $wslColor = 'Green'
        $wslText = "$($script:BoxChars.TreeEnd) $wslSymbol WSL is installed"
    }
    else {
        $wslSymbol = $script:StatusSymbols.MISS.Symbol
        $wslColor = 'Red'
        $wslText = "$($script:BoxChars.TreeEnd) $wslSymbol WSL is not installed"
    }

    Write-Host $script:BoxChars.Vertical -ForegroundColor Cyan -NoNewline
    Write-Host " $($script:BoxChars.TreeEnd) " -ForegroundColor Cyan -NoNewline
    Write-Host $wslSymbol -ForegroundColor $wslColor -NoNewline
    $statusText = if ($Report.WSL.Installed) { " WSL is installed" } else { " WSL is not installed" }
    Write-Host $statusText.PadRight($width - 8) -NoNewline
    Write-Host $script:BoxChars.Vertical -ForegroundColor Cyan

    # API Keys Section
    Write-BoxLine -Left $script:BoxChars.TeeRight -Fill $script:BoxChars.Horizontal -Right $script:BoxChars.TeeLeft -Width $width -Color Cyan
    Write-BoxText -Text "API KEYS" -Width $width -TextColor DarkGray

    $envKeys = $Report.EnvironmentVariables.Keys | Sort-Object
    $lastEnvIndex = $envKeys.Count - 1
    $envIndex = 0

    foreach ($var in $envKeys) {
        $envVar = $Report.EnvironmentVariables[$var]
        $prefix = if ($envIndex -eq $lastEnvIndex) { $script:BoxChars.TreeEnd } else { $script:BoxChars.TreeBranch }

        Write-Host $script:BoxChars.Vertical -ForegroundColor Cyan -NoNewline
        Write-Host " $prefix " -ForegroundColor Cyan -NoNewline

        if ($envVar.Set) {
            Write-Host $script:StatusSymbols.OK.Symbol -ForegroundColor Green -NoNewline
            Write-Host " $($var.PadRight(22)) " -NoNewline
            Write-Host $envVar.Masked.PadRight($width - 32) -ForegroundColor DarkGray -NoNewline
        }
        else {
            Write-Host $script:StatusSymbols.WARN.Symbol -ForegroundColor Yellow -NoNewline
            Write-Host " $($var.PadRight(22)) " -NoNewline
            Write-Host "Not set".PadRight($width - 32) -ForegroundColor DarkGray -NoNewline
        }
        Write-Host $script:BoxChars.Vertical -ForegroundColor Cyan

        $envIndex++
    }

    # Bottom border
    Write-BoxLine -Left $script:BoxChars.BottomLeft -Fill $script:BoxChars.Horizontal -Right $script:BoxChars.BottomRight -Width $width -Color Cyan
    Write-Host ""
}

#endregion

#region PowerShell Update

function Update-PowerShellVersion {
    Write-ColorOutput "`nUpdating PowerShell..." -ForegroundColor Cyan

    if (-not (Test-CommandExists 'winget')) {
        Write-ColorOutput "WinGet is required to update PowerShell" -ForegroundColor Red
        return $false
    }

    try {
        $output = winget upgrade Microsoft.PowerShell --accept-package-agreements --accept-source-agreements 2>&1
        Write-Host $output
        Write-ColorOutput "PowerShell update completed. Please restart your terminal." -ForegroundColor Green
        return $true
    }
    catch {
        Write-ColorOutput "Failed to update PowerShell: $_" -ForegroundColor Red
        return $false
    }
}

#endregion

#region WSL Setup

function Install-WSL {
    Write-ColorOutput "`nSetting up WSL..." -ForegroundColor Cyan

    if (Test-WSLInstalled) {
        Write-ColorOutput "WSL is already installed" -ForegroundColor Green
        return $true
    }

    if (-not (Test-AdminElevation)) {
        Write-ColorOutput "Administrator privileges required to install WSL" -ForegroundColor Red
        Write-Host "Please run: wsl --install"
        Write-Host "Or run this script as Administrator"
        return $false
    }

    try {
        Write-Host "Installing WSL (this may take a while)..."
        $output = wsl --install 2>&1
        Write-Host $output
        Write-ColorOutput "WSL installation initiated. Please restart your computer to complete setup." -ForegroundColor Green
        return $true
    }
    catch {
        Write-ColorOutput "Failed to install WSL: $_" -ForegroundColor Red
        return $false
    }
}

#endregion

#region UI Functions

function Show-Banner {
    $width = 64

    Write-Host ""
    # Top border with double lines
    Write-BoxLine -Left $script:BoxChars.DoubleTopLeft -Fill $script:BoxChars.DoubleHorizontal -Right $script:BoxChars.DoubleTopRight -Width $width -Color Cyan

    # Empty line
    Write-BoxText -Text "" -Left $script:BoxChars.DoubleVertical -Right $script:BoxChars.DoubleVertical -Width $width -TextColor Cyan

    # Title line with tool emoji
    $title = "$($script:MenuIcons.Repair)  AGENTHELPER  v$script:Version"
    Write-BoxText -Text $title -Left $script:BoxChars.DoubleVertical -Right $script:BoxChars.DoubleVertical -Width $width -TextColor White -Center

    # Empty line
    Write-BoxText -Text "" -Left $script:BoxChars.DoubleVertical -Right $script:BoxChars.DoubleVertical -Width $width -TextColor Cyan

    # Bottom border
    Write-BoxLine -Left $script:BoxChars.DoubleBottomLeft -Fill $script:BoxChars.DoubleHorizontal -Right $script:BoxChars.DoubleBottomRight -Width $width -Color Cyan
    Write-Host ""
}

function Show-StatusTable {
    param([hashtable]$Status)

    # Column widths: Tool(25), Platform(11), Installed(11), Latest(10), Status(12)
    $colWidths = @(25, 11, 11, 10, 12)

    # Helper function for status display
    function Get-StatusText {
        param([string]$StatusCode)

        switch ($StatusCode) {
            'OK'           { return @{ Text = "✓ OK"; Color = 'Green' } }
            'UPDATE'       { return @{ Text = "↑ UPDATE"; Color = 'Yellow' } }
            'MISS'         { return @{ Text = "✗ MISS"; Color = 'Red' } }
            'WSL_REQUIRED' { return @{ Text = "⚠ WSL"; Color = 'DarkYellow' } }
            default        { return @{ Text = $StatusCode; Color = 'Gray' } }
        }
    }

    Write-Host ""

    # Table top border
    Write-TableSeparator -Widths $colWidths -Left $script:BoxChars.TableTopLeft -Right $script:BoxChars.TableTopRight -Cross $script:BoxChars.TeeDown

    # Header row
    Write-TableRow -Columns @("Tool", "Platform", "Installed", "Latest", "Status") -Widths $colWidths -Colors @([ConsoleColor]::White, [ConsoleColor]::White, [ConsoleColor]::White, [ConsoleColor]::White, [ConsoleColor]::White)

    # Header separator
    Write-TableSeparator -Widths $colWidths

    # Sort tools: Windows first, then WSL, alphabetically within each group
    $sortedTools = $Status.Keys | Sort-Object {
        $requiresWSL = $script:ToolDefinitions[$_].RequiresWSL
        $name = $Status[$_].Name
        # Sort by: 0=Windows, 1=WSL, then by name
        @($(if ($requiresWSL) { 1 } else { 0 }), $name)
    }

    foreach ($key in $sortedTools) {
        $tool = $Status[$key]
        $name = $tool.Name
        $platform = if ($tool.RequiresWSL) { "WSL" } else { "Windows" }
        $installed = if ($tool.InstalledVersion) { $tool.InstalledVersion } else { "-" }
        $latest = if ($tool.LatestVersion) { $tool.LatestVersion } else { "unknown" }

        $statusInfo = Get-StatusText -StatusCode $tool.Status

        Write-TableRow -Columns @($name, $platform, $installed, $latest, $statusInfo.Text) -Widths $colWidths -Colors @([ConsoleColor]::White, [ConsoleColor]::DarkGray, [ConsoleColor]::Cyan, [ConsoleColor]::Gray, $statusInfo.Color)
    }

    # Table bottom border
    Write-TableSeparator -Widths $colWidths -Left $script:BoxChars.TableBottomLeft -Right $script:BoxChars.TableBottomRight -Cross $script:BoxChars.TeeUp

    # Show update count
    $updateCount = ($Status.Values | Where-Object { $_.Status -eq 'UPDATE' }).Count
    if ($updateCount -gt 0) {
        Write-Host ""
        Write-Host "  $updateCount update(s) available" -ForegroundColor Yellow
    }

    Write-Host ""
}

function Show-CommandHint {
    Write-Host "  Type " -NoNewline -ForegroundColor DarkGray
    Write-Host "/help" -NoNewline -ForegroundColor Cyan
    Write-Host " for commands" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Help {
    Write-Host ""
    Write-Host "Available Commands:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  /status, /s          " -NoNewline -ForegroundColor Cyan
    Write-Host "Refresh tool status" -ForegroundColor White
    Write-Host "  /upgrade, /u         " -NoNewline -ForegroundColor Cyan
    Write-Host "Upgrade all installed tools with updates" -ForegroundColor White
    Write-Host "  /upgrade <tool>      " -NoNewline -ForegroundColor Cyan
    Write-Host "Upgrade specific tool" -ForegroundColor White
    Write-Host "  /install <tool>      " -NoNewline -ForegroundColor Cyan
    Write-Host "Install a tool (or 'all')" -ForegroundColor White
    Write-Host "  /repair <tool>       " -NoNewline -ForegroundColor Cyan
    Write-Host "Repair tool installation" -ForegroundColor White
    Write-Host "  /env                 " -NoNewline -ForegroundColor Cyan
    Write-Host "Show environment report" -ForegroundColor White
    Write-Host "  /quit, /q            " -NoNewline -ForegroundColor Cyan
    Write-Host "Exit" -ForegroundColor White
    Write-Host ""
    Write-Host "Tools: " -NoNewline -ForegroundColor DarkGray
    Write-Host "claude, copilot, opencode, codex, aider, cursor, cline, kiro, vscode, vscode-insiders" -ForegroundColor Gray
    Write-Host ""
}

function Get-ToolKeyFromAlias {
    param([string]$Alias)

    $lowerAlias = $Alias.ToLower()

    # Check direct alias mapping
    if ($script:ToolAliases.ContainsKey($lowerAlias)) {
        return $script:ToolAliases[$lowerAlias]
    }

    # Check if it's already a valid tool key (case-insensitive)
    foreach ($key in $script:ToolDefinitions.Keys) {
        if ($key.ToLower() -eq $lowerAlias) {
            return $key
        }
    }

    return $null
}

function Invoke-CLICommand {
    param(
        [string]$Input,
        [ref]$Status
    )

    $trimmedInput = $Input.Trim()

    # Empty input - just redisplay
    if ([string]::IsNullOrWhiteSpace($trimmedInput)) {
        return 'continue'
    }

    # Parse command and arguments
    $parts = $trimmedInput -split '\s+', 2
    $command = $parts[0].ToLower()
    $args = if ($parts.Count -gt 1) { $parts[1].Trim() } else { $null }

    # Handle commands with or without leading slash
    $command = $command.TrimStart('/')

    switch ($command) {
        # Help
        { $_ -in @('help', '?', 'h') } {
            Show-Help
            return 'continue'
        }

        # Status / Refresh
        { $_ -in @('status', 's', 'refresh', 'r') } {
            Write-Host "`nRefreshing status..." -ForegroundColor Cyan
            $Status.Value = Get-AllToolStatus
            return 'refresh'
        }

        # Upgrade
        { $_ -in @('upgrade', 'u', 'update') } {
            if ($args) {
                # Upgrade specific tool
                $toolKey = Get-ToolKeyFromAlias -Alias $args
                if ($toolKey) {
                    Update-CodingTool -ToolKey $toolKey
                    $Status.Value = Get-AllToolStatus
                }
                else {
                    Write-Host "Unknown tool: $args" -ForegroundColor Red
                    Write-Host "Available tools: claude, copilot, opencode, codex, aider, cursor, cline, kiro, vscode, vscode-insiders" -ForegroundColor DarkGray
                }
            }
            else {
                # Upgrade all outdated tools
                Update-OutdatedTools
                $Status.Value = Get-AllToolStatus
            }
            return 'refresh'
        }

        # Install
        { $_ -in @('install', 'i') } {
            if (-not $args) {
                Write-Host "Usage: /install <tool> or /install all" -ForegroundColor Yellow
                Write-Host "Available tools: claude, copilot, opencode, codex, aider, cursor, cline, kiro, vscode, vscode-insiders" -ForegroundColor DarkGray
                return 'continue'
            }

            if ($args.ToLower() -eq 'all') {
                Install-AllTools -PreferredMethod $script:PreferredMethod
            }
            else {
                $toolKey = Get-ToolKeyFromAlias -Alias $args
                if ($toolKey) {
                    Install-CodingTool -ToolKey $toolKey -PreferredMethod $script:PreferredMethod
                }
                else {
                    Write-Host "Unknown tool: $args" -ForegroundColor Red
                    Write-Host "Available tools: claude, copilot, opencode, codex, aider, cursor, cline, kiro, vscode, vscode-insiders" -ForegroundColor DarkGray
                }
            }
            $Status.Value = Get-AllToolStatus
            return 'refresh'
        }

        # Repair
        { $_ -in @('repair', 'fix') } {
            if (-not $args) {
                Write-Host "Usage: /repair <tool>" -ForegroundColor Yellow
                Write-Host "Available tools: claude, copilot, opencode, codex, aider, cursor, cline, kiro, vscode, vscode-insiders" -ForegroundColor DarkGray
                return 'continue'
            }

            $toolKey = Get-ToolKeyFromAlias -Alias $args
            if ($toolKey) {
                Repair-ToolInstallation -ToolKey $toolKey -PreferredMethod $script:PreferredMethod
                $Status.Value = Get-AllToolStatus
            }
            else {
                Write-Host "Unknown tool: $args" -ForegroundColor Red
                Write-Host "Available tools: claude, copilot, opencode, codex, aider, cursor, cline, kiro, vscode, vscode-insiders" -ForegroundColor DarkGray
            }
            return 'refresh'
        }

        # Environment
        { $_ -in @('env', 'environment') } {
            $envReport = Get-EnvironmentReport
            Show-EnvironmentReport -Report $envReport
            return 'continue'
        }

        # Quit
        { $_ -in @('quit', 'q', 'exit', 'bye') } {
            Write-Host "`nGoodbye!" -ForegroundColor Cyan
            return 'quit'
        }

        # Unknown command
        default {
            Write-Host "Unknown command: $trimmedInput" -ForegroundColor Red
            Write-Host "Type /help for available commands" -ForegroundColor DarkGray
            return 'continue'
        }
    }
}

function Start-InteractiveMode {
    # Store preferred method for use in Invoke-CLICommand
    $script:PreferredMethod = $PreferredMethod

    # Clear screen on startup
    Clear-Host

    Show-Banner

    Write-Host "Fetching tool status..." -ForegroundColor DarkGray
    $status = Get-AllToolStatus

    while ($true) {
        Clear-Host
        Show-Banner
        Show-StatusTable -Status $status
        Show-CommandHint

        $userInput = Read-Host ">"
        $result = Invoke-CLICommand -Input $userInput -Status ([ref]$status)

        if ($result -eq 'quit') {
            break
        }
    }
}

#endregion

#region Output Formatting

function ConvertTo-OutputFormat {
    param(
        [object]$Data,
        [string]$Format
    )

    switch ($Format) {
        'Json' {
            return $Data | ConvertTo-Json -Depth 10
        }
        'Object' {
            return $Data
        }
        default {
            return $Data
        }
    }
}

#endregion

#region Main Entry Point

# CLI Mode handling
if ($Status) {
    $statusData = Get-AllToolStatus

    if ($OutputFormat -eq 'Table') {
        Show-Banner
        Show-StatusTable -Status $statusData
    }
    else {
        ConvertTo-OutputFormat -Data $statusData -Format $OutputFormat
    }
}
elseif ($Install) {
    if ($Install -eq 'All') {
        $result = Install-AllTools -PreferredMethod $PreferredMethod -Force:$Force
    }
    else {
        $result = Install-CodingTool -ToolKey $Install -PreferredMethod $PreferredMethod -Force:$Force
    }

    if ($OutputFormat -ne 'Table') {
        ConvertTo-OutputFormat -Data $result -Format $OutputFormat
    }
}
elseif ($Update) {
    if ($Update -eq 'All') {
        # Smart update: only installed tools with available updates
        $result = Update-OutdatedTools
    }
    else {
        $result = Update-CodingTool -ToolKey $Update -Force:$Force
    }

    if ($OutputFormat -ne 'Table') {
        ConvertTo-OutputFormat -Data $result -Format $OutputFormat
    }
}
elseif ($Repair) {
    $result = Repair-ToolInstallation -ToolKey $Repair -PreferredMethod $PreferredMethod

    if ($OutputFormat -ne 'Table') {
        ConvertTo-OutputFormat -Data $result -Format $OutputFormat
    }
}
elseif ($Environment) {
    $envReport = Get-EnvironmentReport

    if ($OutputFormat -eq 'Table') {
        Show-EnvironmentReport -Report $envReport
    }
    else {
        ConvertTo-OutputFormat -Data $envReport -Format $OutputFormat
    }
}
elseif ($UpdatePowerShell) {
    Update-PowerShellVersion
}
elseif ($SetupWSL) {
    Install-WSL
}
else {
    # Interactive mode
    Start-InteractiveMode
}

#endregion

