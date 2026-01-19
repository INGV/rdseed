# Dockerfile for building rdseed v5.3.1
# Supports multi-architecture builds (linux/arm64, linux/amd64)

FROM debian:bookworm-slim AS builder

# Install build dependencies
# Note: libtirpc-dev provides rpc/rpc.h header needed for AH format output
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        make \
        libtirpc-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /src

# Copy source code
COPY . .

# Clean any previous build artifacts
RUN make clean 2>/dev/null || true

# Compile with Linux-compatible flags
# Note: -lnsl is removed (Solaris-specific), -m64 removed (not needed for ARM64)
# Use gnu89 standard to allow legacy C code with implicit function declarations
# -I/usr/include/tirpc needed for rpc/rpc.h from libtirpc
# -fcommon allows multiple definitions of tentative definitions (legacy C behavior)
RUN make CC="gcc" \
    CFLAGS="-O2 -g -std=gnu89 -fcommon -Wno-return-type -Wno-implicit-function-declaration -I/usr/include/tirpc" \
    LDFLAGS="-lm -ltirpc"

# Verify the binary was created
RUN ls -la rdseed

# Final stage - minimal image with just the binary
FROM debian:bookworm-slim AS runtime

# Copy the compiled binary
COPY --from=builder /src/rdseed /usr/local/bin/rdseed

# Set executable permissions
RUN chmod +x /usr/local/bin/rdseed

# Default command shows help
CMD ["rdseed"]
