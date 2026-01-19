//go:build windows

package ui

import (
	"os"

	"golang.org/x/sys/windows"
)

func init() {
	// Enable Virtual Terminal Processing on Windows for ANSI color support
	enableVirtualTerminal(os.Stdout)
	enableVirtualTerminal(os.Stderr)
}

func enableVirtualTerminal(f *os.File) {
	handle := windows.Handle(f.Fd())
	var mode uint32
	if err := windows.GetConsoleMode(handle, &mode); err != nil {
		return
	}
	mode |= windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING
	_ = windows.SetConsoleMode(handle, mode)
}
