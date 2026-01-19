package commands

import (
	"fmt"
	"strings"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/manager"
	"github.com/jschneider/agenthelper/internal/ui"
	"github.com/spf13/cobra"
)

var (
	installMethod string
)

var installCmd = &cobra.Command{
	Use:   "install <tool|all>",
	Short: "Install a coding tool",
	Long: `Install a coding tool by its key name.

Use 'agenthelper install all' to install all available tools.

Examples:
  agenthelper install claude-code
  agenthelper install aider --method pip
  agenthelper install all --method winget`,
	Args: cobra.ExactArgs(1),
	Run:  runInstall,
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) != 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return getToolKeys(), cobra.ShellCompDirectiveNoFileComp
	},
}

func init() {
	rootCmd.AddCommand(installCmd)
	installCmd.Flags().StringVarP(&installMethod, "method", "m", "", "preferred install method (winget, brew, npm, pip, apt)")
}

func runInstall(cmd *cobra.Command, args []string) {
	toolKey := strings.ToLower(args[0])
	mgr := manager.NewManager()

	if toolKey == "all" {
		runInstallAll(mgr)
		return
	}

	tool, ok := config.GetTool(toolKey)
	if !ok {
		ui.Error("Unknown tool: %s", toolKey)
		fmt.Println("\nAvailable tools:")
		for _, t := range config.GetAllTools() {
			fmt.Printf("  - %s (%s)\n", t.Key, t.Name)
		}
		return
	}

	// Check if already installed
	if version, err := mgr.GetInstalledVersion(tool); err == nil {
		ui.Warn("%s is already installed (v%s)", tool.Name, version)
		fmt.Println("Use 'agenthelper update' to update to the latest version.")
		return
	}

	// Install
	var result *manager.InstallResult
	if installMethod != "" {
		// Check if tool has any install methods
		bestMethod, _ := mgr.GetBestInstallMethod(tool)
		if bestMethod == "" {
			ui.Error("No installation method available for %s", tool.Name)
			return
		}
		// Get the specific command for the requested method from the platform's install spec
		osKey := mgr.GetPlatform().GetOSKey()
		spec, ok := tool.Install[osKey]
		if !ok {
			ui.Error("Install method %s not available for %s on this platform", installMethod, tool.Name)
			return
		}
		var command string
		switch installMethod {
		case "winget":
			command = spec.WinGet
		case "brew":
			command = spec.Brew
		case "npm":
			command = spec.Npm
		case "pip":
			command = spec.Pip
		case "apt":
			command = spec.Apt
		}
		if command == "" {
			ui.Error("Install method %s not available for %s", installMethod, tool.Name)
			return
		}
		result = mgr.InstallWithMethod(tool, installMethod, command)
	} else {
		result = mgr.Install(tool)
	}

	if result.Success {
		ui.Success(result.Output)
	} else {
		ui.Error("Installation failed: %v", result.Error)
	}
}

func runInstallAll(mgr *manager.Manager) {
	ui.Info("Installing all tools...")
	results := mgr.InstallAll(installMethod)

	successCount := 0
	failCount := 0

	for key, result := range results {
		tool, _ := config.GetTool(key)
		name := key
		if tool != nil {
			name = tool.Name
		}

		if result.Success {
			successCount++
			if result.Output == "Already installed" {
				ui.Print("  %s %s: already installed", ui.Yellow(ui.SymbolInfo), name)
			} else {
				ui.Print("  %s %s: %s", ui.Green(ui.SymbolSuccess), name, result.Output)
			}
		} else {
			failCount++
			ui.Print("  %s %s: %v", ui.Red(ui.SymbolError), name, result.Error)
		}
	}

	fmt.Println()
	ui.Info("Summary: %d succeeded, %d failed", successCount, failCount)
}

func getToolKeys() []string {
	tools := config.GetAllTools()
	keys := make([]string, len(tools)+1)
	keys[0] = "all"
	for i, t := range tools {
		keys[i+1] = t.Key
	}
	return keys
}
