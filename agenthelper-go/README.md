# AgentHelper

Cross-platform CLI tool manager for coding agents. Manage installation, updates, and status of AI coding assistants.

## Features

- **Cross-Platform**: Works on Windows, macOS, and Linux
- **Single Binary**: No dependencies required
- **Multiple Package Managers**: Supports WinGet, Homebrew, apt, npm, pip
- **Version Tracking**: Check for updates from npm, GitHub, and PyPI
- **Easy Installation**: One-line installers for all platforms

## Supported Tools

| Tool | Description |
|------|-------------|
| Claude Code | Anthropic's AI coding assistant |
| GitHub Copilot CLI | GitHub Copilot in the CLI |
| Aider | AI pair programming |
| OpenCode | Open source AI coding assistant |
| Codex CLI | OpenAI Codex command-line tool |
| VS Code | Microsoft Visual Studio Code |
| Cursor | AI-first code editor |
| Warp | Modern terminal with AI features |

## Installation

### Quick Install (Recommended)

**Windows (PowerShell):**
```powershell
irm https://github.com/jschneider/agenthelper/releases/latest/download/install.ps1 | iex
```

**macOS / Linux:**
```bash
curl -sSL https://github.com/jschneider/agenthelper/releases/latest/download/install.sh | bash
```

### Go Install

If you have Go installed:
```bash
go install github.com/jschneider/agenthelper/cmd/agenthelper@latest
```

### Manual Download

Download the latest binary from [Releases](https://github.com/jschneider/agenthelper/releases).

## Usage

### Check Tool Status
```bash
# Show status of all tools
agenthelper status

# JSON output for scripting
agenthelper status --json
```

### Install Tools
```bash
# Install a specific tool
agenthelper install claude-code

# Install with specific method
agenthelper install aider --method pip

# Install all tools
agenthelper install all
```

### Update Tools
```bash
# Update a specific tool
agenthelper update claude-code

# Update all installed tools
agenthelper update all
# or just
agenthelper update
```

### Repair Installation
```bash
# Repair a broken installation
agenthelper repair claude-code
```

### Run Tools
```bash
# Run a tool
agenthelper run claude-code

# Run with arguments
agenthelper run aider --help
```

### Environment Report
```bash
# Check environment setup
agenthelper env
```

## Configuration

### Tool Definitions

Tool definitions are stored in YAML format. AgentHelper looks for configuration in:

1. `./tools.yaml` (current directory)
2. `./config/tools.yaml` (config subdirectory)
3. `~/.agenthelper/tools.yaml` (user home directory)

Example tool definition:
```yaml
tools:
  - key: my-tool
    name: "My Tool"
    command: "mytool"
    version_cmd: "mytool --version"
    version_pattern: '(\d+\.\d+\.\d+)'
    version_source:
      type: npm
      package: "my-tool"
    install:
      windows:
        winget: "winget install MyTool"
        npm: "npm install -g my-tool"
      darwin:
        brew: "brew install my-tool"
      linux:
        npm: "npm install -g my-tool"
```

## Building from Source

### Prerequisites
- Go 1.21 or later
- Make (optional, for convenience)

### Build Commands
```bash
# Download dependencies
make deps

# Build for current platform
make build

# Build for all platforms
make build-all

# Run tests
make test

# Create release archives
make release
```

### Manual Build
```bash
go build -o agenthelper ./cmd/agenthelper
```

## Project Structure

```
agenthelper/
├── cmd/agenthelper/         # Main entry point
├── internal/
│   ├── commands/            # Cobra CLI commands
│   ├── config/              # Configuration loading
│   ├── manager/             # Business logic
│   ├── platform/            # OS-specific code
│   └── ui/                  # Terminal output
├── config/
│   └── tools.yaml           # Tool definitions
├── scripts/
│   ├── install.ps1          # Windows installer
│   └── install.sh           # Unix installer
├── Makefile
└── README.md
```

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
