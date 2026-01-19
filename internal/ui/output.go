package ui

import (
	"fmt"
	"os"

	"github.com/fatih/color"
)

var (
	// Color functions
	successColor = color.New(color.FgGreen).SprintFunc()
	errorColor   = color.New(color.FgRed).SprintFunc()
	warnColor    = color.New(color.FgYellow).SprintFunc()
	infoColor    = color.New(color.FgCyan).SprintFunc()
	debugColor   = color.New(color.FgWhite, color.Faint).SprintFunc()
	boldColor    = color.New(color.Bold).SprintFunc()

	// Status symbols
	SymbolSuccess = "✓"
	SymbolError   = "✗"
	SymbolWarn    = "!"
	SymbolInfo    = "●"
	SymbolPending = "○"

	// Debug mode
	debugMode = false

	// Color mode
	colorEnabled = true
)

// SetDebugMode enables or disables debug output
func SetDebugMode(enabled bool) {
	debugMode = enabled
}

// SetColorEnabled enables or disables colored output
func SetColorEnabled(enabled bool) {
	colorEnabled = enabled
	color.NoColor = !enabled
}

// IsColorEnabled returns whether colors are enabled
func IsColorEnabled() bool {
	return colorEnabled
}

// Success prints a success message
func Success(format string, a ...interface{}) {
	fmt.Fprintf(os.Stdout, "%s %s\n", successColor(SymbolSuccess), fmt.Sprintf(format, a...))
}

// Error prints an error message
func Error(format string, a ...interface{}) {
	fmt.Fprintf(os.Stderr, "%s %s\n", errorColor(SymbolError), fmt.Sprintf(format, a...))
}

// Warn prints a warning message
func Warn(format string, a ...interface{}) {
	fmt.Fprintf(os.Stdout, "%s %s\n", warnColor(SymbolWarn), fmt.Sprintf(format, a...))
}

// Info prints an info message
func Info(format string, a ...interface{}) {
	fmt.Fprintf(os.Stdout, "%s %s\n", infoColor(SymbolInfo), fmt.Sprintf(format, a...))
}

// Debug prints a debug message (only when debug mode is enabled)
func Debug(format string, a ...interface{}) {
	if debugMode {
		fmt.Fprintf(os.Stdout, "%s %s\n", debugColor("DBG"), debugColor(fmt.Sprintf(format, a...)))
	}
}

// Print prints a message without prefix
func Print(format string, a ...interface{}) {
	fmt.Fprintf(os.Stdout, "%s\n", fmt.Sprintf(format, a...))
}

// Bold prints bold text
func Bold(text string) string {
	return boldColor(text)
}

// Green returns green colored text
func Green(text string) string {
	return successColor(text)
}

// Red returns red colored text
func Red(text string) string {
	return errorColor(text)
}

// Yellow returns yellow colored text
func Yellow(text string) string {
	return warnColor(text)
}

// Cyan returns cyan colored text
func Cyan(text string) string {
	return infoColor(text)
}

// PrintBanner prints the AgentHelper banner
func PrintBanner(version string) {
	banner := `
    _                    _   _   _      _
   / \   __ _  ___ _ __ | |_| | | | ___| |_ __   ___ _ __
  / _ \ / _` + "`" + ` |/ _ \ '_ \| __| |_| |/ _ \ | '_ \ / _ \ '__|
 / ___ \ (_| |  __/ | | | |_|  _  |  __/ | |_) |  __/ |
/_/   \_\__, |\___|_| |_|\__|_| |_|\___|_| .__/ \___|_|
        |___/                            |_|
`
	fmt.Println(infoColor(banner))
	fmt.Printf("  %s %s\n\n", Bold("Version:"), version)
}
