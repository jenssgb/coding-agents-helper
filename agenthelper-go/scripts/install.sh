#!/bin/bash
# AgentHelper Unix Installer
# Usage: curl -sSL https://github.com/USER/agenthelper/releases/latest/download/install.sh | bash

set -e

# Configuration
REPO="jschneider/agenthelper"
INSTALL_DIR="${HOME}/.local/bin"
BIN_NAME="agenthelper"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}  AgentHelper Installer${NC}"
echo -e "${CYAN}  =====================${NC}"
echo ""

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    darwin) OS="darwin" ;;
    linux) OS="linux" ;;
    *)
        echo -e "${RED}  Error: Unsupported operating system: $OS${NC}"
        exit 1
        ;;
esac

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    amd64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64) ARCH="arm64" ;;
    *)
        echo -e "${RED}  Error: Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${GRAY}  Platform: $OS/$ARCH${NC}"

# Get latest release
echo -e "${GRAY}  Fetching latest release...${NC}"
RELEASE_INFO=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest")
VERSION=$(echo "$RELEASE_INFO" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)

if [ -z "$VERSION" ]; then
    echo -e "${RED}  Error: Could not determine latest version${NC}"
    exit 1
fi

echo -e "${GREEN}  Latest version: $VERSION${NC}"

# Construct download URL
ASSET_NAME="${BIN_NAME}-${OS}-${ARCH}"
ARCHIVE_NAME="${BIN_NAME}-${VERSION}-${OS}-${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/$ARCHIVE_NAME"

# Try direct binary first
DIRECT_URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET_NAME"

echo -e "${GRAY}  Downloading...${NC}"

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Try archive first, then direct binary
if curl -sL --fail -o "$TMP_DIR/archive.tar.gz" "$DOWNLOAD_URL" 2>/dev/null; then
    echo -e "${GRAY}  Extracting...${NC}"
    tar -xzf "$TMP_DIR/archive.tar.gz" -C "$TMP_DIR"
    BINARY=$(find "$TMP_DIR" -name "$BIN_NAME" -o -name "${BIN_NAME}-*" -type f | head -1)
elif curl -sL --fail -o "$TMP_DIR/$BIN_NAME" "$DIRECT_URL" 2>/dev/null; then
    BINARY="$TMP_DIR/$BIN_NAME"
else
    echo -e "${RED}  Error: Could not download binary${NC}"
    echo -e "${YELLOW}  Tried:${NC}"
    echo -e "${GRAY}    - $DOWNLOAD_URL${NC}"
    echo -e "${GRAY}    - $DIRECT_URL${NC}"
    exit 1
fi

if [ ! -f "$BINARY" ]; then
    echo -e "${RED}  Error: Binary not found after download${NC}"
    exit 1
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Install binary
echo -e "${GRAY}  Installing to $INSTALL_DIR...${NC}"
chmod +x "$BINARY"
mv "$BINARY" "$INSTALL_DIR/$BIN_NAME"

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}  Note: $INSTALL_DIR is not in your PATH${NC}"
    echo ""
    echo -e "${GRAY}  Add this to your shell profile:${NC}"

    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        bash)
            echo -e "${CYAN}    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc${NC}"
            ;;
        zsh)
            echo -e "${CYAN}    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc${NC}"
            ;;
        fish)
            echo -e "${CYAN}    fish_add_path ~/.local/bin${NC}"
            ;;
        *)
            echo -e "${CYAN}    export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
            ;;
    esac
fi

# Verify installation
echo ""
if "$INSTALL_DIR/$BIN_NAME" version >/dev/null 2>&1; then
    INSTALLED_VERSION=$("$INSTALL_DIR/$BIN_NAME" version 2>&1 | head -1)
    echo -e "${GREEN}  Installation successful!${NC}"
    echo ""
    echo -e "${GRAY}  Installed to: $INSTALL_DIR/$BIN_NAME${NC}"
    echo -e "${GRAY}  $INSTALLED_VERSION${NC}"
else
    echo -e "${YELLOW}  Warning: Installation completed but verification failed${NC}"
    echo -e "${GRAY}  Binary location: $INSTALL_DIR/$BIN_NAME${NC}"
fi

echo ""
echo -e "${CYAN}  Run 'agenthelper' to get started.${NC}"
echo ""
