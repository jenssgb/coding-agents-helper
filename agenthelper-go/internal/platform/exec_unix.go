//go:build !windows

package platform

import "os/exec"

// hideWindow is a no-op on Unix systems
func hideWindow(cmd *exec.Cmd) {
	// No action needed on Unix
}
