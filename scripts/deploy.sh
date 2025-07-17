#!/bin/bash

# Time Service API Deployment Script
# This script handles deployment to different environments

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${1:-development}"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Function to validate environment
validate_environment() {
    case $ENVIRONMENT in
        development|staging|production)
            log_info "Deploying to $ENVIRONMENT environment"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            log_info "Valid environments: development, staging, production"
            exit 1
            ;;
    esac
}

# Function to build images
build_images() {
    log_info "Building Docker images..."

    cd "$PROJECT_ROOT"

    # Build with build cache
    docker-compose build --parallel

    log_success "Images built successfully"
}

# Function to run pre-deployment checks
pre_deployment_checks() {
    log_info "Running pre-deployment checks..."

    # Check if ports are available
    if lsof -i :3000 &> /dev/null; then
        log_warning "Port 3000 is already in use"
    fi

    if lsof -i :4000 &> /dev/null; then
        log_warning "Port 4000 is already in use"
    fi

    # Validate Docker Compose file
    if ! docker-compose config &> /dev/null; then
        log_error "Docker Compose configuration is invalid"
        exit 1
    fi

    log_success "Pre-deployment checks passed"
}

# Function to deploy services
deploy_services() {
    log_info "Deploying services..."

    cd "$PROJECT_ROOT"

    # Stop existing services
    docker-compose down

    # Start services
    docker-compose up -d

    log_success "Services deployed successfully"
}

# Function to wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to be ready..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:3000/health &> /dev/null && \
           curl -s http://localhost:4000/health &> /dev/null; then
            log_success "Services are ready"
            return 0
        fi

        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done

    log_error "Services failed to start within expected time"
    exit 1
}

# Function to run health checks
run_health_checks() {
    log_info "Running health checks..."

    # Check API1 health
    if ! curl -s http://localhost:3000/health | jq -e '.status == "healthy"' &> /dev/null; then
        log_error "API1 health check failed"
        exit 1
    fi

    # Check API2 health
    if ! curl -s http://localhost:4000/health | jq -e '.status == "healthy"' &> /dev/null; then
        log_error "API2 health check failed"
        exit 1
    fi

    log_success "Health checks passed"
}

# Function to run integration tests
run_integration_tests() {
    log_info "Running integration tests..."

    if [ -f "$SCRIPT_DIR/test.sh" ]; then
        bash "$SCRIPT_DIR/test.sh"
    else
        log_warning "Integration test script not found"
    fi
}

# Function to display deployment information
display_deployment_info() {
    log_info "Deployment Information:"
    echo "======================="
    echo "Environment: $ENVIRONMENT"
    echo "API1 HTTP:   http://localhost:3000"
    echo "API1 HTTPS:  https://localhost:3443"
    echo "API2 HTTP:   http://localhost:4000"
    echo "API2 HTTPS:  https://localhost:4443"
    echo
    echo "Health Endpoints:"
    echo "  API1: http://localhost:3000/health"
    echo "  API2: http://localhost:4000/health"
    echo
    echo "Time Endpoints:"
    echo "  API1: http://localhost:3000/time"
    echo "  API2: http://localhost:4000/time"
    echo
    echo "Example Usage:"
    echo "  curl 'http://localhost:3000/time'"
    echo "  curl 'http://localhost:3000/time?timezone=EST'"
    echo
    echo "View logs: docker-compose logs -f"
    echo "Stop services: docker-compose down"
}

# Function to setup monitoring
setup_monitoring() {
    log_info "Setting up monitoring..."

    # This would typically set up metrics collection, alerting, etc.
    # For now, just show how to view logs
    echo "To monitor the services:"
    echo "  docker-compose logs -f"
    echo "  docker stats"

    log_success "Monitoring setup completed"
}

# Function to cleanup old resources
cleanup() {
    log_info "Cleaning up old resources..."

    # Remove unused images
    docker image prune -f

    # Remove unused volumes
    docker volume prune -f

    log_success "Cleanup completed"
}

# Main deployment workflow
main() {
    echo "🚀 Time Service API Deployment"
    echo "=============================="

    check_prerequisites
    validate_environment
    pre_deployment_checks
    build_images
    deploy_services
    wait_for_services
    run_health_checks

    if [ "$ENVIRONMENT" = "development" ]; then
        run_integration_tests
    fi

    setup_monitoring
    display_deployment_info
    cleanup

    log_success "Deployment completed successfully!"
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"
