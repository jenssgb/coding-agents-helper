package commands

import (
	"fmt"
	"strings"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/manager"
	"github.com/jschneider/agenthelper/internal/ui"
	"github.com/spf13/cobra"
)

var repairCmd = &cobra.Command{
	Use:   "repair <tool>",
	Short: "Repair a tool installation",
	Long: `Repair a tool installation by uninstalling and reinstalling it.

This is useful when a tool is in a broken state.

Examples:
  agenthelper repair claude-code
  agenthelper repair aider`,
	Args: cobra.ExactArgs(1),
	Run:  runRepair,
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) != 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return getInstalledToolKeys(), cobra.ShellCompDirectiveNoFileComp
	},
}

func init() {
	rootCmd.AddCommand(repairCmd)
}

func runRepair(cmd *cobra.Command, args []string) {
	toolKey := strings.ToLower(args[0])
	mgr := manager.NewManager()

	tool, ok := config.GetTool(toolKey)
	if !ok {
		ui.Error("Unknown tool: %s", toolKey)
		fmt.Println("\nAvailable tools:")
		for _, t := range config.GetAllTools() {
			fmt.Printf("  - %s (%s)\n", t.Key, t.Name)
		}
		return
	}

	ui.Info("Repairing %s...", tool.Name)

	// Step 1: Try to uninstall
	ui.Print("  Step 1: Uninstalling...")
	uninstallResult := mgr.Uninstall(tool)
	if uninstallResult.Success {
		ui.Print("    %s Uninstalled", ui.Green(ui.SymbolSuccess))
	} else {
		ui.Print("    %s Uninstall failed (continuing anyway): %v", ui.Yellow(ui.SymbolWarn), uninstallResult.Error)
	}

	// Step 2: Reinstall
	ui.Print("  Step 2: Reinstalling...")
	installResult := mgr.Install(tool)
	if installResult.Success {
		ui.Print("    %s Reinstalled", ui.Green(ui.SymbolSuccess))
	} else {
		ui.Error("Repair failed: %v", installResult.Error)
		return
	}

	// Step 3: Verify
	ui.Print("  Step 3: Verifying...")
	version, err := mgr.GetInstalledVersion(tool)
	if err != nil {
		ui.Error("Repair completed but verification failed: %v", err)
		return
	}

	ui.Success("Repair complete. %s v%s is now installed.", tool.Name, version)
}

func getInstalledToolKeys() []string {
	mgr := manager.NewManager()
	tools := config.GetAllTools()
	var keys []string
	for _, t := range tools {
		if _, err := mgr.GetInstalledVersion(&t); err == nil {
			keys = append(keys, t.Key)
		}
	}
	return keys
}
