package commands

import (
	"fmt"
	"os"
	"os/signal"
	"sort"
	"strings"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/manager"
	"github.com/jschneider/agenthelper/internal/platform"
	"github.com/jschneider/agenthelper/internal/ui"
)

// RunPromptMode starts the Claude Code style prompt mode
func RunPromptMode() {
	plat := platform.Current()

	// Print banner with platform info
	ui.PrintPromptBanner(version, plat.String())

	// Show initial status
	refreshStatus()

	// Setup Ctrl+C handler
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt)
	go func() {
		<-sigChan
		fmt.Println("\nGoodbye!")
		os.Exit(0)
	}()

	// Main command loop
	for {
		input := ui.PromptCommand("agenthelper> ")
		cmd, args := ui.ParseCommand(input)

		if cmd == "" {
			continue
		}

		// Handle commands (with or without leading slash)
		switch strings.TrimPrefix(cmd, "/") {
		case "help", "h", "?":
			ui.ShowCommandHelp()
		case "status", "s":
			refreshStatus()
		case "install", "i":
			handleInstall(args)
		case "update", "u":
			handleUpdate(args)
		case "repair", "r":
			handleRepair(args)
		case "run":
			handleRun(args)
		case "env", "e":
			showEnvReport()
		case "exit", "quit", "q":
			fmt.Println("Goodbye!")
			return
		default:
			ui.Warn("Unknown command: %s - Type /help for available commands", cmd)
		}
	}
}

func refreshStatus() {
	mgr := manager.NewManager()

	spinner := ui.NewSpinner("Checking tool status...")
	spinner.Start()
	statuses := mgr.GetAllToolStatus()
	spinner.Stop()

	displayCompactStatus(statuses)
}

func displayCompactStatus(statuses []*manager.ToolStatus) {
	fmt.Println()

	// Sort by status: OK -> Update -> Missing
	sort.Slice(statuses, func(i, j int) bool {
		return statusPriority(statuses[i]) < statusPriority(statuses[j])
	})

	table := ui.CompactStatusTable()

	for _, s := range statuses {
		symbol := getStatusSymbolCompact(s)
		current := "-"
		latest := "-"
		runWith := s.Tool.Command

		if s.IsInstalled {
			current = s.InstalledVer
		}
		if s.LatestVer != "" {
			latest = s.LatestVer
		}

		table.AddRow([]string{
			fmt.Sprintf("%s %s", symbol, s.Tool.Name),
			current,
			latest,
			runWith,
		})
	}

	table.Render()

	// Print compact legend
	fmt.Println()
	fmt.Printf("  %s OK  %s Update  %s Missing\n",
		ui.Green(ui.SymbolSuccess),
		ui.Yellow(ui.SymbolUpdate),
		ui.Red(ui.SymbolError),
	)
	fmt.Println()
}

// statusPriority returns sort priority: 0=OK, 1=Update, 2=Missing
func statusPriority(s *manager.ToolStatus) int {
	if s.IsInstalled && !s.HasUpdate {
		return 0 // OK
	}
	if s.IsInstalled && s.HasUpdate {
		return 1 // Update available
	}
	return 2 // Not installed
}

func getStatusSymbolCompact(s *manager.ToolStatus) string {
	if !s.IsInstalled {
		return ui.Red(ui.SymbolError)
	}
	if s.HasUpdate {
		return ui.Yellow(ui.SymbolUpdate)
	}
	return ui.Green(ui.SymbolSuccess)
}

func handleInstall(args []string) {
	if len(args) == 0 {
		ui.Warn("Usage: /install <tool-key>")
		ui.Print("Available tools:")
		listAvailableTools()
		return
	}

	toolKey := args[0]
	tool, ok := config.GetTool(toolKey)
	if !ok {
		ui.Error("Unknown tool: %s", toolKey)
		listAvailableTools()
		return
	}

	mgr := manager.NewManager()

	// Check if already installed
	if ver, err := mgr.GetInstalledVersion(tool); err == nil {
		ui.Warn("%s is already installed (v%s)", tool.Name, ver)
		return
	}

	ui.Info("Installing %s...", tool.Name)
	result := mgr.Install(tool)
	if result.Success {
		ui.Success("Installed %s: %s", tool.Name, result.Output)
	} else {
		ui.Error("Failed to install %s: %v", tool.Name, result.Error)
	}
}

func handleUpdate(args []string) {
	mgr := manager.NewManager()

	if len(args) == 0 {
		// Update all installed tools
		ui.Info("Updating all installed tools...")

		spinner := ui.NewSpinner("Checking for updates...")
		spinner.Start()
		results := mgr.UpdateAll()
		spinner.Stop()

		for key, result := range results {
			if result.Success {
				if result.WasUpToDate {
					ui.Info("%s: already up to date", key)
				} else {
					ui.Success("%s: %s", key, result.Output)
				}
			} else if result.Error != nil {
				ui.Error("%s: %v", key, result.Error)
			}
		}
		return
	}

	toolKey := args[0]
	tool, ok := config.GetTool(toolKey)
	if !ok {
		ui.Error("Unknown tool: %s", toolKey)
		listAvailableTools()
		return
	}

	// Check if installed
	if _, err := mgr.GetInstalledVersion(tool); err != nil {
		ui.Error("%s is not installed", tool.Name)
		return
	}

	ui.Info("Updating %s...", tool.Name)
	result := mgr.Update(tool)
	if result.Success {
		if result.WasUpToDate {
			ui.Info("%s is already up to date", tool.Name)
		} else {
			ui.Success("Updated %s: %s", tool.Name, result.Output)
		}
	} else {
		ui.Error("Failed to update %s: %v", tool.Name, result.Error)
	}
}

func handleRepair(args []string) {
	if len(args) == 0 {
		ui.Warn("Usage: /repair <tool-key>")
		return
	}

	toolKey := args[0]
	tool, ok := config.GetTool(toolKey)
	if !ok {
		ui.Error("Unknown tool: %s", toolKey)
		listAvailableTools()
		return
	}

	mgr := manager.NewManager()

	// Check if installed
	if _, err := mgr.GetInstalledVersion(tool); err != nil {
		ui.Error("%s is not installed", tool.Name)
		return
	}

	if !ui.PromptConfirm(fmt.Sprintf("Repair %s? This will uninstall and reinstall", tool.Name)) {
		return
	}

	ui.Info("Repairing %s...", tool.Name)

	// Uninstall
	ui.Print("  Uninstalling...")
	mgr.Uninstall(tool)

	// Reinstall
	ui.Print("  Reinstalling...")
	result := mgr.Install(tool)
	if result.Success {
		ui.Success("Repaired %s: %s", tool.Name, result.Output)
	} else {
		ui.Error("Failed to repair %s: %v", tool.Name, result.Error)
	}
}

func handleRun(args []string) {
	if len(args) == 0 {
		ui.Warn("Usage: /run <tool-key>")
		listAvailableTools()
		return
	}

	toolKey := args[0]
	tool, ok := config.GetTool(toolKey)
	if !ok {
		ui.Error("Unknown tool: %s", toolKey)
		listAvailableTools()
		return
	}

	mgr := manager.NewManager()

	// Check if installed
	if _, err := mgr.GetInstalledVersion(tool); err != nil {
		ui.Error("%s is not installed", tool.Name)
		return
	}

	ui.Info("Starting %s...", tool.Name)
	runToolDirect(tool)
}

func showEnvReport() {
	plat := platform.Current()

	fmt.Println()
	ui.Print("%s Platform", ui.Bold("*"))
	fmt.Printf("  OS:   %s\n", plat.OS)
	fmt.Printf("  Arch: %s\n", plat.Arch)
	fmt.Println()

	// Package Managers
	ui.Print("%s Package Managers", ui.Bold("*"))
	managers := []struct {
		name    string
		checker func() bool
	}{
		{"WinGet", func() bool { return platform.NewWinGet().IsAvailable() }},
		{"Homebrew", func() bool { return platform.NewHomebrew().IsAvailable() }},
		{"npm", func() bool { return platform.NewNpm().IsAvailable() }},
		{"pip", func() bool { return platform.NewPip().IsAvailable() }},
	}

	for _, m := range managers {
		status := ui.Red(ui.SymbolError)
		if m.checker() {
			status = ui.Green(ui.SymbolSuccess)
		}
		fmt.Printf("  %s %s\n", status, m.name)
	}
	fmt.Println()

	// Prerequisites
	ui.Print("%s Prerequisites", ui.Bold("*"))
	prereqs := []string{"node", "npm", "python", "pip", "git"}
	for _, p := range prereqs {
		status := ui.Red(ui.SymbolError)
		if manager.CommandExists(p) {
			status = ui.Green(ui.SymbolSuccess)
		}
		fmt.Printf("  %s %s\n", status, p)
	}
	fmt.Println()
}

func listAvailableTools() {
	tools := config.GetAllTools()
	fmt.Println()
	for _, t := range tools {
		fmt.Printf("  %s - %s\n", ui.Cyan(t.Key), t.Name)
	}
	fmt.Println()
}

func runToolDirect(tool *config.ToolDefinition) {
	// Use platform.RunCommand to execute
	_, err := platform.RunCommand(tool.Command)
	if err != nil {
		ui.Error("Failed to run %s: %v", tool.Name, err)
	}
}
