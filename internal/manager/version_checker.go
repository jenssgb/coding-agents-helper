package manager

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/jschneider/agenthelper/internal/config"
)

// VersionInfo holds version information for a tool
type VersionInfo struct {
	Installed string
	Latest    string
	HasUpdate bool
}

// HTTPClient for making API requests
var httpClient = &http.Client{
	Timeout: 10 * time.Second,
}

// GetLatestVersion fetches the latest version for a tool based on its version source
func GetLatestVersion(tool *config.ToolDefinition) (string, error) {
	switch tool.VersionSource.Type {
	case "npm":
		return getLatestNpmVersion(tool.VersionSource.Package)
	case "github":
		return getLatestGitHubVersion(tool.VersionSource.Owner, tool.VersionSource.Repo)
	case "pypi":
		return getLatestPyPIVersion(tool.VersionSource.Package)
	case "vscode-update":
		return getLatestVSCodeVersion(tool.VersionSource.Channel)
	case "cursor-todesktop":
		return getLatestCursorVersion()
	default:
		return "", fmt.Errorf("unknown version source type: %s", tool.VersionSource.Type)
	}
}

// NpmPackageInfo represents npm registry response
type NpmPackageInfo struct {
	DistTags struct {
		Latest string `json:"latest"`
	} `json:"dist-tags"`
}

func getLatestNpmVersion(packageName string) (string, error) {
	url := fmt.Sprintf("https://registry.npmjs.org/%s", packageName)

	resp, err := httpClient.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to fetch npm version: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("npm registry returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	var info NpmPackageInfo
	if err := json.Unmarshal(body, &info); err != nil {
		return "", fmt.Errorf("failed to parse npm response: %w", err)
	}

	return info.DistTags.Latest, nil
}

// GitHubRelease represents GitHub release API response
type GitHubRelease struct {
	TagName string `json:"tag_name"`
	Name    string `json:"name"`
}

func getLatestGitHubVersion(owner, repo string) (string, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/releases/latest", owner, repo)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to fetch GitHub version: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("GitHub API returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	var release GitHubRelease
	if err := json.Unmarshal(body, &release); err != nil {
		return "", fmt.Errorf("failed to parse GitHub response: %w", err)
	}

	// Strip 'v' prefix if present
	version := strings.TrimPrefix(release.TagName, "v")
	return version, nil
}

// PyPIPackageInfo represents PyPI API response
type PyPIPackageInfo struct {
	Info struct {
		Version string `json:"version"`
	} `json:"info"`
}

func getLatestPyPIVersion(packageName string) (string, error) {
	url := fmt.Sprintf("https://pypi.org/pypi/%s/json", packageName)

	resp, err := httpClient.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to fetch PyPI version: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("PyPI returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	var info PyPIPackageInfo
	if err := json.Unmarshal(body, &info); err != nil {
		return "", fmt.Errorf("failed to parse PyPI response: %w", err)
	}

	return info.Info.Version, nil
}

// ExtractVersion extracts version from command output using regex pattern
func ExtractVersion(output, pattern string) string {
	if pattern == "" {
		pattern = `(\d+\.\d+\.\d+)`
	}

	re, err := regexp.Compile(pattern)
	if err != nil {
		return ""
	}

	matches := re.FindStringSubmatch(output)
	if len(matches) > 1 {
		return matches[1]
	}
	if len(matches) > 0 {
		return matches[0]
	}
	return ""
}

// VSCodeUpdateInfo represents VS Code update API response
type VSCodeUpdateInfo struct {
	ProductVersion string `json:"productVersion"`
	Name           string `json:"name"`
}

func getLatestVSCodeVersion(channel string) (string, error) {
	if channel == "" {
		channel = "stable"
	}
	url := fmt.Sprintf("https://update.code.visualstudio.com/api/update/win32-x64-user/%s/latest", channel)

	resp, err := httpClient.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to fetch VS Code version: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("VS Code update API returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	var info VSCodeUpdateInfo
	if err := json.Unmarshal(body, &info); err != nil {
		return "", fmt.Errorf("failed to parse VS Code response: %w", err)
	}

	// Extract just the version number (remove "-insider" suffix if present)
	version := strings.Split(info.ProductVersion, "-")[0]
	return version, nil
}

func getLatestCursorVersion() (string, error) {
	url := "https://download.todesktop.com/230313mzl4w4u92/latest.yml"

	resp, err := httpClient.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to fetch Cursor version: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("Cursor API returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	// Parse YAML manually - look for "version: X.Y.Z"
	lines := strings.Split(string(body), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "version:") {
			version := strings.TrimPrefix(line, "version:")
			return strings.TrimSpace(version), nil
		}
	}

	return "", fmt.Errorf("could not find version in Cursor response")
}
