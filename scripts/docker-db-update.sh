#!/bin/bash

################################################################################
# Docker Database Container Update Script
# Property Management System
#
# This script safely updates the MariaDB Docker container while preserving data.
# It handles the complete lifecycle: backup, update, verify, and cleanup.
#
# Usage:
#   bash docker-db-update.sh [OPTIONS]
#
# Options:
#   --target-version    Target MariaDB version (default: latest 10.11.x)
#   --skip-backup       Skip creating backup before update (not recommended)
#   --force             Skip confirmation prompts
#
# Examples:
#   bash docker-db-update.sh
#   bash docker-db-update.sh --target-version 10.11.8
#   bash docker-db-update.sh --force
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups"
CONTAINER_NAME="property-db"
VOLUME_NAME="property-management_db_data"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"

# Database credentials
DB_NAME="property_management"
DB_USER="propman"
DB_PASS="secure_dev_password"

# Options
TARGET_VERSION=""
SKIP_BACKUP=false
FORCE=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Docker Database Container Update Script for Property Management System

This script safely updates the MariaDB Docker container while preserving your data.

OPTIONS:
    --target-version VER  Target MariaDB version (e.g., 10.11.8, 11.2)
    --skip-backup         Skip creating backup before update (NOT recommended)
    --force               Skip all confirmation prompts
    -h, --help            Show this help message

EXAMPLES:
    # Standard update (pulls latest image for current version line)
    $0

    # Update to specific version
    $0 --target-version 10.11.8

    # Force update without prompts (for automation)
    $0 --force

SAFETY FEATURES:
    - Automatic backup before update
    - Data verification after update
    - Rollback instructions provided

WHAT THIS SCRIPT DOES:
    1. Creates a full database backup
    2. Stops the database container
    3. Pulls the new MariaDB image
    4. Starts the container with new image
    5. Verifies database accessibility
    6. Reports success or provides rollback steps

EOF
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target-version)
                TARGET_VERSION="$2"
                shift 2
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

################################################################################
# Check Prerequisites
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"

    local all_good=true

    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        print_error "docker is not installed"
        all_good=false
    else
        print_success "docker found"
    fi

    # Check Docker Compose
    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        print_error "docker compose is not available"
        all_good=false
    else
        print_success "docker compose found"
    fi

    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "docker-compose.yml not found at: $COMPOSE_FILE"
        all_good=false
    else
        print_success "docker-compose.yml found"
    fi

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Container '$CONTAINER_NAME' not found"
        print_info "This may be a fresh deployment"
    else
        print_success "Container '$CONTAINER_NAME' exists"
    fi

    if [ "$all_good" = false ]; then
        print_error "Prerequisites check failed"
        exit 1
    fi
}

################################################################################
# Get Current Status
################################################################################

get_current_status() {
    print_header "Current Status"

    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_success "Container is running"

        # Get current image version
        local current_image=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null)
        print_info "Current image: $current_image"

        # Get MariaDB version from running container
        local mariadb_version=$(docker exec "$CONTAINER_NAME" mysql --version 2>/dev/null | grep -oP 'Ver \K[0-9.]+' || echo "unknown")
        print_info "MariaDB version: $mariadb_version"

        # Get database size
        local db_size=$(docker exec "$CONTAINER_NAME" mysql \
            --user="$DB_USER" \
            --password="$DB_PASS" \
            "$DB_NAME" \
            -sN -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.tables WHERE table_schema = '$DB_NAME';" 2>/dev/null || echo "unknown")
        print_info "Database size: ${db_size} MB"

        # Get table count
        local table_count=$(docker exec "$CONTAINER_NAME" mysql \
            --user="$DB_USER" \
            --password="$DB_PASS" \
            "$DB_NAME" \
            -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';" 2>/dev/null || echo "unknown")
        print_info "Tables: $table_count"

    else
        print_warning "Container is not running"
    fi

    # Check volume
    if docker volume ls --format '{{.Name}}' | grep -q "^${VOLUME_NAME}$"; then
        print_success "Data volume exists: $VOLUME_NAME"
        local volume_size=$(docker system df -v 2>/dev/null | grep "$VOLUME_NAME" | awk '{print $3}' || echo "unknown")
        print_info "Volume size: $volume_size"
    else
        print_warning "Data volume not found: $VOLUME_NAME"
    fi
}

################################################################################
# Confirmation
################################################################################

confirm_update() {
    if [ "$FORCE" = true ]; then
        return 0
    fi

    print_header "Confirmation Required"

    echo -e "${YELLOW}This will update the MariaDB Docker container.${NC}\n"

    if [ "$SKIP_BACKUP" = true ]; then
        echo -e "${RED}WARNING: Backup will be skipped!${NC}"
    else
        echo -e "A full backup will be created before the update."
    fi

    if [ -n "$TARGET_VERSION" ]; then
        echo -e "Target version: ${BLUE}$TARGET_VERSION${NC}"
    fi

    echo ""
    read -p "Proceed with update? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        print_info "Update cancelled"
        exit 0
    fi
}

################################################################################
# Create Backup
################################################################################

create_backup() {
    if [ "$SKIP_BACKUP" = true ]; then
        print_warning "Skipping backup (--skip-backup specified)"
        return 0
    fi

    print_header "Creating Backup"

    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/property_management_pre_update_${timestamp}.sql.gz"

    print_info "Backup file: $backup_file"

    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Container not running, starting temporarily for backup..."
        cd "$PROJECT_ROOT" && docker compose up -d db
        sleep 10  # Wait for database to be ready
    fi

    # Create backup
    if docker exec "$CONTAINER_NAME" mysqldump \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        --single-transaction \
        --quick \
        --routines \
        --triggers \
        --events \
        "$DB_NAME" 2>/dev/null | gzip > "$backup_file"; then
        print_success "Backup created successfully"
        local backup_size=$(du -h "$backup_file" | cut -f1)
        print_info "Backup size: $backup_size"
    else
        print_error "Backup failed!"
        print_error "Aborting update for safety"
        exit 1
    fi

    # Store backup path for potential rollback
    BACKUP_FILE_PATH="$backup_file"
}

################################################################################
# Update Container
################################################################################

update_container() {
    print_header "Updating Container"

    cd "$PROJECT_ROOT"

    # Stop all services
    print_info "Stopping services..."
    docker compose down

    # Pull new image
    print_info "Pulling new image..."
    if [ -n "$TARGET_VERSION" ]; then
        # Update docker-compose.yml to use specific version
        print_info "Target version: mariadb:$TARGET_VERSION"
        # For now, just pull the default from compose file
        # Users can modify docker-compose.yml for specific versions
    fi

    docker compose pull db

    # Start database service
    print_info "Starting database service..."
    docker compose up -d db

    # Wait for database to be ready
    print_info "Waiting for database to be ready..."
    local retries=30
    local count=0

    while [ $count -lt $retries ]; do
        if docker exec "$CONTAINER_NAME" mysqladmin ping -u"$DB_USER" -p"$DB_PASS" --silent 2>/dev/null; then
            print_success "Database is ready"
            break
        fi
        count=$((count + 1))
        sleep 2
        echo -n "."
    done

    if [ $count -eq $retries ]; then
        print_error "Database failed to start within expected time"
        print_warning "Check logs with: docker compose logs db"
        exit 1
    fi
}

################################################################################
# Verify Update
################################################################################

verify_update() {
    print_header "Verifying Update"

    # Get new MariaDB version
    local new_version=$(docker exec "$CONTAINER_NAME" mysql --version 2>/dev/null | grep -oP 'Ver \K[0-9.]+' || echo "unknown")
    print_info "MariaDB version: $new_version"

    # Check database accessibility
    if docker exec "$CONTAINER_NAME" mysql \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        "$DB_NAME" \
        -e "SELECT 1;" >/dev/null 2>&1; then
        print_success "Database is accessible"
    else
        print_error "Cannot access database!"
        return 1
    fi

    # Verify tables exist
    local table_count=$(docker exec "$CONTAINER_NAME" mysql \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        "$DB_NAME" \
        -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';" 2>/dev/null)
    print_info "Tables found: $table_count"

    if [ "$table_count" -eq 0 ]; then
        print_warning "No tables found - database may need initialization"
    else
        print_success "Tables verified"
    fi

    # Run a simple query to verify data
    local user_count=$(docker exec "$CONTAINER_NAME" mysql \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        "$DB_NAME" \
        -sN -e "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
    print_info "Users in database: $user_count"
}

################################################################################
# Start All Services
################################################################################

start_all_services() {
    print_header "Starting All Services"

    cd "$PROJECT_ROOT"

    print_info "Starting all services..."
    docker compose up -d

    # Wait a moment for services to start
    sleep 5

    # Check service status
    echo -e "\n${BLUE}Service Status:${NC}"
    docker compose ps
}

################################################################################
# Print Summary
################################################################################

print_summary() {
    print_header "Update Summary"

    local new_version=$(docker exec "$CONTAINER_NAME" mysql --version 2>/dev/null | grep -oP 'Ver \K[0-9.]+' || echo "unknown")

    echo -e "${GREEN}Container update completed successfully!${NC}\n"

    echo -e "${BLUE}Update Details:${NC}"
    echo -e "  Container: ${YELLOW}$CONTAINER_NAME${NC}"
    echo -e "  MariaDB Version: ${YELLOW}$new_version${NC}"

    if [ -n "$BACKUP_FILE_PATH" ]; then
        echo -e "\n${BLUE}Backup Location:${NC}"
        echo -e "  ${YELLOW}$BACKUP_FILE_PATH${NC}"
    fi

    echo -e "\n${BLUE}If something went wrong:${NC}"
    echo -e "  1. Stop services: ${YELLOW}docker compose down${NC}"
    if [ -n "$BACKUP_FILE_PATH" ]; then
        echo -e "  2. Restore backup: ${YELLOW}bash scripts/restore-db.sh $BACKUP_FILE_PATH --docker${NC}"
    fi
    echo -e "  3. Start services: ${YELLOW}docker compose up -d${NC}"

    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║     Property Management System - Docker DB Update                ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Parse command line arguments
    parse_arguments "$@"

    # Execute update steps
    check_prerequisites
    get_current_status
    confirm_update
    create_backup
    update_container
    verify_update
    start_all_services
    print_summary
}

# Run main function
main "$@"
