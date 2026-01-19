package config

import (
	"embed"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"
)

//go:embed embedded_tools.yaml
var embeddedConfig embed.FS

// Config holds the application configuration
type Config struct {
	Tools []ToolDefinition `yaml:"tools" mapstructure:"tools"`
}

// ToolDefinition defines a coding agent tool
type ToolDefinition struct {
	Key            string                 `yaml:"key" mapstructure:"key"`
	Name           string                 `yaml:"name" mapstructure:"name"`
	Command        string                 `yaml:"command" mapstructure:"command"`
	Subcommand     string                 `yaml:"subcommand,omitempty" mapstructure:"subcommand"`
	VersionCmd     string                 `yaml:"version_cmd" mapstructure:"version_cmd"`
	VersionPattern string                 `yaml:"version_pattern" mapstructure:"version_pattern"`
	VersionSource  VersionSource          `yaml:"version_source" mapstructure:"version_source"`
	Install        map[string]InstallSpec `yaml:"install" mapstructure:"install"`
	Uninstall      map[string]InstallSpec `yaml:"uninstall,omitempty" mapstructure:"uninstall"`
	EnvVars        []string               `yaml:"env_vars,omitempty" mapstructure:"env_vars"`
	Description    string                 `yaml:"description,omitempty" mapstructure:"description"`
}

// VersionSource defines where to check for latest versions
type VersionSource struct {
	Type    string `yaml:"type" mapstructure:"type"` // npm, github, pypi, vscode-update, cursor-todesktop, unknown
	Package string `yaml:"package,omitempty" mapstructure:"package"`
	Owner   string `yaml:"owner,omitempty" mapstructure:"owner"`
	Repo    string `yaml:"repo,omitempty" mapstructure:"repo"`
	Channel string `yaml:"channel,omitempty" mapstructure:"channel"` // for vscode-update: stable, insider
}

// InstallSpec defines installation commands for different package managers
type InstallSpec struct {
	WinGet string `yaml:"winget,omitempty" mapstructure:"winget"`
	Npm    string `yaml:"npm,omitempty" mapstructure:"npm"`
	Brew   string `yaml:"brew,omitempty" mapstructure:"brew"`
	Apt    string `yaml:"apt,omitempty" mapstructure:"apt"`
	Pacman string `yaml:"pacman,omitempty" mapstructure:"pacman"`
	Pip    string `yaml:"pip,omitempty" mapstructure:"pip"`
	Script string `yaml:"script,omitempty" mapstructure:"script"`
}

var (
	// AppConfig holds the loaded configuration
	AppConfig *Config
	// ToolsMap provides quick access to tools by key
	ToolsMap map[string]*ToolDefinition
)

// LoadToolDefinitions loads tool definitions from config file or embedded defaults
func LoadToolDefinitions() error {
	var configData []byte
	var err error

	// Try to load from external config file first
	configPaths := []string{
		"tools.yaml",
		"config/tools.yaml",
	}

	// Add home directory config
	if home, err := os.UserHomeDir(); err == nil {
		configPaths = append(configPaths, filepath.Join(home, ".agenthelper", "tools.yaml"))
	}

	for _, path := range configPaths {
		if data, err := os.ReadFile(path); err == nil {
			configData = data
			break
		}
	}

	// Fall back to embedded config
	if configData == nil {
		configData, err = embeddedConfig.ReadFile("embedded_tools.yaml")
		if err != nil {
			return fmt.Errorf("failed to load embedded config: %w", err)
		}
	}

	// Parse YAML
	AppConfig = &Config{}
	if err := yaml.Unmarshal(configData, AppConfig); err != nil {
		return fmt.Errorf("failed to parse config: %w", err)
	}

	// Build tools map for quick access
	ToolsMap = make(map[string]*ToolDefinition)
	for i := range AppConfig.Tools {
		tool := &AppConfig.Tools[i]
		ToolsMap[tool.Key] = tool
	}

	return nil
}

// GetTool returns a tool by key
func GetTool(key string) (*ToolDefinition, bool) {
	tool, ok := ToolsMap[key]
	return tool, ok
}

// GetAllTools returns all tool definitions
func GetAllTools() []ToolDefinition {
	if AppConfig == nil {
		return nil
	}
	return AppConfig.Tools
}

// GetViper returns the viper instance for additional config
func GetViper() *viper.Viper {
	return viper.GetViper()
}
