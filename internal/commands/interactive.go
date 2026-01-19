package commands

import (
	"fmt"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/manager"
	"github.com/jschneider/agenthelper/internal/platform"
	"github.com/jschneider/agenthelper/internal/ui"
)

// RunInteractive starts the interactive menu mode
func RunInteractive() {
	ui.PrintBanner(version)

	mainMenu()
}

func mainMenu() {
	for {
		menu := ui.NewMenu("Main Menu")
		menu.AddItem("1", "Status", "Show status of all tools", func() bool {
			showStatusInteractive()
			return false
		})
		menu.AddItem("2", "Install", "Install coding tools", func() bool {
			showInstallMenu()
			return false
		})
		menu.AddItem("3", "Update", "Update installed tools", func() bool {
			showUpdateMenu()
			return false
		})
		menu.AddItem("4", "Repair", "Repair tool installation", func() bool {
			showRepairMenu()
			return false
		})
		menu.AddItem("5", "Run", "Run a coding tool", func() bool {
			showRunMenu()
			return false
		})
		menu.AddItem("6", "Environment", "Show environment report", func() bool {
			showEnvInteractive()
			return false
		})
		menu.AddBackOption("Exit")

		menu.Display()
		return
	}
}

func showStatusInteractive() {
	mgr := manager.NewManager()
	plat := platform.Current()

	fmt.Println()
	ui.Print("Platform: %s", ui.Cyan(plat.String()))
	fmt.Println()

	spinner := ui.NewSpinner("Checking tool status...")
	spinner.Start()
	statuses := mgr.GetAllToolStatus()
	spinner.Stop()

	displayStatusTable(statuses)
	ui.WaitForEnter()
}

func showEnvInteractive() {
	// Reuse env command logic
	runEnvReport()
	ui.WaitForEnter()
}

func runEnvReport() {
	plat := platform.Current()

	fmt.Println()
	ui.Print("%s Platform", ui.Bold("●"))
	fmt.Printf("  OS:   %s\n", plat.OS)
	fmt.Printf("  Arch: %s\n", plat.Arch)
	fmt.Println()

	// Package Managers
	ui.Print("%s Package Managers", ui.Bold("●"))
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
	ui.Print("%s Prerequisites", ui.Bold("●"))
	prereqs := []string{"node", "npm", "python", "pip", "git"}
	for _, p := range prereqs {
		status := ui.Red(ui.SymbolError)
		if manager.CommandExists(p) {
			status = ui.Green(ui.SymbolSuccess)
		}
		fmt.Printf("  %s %s\n", status, p)
	}
}

func showInstallMenu() {
	tools := config.GetAllTools()
	mgr := manager.NewManager()

	options := make([]string, 0, len(tools)+1)
	options = append(options, "All tools")
	for _, t := range tools {
		// Check if installed
		status := ui.Red("not installed")
		if _, err := mgr.GetInstalledVersion(&t); err == nil {
			status = ui.Green("installed")
		}
		options = append(options, fmt.Sprintf("%s (%s)", t.Name, status))
	}

	selected := ui.PromptSelect("Select tool to install", options)
	if selected < 0 {
		return
	}

	if selected == 0 {
		// Install all
		if ui.PromptConfirm("Install all tools?") {
			ui.Info("Installing all tools...")
			results := mgr.InstallAll("")
			for key, result := range results {
				if result.Success {
					ui.Success("%s: %s", key, result.Output)
				} else {
					ui.Error("%s: %v", key, result.Error)
				}
			}
		}
	} else {
		tool := tools[selected-1]
		if ui.PromptConfirm(fmt.Sprintf("Install %s?", tool.Name)) {
			result := mgr.Install(&tool)
			if result.Success {
				ui.Success(result.Output)
			} else {
				ui.Error("Installation failed: %v", result.Error)
			}
		}
	}

	ui.WaitForEnter()
}

func showUpdateMenu() {
	tools := config.GetAllTools()
	mgr := manager.NewManager()

	// Only show installed tools
	installedTools := []config.ToolDefinition{}
	for _, t := range tools {
		if _, err := mgr.GetInstalledVersion(&t); err == nil {
			installedTools = append(installedTools, t)
		}
	}

	if len(installedTools) == 0 {
		ui.Warn("No tools installed")
		ui.WaitForEnter()
		return
	}

	options := make([]string, 0, len(installedTools)+1)
	options = append(options, "All installed tools")
	for _, t := range installedTools {
		ver, _ := mgr.GetInstalledVersion(&t)
		options = append(options, fmt.Sprintf("%s (v%s)", t.Name, ver))
	}

	selected := ui.PromptSelect("Select tool to update", options)
	if selected < 0 {
		return
	}

	if selected == 0 {
		// Update all
		if ui.PromptConfirm("Update all installed tools?") {
			ui.Info("Updating all tools...")
			results := mgr.UpdateAll()
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
		}
	} else {
		tool := installedTools[selected-1]
		if ui.PromptConfirm(fmt.Sprintf("Update %s?", tool.Name)) {
			result := mgr.Update(&tool)
			if result.Success {
				ui.Success(result.Output)
			} else {
				ui.Error("Update failed: %v", result.Error)
			}
		}
	}

	ui.WaitForEnter()
}

func showRepairMenu() {
	tools := config.GetAllTools()
	mgr := manager.NewManager()

	// Only show installed tools
	installedTools := []config.ToolDefinition{}
	for _, t := range tools {
		if _, err := mgr.GetInstalledVersion(&t); err == nil {
			installedTools = append(installedTools, t)
		}
	}

	if len(installedTools) == 0 {
		ui.Warn("No tools installed to repair")
		ui.WaitForEnter()
		return
	}

	options := make([]string, len(installedTools))
	for i, t := range installedTools {
		options[i] = t.Name
	}

	selected := ui.PromptSelect("Select tool to repair", options)
	if selected < 0 {
		return
	}

	tool := installedTools[selected]
	if ui.PromptConfirm(fmt.Sprintf("Repair %s? This will uninstall and reinstall.", tool.Name)) {
		ui.Info("Repairing %s...", tool.Name)

		// Uninstall
		ui.Print("  Uninstalling...")
		mgr.Uninstall(&tool)

		// Reinstall
		ui.Print("  Reinstalling...")
		result := mgr.Install(&tool)
		if result.Success {
			ui.Success("Repair complete: %s", result.Output)
		} else {
			ui.Error("Repair failed: %v", result.Error)
		}
	}

	ui.WaitForEnter()
}

func showRunMenu() {
	tools := config.GetAllTools()
	mgr := manager.NewManager()

	// Only show installed tools
	installedTools := []config.ToolDefinition{}
	for _, t := range tools {
		if _, err := mgr.GetInstalledVersion(&t); err == nil {
			installedTools = append(installedTools, t)
		}
	}

	if len(installedTools) == 0 {
		ui.Warn("No tools installed to run")
		ui.WaitForEnter()
		return
	}

	options := make([]string, len(installedTools))
	for i, t := range installedTools {
		options[i] = fmt.Sprintf("%s (%s)", t.Name, t.Command)
	}

	selected := ui.PromptSelect("Select tool to run", options)
	if selected < 0 {
		return
	}

	tool := installedTools[selected]
	ui.Info("Starting %s...", tool.Name)
	ui.Print("(The tool will open in a new window or take over this terminal)")
	fmt.Println()

	// Run the tool
	runToolDirect(&tool)
}

func runToolDirect(tool *config.ToolDefinition) {
	// Use platform.RunCommand to execute
	_, err := platform.RunCommand(tool.Command)
	if err != nil {
		ui.Error("Failed to run %s: %v", tool.Name, err)
	}
}
