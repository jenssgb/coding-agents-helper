package ui

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// MenuItem represents a menu option
type MenuItem struct {
	Key         string
	Label       string
	Description string
	Action      func() bool // Returns true to exit menu
}

// Menu represents an interactive menu
type Menu struct {
	Title    string
	Items    []MenuItem
	ShowBack bool
}

// NewMenu creates a new menu
func NewMenu(title string) *Menu {
	return &Menu{
		Title:    title,
		Items:    []MenuItem{},
		ShowBack: false,
	}
}

// AddItem adds an item to the menu
func (m *Menu) AddItem(key, label, description string, action func() bool) {
	m.Items = append(m.Items, MenuItem{
		Key:         key,
		Label:       label,
		Description: description,
		Action:      action,
	})
}

// AddBackOption enables the back/exit option
func (m *Menu) AddBackOption(label string) {
	m.ShowBack = true
	m.AddItem("0", label, "", func() bool { return true })
}

// Display shows the menu and handles input
func (m *Menu) Display() {
	reader := bufio.NewReader(os.Stdin)

	for {
		// Clear screen effect with newlines
		fmt.Println()

		// Print title
		fmt.Println(Bold(m.Title))
		fmt.Println(strings.Repeat("─", len(m.Title)+4))
		fmt.Println()

		// Print menu items
		for _, item := range m.Items {
			if item.Description != "" {
				fmt.Printf("  [%s] %s - %s\n", Cyan(item.Key), item.Label, item.Description)
			} else {
				fmt.Printf("  [%s] %s\n", Cyan(item.Key), item.Label)
			}
		}

		fmt.Println()
		fmt.Print("Select option: ")

		input, err := reader.ReadString('\n')
		if err != nil {
			continue
		}

		input = strings.TrimSpace(input)
		if input == "" {
			continue
		}

		// Find and execute the selected item
		found := false
		for _, item := range m.Items {
			if strings.EqualFold(item.Key, input) {
				found = true
				if item.Action != nil {
					if item.Action() {
						return // Exit menu
					}
				}
				break
			}
		}

		if !found {
			Error("Invalid option: %s", input)
		}
	}
}

// PromptConfirm asks for yes/no confirmation
func PromptConfirm(message string) bool {
	reader := bufio.NewReader(os.Stdin)
	fmt.Printf("%s [y/N]: ", message)

	input, err := reader.ReadString('\n')
	if err != nil {
		return false
	}

	input = strings.TrimSpace(strings.ToLower(input))
	return input == "y" || input == "yes"
}

// PromptSelect shows a selection menu and returns the selected index
func PromptSelect(title string, options []string) int {
	reader := bufio.NewReader(os.Stdin)

	fmt.Println()
	fmt.Println(Bold(title))
	fmt.Println()

	for i, opt := range options {
		fmt.Printf("  [%d] %s\n", i+1, opt)
	}
	fmt.Println("  [0] Cancel")

	fmt.Println()
	fmt.Print("Select: ")

	input, err := reader.ReadString('\n')
	if err != nil {
		return -1
	}

	input = strings.TrimSpace(input)
	num, err := strconv.Atoi(input)
	if err != nil || num < 0 || num > len(options) {
		return -1
	}

	return num - 1 // -1 means cancelled (0 input), otherwise 0-based index
}

// WaitForEnter waits for user to press Enter
func WaitForEnter() {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("\nPress Enter to continue...")
	reader.ReadString('\n')
}
