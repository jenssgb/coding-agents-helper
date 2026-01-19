package commands

import (
	"fmt"
	"runtime"

	"github.com/jschneider/agenthelper/internal/platform"
	"github.com/spf13/cobra"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print version information",
	Long:  `Print the version number and build information for AgentHelper.`,
	Run: func(cmd *cobra.Command, args []string) {
		plat := platform.Current()
		fmt.Printf("AgentHelper v%s\n", version)
		fmt.Printf("  Platform: %s\n", plat.String())
		fmt.Printf("  Go:       %s\n", runtime.Version())
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
