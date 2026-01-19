# AgentHelper Makefile
# Cross-platform build configuration

# Version from git tags
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Go build settings
GO := go
GOFLAGS := -trimpath
LDFLAGS := -ldflags "-s -w -X main.Version=$(VERSION) -X main.Commit=$(COMMIT) -X main.BuildDate=$(BUILD_DATE)"

# Output directory
DIST := dist

# Binary name
BINARY := agenthelper

# Default target
.PHONY: all
all: build

# Development build
.PHONY: build
build:
	$(GO) build $(GOFLAGS) $(LDFLAGS) -o $(DIST)/$(BINARY)$(shell go env GOEXE) ./cmd/agenthelper

# Run the application
.PHONY: run
run: build
	./$(DIST)/$(BINARY)$(shell go env GOEXE)

# Install dependencies
.PHONY: deps
deps:
	$(GO) mod download
	$(GO) mod tidy

# Format code
.PHONY: fmt
fmt:
	$(GO) fmt ./...

# Lint code
.PHONY: lint
lint:
	golangci-lint run

# Run tests
.PHONY: test
test:
	$(GO) test -v ./...

# Run tests with coverage
.PHONY: test-coverage
test-coverage:
	$(GO) test -v -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html

# Clean build artifacts
.PHONY: clean
clean:
	rm -rf $(DIST)
	rm -f coverage.out coverage.html

# Build for all platforms
.PHONY: build-all
build-all: clean
	@mkdir -p $(DIST)
	@echo "Building for Windows (amd64)..."
	GOOS=windows GOARCH=amd64 $(GO) build $(GOFLAGS) $(LDFLAGS) -o $(DIST)/$(BINARY)-windows-amd64.exe ./cmd/agenthelper
	@echo "Building for Windows (arm64)..."
	GOOS=windows GOARCH=arm64 $(GO) build $(GOFLAGS) $(LDFLAGS) -o $(DIST)/$(BINARY)-windows-arm64.exe ./cmd/agenthelper
	@echo "Building for macOS (amd64)..."
	GOOS=darwin GOARCH=amd64 $(GO) build $(GOFLAGS) $(LDFLAGS) -o $(DIST)/$(BINARY)-darwin-amd64 ./cmd/agenthelper
	@echo "Building for macOS (arm64)..."
	GOOS=darwin GOARCH=arm64 $(GO) build $(GOFLAGS) $(LDFLAGS) -o $(DIST)/$(BINARY)-darwin-arm64 ./cmd/agenthelper
	@echo "Building for Linux (amd64)..."
	GOOS=linux GOARCH=amd64 $(GO) build $(GOFLAGS) $(LDFLAGS) -o $(DIST)/$(BINARY)-linux-amd64 ./cmd/agenthelper
	@echo "Building for Linux (arm64)..."
	GOOS=linux GOARCH=arm64 $(GO) build $(GOFLAGS) $(LDFLAGS) -o $(DIST)/$(BINARY)-linux-arm64 ./cmd/agenthelper
	@echo "Done! Binaries in $(DIST)/"
	@ls -la $(DIST)/

# Create release archives
.PHONY: release
release: build-all
	@echo "Creating release archives..."
	@cd $(DIST) && \
		zip $(BINARY)-$(VERSION)-windows-amd64.zip $(BINARY)-windows-amd64.exe && \
		zip $(BINARY)-$(VERSION)-windows-arm64.zip $(BINARY)-windows-arm64.exe && \
		tar -czf $(BINARY)-$(VERSION)-darwin-amd64.tar.gz $(BINARY)-darwin-amd64 && \
		tar -czf $(BINARY)-$(VERSION)-darwin-arm64.tar.gz $(BINARY)-darwin-arm64 && \
		tar -czf $(BINARY)-$(VERSION)-linux-amd64.tar.gz $(BINARY)-linux-amd64 && \
		tar -czf $(BINARY)-$(VERSION)-linux-arm64.tar.gz $(BINARY)-linux-arm64
	@echo "Release archives created in $(DIST)/"

# Generate checksums
.PHONY: checksums
checksums:
	@cd $(DIST) && sha256sum *.zip *.tar.gz > checksums.txt
	@echo "Checksums:"
	@cat $(DIST)/checksums.txt

# Install locally
.PHONY: install
install: build
	$(GO) install $(GOFLAGS) $(LDFLAGS) ./cmd/agenthelper

# Show help
.PHONY: help
help:
	@echo "AgentHelper Build System"
	@echo ""
	@echo "Targets:"
	@echo "  build        Build for current platform"
	@echo "  build-all    Build for all platforms"
	@echo "  run          Build and run"
	@echo "  test         Run tests"
	@echo "  test-coverage Run tests with coverage"
	@echo "  fmt          Format code"
	@echo "  lint         Run linter"
	@echo "  deps         Download dependencies"
	@echo "  clean        Remove build artifacts"
	@echo "  install      Install to GOPATH/bin"
	@echo "  release      Create release archives"
	@echo "  checksums    Generate SHA256 checksums"
	@echo "  help         Show this help"
	@echo ""
	@echo "Version: $(VERSION)"
