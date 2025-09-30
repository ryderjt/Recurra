#!/bin/bash

# Recurra Build Script
# This script builds the Recurra app for different configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Recurra/Recurra.xcodeproj/project.pbxproj" ]; then
    print_error "Please run this script from the repository root directory"
    exit 1
fi

# Parse command line arguments
CONFIGURATION="Release"
SCHEME="Recurra"
DESTINATION="platform=macOS"
CLEAN=false
ARCHIVE=false
EXPORT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        -s|--scheme)
            SCHEME="$2"
            shift 2
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --archive)
            ARCHIVE=true
            shift
            ;;
        --export)
            EXPORT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -c, --configuration CONFIG    Build configuration (Debug|Release) [default: Release]"
            echo "  -s, --scheme SCHEME          Xcode scheme [default: Recurra]"
            echo "  -d, --destination DEST       Build destination [default: platform=macOS]"
            echo "  --clean                      Clean build folder before building"
            echo "  --archive                    Create archive"
            echo "  --export                     Export archive (requires --archive)"
            echo "  -h, --help                   Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Change to the Recurra directory
cd Recurra

# Clean if requested
if [ "$CLEAN" = true ]; then
    print_status "Cleaning build folder..."
    xcodebuild clean -project Recurra.xcodeproj -scheme "$SCHEME"
fi

# Build the project
print_status "Building $SCHEME in $CONFIGURATION configuration..."

if [ "$ARCHIVE" = true ]; then
    print_status "Creating archive..."
    xcodebuild archive \
        -project Recurra.xcodeproj \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -archivePath Recurra.xcarchive
    print_success "Archive created: Recurra.xcarchive"
    
    if [ "$EXPORT" = true ]; then
        print_status "Exporting archive..."
        if [ -f "exportOptions.plist" ]; then
            xcodebuild -exportArchive \
                -archivePath Recurra.xcarchive \
                -exportPath ./build \
                -exportOptionsPlist exportOptions.plist
            print_success "Archive exported to ./build/"
        else
            print_warning "exportOptions.plist not found. Skipping export."
        fi
    fi
else
    xcodebuild build \
        -project Recurra.xcodeproj \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION"
    print_success "Build completed successfully!"
fi

# Run tests if in Debug mode
if [ "$CONFIGURATION" = "Debug" ]; then
    print_status "Running tests..."
    xcodebuild test \
        -project Recurra.xcodeproj \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -resultBundlePath TestResults.xcresult || print_warning "Tests failed or no tests found"
fi

print_success "Build script completed!"
