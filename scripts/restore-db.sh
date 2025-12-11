#!/bin/bash

################################################################################
# Database Restore Script
# Property Management System
#
# This script restores the MySQL/MariaDB database from a backup file with:
# - Support for compressed (.gz) and uncompressed (.sql) backups
# - Optional backup of current database before restore
# - Verification of restored data
# - Support for restoring from S3
#
# Usage:
#   bash restore-db.sh BACKUP_FILE [OPTIONS]
#
# Options:
#   --no-backup         Skip backing up current database before restore
#   --s3-bucket BUCKET  Download backup from S3 bucket
#   --docker            Restore to Docker container instead of local database
#   --force             Skip confirmation prompt
#
# Examples:
#   bash restore-db.sh backups/property_management_20240101_120000.sql.gz
#   bash restore-db.sh property_management_backup.sql.gz --docker
#   bash restore-db.sh backup.sql.gz --s3-bucket my-backups
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
DB_NAME="property_management"
DB_USER="propman"
DB_PASS="secure_dev_password"
DB_HOST="localhost"

# Restore configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups"
CREATE_BACKUP=true
S3_BUCKET=""
USE_DOCKER=false
FORCE=false
BACKUP_FILE=""

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
Usage: $0 BACKUP_FILE [OPTIONS]

Database Restore Script for Property Management System

ARGUMENTS:
    BACKUP_FILE         Path to backup file (.sql or .sql.gz)

OPTIONS:
    --no-backup         Skip backing up current database before restore
    --s3-bucket BUCKET  Download backup from S3 bucket first
    --docker            Restore to Docker container (uses 'property-db' container)
    --force             Skip confirmation prompt
    -h, --help          Show this help message

EXAMPLES:
    # Restore from local backup
    $0 backups/property_management_20240101_120000.sql.gz

    # Restore to Docker container
    $0 backups/property_management_20240101_120000.sql.gz --docker

    # Restore from S3
    $0 property_management_20240101_120000.sql.gz --s3-bucket my-backups

    # Restore without creating backup of current data
    $0 backup.sql.gz --no-backup

    # Force restore without confirmation
    $0 backup.sql.gz --force

NOTES:
    - By default, the current database is backed up before restore
    - Compressed (.gz) files are automatically decompressed
    - For Docker, the container must be running

EOF
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    # First argument should be the backup file
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi

    BACKUP_FILE="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-backup)
                CREATE_BACKUP=false
                shift
                ;;
            --s3-bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            --docker)
                USE_DOCKER=true
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

    # Check if using Docker
    if [ "$USE_DOCKER" = true ]; then
        if ! command -v docker >/dev/null 2>&1; then
            print_error "docker is not installed"
            all_good=false
        else
            print_success "docker found"
        fi

        # Check if container is running
        if ! docker ps --format '{{.Names}}' | grep -q "^property-db$"; then
            print_error "Docker container 'property-db' is not running"
            print_info "Start it with: docker compose up -d db"
            all_good=false
        else
            print_success "Docker container 'property-db' is running"
        fi
    else
        # Check if mysql is available
        if ! command -v mysql >/dev/null 2>&1; then
            print_error "mysql client is not installed"
            all_good=false
        else
            print_success "mysql client found"
        fi

        # Check database connection
        print_info "Testing database connection..."
        if mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" "$DB_NAME" -e "SELECT 1;" > /dev/null 2>&1; then
            print_success "Database connection successful"
        else
            print_error "Cannot connect to database"
            all_good=false
        fi
    fi

    # Check if gzip is available (for compressed backups)
    if ! command -v gzip >/dev/null 2>&1; then
        print_error "gzip is not installed"
        all_good=false
    else
        print_success "gzip found"
    fi

    # Download from S3 if specified
    if [ -n "$S3_BUCKET" ]; then
        if ! command -v aws >/dev/null 2>&1; then
            print_error "aws-cli is not installed (required for S3 download)"
            all_good=false
        else
            print_success "aws-cli found"
            download_from_s3
        fi
    fi

    # Check if backup file exists
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Backup file not found: $BACKUP_FILE"
        all_good=false
    else
        print_success "Backup file found: $BACKUP_FILE"
        local file_size=$(du -h "$BACKUP_FILE" | cut -f1)
        print_info "File size: $file_size"
    fi

    if [ "$all_good" = false ]; then
        print_error "Prerequisites check failed"
        exit 1
    fi
}

################################################################################
# Download from S3
################################################################################

download_from_s3() {
    print_header "Downloading from S3"

    local s3_path="s3://${S3_BUCKET}/property-management/backups/${BACKUP_FILE}"
    local local_path="${BACKUP_DIR}/$(basename "$BACKUP_FILE")"

    print_info "S3 path: $s3_path"
    print_info "Local path: $local_path"

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    if aws s3 cp "$s3_path" "$local_path"; then
        print_success "Backup downloaded from S3"
        BACKUP_FILE="$local_path"
    else
        print_error "Failed to download from S3"
        exit 1
    fi
}

################################################################################
# Confirmation Prompt
################################################################################

confirm_restore() {
    if [ "$FORCE" = true ]; then
        return 0
    fi

    print_header "Confirmation Required"

    echo -e "${YELLOW}WARNING: This will replace all data in the '$DB_NAME' database!${NC}\n"
    echo -e "Backup file: ${BLUE}$BACKUP_FILE${NC}"

    if [ "$CREATE_BACKUP" = true ]; then
        echo -e "A backup of current data will be created first."
    else
        echo -e "${RED}No backup of current data will be created!${NC}"
    fi

    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        print_info "Restore cancelled"
        exit 0
    fi
}

################################################################################
# Backup Current Database
################################################################################

backup_current_database() {
    if [ "$CREATE_BACKUP" = false ]; then
        print_warning "Skipping backup of current database"
        return 0
    fi

    print_header "Backing Up Current Database"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local pre_restore_backup="${BACKUP_DIR}/property_management_pre_restore_${timestamp}.sql.gz"

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    print_info "Creating backup: $pre_restore_backup"

    if [ "$USE_DOCKER" = true ]; then
        # Backup from Docker container
        if docker exec property-db mysqldump \
            --user="$DB_USER" \
            --password="$DB_PASS" \
            --single-transaction \
            --quick \
            --routines \
            --triggers \
            "$DB_NAME" 2>/dev/null | gzip > "$pre_restore_backup"; then
            print_success "Current database backed up successfully"
        else
            print_error "Failed to backup current database"
            exit 1
        fi
    else
        # Backup from local database
        if mysqldump \
            --user="$DB_USER" \
            --password="$DB_PASS" \
            --host="$DB_HOST" \
            --single-transaction \
            --quick \
            --routines \
            --triggers \
            "$DB_NAME" 2>/dev/null | gzip > "$pre_restore_backup"; then
            print_success "Current database backed up successfully"
        else
            print_error "Failed to backup current database"
            exit 1
        fi
    fi

    local backup_size=$(du -h "$pre_restore_backup" | cut -f1)
    print_info "Backup size: $backup_size"
    print_info "Location: $pre_restore_backup"
}

################################################################################
# Restore Database
################################################################################

restore_database() {
    print_header "Restoring Database"

    print_info "Backup file: $BACKUP_FILE"

    # Determine if file is compressed
    local is_compressed=false
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        is_compressed=true
        print_info "Detected compressed backup (gzip)"
    else
        print_info "Detected uncompressed backup"
    fi

    print_info "Starting restore..."

    if [ "$USE_DOCKER" = true ]; then
        # Restore to Docker container
        if [ "$is_compressed" = true ]; then
            if gunzip -c "$BACKUP_FILE" | docker exec -i property-db mysql \
                --user="$DB_USER" \
                --password="$DB_PASS" \
                2>/dev/null; then
                print_success "Database restored successfully"
            else
                print_error "Database restore failed"
                exit 1
            fi
        else
            if docker exec -i property-db mysql \
                --user="$DB_USER" \
                --password="$DB_PASS" \
                < "$BACKUP_FILE" 2>/dev/null; then
                print_success "Database restored successfully"
            else
                print_error "Database restore failed"
                exit 1
            fi
        fi
    else
        # Restore to local database
        if [ "$is_compressed" = true ]; then
            if gunzip -c "$BACKUP_FILE" | mysql \
                --user="$DB_USER" \
                --password="$DB_PASS" \
                --host="$DB_HOST" \
                2>/dev/null; then
                print_success "Database restored successfully"
            else
                print_error "Database restore failed"
                exit 1
            fi
        else
            if mysql \
                --user="$DB_USER" \
                --password="$DB_PASS" \
                --host="$DB_HOST" \
                < "$BACKUP_FILE" 2>/dev/null; then
                print_success "Database restored successfully"
            else
                print_error "Database restore failed"
                exit 1
            fi
        fi
    fi
}

################################################################################
# Verify Restore
################################################################################

verify_restore() {
    print_header "Verifying Restore"

    local table_count
    local row_counts

    if [ "$USE_DOCKER" = true ]; then
        table_count=$(docker exec property-db mysql \
            --user="$DB_USER" \
            --password="$DB_PASS" \
            "$DB_NAME" \
            -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';" 2>/dev/null)

        row_counts=$(docker exec property-db mysql \
            --user="$DB_USER" \
            --password="$DB_PASS" \
            "$DB_NAME" \
            -e "SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = '$DB_NAME' ORDER BY table_name;" 2>/dev/null)
    else
        table_count=$(mysql \
            --user="$DB_USER" \
            --password="$DB_PASS" \
            --host="$DB_HOST" \
            "$DB_NAME" \
            -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';")

        row_counts=$(mysql \
            --user="$DB_USER" \
            --password="$DB_PASS" \
            --host="$DB_HOST" \
            "$DB_NAME" \
            -e "SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = '$DB_NAME' ORDER BY table_name;")
    fi

    print_success "Database accessible after restore"
    print_info "Tables found: $table_count"

    echo -e "\n${BLUE}Table Row Counts:${NC}"
    echo "$row_counts"
}

################################################################################
# Print Summary
################################################################################

print_summary() {
    print_header "Restore Summary"

    echo -e "${GREEN}Database restore completed successfully!${NC}\n"

    echo -e "${BLUE}Restore Details:${NC}"
    echo -e "  Database: ${YELLOW}$DB_NAME${NC}"
    echo -e "  Backup file: ${YELLOW}$BACKUP_FILE${NC}"

    if [ "$USE_DOCKER" = true ]; then
        echo -e "  Target: ${YELLOW}Docker container (property-db)${NC}"
    else
        echo -e "  Target: ${YELLOW}Local database ($DB_HOST)${NC}"
    fi

    if [ "$CREATE_BACKUP" = true ]; then
        echo -e "\n${BLUE}Recovery Option:${NC}"
        echo -e "  If something went wrong, check the pre-restore backup in:"
        echo -e "  ${YELLOW}$BACKUP_DIR${NC}"
    fi

    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║        Property Management System - Database Restore             ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Parse command line arguments
    parse_arguments "$@"

    # Execute restore steps
    check_prerequisites
    confirm_restore
    backup_current_database
    restore_database
    verify_restore
    print_summary
}

# Run main function
main "$@"
