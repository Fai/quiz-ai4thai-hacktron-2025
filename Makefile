.PHONY: build run test clean logs dev-up dev-down health-check

# Default target
all: build

# Build the project
build:
	cargo build --release

# Run development environment
dev-up:
	docker-compose up --build -d

# Stop development environment
dev-down:
	docker-compose down

# Run with logs
run:
	docker-compose up --build

# Run tests
test:
	cargo test

# Clean up
clean:
	cargo clean
	docker-compose down -v
	docker system prune -f

# Show logs
logs:
	docker-compose logs -f

# Show logs for specific service
logs-api1:
	docker-compose logs -f api1

logs-api2:
	docker-compose logs -f api2

# Health check
health-check:
	@echo "Checking API1 health..."
	@curl -s http://localhost:3000/health | jq .
	@echo "Checking API2 health..."
	@curl -s http://localhost:4000/health | jq .

# Test endpoints
test-endpoints:
	@echo "Testing API1 time endpoint..."
	@curl -s "http://localhost:3000/time" | jq .
	@echo "Testing API1 with timezone..."
	@curl -s "http://localhost:3000/time?timezone=EST" | jq .
	@echo "Testing API2 directly..."
	@curl -s "http://localhost:4000/time" | jq .

# Development setup
dev-setup:
	@echo "Installing development dependencies..."
	@command -v cargo >/dev/null 2>&1 || { echo "Rust is required but not installed. Please install Rust first."; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Please install Docker first."; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose is required but not installed. Please install Docker Compose first."; exit 1; }
	@echo "Development environment ready!"

# Format code
fmt:
	cargo fmt

# Check code
check:
	cargo check

# Run clippy
clippy:
	cargo clippy -- -D warnings
