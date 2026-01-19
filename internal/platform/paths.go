package platform

import (
	"os"
	"path/filepath"
)

// Paths holds OS-specific paths
type Paths struct {
	Home       string
	ConfigDir  string
	CacheDir   string
	BinDir     string
	DataDir    string
}

// GetPaths returns OS-specific paths for the current platform
func GetPaths() (*Paths, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}

	p := &Paths{
		Home: home,
	}

	switch Current().OS {
	case Windows:
		p.ConfigDir = filepath.Join(home, "AppData", "Roaming", "agenthelper")
		p.CacheDir = filepath.Join(home, "AppData", "Local", "agenthelper", "cache")
		p.DataDir = filepath.Join(home, "AppData", "Local", "agenthelper")
		p.BinDir = filepath.Join(home, "AppData", "Local", "Programs", "agenthelper")
	case Darwin:
		p.ConfigDir = filepath.Join(home, ".config", "agenthelper")
		p.CacheDir = filepath.Join(home, "Library", "Caches", "agenthelper")
		p.DataDir = filepath.Join(home, "Library", "Application Support", "agenthelper")
		p.BinDir = filepath.Join(home, ".local", "bin")
	default: // Linux and others
		p.ConfigDir = filepath.Join(home, ".config", "agenthelper")
		p.CacheDir = filepath.Join(home, ".cache", "agenthelper")
		p.DataDir = filepath.Join(home, ".local", "share", "agenthelper")
		p.BinDir = filepath.Join(home, ".local", "bin")
	}

	return p, nil
}

// EnsureDirectories creates all necessary directories
func (p *Paths) EnsureDirectories() error {
	dirs := []string{p.ConfigDir, p.CacheDir, p.DataDir, p.BinDir}
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
	}
	return nil
}

// GetEnvPath returns the PATH environment variable as a slice
func GetEnvPath() []string {
	path := os.Getenv("PATH")
	if path == "" {
		return nil
	}
	return filepath.SplitList(path)
}

// IsInPath checks if a directory is in the PATH
func IsInPath(dir string) bool {
	for _, p := range GetEnvPath() {
		if filepath.Clean(p) == filepath.Clean(dir) {
			return true
		}
	}
	return false
}

// GetExecutablePath finds the full path of an executable
func GetExecutablePath(name string) (string, error) {
	// Add .exe extension on Windows if not present
	if IsWindows() && filepath.Ext(name) == "" {
		name = name + ".exe"
	}

	// Check in PATH
	for _, dir := range GetEnvPath() {
		fullPath := filepath.Join(dir, name)
		if _, err := os.Stat(fullPath); err == nil {
			return fullPath, nil
		}
	}

	return "", os.ErrNotExist
}
