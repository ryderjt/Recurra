# Build and Release Guide

This document explains how to build, test, and release the Recurra app using the provided automation tools.

## Quick Start

### Local Development
```bash
# Build in Debug mode
make debug

# Build in Release mode
make build

# Run tests
make test

# Create a release build with DMG
make release
```

### Using the Build Script
```bash
# Basic build
./build.sh

# Debug build
./build.sh --configuration Debug

# Clean build
./build.sh --clean

# Create archive
./build.sh --archive

# Export archive
./build.sh --archive --export
```

## GitHub Actions Workflows

### 1. Continuous Integration (CI)
**File:** `.github/workflows/ci.yml`
**Triggers:** Push to main/develop, Pull Requests

**What it does:**
- Builds the app in Debug and Release modes
- Runs tests
- Runs SwiftLint code quality checks
- Creates an archive
- Uploads build artifacts

### 2. Build Workflow
**File:** `.github/workflows/build.yml`
**Triggers:** Push to main/develop, Pull Requests, Manual

**What it does:**
- Builds the app in Release mode
- Creates an archive
- Exports the app
- Creates a DMG file
- Uploads artifacts

### 3. Release Workflow
**File:** `.github/workflows/release.yml`
**Triggers:** Git tags (v*), Manual

**What it does:**
- Builds and signs the app
- Creates a DMG
- Notarizes with Apple
- Creates a GitHub release

## Setting Up Automated Releases

### Prerequisites
1. Apple Developer Account
2. Developer ID Application Certificate
3. Apple ID with app-specific password

### Required GitHub Secrets
Add these in your repository settings under "Secrets and variables" → "Actions":

- `CERTIFICATE_P12`: Your Developer ID certificate (base64 encoded)
- `CERTIFICATE_PASSWORD`: Password for the P12 certificate
- `APPLE_ID`: Your Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password
- `APPLE_TEAM_ID`: Your Apple Developer Team ID

### Creating a Release
1. **Tag a version:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Or manually trigger:**
   - Go to Actions → Release Build
   - Click "Run workflow"
   - Enter version number

## Local Build Commands

### Basic Commands
```bash
# Build Release
make build

# Build Debug
make debug

# Clean and build
make clean && make build

# Run tests
make test

# Create archive
make archive

# Create DMG
make dmg

# Full release build
make release
```

### Advanced Build Script Usage
```bash
# Custom configuration
./build.sh --configuration Debug --scheme Recurra

# Clean build
./build.sh --clean --configuration Release

# Archive and export
./build.sh --archive --export

# Custom destination
./build.sh --destination "platform=macOS,arch=x86_64"
```

## Code Quality

### SwiftLint
The project includes SwiftLint configuration (`.swiftlint.yml`) for consistent code style.

**Install SwiftLint:**
```bash
brew install swiftlint
```

**Run locally:**
```bash
cd Recurra/Recurra
swiftlint lint
```

**Fix issues:**
```bash
swiftlint --fix
```

## Testing

### Running Tests
```bash
# Using Makefile
make test

# Using build script
./build.sh --configuration Debug

# Direct Xcode command
cd Recurra
xcodebuild test -project Recurra.xcodeproj -scheme Recurra
```

### Adding Tests
1. Create test files in `Recurra/RecurraTests/`
2. Follow the existing test structure
3. Tests will run automatically in CI

## Troubleshooting

### Common Issues

**Build fails:**
- Check Xcode version compatibility
- Verify all dependencies are installed
- Clean build folder: `make clean`

**Code signing fails:**
- Verify certificates are installed in Keychain
- Check provisioning profiles
- Ensure Developer ID Application certificate is present

**Notarization fails:**
- Verify Apple ID credentials
- Check app-specific password is correct
- Ensure Team ID matches your Apple Developer account

**Tests fail:**
- Check test target is properly configured
- Verify test files are included in the project
- Run tests locally first

### Getting Help
1. Check the GitHub Actions logs for detailed error messages
2. Run builds locally to reproduce issues
3. Verify all secrets are correctly set
4. Check Apple Developer account status

## File Structure
```
Recurra/
├── .github/workflows/     # GitHub Actions workflows
├── Recurra/              # Main app source code
├── RecurraTests/         # Test files
├── build.sh              # Build script
├── Makefile              # Build commands
├── .swiftlint.yml        # SwiftLint configuration
└── exportOptions.plist   # Xcode export options
```

## Environment Requirements
- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+
- SwiftLint (for code quality)
- Apple Developer Account (for releases)
