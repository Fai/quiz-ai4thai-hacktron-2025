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
    wget \
    libgcc

# Copy the binary
COPY --from=builder /app/target/release/api2 /usr/local/bin/api2

# Change ownership and make executable
RUN chmod +x /usr/local/bin/api2

# Create a simple startup script
RUN echo '#!/bin/sh' > /usr/local/bin/start.sh && \
    echo 'echo "Starting API2..."' >> /usr/local/bin/start.sh && \
    echo 'api2' >> /usr/local/bin/start.sh && \
    chmod +x /usr/local/bin/start.sh

# Expose ports
EXPOSE 4000

# Health check with more frequent checks during startup
HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=5 \
    CMD wget -q -O - http://localhost:4000/health || exit 1

# Run the application with the startup script
CMD ["/usr/local/bin/start.sh"]
