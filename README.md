# Building rdseed v5.3.1

This document explains how to build rdseed using the `build.sh` script.

## Prerequisites

- **Docker Desktop** (with buildx support) - for Linux cross-compilation
- **Xcode Command Line Tools** - for native macOS builds

## Quick Start

```bash
# Build Linux binaries (aarch64 + x86_64) via Docker (default)
./build.sh

# Build for your current system (macOS or Linux)
./build.sh -t native

# Build everything
./build.sh -t all

# Build from a tar.gz source archive
./build.sh -i soft/rdseedv5.3.1.tar.gz -t native
```

## Options

| Option | Description |
|--------|-------------|
| `-i, --input-file <file>` | Input tar.gz file containing rdseed source |
| `-o, --output <dir>` | Output directory for built binaries (default: `./output`) |
| `-t, --type <type>` | Build type: `native`, `docker`, `clean`, `all` (default: `docker`) |
| `-h, --help` | Show help message |

## Build Types

| Type | Description |
|------|-------------|
| `docker` | Build Linux binaries via Docker (default) |
| `native` | Build natively for the host system |
| `clean` | Remove all build artifacts |
| `all` | Build both Docker and native |

## Output

All binaries are placed in the `output/` directory (or custom directory specified with `-o`):

```
output/
├── linux-aarch64/
│   └── rdseed          # Linux ARM64 binary
├── linux-amd64/
│   └── rdseed          # Linux x86_64 binary
└── native/
    └── rdseed          # Native binary (macOS or Linux host)
```

## Platform Support

| Platform | Build Method | Binary Type |
|----------|--------------|-------------|
| Linux aarch64 | Docker | ELF 64-bit ARM |
| Linux x86_64 | Docker | ELF 64-bit x86-64 |
| macOS aarch64 | Native | Mach-O 64-bit ARM64 |
| macOS x86_64 | Native | Mach-O 64-bit x86-64 |

## Examples

### Build Linux binaries on Apple Silicon Mac

```bash
./build.sh

# Verify the binaries
file output/linux-aarch64/rdseed
# ELF 64-bit LSB executable, ARM aarch64

file output/linux-amd64/rdseed
# ELF 64-bit LSB executable, x86-64
```

### Build native macOS binary

```bash
./build.sh -t native

# Verify the binary
file output/native/rdseed
# Mach-O 64-bit executable arm64
```

### Build from a tar.gz source archive

```bash
# Build native binary from tar.gz
./build.sh -i soft/rdseedv5.3.1.tar.gz -t native

# Build all targets from tar.gz
./build.sh -i soft/rdseedv5.3.1.tar.gz -t all

# Build with custom output directory
./build.sh -i soft/rdseedv5.3.1.tar.gz -o ./dist -t native
```

### Clean and rebuild everything

```bash
./build.sh -t clean
./build.sh -t all
```

## Notes

- The Docker build creates a persistent buildx builder named `rdseed-multiarch` for faster subsequent builds
- Linux binaries are dynamically linked and require `libtirpc` at runtime for AH format support
- The native macOS build uses system libraries only
