package platform

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// PackageManager defines the interface for package managers
type PackageManager interface {
	Name() string
	IsAvailable() bool
	Install(command string) error
	Update(command string) error
	Uninstall(command string) error
}

// BasePackageManager provides common functionality
type BasePackageManager struct {
	name    string
	command string
}

// runCommand executes a command and returns output
func runCommand(command string) (string, error) {
	var cmd *exec.Cmd

	if IsWindows() {
		cmd = exec.Command("cmd", "/C", command)
		hideWindow(cmd) // Hide console window on Windows
	} else {
		cmd = exec.Command("sh", "-c", command)
	}

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("%v: %s", err, stderr.String())
	}

	return strings.TrimSpace(stdout.String()), nil
}

// RunCommand is a public wrapper for running commands (hides window on Windows)
func RunCommand(command string) (string, error) {
	return runCommand(command)
}

// NewHiddenCommand creates an exec.Cmd that won't show a console window on Windows
func NewHiddenCommand(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	if IsWindows() {
		hideWindow(cmd)
	}
	return cmd
}

// NewShellCommand creates a shell command that won't show a console window on Windows
func NewShellCommand(command string) *exec.Cmd {
	var cmd *exec.Cmd
	if IsWindows() {
		cmd = exec.Command("cmd", "/C", command)
		hideWindow(cmd)
	} else {
		cmd = exec.Command("sh", "-c", command)
	}
	return cmd
}

// commandExists checks if a command is available
func commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

// WinGet implements PackageManager for Windows Package Manager
type WinGet struct {
	BasePackageManager
}

func NewWinGet() *WinGet {
	return &WinGet{
		BasePackageManager{name: "WinGet", command: "winget"},
	}
}

func (w *WinGet) Name() string { return w.name }

func (w *WinGet) IsAvailable() bool {
	return IsWindows() && commandExists("winget")
}

func (w *WinGet) Install(command string) error {
	_, err := runCommand(command)
	return err
}

func (w *WinGet) Update(command string) error {
	_, err := runCommand(command)
	return err
}

func (w *WinGet) Uninstall(command string) error {
	_, err := runCommand(command)
	return err
}

// Homebrew implements PackageManager for macOS/Linux Homebrew
type Homebrew struct {
	BasePackageManager
}

func NewHomebrew() *Homebrew {
	return &Homebrew{
		BasePackageManager{name: "Homebrew", command: "brew"},
	}
}

func (h *Homebrew) Name() string { return h.name }

func (h *Homebrew) IsAvailable() bool {
	return (IsDarwin() || IsLinux()) && commandExists("brew")
}

func (h *Homebrew) Install(command string) error {
	_, err := runCommand(command)
	return err
}

func (h *Homebrew) Update(command string) error {
	_, err := runCommand(command)
	return err
}

func (h *Homebrew) Uninstall(command string) error {
	_, err := runCommand(command)
	return err
}

// Apt implements PackageManager for Debian/Ubuntu apt
type Apt struct {
	BasePackageManager
}

func NewApt() *Apt {
	return &Apt{
		BasePackageManager{name: "apt", command: "apt"},
	}
}

func (a *Apt) Name() string { return a.name }

func (a *Apt) IsAvailable() bool {
	return IsLinux() && commandExists("apt")
}

func (a *Apt) Install(command string) error {
	_, err := runCommand(command)
	return err
}

func (a *Apt) Update(command string) error {
	_, err := runCommand(command)
	return err
}

func (a *Apt) Uninstall(command string) error {
	_, err := runCommand(command)
	return err
}

// Pacman implements PackageManager for Arch Linux
type Pacman struct {
	BasePackageManager
}

func NewPacman() *Pacman {
	return &Pacman{
		BasePackageManager{name: "pacman", command: "pacman"},
	}
}

func (p *Pacman) Name() string { return p.name }

func (p *Pacman) IsAvailable() bool {
	return IsLinux() && commandExists("pacman")
}

func (p *Pacman) Install(command string) error {
	_, err := runCommand(command)
	return err
}

func (p *Pacman) Update(command string) error {
	_, err := runCommand(command)
	return err
}

func (p *Pacman) Uninstall(command string) error {
	_, err := runCommand(command)
	return err
}

// Npm implements PackageManager for Node.js npm
type Npm struct {
	BasePackageManager
}

func NewNpm() *Npm {
	return &Npm{
		BasePackageManager{name: "npm", command: "npm"},
	}
}

func (n *Npm) Name() string { return n.name }

func (n *Npm) IsAvailable() bool {
	return commandExists("npm")
}

func (n *Npm) Install(command string) error {
	_, err := runCommand(command)
	return err
}

func (n *Npm) Update(command string) error {
	_, err := runCommand(command)
	return err
}

func (n *Npm) Uninstall(command string) error {
	_, err := runCommand(command)
	return err
}

// Pip implements PackageManager for Python pip
type Pip struct {
	BasePackageManager
}

func NewPip() *Pip {
	return &Pip{
		BasePackageManager{name: "pip", command: "pip"},
	}
}

func (p *Pip) Name() string { return p.name }

func (p *Pip) IsAvailable() bool {
	return commandExists("pip") || commandExists("pip3")
}

func (p *Pip) Install(command string) error {
	_, err := runCommand(command)
	return err
}

func (p *Pip) Update(command string) error {
	_, err := runCommand(command)
	return err
}

func (p *Pip) Uninstall(command string) error {
	_, err := runCommand(command)
	return err
}

// DetectPackageManagers returns all available package managers for the current platform
func DetectPackageManagers() []PackageManager {
	var managers []PackageManager

	// Platform-specific managers first
	switch Current().OS {
	case Windows:
		if pm := NewWinGet(); pm.IsAvailable() {
			managers = append(managers, pm)
		}
	case Darwin:
		if pm := NewHomebrew(); pm.IsAvailable() {
			managers = append(managers, pm)
		}
	case Linux:
		if pm := NewHomebrew(); pm.IsAvailable() {
			managers = append(managers, pm)
		}
		if pm := NewApt(); pm.IsAvailable() {
			managers = append(managers, pm)
		}
		if pm := NewPacman(); pm.IsAvailable() {
			managers = append(managers, pm)
		}
	}

	// Cross-platform managers
	if pm := NewNpm(); pm.IsAvailable() {
		managers = append(managers, pm)
	}
	if pm := NewPip(); pm.IsAvailable() {
		managers = append(managers, pm)
	}

	return managers
}

// GetPackageManagerByName returns a specific package manager by name
func GetPackageManagerByName(name string) PackageManager {
	name = strings.ToLower(name)
	switch name {
	case "winget":
		return NewWinGet()
	case "brew", "homebrew":
		return NewHomebrew()
	case "apt":
		return NewApt()
	case "pacman":
		return NewPacman()
	case "npm":
		return NewNpm()
	case "pip":
		return NewPip()
	default:
		return nil
	}
}
