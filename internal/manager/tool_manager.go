package manager

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
	"sync"

	"github.com/Masterminds/semver/v3"
	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/platform"
)

// ToolStatus represents the current status of a tool
type ToolStatus struct {
	Tool           *config.ToolDefinition
	IsInstalled    bool
	InstalledVer   string
	LatestVer      string
	HasUpdate      bool
	InstallMethods []string
	Error          error
}

// Manager handles tool operations
type Manager struct {
	platform *platform.Platform
	managers []platform.PackageManager
}

// NewManager creates a new tool manager
func NewManager() *Manager {
	return &Manager{
		platform: platform.Current(),
		managers: platform.DetectPackageManagers(),
	}
}

// GetPlatform returns the current platform
func (m *Manager) GetPlatform() *platform.Platform {
	return m.platform
}

// GetToolStatus returns the status of a single tool
func (m *Manager) GetToolStatus(tool *config.ToolDefinition) *ToolStatus {
	status := &ToolStatus{
		Tool: tool,
	}

	// Check if installed
	installedVersion, err := m.GetInstalledVersion(tool)
	if err == nil && installedVersion != "" {
		status.IsInstalled = true
		status.InstalledVer = installedVersion
	}

	// Get latest version
	latestVersion, err := GetLatestVersion(tool)
	if err == nil && latestVersion != "" {
		status.LatestVer = latestVersion

		// Compare versions
		if status.IsInstalled && status.InstalledVer != "" {
			hasUpdate, _ := m.CompareVersions(status.InstalledVer, latestVersion)
			status.HasUpdate = hasUpdate
		}
	}

	// Get available install methods
	status.InstallMethods = m.GetAvailableInstallMethods(tool)

	return status
}

// GetAllToolStatus returns status for all tools
func (m *Manager) GetAllToolStatus() []*ToolStatus {
	tools := config.GetAllTools()
	statuses := make([]*ToolStatus, len(tools))

	var wg sync.WaitGroup
	for i, tool := range tools {
		wg.Add(1)
		go func(idx int, t config.ToolDefinition) {
			defer wg.Done()
			statuses[idx] = m.GetToolStatus(&t)
		}(i, tool)
	}
	wg.Wait()

	return statuses
}

// GetInstalledVersion returns the installed version of a tool
func (m *Manager) GetInstalledVersion(tool *config.ToolDefinition) (string, error) {
	if tool.VersionCmd == "" {
		return "", fmt.Errorf("no version command defined")
	}

	cmd := platform.NewShellCommand(tool.VersionCmd)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("command failed: %w", err)
	}

	output := stdout.String()
	if output == "" {
		output = stderr.String() // Some tools output version to stderr
	}

	version := ExtractVersion(output, tool.VersionPattern)
	if version == "" {
		return "", fmt.Errorf("could not extract version from output")
	}

	return version, nil
}

// CompareVersions compares two semantic versions
// Returns true if latest > installed (update available)
func (m *Manager) CompareVersions(installed, latest string) (bool, error) {
	// Clean up version strings
	installed = strings.TrimPrefix(installed, "v")
	latest = strings.TrimPrefix(latest, "v")

	installedVer, err := semver.NewVersion(installed)
	if err != nil {
		return false, fmt.Errorf("invalid installed version: %w", err)
	}

	latestVer, err := semver.NewVersion(latest)
	if err != nil {
		return false, fmt.Errorf("invalid latest version: %w", err)
	}

	return latestVer.GreaterThan(installedVer), nil
}

// GetAvailableInstallMethods returns install methods available for the current platform
func (m *Manager) GetAvailableInstallMethods(tool *config.ToolDefinition) []string {
	var methods []string
	osKey := m.platform.GetOSKey()

	installSpec, ok := tool.Install[osKey]
	if !ok {
		return methods
	}

	// Check each method
	if installSpec.WinGet != "" && platform.IsWindows() {
		if pm := platform.NewWinGet(); pm.IsAvailable() {
			methods = append(methods, "winget")
		}
	}
	if installSpec.Brew != "" {
		if pm := platform.NewHomebrew(); pm.IsAvailable() {
			methods = append(methods, "brew")
		}
	}
	if installSpec.Apt != "" {
		if pm := platform.NewApt(); pm.IsAvailable() {
			methods = append(methods, "apt")
		}
	}
	if installSpec.Pacman != "" {
		if pm := platform.NewPacman(); pm.IsAvailable() {
			methods = append(methods, "pacman")
		}
	}
	if installSpec.Npm != "" {
		if pm := platform.NewNpm(); pm.IsAvailable() {
			methods = append(methods, "npm")
		}
	}
	if installSpec.Pip != "" {
		if pm := platform.NewPip(); pm.IsAvailable() {
			methods = append(methods, "pip")
		}
	}
	if installSpec.Script != "" {
		methods = append(methods, "script")
	}

	return methods
}

// GetBestInstallMethod returns the preferred install method for a tool
func (m *Manager) GetBestInstallMethod(tool *config.ToolDefinition) (string, string) {
	osKey := m.platform.GetOSKey()
	installSpec, ok := tool.Install[osKey]
	if !ok {
		return "", ""
	}

	// Priority order varies by platform
	if platform.IsWindows() {
		if installSpec.WinGet != "" {
			if pm := platform.NewWinGet(); pm.IsAvailable() {
				return "winget", installSpec.WinGet
			}
		}
	}

	if platform.IsDarwin() {
		if installSpec.Brew != "" {
			if pm := platform.NewHomebrew(); pm.IsAvailable() {
				return "brew", installSpec.Brew
			}
		}
	}

	if platform.IsLinux() {
		if installSpec.Apt != "" {
			if pm := platform.NewApt(); pm.IsAvailable() {
				return "apt", installSpec.Apt
			}
		}
		if installSpec.Brew != "" {
			if pm := platform.NewHomebrew(); pm.IsAvailable() {
				return "brew", installSpec.Brew
			}
		}
		if installSpec.Pacman != "" {
			if pm := platform.NewPacman(); pm.IsAvailable() {
				return "pacman", installSpec.Pacman
			}
		}
	}

	// Cross-platform fallbacks
	if installSpec.Npm != "" {
		if pm := platform.NewNpm(); pm.IsAvailable() {
			return "npm", installSpec.Npm
		}
	}

	if installSpec.Pip != "" {
		if pm := platform.NewPip(); pm.IsAvailable() {
			return "pip", installSpec.Pip
		}
	}

	if installSpec.Script != "" {
		return "script", installSpec.Script
	}

	return "", ""
}

// CommandExists checks if a command is available in PATH
func CommandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}
