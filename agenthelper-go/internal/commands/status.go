package commands

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/jschneider/agenthelper/internal/manager"
	"github.com/jschneider/agenthelper/internal/platform"
	"github.com/jschneider/agenthelper/internal/ui"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show status of all tools",
	Long: `Display the installation status, versions, and available updates
for all configured coding agent tools.`,
	Run: runStatus,
}

// StatusOutput represents JSON output format
type StatusOutput struct {
	Platform string             `json:"platform"`
	Tools    []ToolStatusOutput `json:"tools"`
}

// ToolStatusOutput represents a single tool's status in JSON
type ToolStatusOutput struct {
	Key            string   `json:"key"`
	Name           string   `json:"name"`
	Installed      bool     `json:"installed"`
	InstalledVer   string   `json:"installed_version,omitempty"`
	LatestVer      string   `json:"latest_version,omitempty"`
	HasUpdate      bool     `json:"has_update"`
	InstallMethods []string `json:"install_methods,omitempty"`
	Command        string   `json:"command"`
}

func init() {
	rootCmd.AddCommand(statusCmd)
}

func runStatus(cmd *cobra.Command, args []string) {
	mgr := manager.NewManager()
	plat := platform.Current()

	if !viper.GetBool("json") {
		ui.PrintBanner(version)
		ui.Print("Platform: %s\n", ui.Cyan(plat.String()))
	}

	// Fetch all tool statuses
	if !viper.GetBool("json") {
		spinner := ui.NewSpinner("Checking tool status...")
		spinner.Start()
		defer spinner.Stop()
	}

	statuses := mgr.GetAllToolStatus()

	if viper.GetBool("json") {
		outputJSON(plat, statuses)
		return
	}

	// Stop spinner and display table
	fmt.Println() // Clear spinner line

	displayStatusTable(statuses)
}

func outputJSON(plat *platform.Platform, statuses []*manager.ToolStatus) {
	output := StatusOutput{
		Platform: plat.String(),
		Tools:    make([]ToolStatusOutput, len(statuses)),
	}

	for i, s := range statuses {
		output.Tools[i] = ToolStatusOutput{
			Key:            s.Tool.Key,
			Name:           s.Tool.Name,
			Installed:      s.IsInstalled,
			InstalledVer:   s.InstalledVer,
			LatestVer:      s.LatestVer,
			HasUpdate:      s.HasUpdate,
			InstallMethods: s.InstallMethods,
			Command:        s.Tool.Command,
		}
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	encoder.Encode(output)
}

func displayStatusTable(statuses []*manager.ToolStatus) {
	table := ui.StatusTable()

	for _, s := range statuses {
		status := getStatusSymbol(s)
		installed := "-"
		latest := "-"
		command := s.Tool.Command

		if s.IsInstalled {
			installed = s.InstalledVer
		}

		if s.LatestVer != "" {
			latest = s.LatestVer
		}

		table.AddRow([]string{
			s.Tool.Name,
			status,
			installed,
			latest,
			command,
		})
	}

	table.Render()

	// Print legend
	fmt.Println()
	fmt.Printf("  %s Installed (up to date)  %s Update available  %s Not installed\n",
		ui.Green(ui.SymbolSuccess),
		ui.Yellow(ui.SymbolWarn),
		ui.Red(ui.SymbolError),
	)
}

func getStatusSymbol(s *manager.ToolStatus) string {
	if !s.IsInstalled {
		return ui.Red(ui.SymbolError + " Not installed")
	}
	if s.HasUpdate {
		return ui.Yellow(ui.SymbolWarn + " Update available")
	}
	return ui.Green(ui.SymbolSuccess + " Up to date")
}
