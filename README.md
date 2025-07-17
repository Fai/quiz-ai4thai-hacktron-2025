# QUIZ-AI4THAI-HACKTRON-2025

A cloud-native microservices architecture built with Rust, featuring two API services that work together to provide current server time information. This project follows AWS best practices for API design, system design, and cloud-native development.

## Architecture Overview

```
User Request → API1 (Gateway:3000/3443) → API2 (Time Provider:4000/4443) → Response
```

- **API1** (Gateway Service): Receives user requests and forwards them to API2
- **API2** (Time Provider): Returns current server datetime based on timezone
- Both services run on standard HTTP (3000, 4000) and secure HTTPS (3443, 4443) ports
- Comprehensive logging and monitoring
- Containerized with Docker and orchestrated with Docker Compose

## Complete Repository Structure

```sh
/
├── Cargo.toml              # Workspace config
├── docker-compose.yml      # Container orchestration
├── README.md              # Documentation
├── .gitignore             # Git ignore rules
├── api1/                  # Gateway service
│   ├── Cargo.toml
│   ├── Dockerfile
│   └── src/
│       └── main.rs
├── api2/                  # Time provider service
│   ├── Cargo.toml
│   ├── Dockerfile
│   └── src/
│       └── main.rs
└── scripts/               # Deployment scripts
    ├── deploy.sh
    └── test.sh
```

### Core Application Files:

Cargo.toml - Workspace configuration with shared dependencies
api1/src/main.rs - Gateway service that forwards requests to API2
api2/src/main.rs - Time provider service that returns server datetime
api1/Cargo.toml & api2/Cargo.toml - Individual service dependencies

### Docker & Deployment:

docker-compose.yml - Full orchestration with health checks, networking, and resource limits
api1/Dockerfile & api2/Dockerfile - Multi-stage builds with security best practices
scripts/deploy.sh - Production-ready deployment script
scripts/test.sh - Comprehensive testing script

### Development & CI/CD:

Makefile - Development workflow automation
.github/workflows/ci.yml - Complete CI/CD pipeline
README.md - Comprehensive documentation
LICENSE - MIT license

## Features

- ✅ **Cloud-Native Architecture**: Microservices with proper service discovery
- ✅ **Security**: HTTPS endpoints, non-root containers, resource limits
- ✅ **Observability**: Structured logging, health checks, request tracing
- ✅ **Reliability**: Graceful error handling, circuit breaker patterns
- ✅ **Scalability**: Containerized services with resource management
- ✅ **Developer Experience**: Comprehensive tooling and documentation

## API Endpoints

### API1 (Gateway Service)
- **Base URL**: `http://localhost:3000` (HTTP) / `https://localhost:3443` (HTTPS)
- `GET /` - Service information
- `GET /health` - Health check endpoint
- `GET /time?timezone=<tz>` - Get current time (forwards to API2)

### API2 (Time Provider)
- **Base URL**: `http://localhost:4000` (HTTP) / `https://localhost:4443` (HTTPS)
- `GET /` - Service information
- `GET /health` - Health check endpoint
- `GET /time?timezone=<tz>` - Get current server time

### Supported Timezones
- `UTC` (default)
- `EST` / `US/Eastern`
- `PST` / `US/Pacific`
- `CET` / `Europe/Berlin`

## Quick Start

### Prerequisites
- Docker and Docker Compose
- `curl` and `jq` for testing (optional)
- Rust 1.75+ (for local development)

### 1. Clone the Repository
```bash
git clone <repository-url>
cd time-service-api
```

### 2. Build and Run with Docker Compose
```bash
# Build and start services
docker-compose up --build

# Or run in detached mode
docker-compose up --build -d
```

### 3. Verify Services are Running
```bash
# Check health
curl http://localhost:3000/health
curl http://localhost:4000/health

# Test the time endpoint
curl "http://localhost:3000/time"
curl "http://localhost:3000/time?timezone=EST"
```

## Development

### Using Make Commands
```bash
# Setup development environment
make dev-setup

# Build and run services
make run

# Run in background
make dev-up

# Stop services
make dev-down

# View logs
make logs

# Health check
make health-check

# Test endpoints
make test-endpoints

# Clean up
make clean
```

### Local Development
```bash
# Install dependencies
cargo build

# Run API1 locally
cd api1
cargo run

# Run API2 locally (in another terminal)
cd api2
cargo run
```

## Testing

### Manual Testing
```bash
# Test API1 (Gateway)
curl -X GET "http://localhost:3000/time"
curl -X GET "http://localhost:3000/time?timezone=EST"

# Test API2 (Direct)
curl -X GET "http://localhost:4000/time"
curl -X GET "http://localhost:4000/time?timezone=PST"

# Health checks
curl -X GET "http://localhost:3000/health"
curl -X GET "http://localhost:4000/health"
```

### Expected Response Format
```json
{
  "timestamp": "2024-01-20T15:30:45.123Z",
  "timezone": "UTC",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "source": "api1->api2"
}
```

### Load Testing
```bash
# Install hey (HTTP load testing tool)
go install github.com/rakyll/hey@latest

# Basic load test
hey -n 1000 -c 10 http://localhost:3000/time

# Load test with different timezones
hey -n 500 -c 5 "http://localhost:3000/time?timezone=EST"
```

## Monitoring and Observability

### Logs
The application uses structured logging with the following log levels:
- `DEBUG`: Detailed request/response information
- `INFO`: General application flow
- `WARN`: Recoverable errors
- `ERROR`: Unrecoverable errors

### Viewing Logs
```bash
# All logs
docker-compose logs -f

# API1 logs only
docker-compose logs -f api1

# API2 logs only
docker-compose logs -f api2

# Filter by log level
docker-compose logs api1 | grep ERROR
```

### Health Checks
Both services provide comprehensive health checks:
- Container-level health checks via Docker
- Application-level health endpoints
- Service dependency checks

### Metrics
Key metrics to monitor:
- Request latency
- Error rates
- Service availability
- Resource utilization

## Configuration

### Environment Variables
- `API2_URL`: URL for API2 service (default: `http://api2:4000`)
- `RUST_LOG`: Log level configuration (default: `debug`)

### Docker Compose Configuration
- **Resource Limits**: CPU and memory limits for production deployment
- **Health Checks**: Automated health monitoring
- **Networking**: Isolated service network
- **Restart Policy**: Automatic restart on failure

## Security Considerations

### Container Security
- Non-root user execution
- Minimal base images
- Multi-stage builds
- Resource limits

### Network Security
- Internal service communication
- CORS configuration
- Request/response validation

### Production Deployment
For production deployment, consider:
- TLS/SSL certificate configuration
- API rate limiting
- Authentication and authorization
- Database integration for persistent storage
- Load balancing
- Service mesh (Istio, Linkerd)

## Troubleshooting

### Common Issues

1. **Services not starting**
   ```bash
   # Check logs
   docker-compose logs

   # Rebuild containers
   docker-compose up --build --force-recreate
   ```

2. **API1 cannot reach API2**
   ```bash
   # Check network connectivity
   docker-compose exec api1 curl http://api2:4000/health
   ```

3. **Port conflicts**
   ```bash
   # Check what's using the ports
   lsof -i :3000
   lsof -i :4000
   ```

4. **Memory or CPU issues**
   ```bash
   # Check resource usage
   docker stats
   ```

### Debug Mode
```bash
# Run with debug logging
RUST_LOG=debug docker-compose up

# Access container shell
docker-compose exec api1 /bin/bash
```

## Contributing

### Development Workflow
1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Run tests and linting
5. Submit a pull request

### Code Quality
```bash
# Format code
cargo fmt

# Run linter
cargo clippy

# Run tests
cargo test

# Security audit
cargo audit
```

### Git Hooks
Consider setting up pre-commit hooks:
```bash
# Install pre-commit
pip install pre-commit

# Setup hooks
pre-commit install
```

## Architecture Decisions

### Technology Stack
- **Rust**: Memory safety, performance, and concurrency
- **Axum**: Modern, ergonomic web framework
- **Tokio**: Async runtime for high-performance I/O
- **Tower**: Middleware and service abstractions
- **Docker**: Containerization and deployment

### Design Patterns
- **Gateway Pattern**: API1 acts as a gateway to API2
- **Health Check Pattern**: Comprehensive health monitoring
- **Circuit Breaker**: Graceful error handling
- **Structured Logging**: Consistent log format across services

## Performance Considerations

### Optimization Strategies
- Connection pooling for HTTP clients
- Async/await for non-blocking I/O
- Efficient JSON serialization
- Memory-efficient data structures

### Benchmarks
Expected performance characteristics:
- **Latency**: < 10ms for local requests
- **Throughput**: > 1000 requests/second
- **Memory**: < 50MB per service
- **CPU**: < 10% under normal load

## Future Enhancements

### Planned Features
- [ ] Authentication and authorization
- [ ] Rate limiting
- [ ] Caching layer (Redis)
- [ ] Database integration
- [ ] Metrics collection (Prometheus)
- [ ] Distributed tracing (Jaeger)
- [ ] API versioning
- [ ] WebSocket support

### Infrastructure
- [ ] Kubernetes deployment
- [ ] Helm charts
- [ ] CI/CD pipeline
- [ ] Infrastructure as Code (Terraform)
- [ ] Service mesh integration

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions:
- Create an issue on GitHub
- Check the troubleshooting section
- Review the logs for error details

---

**Built with ❤️ by KPR Team**
