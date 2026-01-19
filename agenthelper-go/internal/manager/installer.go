package manager

import (
	"bytes"
	"fmt"

	"github.com/jschneider/agenthelper/internal/config"
	"github.com/jschneider/agenthelper/internal/platform"
	"github.com/jschneider/agenthelper/internal/ui"
)

// InstallResult represents the result of an installation
type InstallResult struct {
	Success bool
	Method  string
	Output  string
	Error   error
}

// Install installs a tool using the best available method
func (m *Manager) Install(tool *config.ToolDefinition) *InstallResult {
	method, command := m.GetBestInstallMethod(tool)
	if method == "" {
		return &InstallResult{
			Success: false,
			Error:   fmt.Errorf("no installation method available for %s on %s", tool.Name, m.platform.String()),
		}
	}

	return m.InstallWithMethod(tool, method, command)
}

// InstallWithMethod installs a tool using a specific method
func (m *Manager) InstallWithMethod(tool *config.ToolDefinition, method, command string) *InstallResult {
	result := &InstallResult{
		Method: method,
	}

	ui.Info("Installing %s using %s...", tool.Name, method)

	cmd := platform.NewShellCommand(command)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	result.Output = stdout.String()
	if result.Output == "" {
		result.Output = stderr.String()
	}

	if err != nil {
		result.Success = false
		result.Error = fmt.Errorf("installation failed: %w\n%s", err, stderr.String())
		return result
	}

	// Verify installation
	version, err := m.GetInstalledVersion(tool)
	if err != nil {
		result.Success = false
		result.Error = fmt.Errorf("installation completed but tool not found: %w", err)
		return result
	}

	result.Success = true
	result.Output = fmt.Sprintf("Successfully installed %s version %s", tool.Name, version)
	return result
}

// InstallAll installs all tools
func (m *Manager) InstallAll(preferredMethod string) map[string]*InstallResult {
	results := make(map[string]*InstallResult)
	tools := config.GetAllTools()

	for _, tool := range tools {
		t := tool // Create a copy for the closure

		// Check if already installed
		if _, err := m.GetInstalledVersion(&t); err == nil {
			results[t.Key] = &InstallResult{
				Success: true,
				Output:  "Already installed",
			}
			continue
		}

		// Install
		if preferredMethod != "" {
			osKey := m.platform.GetOSKey()
			if spec, ok := t.Install[osKey]; ok {
				var cmd string
				switch preferredMethod {
				case "winget":
					cmd = spec.WinGet
				case "brew":
					cmd = spec.Brew
				case "npm":
					cmd = spec.Npm
				case "pip":
					cmd = spec.Pip
				case "apt":
					cmd = spec.Apt
				}
				if cmd != "" {
					results[t.Key] = m.InstallWithMethod(&t, preferredMethod, cmd)
					continue
				}
			}
		}

		results[t.Key] = m.Install(&t)
	}

	return results
}

// Uninstall removes a tool
func (m *Manager) Uninstall(tool *config.ToolDefinition) *InstallResult {
	result := &InstallResult{}

	osKey := m.platform.GetOSKey()
	uninstallSpec, ok := tool.Uninstall[osKey]
	if !ok {
		return &InstallResult{
			Success: false,
			Error:   fmt.Errorf("no uninstall method available for %s on %s", tool.Name, m.platform.String()),
		}
	}

	// Try uninstall methods in order
	var command string
	var method string

	if platform.IsWindows() && uninstallSpec.WinGet != "" {
		method = "winget"
		command = uninstallSpec.WinGet
	} else if uninstallSpec.Brew != "" {
		method = "brew"
		command = uninstallSpec.Brew
	} else if uninstallSpec.Npm != "" {
		method = "npm"
		command = uninstallSpec.Npm
	} else if uninstallSpec.Pip != "" {
		method = "pip"
		command = uninstallSpec.Pip
	}

	if command == "" {
		return &InstallResult{
			Success: false,
			Error:   fmt.Errorf("no uninstall command found for %s", tool.Name),
		}
	}

	ui.Info("Uninstalling %s using %s...", tool.Name, method)

	cmd := platform.NewShellCommand(command)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	result.Output = stdout.String()
	result.Method = method

	if err != nil {
		result.Success = false
		result.Error = fmt.Errorf("uninstall failed: %w\n%s", err, stderr.String())
		return result
	}

	result.Success = true
	result.Output = fmt.Sprintf("Successfully uninstalled %s", tool.Name)
	return result
}
