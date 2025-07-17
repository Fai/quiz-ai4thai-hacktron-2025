# Build stage
FROM rust:1.82-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    musl-dev \
    pkgconfig \
    openssl-dev \
    curl

# Set working directory
WORKDIR /app

# Copy workspace files
COPY Cargo.toml Cargo.lock ./
COPY api1/Cargo.toml ./api1/
COPY api2/Cargo.toml ./api2/

# Create dummy source files to cache dependencies
RUN mkdir -p api1/src api2/src && \
    echo "fn main() {}" > api1/src/main.rs && \
    echo "fn main() {}" > api2/src/main.rs

# Build dependencies
RUN cargo build --release --bin api2

# Remove dummy files and copy real source
RUN rm -rf api1/src api2/src
COPY api1/src ./api1/src
COPY api2/src ./api2/src

# Build the application
RUN cargo build --release --bin api2

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    libgcc

# Create non-root user
RUN adduser -D -s /bin/sh appuser

# Copy the binary
COPY --from=builder /app/target/release/api2 /usr/local/bin/api2

# Change ownership
RUN chown appuser:appuser /usr/local/bin/api2

# Switch to non-root user
USER appuser

# Expose ports
EXPOSE 4000 4443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Run the application
CMD ["api2"]
