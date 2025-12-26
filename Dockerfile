# Build stage
FROM rust:1.83 as builder

WORKDIR /app

# Copy manifest files
COPY Cargo.toml ./
# Note: Cargo.lock will be generated automatically during build if it doesn't exist

# Copy source code
COPY main.rs ./

# Build the application
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/target/release/actix-server /app/actix-server

# Expose port
EXPOSE 8080

# Run the application
CMD ["./actix-server"]

