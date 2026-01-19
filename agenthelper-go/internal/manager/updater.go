package manager

import (
	"bytes"
	"fmt"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/platform"
	"github.com/jschneider/agenthelper/internal/ui"
)

// UpdateResult represents the result of an update
type UpdateResult struct {
	Success     bool
	Method      string
	OldVersion  string
	NewVersion  string
	Output      string
	Error       error
	WasUpToDate bool
}

// Update updates a tool to the latest version
func (m *Manager) Update(tool *config.ToolDefinition) *UpdateResult {
	result := &UpdateResult{}

	// Get current version
	currentVersion, err := m.GetInstalledVersion(tool)
	if err != nil {
		return &UpdateResult{
			Success: false,
			Error:   fmt.Errorf("tool not installed: %w", err),
		}
	}
	result.OldVersion = currentVersion

	// Get latest version
	latestVersion, err := GetLatestVersion(tool)
	if err != nil {
		// If we can't get the latest version, try to update anyway
		ui.Warn("Could not fetch latest version, attempting update anyway")
	} else {
		result.NewVersion = latestVersion

		// Check if update is needed
		hasUpdate, err := m.CompareVersions(currentVersion, latestVersion)
		if err == nil && !hasUpdate {
			result.Success = true
			result.WasUpToDate = true
			result.Output = fmt.Sprintf("%s is already up to date (v%s)", tool.Name, currentVersion)
			return result
		}
	}

	// Get update command
	method, command := m.GetBestInstallMethod(tool)
	if method == "" {
		return &UpdateResult{
			Success: false,
			Error:   fmt.Errorf("no update method available for %s on %s", tool.Name, m.platform.String()),
		}
	}

	// For npm packages, modify command to update
	if method == "npm" {
		// npm install -g already updates to latest
	}

	ui.Info("Updating %s using %s...", tool.Name, method)

	// For winget, use upgrade command
	if platform.IsWindows() && method == "winget" {
		osKey := m.platform.GetOSKey()
		if spec, ok := tool.Install[osKey]; ok && spec.WinGet != "" {
			// Replace 'install' with 'upgrade' in the command
			command = replaceWingetInstallWithUpgrade(spec.WinGet)
		}
	}

	cmd := platform.NewShellCommand(command)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err = cmd.Run()
	result.Output = stdout.String()
	result.Method = method

	if err != nil {
		result.Success = false
		result.Error = fmt.Errorf("update failed: %w\n%s", err, stderr.String())
		return result
	}

	// Verify update
	newVersion, err := m.GetInstalledVersion(tool)
	if err != nil {
		result.Success = false
		result.Error = fmt.Errorf("update completed but could not verify: %w", err)
		return result
	}

	result.Success = true
	result.NewVersion = newVersion
	if result.OldVersion == result.NewVersion {
		result.WasUpToDate = true
		result.Output = fmt.Sprintf("%s is already at latest version (v%s)", tool.Name, newVersion)
	} else {
		result.Output = fmt.Sprintf("Successfully updated %s from v%s to v%s", tool.Name, result.OldVersion, result.NewVersion)
	}

	return result
}

// UpdateAll updates all installed tools
func (m *Manager) UpdateAll() map[string]*UpdateResult {
	results := make(map[string]*UpdateResult)
	tools := config.GetAllTools()

	for _, tool := range tools {
		t := tool // Create a copy for the closure

		// Check if installed
		if _, err := m.GetInstalledVersion(&t); err != nil {
			results[t.Key] = &UpdateResult{
				Success: false,
				Error:   fmt.Errorf("not installed"),
			}
			continue
		}

		results[t.Key] = m.Update(&t)
	}

	return results
}

// replaceWingetInstallWithUpgrade converts a winget install command to upgrade
func replaceWingetInstallWithUpgrade(installCmd string) string {
	// Simple replacement - might need more sophisticated parsing
	if len(installCmd) > 6 && installCmd[:6] == "winget" {
		return "winget upgrade" + installCmd[14:] // Replace "winget install" with "winget upgrade"
	}
	return installCmd
}
