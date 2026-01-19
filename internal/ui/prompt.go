package ui

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// Command represents a parsed slash command
type Command struct {
	Name string
	Args []string
}

// PromptCommand displays a prompt and reads user input
func PromptCommand(prompt string) string {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print(Cyan(prompt))

	input, err := reader.ReadString('\n')
	if err != nil {
		return ""
	}

	return strings.TrimSpace(input)
}

// ParseCommand parses user input into a command and arguments
func ParseCommand(input string) (cmd string, args []string) {
	input = strings.TrimSpace(input)
	if input == "" {
		return "", nil
	}

	parts := strings.Fields(input)
	if len(parts) == 0 {
		return "", nil
	}

	cmd = strings.ToLower(parts[0])
	if len(parts) > 1 {
		args = parts[1:]
	}

	return cmd, args
}

// ShowCommandHelp displays available slash commands
func ShowCommandHelp() {
	fmt.Println()
	fmt.Println(Bold("Available Commands:"))
	fmt.Println()

	commands := []struct {
		cmd  string
		desc string
	}{
		{"/help", "Show this help message"},
		{"/status", "Refresh the tool status table"},
		{"/install <tool>", "Install a specific tool"},
		{"/update [tool]", "Update all tools or a specific tool"},
		{"/repair <tool>", "Uninstall and reinstall a tool"},
		{"/run <tool>", "Launch a tool"},
		{"/env", "Show environment report"},
		{"/exit", "Exit AgentHelper (or Ctrl+C)"},
	}

	for _, c := range commands {
		fmt.Printf("  %-20s %s\n", Cyan(c.cmd), c.desc)
	}
	fmt.Println()
}

// PrintPromptBanner prints the banner with platform info for prompt mode
func PrintPromptBanner(version string, platformStr string) {
	banner := `
    _                    _   _   _      _
   / \   __ _  ___ _ __ | |_| | | | ___| |_ __   ___ _ __
  / _ \ / _` + "`" + ` |/ _ \ '_ \| __| |_| |/ _ \ | '_ \ / _ \ '__|
 / ___ \ (_| |  __/ | | | |_|  _  |  __/ | |_) |  __/ |
/_/   \_\__, |\___|_| |_|\__|_| |_|\___|_| .__/ \___|_|
        |___/                            |_|
`
	fmt.Println(Cyan(banner))
	fmt.Printf("  %s  %s\n\n", Bold("Platform:"), platformStr)
}
