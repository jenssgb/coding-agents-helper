package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/manager"
	"github.com/jschneider/agenthelper/internal/platform"
	"github.com/jschneider/agenthelper/internal/ui"
	"github.com/spf13/cobra"
)

var runCmd = &cobra.Command{
	Use:   "run <tool> [args...]",
	Short: "Run a coding tool",
	Long: `Run a coding tool with optional arguments.

Any arguments after the tool name are passed directly to the tool.

Examples:
  agenthelper run claude-code
  agenthelper run aider --help
  agenthelper run vscode .`,
	Args:               cobra.MinimumNArgs(1),
	DisableFlagParsing: true,
	Run:                runTool,
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) != 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return getInstalledToolKeys(), cobra.ShellCompDirectiveNoFileComp
	},
}

func init() {
	rootCmd.AddCommand(runCmd)
}

func runTool(cmd *cobra.Command, args []string) {
	toolKey := strings.ToLower(args[0])
	toolArgs := args[1:]

	tool, ok := config.GetTool(toolKey)
	if !ok {
		ui.Error("Unknown tool: %s", toolKey)
		fmt.Println("\nAvailable tools:")
		for _, t := range config.GetAllTools() {
			fmt.Printf("  - %s (%s)\n", t.Key, t.Name)
		}
		os.Exit(1)
	}

	mgr := manager.NewManager()

	// Check if installed
	if _, err := mgr.GetInstalledVersion(tool); err != nil {
		ui.Error("%s is not installed", tool.Name)
		fmt.Println("Use 'agenthelper install' to install it first.")
		os.Exit(1)
	}

	// Build command
	command := tool.Command
	if tool.Subcommand != "" {
		toolArgs = append([]string{tool.Subcommand}, toolArgs...)
	}

	// Execute the tool
	var execCmd *exec.Cmd
	if platform.IsWindows() {
		// On Windows, try direct execution first
		execCmd = exec.Command(command, toolArgs...)
	} else {
		execCmd = exec.Command(command, toolArgs...)
	}

	execCmd.Stdin = os.Stdin
	execCmd.Stdout = os.Stdout
	execCmd.Stderr = os.Stderr

	err := execCmd.Run()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		ui.Error("Failed to run %s: %v", tool.Name, err)
		os.Exit(1)
	}
}
