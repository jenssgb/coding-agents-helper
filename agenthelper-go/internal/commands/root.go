package commands

import (
	"fmt"
	"os"

	"github.com/fatih/color"
	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/ui"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	version    = "dev"
	cfgFile    string
	jsonOutput bool
	noColor    bool
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "agenthelper",
	Short: "Manage coding agent CLI tools",
	Long: `AgentHelper - Cross-platform CLI tool manager for coding agents

Manages installation, updates, and status of coding agent tools like:
  - Claude Code
  - GitHub Copilot CLI
  - Aider
  - VS Code / Cursor
  - And more...

Run 'agenthelper status' to see all tools and their versions.`,
	Run: func(cmd *cobra.Command, args []string) {
		// If no subcommand is provided, show status
		statusCmd.Run(cmd, args)
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
func Execute() error {
	return rootCmd.Execute()
}

// SetVersion sets the version string from main
func SetVersion(v string) {
	version = v
}

// GetVersion returns the current version
func GetVersion() string {
	return version
}

func init() {
	cobra.OnInitialize(initConfig)

	// Global flags
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.agenthelper.yaml)")
	rootCmd.PersistentFlags().BoolVar(&jsonOutput, "json", false, "output in JSON format")
	rootCmd.PersistentFlags().BoolVar(&noColor, "no-color", false, "disable colored output")

	// Bind flags to viper
	viper.BindPFlag("json", rootCmd.PersistentFlags().Lookup("json"))
	viper.BindPFlag("no-color", rootCmd.PersistentFlags().Lookup("no-color"))
}

func initConfig() {
	// Handle color settings first
	if noColor || viper.GetBool("no-color") {
		ui.SetColorEnabled(false)
	}

	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintln(os.Stderr, color.RedString("Error: %v", err))
			os.Exit(1)
		}

		viper.AddConfigPath(home)
		viper.AddConfigPath(".")
		viper.SetConfigType("yaml")
		viper.SetConfigName(".agenthelper")
	}

	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err == nil {
		if !jsonOutput {
			ui.Debug("Using config file: %s", viper.ConfigFileUsed())
		}
	}

	// Load tool definitions
	if err := config.LoadToolDefinitions(); err != nil {
		if !jsonOutput {
			ui.Warn("Could not load tool definitions: %v", err)
		}
	}
}
