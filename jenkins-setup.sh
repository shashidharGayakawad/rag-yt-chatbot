#!/bin/bash
# Jenkins Quick Start Script
# Usage: ./jenkins-setup.sh [start|stop|logs|status|clean|help]

set -e

COMMAND=${1:-start}
COMPOSE_FILE="docker-compose.jenkins.yml"
CONTAINER_NAME="jenkins-controller"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERR]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not installed"
        exit 1
    fi
    print_success "Docker found"
}

check_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose not installed"
        exit 1
    fi
    print_success "Docker Compose found"
}

start_jenkins() {
    print_status "Starting Jenkins..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "File not found: $COMPOSE_FILE"
        exit 1
    fi
    
    docker-compose -f "$COMPOSE_FILE" up -d
    print_success "Jenkins started"
    
    print_status "Waiting for Jenkins..."
    sleep 10
    
    INITIAL_PASSWORD=$(docker-compose -f "$COMPOSE_FILE" exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Jenkins Started!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "URL: http://localhost:8080"
    if [ -n "$INITIAL_PASSWORD" ]; then
        echo "Initial Password: $INITIAL_PASSWORD"
    fi
    echo ""
}

stop_jenkins() {
    print_status "Stopping Jenkins..."
    docker-compose -f "$COMPOSE_FILE" down
    print_success "Jenkins stopped"
}

view_logs() {
    print_status "Showing Jenkins logs (Ctrl+C to exit)..."
    docker-compose -f "$COMPOSE_FILE" logs -f jenkins
}

status_jenkins() {
    print_status "Checking Jenkins status..."
    if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" --quiet | grep -q . ; then
        print_success "Jenkins is running"
        echo ""
        docker ps --filter "name=$CONTAINER_NAME"
    else
        print_error "Jenkins is not running"
    fi
}

clean_jenkins() {
    print_warn "This will delete all Jenkins data!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        print_status "Cleaning up..."
        docker-compose -f "$COMPOSE_FILE" down -v
        print_success "Jenkins cleaned"
    else
        print_status "Cleanup cancelled"
    fi
}

show_help() {
    echo "Jenkins Quick Start"
    echo ""
    echo "Usage: ./jenkins-setup.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start   - Start Jenkins container"
    echo "  stop    - Stop Jenkins container"
    echo "  logs    - View Jenkins logs"
    echo "  status  - Check Jenkins status"
    echo "  clean   - Remove Jenkins data (DESTRUCTIVE)"
    echo "  help    - Show this help"
    echo ""
}

case "$COMMAND" in
    start)
        check_docker
        check_compose
        start_jenkins
        ;;
    stop)
        check_docker
        check_compose
        stop_jenkins
        ;;
    logs)
        check_docker
        check_compose
        view_logs
        ;;
    status)
        check_docker
        status_jenkins
        ;;
    clean)
        check_docker
        check_compose
        clean_jenkins
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
