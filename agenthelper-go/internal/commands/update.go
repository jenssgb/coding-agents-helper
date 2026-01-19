package commands

import (
	"fmt"
	"strings"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/manager"
	"github.com/jschneider/agenthelper/internal/ui"
	"github.com/spf13/cobra"
)

var updateCmd = &cobra.Command{
	Use:   "update [tool|all]",
	Short: "Update installed tools",
	Long: `Update one or all installed coding tools to their latest versions.

Examples:
  agenthelper update claude-code
  agenthelper update all
  agenthelper update  # same as 'update all'`,
	Args: cobra.MaximumNArgs(1),
	Run:  runUpdate,
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) != 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return getToolKeys(), cobra.ShellCompDirectiveNoFileComp
	},
}

func init() {
	rootCmd.AddCommand(updateCmd)
}

func runUpdate(cmd *cobra.Command, args []string) {
	mgr := manager.NewManager()

	toolKey := "all"
	if len(args) > 0 {
		toolKey = strings.ToLower(args[0])
	}

	if toolKey == "all" {
		runUpdateAll(mgr)
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

	// Check if installed
	if _, err := mgr.GetInstalledVersion(tool); err != nil {
		ui.Error("%s is not installed", tool.Name)
		fmt.Println("Use 'agenthelper install' to install it first.")
		return
	}

	result := mgr.Update(tool)

	if result.Success {
		if result.WasUpToDate {
			ui.Info(result.Output)
		} else {
			ui.Success(result.Output)
		}
	} else {
		ui.Error("Update failed: %v", result.Error)
	}
}

func runUpdateAll(mgr *manager.Manager) {
	ui.Info("Updating all installed tools...")
	results := mgr.UpdateAll()

	updatedCount := 0
	upToDateCount := 0
	failCount := 0
	notInstalledCount := 0

	for key, result := range results {
		tool, _ := config.GetTool(key)
		name := key
		if tool != nil {
			name = tool.Name
		}

		if result.Error != nil && strings.Contains(result.Error.Error(), "not installed") {
			notInstalledCount++
			continue
		}

		if result.Success {
			if result.WasUpToDate {
				upToDateCount++
				ui.Print("  %s %s: up to date (v%s)", ui.Green(ui.SymbolSuccess), name, result.OldVersion)
			} else {
				updatedCount++
				ui.Print("  %s %s: updated v%s → v%s", ui.Green(ui.SymbolSuccess), name, result.OldVersion, result.NewVersion)
			}
		} else {
			failCount++
			ui.Print("  %s %s: %v", ui.Red(ui.SymbolError), name, result.Error)
		}
	}

	fmt.Println()
	ui.Info("Summary: %d updated, %d up to date, %d failed, %d not installed",
		updatedCount, upToDateCount, failCount, notInstalledCount)
}
