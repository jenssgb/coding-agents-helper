package platform

import (
	"runtime"
	"strings"
)

// OS represents the operating system
type OS string

const (
	Windows OS = "windows"
	Darwin  OS = "darwin"
	Linux   OS = "linux"
	Unknown OS = "unknown"
)

// Arch represents the CPU architecture
type Arch string

const (
	AMD64   Arch = "amd64"
	ARM64   Arch = "arm64"
	I386    Arch = "386"
	UnknownArch Arch = "unknown"
)

// Platform contains information about the current platform
type Platform struct {
	OS       OS
	Arch     Arch
	OSString string
	IsWSL    bool
}

// Current returns information about the current platform
func Current() *Platform {
	p := &Platform{
		OSString: runtime.GOOS,
	}

	switch runtime.GOOS {
	case "windows":
		p.OS = Windows
	case "darwin":
		p.OS = Darwin
	case "linux":
		p.OS = Linux
		p.IsWSL = isWSL()
	default:
		p.OS = Unknown
	}

	switch runtime.GOARCH {
	case "amd64":
		p.Arch = AMD64
	case "arm64":
		p.Arch = ARM64
	case "386":
		p.Arch = I386
	default:
		p.Arch = UnknownArch
	}

	return p
}

// IsWindows returns true if running on Windows
func IsWindows() bool {
	return runtime.GOOS == "windows"
}

// IsDarwin returns true if running on macOS
func IsDarwin() bool {
	return runtime.GOOS == "darwin"
}

// IsLinux returns true if running on Linux
func IsLinux() bool {
	return runtime.GOOS == "linux"
}

// isWSL checks if running inside Windows Subsystem for Linux
func isWSL() bool {
	// Check for WSL-specific environment variables or files
	// This is a simplified check
	return strings.Contains(strings.ToLower(runtime.GOOS), "linux") &&
		(checkWSLInterop() || checkWSLProc())
}

func checkWSLInterop() bool {
	// In a real implementation, check for /proc/sys/fs/binfmt_misc/WSLInterop
	return false
}

func checkWSLProc() bool {
	// In a real implementation, check /proc/version for Microsoft
	return false
}

// String returns a human-readable platform string
func (p *Platform) String() string {
	osName := string(p.OS)
	switch p.OS {
	case Windows:
		osName = "Windows"
	case Darwin:
		osName = "macOS"
	case Linux:
		if p.IsWSL {
			osName = "Linux (WSL)"
		} else {
			osName = "Linux"
		}
	}

	return osName + "/" + string(p.Arch)
}

// GetOSKey returns the key used in tool definitions for this platform
func (p *Platform) GetOSKey() string {
	return string(p.OS)
}
