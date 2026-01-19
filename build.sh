#!/bin/bash
#
# build.sh - Build script for rdseed v5.3.1
#
# Usage:
#   ./build.sh -i <file> [options]
#
# Options:
#   -i, --input-file <file>  Input tar.gz file containing rdseed source (REQUIRED)
#   -o, --output <dir>       Output directory for built binaries (default: ./output)
#   -t, --type <type>        Build type: native, docker, clean, all (default: docker)
#   -h, --help               Show this help message
#
# Build types:
#   docker    Build for Linux (arm64 + x86_64) via Docker (default)
#   native    Build natively for the host system (macOS or Linux)
#   clean     Clean all build artifacts
#   all       Build both Docker and native
#
# Output:
#   output/linux-arm64/rdseed    - Linux ARM64 binary (Docker)
#   output/linux-amd64/rdseed    - Linux x86_64 binary (Docker)
#   output/macos-arm64/rdseed    - macOS ARM64 binary (native)
#   output/macos-amd64/rdseed    - macOS x86_64 binary (native)
#   output/linux-arm64/rdseed    - Linux ARM64 binary (native)
#   output/linux-amd64/rdseed    - Linux x86_64 binary (native)

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
INPUT_FILE=""
OUTPUT_DIR="$SCRIPT_DIR/output"
BUILD_TYPE="docker"
SRC_DIR="$SCRIPT_DIR"
TMP_DIR=""

# Docker image name
IMAGE_NAME="rdseed-builder"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Extract source from tar.gz file
extract_source() {
    local tarfile="$1"

    if [ ! -f "$tarfile" ]; then
        print_msg "$RED" "Error: Input file not found: $tarfile"
        exit 1
    fi

    # Create tmp directory
    TMP_DIR="$SCRIPT_DIR/tmp"
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    print_msg "$YELLOW" "Extracting $tarfile to $TMP_DIR..."
    tar -xzf "$tarfile" -C "$TMP_DIR"

    # Find the extracted directory (assumes single top-level dir)
    SRC_DIR=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)

    if [ -z "$SRC_DIR" ]; then
        print_msg "$RED" "Error: No directory found after extraction"
        exit 1
    fi

    print_msg "$GREEN" "Source extracted to: $SRC_DIR"
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input-file)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    print_msg "$RED" "Error: -i/--input-file requires a file argument"
                    exit 1
                fi
                INPUT_FILE="$2"
                shift 2
                ;;
            -o|--output)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    print_msg "$RED" "Error: -o/--output requires a directory argument"
                    exit 1
                fi
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -t|--type)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    print_msg "$RED" "Error: -t/--type requires a build type argument (native, docker, clean, all)"
                    exit 1
                fi
                BUILD_TYPE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                print_msg "$RED" "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                print_msg "$RED" "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check if Docker is available and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_msg "$RED" "Error: Docker is not installed"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_msg "$RED" "Error: Docker daemon is not running"
        exit 1
    fi
}

# Setup Docker buildx for multi-architecture builds
setup_buildx() {
    print_msg "$YELLOW" "Setting up Docker buildx for multi-architecture builds..."

    # Check if buildx is available
    if ! docker buildx version &> /dev/null; then
        print_msg "$RED" "Error: Docker buildx is not available. Please update Docker Desktop."
        exit 1
    fi

    # Create or use existing builder
    local builder_name="rdseed-multiarch"
    if ! docker buildx inspect "$builder_name" &> /dev/null; then
        print_msg "$YELLOW" "Creating buildx builder: $builder_name"
        docker buildx create --name "$builder_name" --use --bootstrap
    else
        docker buildx use "$builder_name"
    fi
}

# Build for a specific platform using Docker
build_docker_platform() {
    local platform=$1
    local output_subdir=$2

    print_msg "$GREEN" "Building for $platform..."

    local output_path="$OUTPUT_DIR/$output_subdir"
    mkdir -p "$output_path"

    # Build and extract binary (use SRC_DIR as context)
    docker buildx build \
        --platform "$platform" \
        --target builder \
        --output "type=local,dest=$output_path" \
        --file "$SCRIPT_DIR/Dockerfile" \
        "$SRC_DIR"

    # The binary is in the /src directory of the builder stage
    # Clean up all the extra filesystem directories that buildx exports
    if [ -f "$output_path/src/rdseed" ]; then
        mv "$output_path/src/rdseed" "$output_path/rdseed"
    fi

    # Clean up extra directories from buildx export
    for dir in bin boot dev etc home lib lib64 media mnt opt proc root run sbin srv sys tmp usr var src; do
        rm -rf "$output_path/$dir" 2>/dev/null || true
    done

    if [ -f "$output_path/rdseed" ]; then
        print_msg "$GREEN" "Binary created: $output_path/rdseed"
        file "$output_path/rdseed"
    else
        print_msg "$RED" "Error: Binary not found for $platform"
        return 1
    fi
}

# Build using Docker for Linux platforms
build_docker() {
    check_docker
    setup_buildx

    print_msg "$GREEN" "========================================="
    print_msg "$GREEN" "Building rdseed with Docker (multi-arch)"
    print_msg "$GREEN" "========================================="

    # Build for ARM64
    build_docker_platform "linux/arm64" "linux-arm64"

    # Build for AMD64
    build_docker_platform "linux/amd64" "linux-amd64"

    print_msg "$GREEN" ""
    print_msg "$GREEN" "Docker build complete!"
    print_msg "$GREEN" "Binaries available in:"
    print_msg "$GREEN" "  - $OUTPUT_DIR/linux-arm64/rdseed"
    print_msg "$GREEN" "  - $OUTPUT_DIR/linux-amd64/rdseed"
}

# Build natively for the host system
build_native() {
    print_msg "$GREEN" "========================================="
    print_msg "$GREEN" "Building rdseed natively for host system"
    print_msg "$GREEN" "========================================="

    # Detect OS and architecture
    local os_type=$(uname -s)
    local arch_type=$(uname -m)

    # Normalize OS name
    local os_name
    case "$os_type" in
        Darwin) os_name="macos" ;;
        Linux)  os_name="linux" ;;
        *)      os_name=$(echo "$os_type" | tr '[:upper:]' '[:lower:]') ;;
    esac

    # Normalize architecture name
    local arch_name
    case "$arch_type" in
        x86_64)         arch_name="amd64" ;;
        aarch64|arm64)  arch_name="arm64" ;;
        *)              arch_name="$arch_type" ;;
    esac

    local output_subdir="${os_name}-${arch_name}"
    local output_path="$OUTPUT_DIR/$output_subdir"
    mkdir -p "$output_path"

    local cc="cc"
    # Use gnu89 standard to allow legacy C code with implicit function declarations
    local cflags="-O2 -g -std=gnu89 -Wno-return-type -Wno-implicit-function-declaration"
    local ldflags="-lm"

    case "$os_type" in
        Darwin)
            print_msg "$YELLOW" "Detected macOS ($arch_type) -> $output_subdir"
            # On macOS, use clang (default cc)
            cc="clang"
            ldflags="-lm -lc"
            ;;
        Linux)
            print_msg "$YELLOW" "Detected Linux ($arch_type) -> $output_subdir"
            cc="gcc"
            ldflags="-lm"
            ;;
        *)
            print_msg "$YELLOW" "Detected $os_type ($arch_type) -> $output_subdir"
            ;;
    esac

    # Clean previous build
    print_msg "$YELLOW" "Cleaning previous build..."
    make -C "$SRC_DIR" clean 2>/dev/null || true

    # Build
    print_msg "$YELLOW" "Compiling with: CC=$cc CFLAGS=\"$cflags\" LDFLAGS=\"$ldflags\""
    print_msg "$YELLOW" "Source directory: $SRC_DIR"
    make -C "$SRC_DIR" CC="$cc" CFLAGS="$cflags" LDFLAGS="$ldflags"

    # Copy binary to output directory
    if [ -f "$SRC_DIR/rdseed" ]; then
        cp "$SRC_DIR/rdseed" "$output_path/rdseed"
        print_msg "$GREEN" ""
        print_msg "$GREEN" "Native build complete!"
        print_msg "$GREEN" "Binary available at: $output_path/rdseed"
        file "$output_path/rdseed"
    else
        print_msg "$RED" "Error: Build failed - rdseed binary not created"
        exit 1
    fi
}

# Clean all build artifacts
clean() {
    print_msg "$YELLOW" "Cleaning build artifacts..."

    # Clean make artifacts (only if SRC_DIR has a Makefile)
    if [ -f "$SRC_DIR/Makefile" ]; then
        make -C "$SRC_DIR" clean 2>/dev/null || true
    fi

    # Remove output directory
    if [ -d "$OUTPUT_DIR" ]; then
        rm -rf "$OUTPUT_DIR"
        print_msg "$GREEN" "Removed: $OUTPUT_DIR"
    fi

    # Remove tmp directory (extracted sources)
    if [ -d "$SCRIPT_DIR/tmp" ]; then
        rm -rf "$SCRIPT_DIR/tmp"
        print_msg "$GREEN" "Removed: $SCRIPT_DIR/tmp"
    fi

    # Remove rdseed binary in root (legacy location)
    if [ -f "$SCRIPT_DIR/rdseed" ]; then
        rm -f "$SCRIPT_DIR/rdseed"
        print_msg "$GREEN" "Removed: $SCRIPT_DIR/rdseed"
    fi

    # Remove Docker builder (optional, commented out to preserve for faster rebuilds)
    # docker buildx rm rdseed-multiarch 2>/dev/null || true

    print_msg "$GREEN" "Clean complete!"
}

# Show usage
usage() {
    echo "Usage: $0 -i <file> [options]"
    echo ""
    echo "Options:"
    echo "  -i, --input-file <file>  Input tar.gz file containing rdseed source (REQUIRED)"
    echo "  -o, --output <dir>       Output directory for built binaries (default: ./output)"
    echo "  -t, --type <type>        Build type: native, docker, clean, all (default: docker)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Build types:"
    echo "  docker    Build for Linux (arm64 + x86_64) via Docker (default)"
    echo "  native    Build natively for the host system (macOS or Linux)"
    echo "  clean     Clean all build artifacts"
    echo "  all       Build both Docker and native"
    echo ""
    echo "Output:"
    echo "  <output>/linux-arm64/rdseed    - Linux ARM64 binary (Docker)"
    echo "  <output>/linux-amd64/rdseed    - Linux x86_64 binary (Docker)"
    echo "  <output>/<os>-<arch>/rdseed    - Native binary (e.g., macos-arm64, linux-amd64)"
    echo ""
    echo "Examples:"
    echo "  $0 -i soft/rdseedv5.3.1.tar.gz                    # Build Linux binaries (Docker)"
    echo "  $0 -i soft/rdseedv5.3.1.tar.gz -t native          # Build native binary"
    echo "  $0 -i soft/rdseedv5.3.1.tar.gz -t all             # Build all targets"
    echo "  $0 -i soft/rdseedv5.3.1.tar.gz -o ./dist -t all   # Custom output directory"
}

# Main

# Parse command-line arguments
parse_args "$@"

# Validate required parameters
if [ -z "$INPUT_FILE" ]; then
    print_msg "$RED" "Error: Input file is required"
    print_msg "$RED" "Use -i or --input-file to specify the tar.gz source archive"
    echo ""
    usage
    exit 1
fi

# Convert OUTPUT_DIR to absolute path if relative
if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/$OUTPUT_DIR"
fi

# Convert INPUT_FILE to absolute path if relative
if [[ "$INPUT_FILE" != /* ]]; then
    INPUT_FILE="$SCRIPT_DIR/$INPUT_FILE"
fi

# Extract source from input file
extract_source "$INPUT_FILE"

# Execute build based on BUILD_TYPE
case "$BUILD_TYPE" in
    docker)
        build_docker
        ;;
    native)
        build_native
        ;;
    clean)
        clean
        ;;
    all)
        build_docker
        build_native
        ;;
    *)
        print_msg "$RED" "Unknown build type: $BUILD_TYPE"
        print_msg "$RED" "Valid types: native, docker, clean, all"
        usage
        exit 1
        ;;
esac
