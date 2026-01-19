package ui

import (
	"os"

	"github.com/olekukonko/tablewriter"
)

// Table represents a formatted table for terminal output
type Table struct {
	table *tablewriter.Table
}

// NewTable creates a new table with the given headers
func NewTable(headers []string) *Table {
	t := tablewriter.NewWriter(os.Stdout)
	t.SetHeader(headers)
	t.SetBorder(true)
	t.SetRowLine(false)
	t.SetHeaderLine(true)
	t.SetAlignment(tablewriter.ALIGN_LEFT)
	t.SetHeaderAlignment(tablewriter.ALIGN_LEFT)
	t.SetCenterSeparator("┼")
	t.SetColumnSeparator("│")
	t.SetRowSeparator("─")
	t.SetTablePadding(" ")
	t.SetNoWhiteSpace(false)

	return &Table{table: t}
}

// AddRow adds a row to the table
func (t *Table) AddRow(row []string) {
	t.table.Append(row)
}

// AddRows adds multiple rows to the table
func (t *Table) AddRows(rows [][]string) {
	for _, row := range rows {
		t.table.Append(row)
	}
}

// Render prints the table to stdout
func (t *Table) Render() {
	t.table.Render()
}

// SetColumnColors sets colors for each column
func (t *Table) SetColumnColors(colors ...tablewriter.Colors) {
	t.table.SetColumnColor(colors...)
}

// SetHeaderColor sets the header color
func (t *Table) SetHeaderColor(colors ...tablewriter.Colors) {
	t.table.SetHeaderColor(colors...)
}

// StatusTable creates a pre-configured table for tool status display
func StatusTable() *Table {
	t := NewTable([]string{"Tool", "Status", "Installed", "Latest", "Command"})
	if IsColorEnabled() {
		t.table.SetColumnColor(
			tablewriter.Colors{tablewriter.Bold},
			tablewriter.Colors{},
			tablewriter.Colors{},
			tablewriter.Colors{},
			tablewriter.Colors{tablewriter.FgHiBlackColor},
		)
	}
	return t
}

// EnvTable creates a pre-configured table for environment report
func EnvTable() *Table {
	t := NewTable([]string{"Check", "Status", "Details"})
	if IsColorEnabled() {
		t.table.SetColumnColor(
			tablewriter.Colors{tablewriter.Bold},
			tablewriter.Colors{},
			tablewriter.Colors{},
		)
	}
	return t
}

// CompactStatusTable creates a minimal table without borders for Claude Code style display
func CompactStatusTable() *Table {
	t := tablewriter.NewWriter(os.Stdout)
	t.SetHeader([]string{"TOOL", "CURRENT", "LATEST", "RUN WITH"})
	t.SetBorder(false)
	t.SetRowLine(false)
	t.SetHeaderLine(true)
	t.SetAlignment(tablewriter.ALIGN_LEFT)
	t.SetHeaderAlignment(tablewriter.ALIGN_LEFT)
	t.SetCenterSeparator("")
	t.SetColumnSeparator("")
	t.SetRowSeparator("─")
	t.SetTablePadding("  ")
	t.SetNoWhiteSpace(false)
	t.SetAutoWrapText(false)
	t.SetColWidth(30)

	if IsColorEnabled() {
		t.SetHeaderColor(
			tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiWhiteColor},
			tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiWhiteColor},
			tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiWhiteColor},
			tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiWhiteColor},
		)
	}

	return &Table{table: t}
}
