package commands

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/manager"
	"github.com/jschneider/agenthelper/internal/platform"
	"github.com/jschneider/agenthelper/internal/ui"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var envCmd = &cobra.Command{
	Use:   "env",
	Short: "Show environment report",
	Long: `Display environment information including:
- Platform detection
- Available package managers
- Required environment variables (API keys)
- PATH configuration`,
	Run: runEnv,
}

// EnvReport represents the environment report
type EnvReport struct {
	Platform        PlatformInfo       `json:"platform"`
	PackageManagers []PackageManager   `json:"package_managers"`
	EnvVars         []EnvVarStatus     `json:"env_vars"`
	Prerequisites   []PrerequisiteInfo `json:"prerequisites"`
}

// PlatformInfo contains platform details
type PlatformInfo struct {
	OS     string `json:"os"`
	Arch   string `json:"arch"`
	IsWSL  bool   `json:"is_wsl,omitempty"`
	String string `json:"string"`
}

// PackageManager info
type PackageManager struct {
	Name      string `json:"name"`
	Available bool   `json:"available"`
}

// EnvVarStatus shows env var status
type EnvVarStatus struct {
	Name  string `json:"name"`
	IsSet bool   `json:"is_set"`
	Tool  string `json:"tool,omitempty"`
}

// PrerequisiteInfo shows prerequisite status
type PrerequisiteInfo struct {
	Name      string `json:"name"`
	Available bool   `json:"available"`
	Version   string `json:"version,omitempty"`
}

func init() {
	rootCmd.AddCommand(envCmd)
}

func runEnv(cmd *cobra.Command, args []string) {
	report := buildEnvReport()

	if viper.GetBool("json") {
		outputEnvJSON(report)
		return
	}

	displayEnvReport(report)
}

func buildEnvReport() *EnvReport {
	plat := platform.Current()
	report := &EnvReport{
		Platform: PlatformInfo{
			OS:     string(plat.OS),
			Arch:   string(plat.Arch),
			IsWSL:  plat.IsWSL,
			String: plat.String(),
		},
	}

	// Check package managers
	managers := []struct {
		name    string
		checker func() bool
	}{
		{"WinGet", func() bool { return platform.NewWinGet().IsAvailable() }},
		{"Homebrew", func() bool { return platform.NewHomebrew().IsAvailable() }},
		{"apt", func() bool { return platform.NewApt().IsAvailable() }},
		{"pacman", func() bool { return platform.NewPacman().IsAvailable() }},
		{"npm", func() bool { return platform.NewNpm().IsAvailable() }},
		{"pip", func() bool { return platform.NewPip().IsAvailable() }},
	}

	for _, m := range managers {
		report.PackageManagers = append(report.PackageManagers, PackageManager{
			Name:      m.name,
			Available: m.checker(),
		})
	}

	// Check environment variables from tools
	envVarsChecked := make(map[string]bool)
	for _, tool := range config.GetAllTools() {
		for _, envVar := range tool.EnvVars {
			if envVarsChecked[envVar] {
				continue
			}
			envVarsChecked[envVar] = true
			report.EnvVars = append(report.EnvVars, EnvVarStatus{
				Name:  envVar,
				IsSet: os.Getenv(envVar) != "",
				Tool:  tool.Name,
			})
		}
	}

	// Check prerequisites
	prerequisites := []struct {
		name    string
		command string
	}{
		{"Node.js", "node"},
		{"npm", "npm"},
		{"Python", "python"},
		{"pip", "pip"},
		{"Git", "git"},
	}

	for _, p := range prerequisites {
		available := manager.CommandExists(p.command)
		report.Prerequisites = append(report.Prerequisites, PrerequisiteInfo{
			Name:      p.name,
			Available: available,
		})
	}

	return report
}

func outputEnvJSON(report *EnvReport) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	encoder.Encode(report)
}

func displayEnvReport(report *EnvReport) {
	ui.PrintBanner(version)

	// Platform
	ui.Print("%s Platform", ui.Bold("●"))
	fmt.Printf("  OS:   %s\n", report.Platform.OS)
	fmt.Printf("  Arch: %s\n", report.Platform.Arch)
	if report.Platform.IsWSL {
		fmt.Printf("  WSL:  Yes\n")
	}
	fmt.Println()

	// Package Managers
	ui.Print("%s Package Managers", ui.Bold("●"))
	table := ui.EnvTable()
	for _, pm := range report.PackageManagers {
		status := ui.Red(ui.SymbolError + " Not found")
		if pm.Available {
			status = ui.Green(ui.SymbolSuccess + " Available")
		}
		table.AddRow([]string{pm.Name, status, ""})
	}
	table.Render()
	fmt.Println()

	// Prerequisites
	ui.Print("%s Prerequisites", ui.Bold("●"))
	prereqTable := ui.EnvTable()
	for _, p := range report.Prerequisites {
		status := ui.Red(ui.SymbolError + " Not found")
		if p.Available {
			status = ui.Green(ui.SymbolSuccess + " Available")
		}
		prereqTable.AddRow([]string{p.Name, status, ""})
	}
	prereqTable.Render()
	fmt.Println()

	// Environment Variables
	if len(report.EnvVars) > 0 {
		ui.Print("%s API Keys / Environment Variables", ui.Bold("●"))
		envTable := ui.EnvTable()
		for _, ev := range report.EnvVars {
			status := ui.Red(ui.SymbolError + " Not set")
			if ev.IsSet {
				status = ui.Green(ui.SymbolSuccess + " Set")
			}
			envTable.AddRow([]string{ev.Name, status, "Used by " + ev.Tool})
		}
		envTable.Render()
		fmt.Println()
	}

	// Summary
	missingPrereqs := 0
	for _, p := range report.Prerequisites {
		if !p.Available {
			missingPrereqs++
		}
	}

	missingEnvVars := 0
	for _, e := range report.EnvVars {
		if !e.IsSet {
			missingEnvVars++
		}
	}

	if missingPrereqs > 0 || missingEnvVars > 0 {
		ui.Warn("Issues detected:")
		if missingPrereqs > 0 {
			fmt.Printf("  - %d prerequisite(s) not found\n", missingPrereqs)
		}
		if missingEnvVars > 0 {
			fmt.Printf("  - %d environment variable(s) not set\n", missingEnvVars)
		}
	} else {
		ui.Success("Environment looks good!")
	}
}
