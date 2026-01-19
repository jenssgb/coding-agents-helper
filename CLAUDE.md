# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**AgentHelper** - Cross-platform CLI tool manager for coding agents, written in Go. Manages installation, updates, and status of coding agent tools like Claude Code, GitHub Copilot CLI, Aider, VS Code, and more.

## Quick Start

```bash
# Run directly from root
./agenthelper.exe           # Interactive mode (Windows)
./dist/agenthelper          # Interactive mode (Linux/macOS)

# CLI commands
agenthelper status          # Show status of all tools
agenthelper status --json   # JSON output for scripting
agenthelper install <tool>  # Install a specific tool
agenthelper update          # Update all installed tools
agenthelper env             # Show environment report
```

## Building

```bash
# Build for current platform
go build -o dist/agenthelper ./cmd/agenthelper

# Or use Makefile
make build          # Build for current platform
make build-all      # Cross-compile for all platforms
```

## Project Structure

```
├── cmd/agenthelper/        # Entry point (main.go)
├── internal/
│   ├── commands/           # Cobra CLI commands
│   │   ├── root.go         # Root command & interactive mode
│   │   ├── status.go       # Status command
│   │   ├── install.go      # Install command
│   │   ├── update.go       # Update command
│   │   ├── interactive.go  # Interactive menu system
│   │   └── ...
│   ├── manager/            # Business logic
│   │   ├── tool_manager.go # Tool status & operations
│   │   ├── installer.go    # Installation logic
│   │   ├── updater.go      # Update logic
│   │   └── version_checker.go
│   ├── platform/           # OS-specific code
│   │   ├── detector.go     # OS/Arch detection
│   │   ├── packagemanager.go # WinGet, Brew, apt, npm, pip
│   │   └── exec_windows.go # Hidden window support
│   ├── config/             # Configuration
│   │   ├── config.go       # Viper config loading
│   │   └── embedded_tools.yaml
│   └── ui/                 # Terminal UI
│       ├── output.go       # Colored output
│       ├── table.go        # Status tables
│       ├── menu.go         # Interactive menus
│       └── spinner.go      # Progress indicators
├── config/tools.yaml       # External tool definitions (optional)
├── dist/                   # Built binaries
├── scripts/                # Install scripts
├── go.mod
└── Makefile
```

## Adding a New Tool

Edit `internal/config/embedded_tools.yaml` or `config/tools.yaml`:

```yaml
- key: new-tool
  name: "New Tool Name"
  command: "newtool"
  version_cmd: "newtool --version"
  version_pattern: '(\d+\.\d+\.\d+)'
  description: "Description of the tool"
  version_source:
    type: npm          # npm, github, pypi, or unknown
    package: "pkg-name"  # for npm/pypi
    # owner: "user"      # for github
    # repo: "repo"       # for github
  install:
    windows:
      winget: "winget install --id Publisher.App -e"
      npm: "npm install -g package-name"
    darwin:
      brew: "brew install package"
    linux:
      apt: "apt install package"
  env_vars:
    - API_KEY_NAME
```

## Key Dependencies

- **Cobra** - CLI framework
- **Viper** - Configuration management
- **semver** - Version comparison
- **color** - Colored terminal output
- **tablewriter** - ASCII tables

## Supported Tools

Claude Code, GitHub Copilot CLI, OpenCode, OpenAI Codex CLI, Aider, VS Code, VS Code Insiders, Cursor, Warp Terminal, Windows Terminal, Cline, Kiro CLI (Amazon Q)

## Platform Support

- Windows (amd64, arm64)
- macOS (amd64, arm64)
- Linux (amd64, arm64)

Package managers: WinGet (Windows), Homebrew (macOS/Linux), apt (Debian/Ubuntu), pacman (Arch), npm, pip
