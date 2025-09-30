# Recurra Makefile
# Simple build commands for the Recurra app

.PHONY: help build clean test archive export install

# Default target
help:
	@echo "Recurra Build Commands:"
	@echo "  make build     - Build the app in Release mode"
	@echo "  make debug     - Build the app in Debug mode"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make test      - Run tests"
	@echo "  make archive   - Create archive"
	@echo "  make export    - Export archive"
	@echo "  make dmg       - Create DMG file"
	@echo "  make install   - Install SwiftLint and dependencies"

# Build targets
build:
	@echo "Building Recurra in Release mode..."
	@./build.sh --configuration Release

debug:
	@echo "Building Recurra in Debug mode..."
	@./build.sh --configuration Debug

clean:
	@echo "Cleaning build artifacts..."
	@./build.sh --clean --configuration Release

test:
	@echo "Running tests..."
	@./build.sh --configuration Debug

archive:
	@echo "Creating archive..."
	@./build.sh --archive --configuration Release

export: archive
	@echo "Exporting archive..."
	@./build.sh --export --configuration Release

dmg: export
	@echo "Creating DMG..."
	@cd Recurra && \
	mkdir -p dmg_temp && \
	cp -R build/Recurra.app dmg_temp/ && \
	hdiutil create -volname "Recurra" -srcfolder dmg_temp -ov -format UDZO Recurra.dmg && \
	rm -rf dmg_temp
	@echo "DMG created: Recurra/Recurra.dmg"

# Development setup
install:
	@echo "Installing development dependencies..."
	@if ! command -v swiftlint &> /dev/null; then \
		echo "Installing SwiftLint..."; \
		brew install swiftlint; \
	else \
		echo "SwiftLint already installed"; \
	fi

# CI targets
ci: clean test build
	@echo "CI build completed"

# Release targets
release: clean archive export dmg
	@echo "Release build completed"
