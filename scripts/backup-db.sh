#!/bin/bash

################################################################################
# Database Backup Script
# Property Management System
#
# This script creates compressed backups of the MySQL/MariaDB database with:
# - Timestamped backup files
# - Automatic compression (gzip)
# - Backup rotation (optional)
# - S3 upload support (optional)
# - Email notifications (optional)
#
# Usage:
#   bash backup-db.sh [OPTIONS]
#
# Options:
#   --output-dir DIR    Backup directory (default: ../backups)
#   --keep-days DAYS    Delete backups older than N days (default: 30)
#   --s3-bucket BUCKET  Upload to S3 bucket (requires aws-cli)
#   --email EMAIL       Send notification email on completion
#   --quiet             Suppress output messages
#
# Examples:
#   bash backup-db.sh
#   bash backup-db.sh --output-dir /backup --keep-days 90
#   bash backup-db.sh --s3-bucket my-backups --email admin@example.com
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

# Backup configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups"
KEEP_DAYS=30
S3_BUCKET=""
EMAIL_TO=""
QUIET=false

# Timestamp for backup file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="property_management_${TIMESTAMP}.sql"
BACKUP_FILE_GZ="${BACKUP_FILE}.gz"

################################################################################
# Helper Functions
################################################################################

print_header() {
    [ "$QUIET" = false ] && echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    [ "$QUIET" = false ] && echo -e "${BLUE}  $1${NC}"
    [ "$QUIET" = false ] && echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    [ "$QUIET" = false ] && echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    [ "$QUIET" = false ] && echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    [ "$QUIET" = false ] && echo -e "${BLUE}ℹ${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Database Backup Script for Property Management System

OPTIONS:
    --output-dir DIR    Backup directory (default: ../backups)
    --keep-days DAYS    Delete backups older than N days (default: 30, 0=keep all)
    --s3-bucket BUCKET  Upload backup to S3 bucket (requires aws-cli)
    --email EMAIL       Send notification email on completion
    --quiet             Suppress non-error output
    -h, --help          Show this help message

EXAMPLES:
    # Basic backup
    $0

    # Backup to custom directory
    $0 --output-dir /var/backups/property

    # Backup with 90-day retention
    $0 --keep-days 90

    # Backup and upload to S3
    $0 --s3-bucket my-company-backups

    # Backup with email notification
    $0 --email admin@example.com

    # Quiet mode (cron-friendly)
    $0 --quiet

CONFIGURATION:
    Edit the script to change database credentials:
    - DB_NAME (default: property_management)
    - DB_USER (default: propman)
    - DB_PASS (default: secure_dev_password)
    - DB_HOST (default: localhost)

CRON EXAMPLE:
    # Daily backup at 2 AM
    0 2 * * * /path/to/backup-db.sh --quiet --keep-days 30

EOF
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --keep-days)
                KEEP_DAYS="$2"
                shift 2
                ;;
            --s3-bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            --email)
                EMAIL_TO="$2"
                shift 2
                ;;
            --quiet)
                QUIET=true
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

    # Check if mysql/mysqldump is available
    if ! command -v mysqldump >/dev/null 2>&1; then
        print_error "mysqldump is not installed"
        all_good=false
    else
        print_success "mysqldump found"
    fi

    # Check database connection
    print_info "Testing database connection..."
    if mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" "$DB_NAME" -e "SELECT 1;" > /dev/null 2>&1; then
        print_success "Database connection successful"
    else
        print_error "Cannot connect to database"
        print_info "Database: $DB_NAME"
        print_info "User: $DB_USER"
        print_info "Host: $DB_HOST"
        all_good=false
    fi

    # Check if gzip is available
    if ! command -v gzip >/dev/null 2>&1; then
        print_error "gzip is not installed"
        all_good=false
    else
        print_success "gzip found"
    fi

    # Check if backup directory exists, create if not
    if [ ! -d "$BACKUP_DIR" ]; then
        print_info "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi

    # Check write permissions
    if [ ! -w "$BACKUP_DIR" ]; then
        print_error "No write permission to backup directory: $BACKUP_DIR"
        all_good=false
    else
        print_success "Backup directory writable"
    fi

    # Check S3 prerequisites if needed
    if [ -n "$S3_BUCKET" ]; then
        if ! command -v aws >/dev/null 2>&1; then
            print_error "aws-cli is not installed (required for S3 upload)"
            all_good=false
        else
            print_success "aws-cli found"
        fi
    fi

    if [ "$all_good" = false ]; then
        print_error "Prerequisites check failed"
        exit 1
    fi
}

################################################################################
# Create Database Backup
################################################################################

create_backup() {
    print_header "Creating Database Backup"

    local backup_path="${BACKUP_DIR}/${BACKUP_FILE}"
    local backup_path_gz="${BACKUP_DIR}/${BACKUP_FILE_GZ}"

    print_info "Backup file: $BACKUP_FILE_GZ"
    print_info "Backup location: $BACKUP_DIR"

    # Create mysqldump
    print_info "Dumping database..."
    if mysqldump \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        --host="$DB_HOST" \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --routines \
        --triggers \
        --events \
        --add-drop-database \
        --databases "$DB_NAME" \
        > "$backup_path" 2>/dev/null; then
        print_success "Database dumped successfully"
    else
        print_error "Database dump failed"
        rm -f "$backup_path"
        exit 1
    fi

    # Get uncompressed size
    local size_uncompressed=$(du -h "$backup_path" | cut -f1)
    print_info "Uncompressed size: $size_uncompressed"

    # Compress backup
    print_info "Compressing backup..."
    if gzip -9 "$backup_path"; then
        print_success "Backup compressed successfully"
    else
        print_error "Compression failed"
        exit 1
    fi

    # Get compressed size
    local size_compressed=$(du -h "$backup_path_gz" | cut -f1)
    print_success "Backup created: $BACKUP_FILE_GZ"
    print_info "Compressed size: $size_compressed"

    # Calculate backup statistics
    local db_size=$(mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" "$DB_NAME" -sN -e \
        "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size_MB'
         FROM information_schema.tables
         WHERE table_schema = '$DB_NAME';")
    print_info "Database size: ${db_size} MB"
}

################################################################################
# Upload to S3
################################################################################

upload_to_s3() {
    if [ -z "$S3_BUCKET" ]; then
        return 0
    fi

    print_header "Uploading to S3"

    local backup_path_gz="${BACKUP_DIR}/${BACKUP_FILE_GZ}"
    local s3_path="s3://${S3_BUCKET}/property-management/backups/${BACKUP_FILE_GZ}"

    print_info "S3 bucket: $S3_BUCKET"
    print_info "S3 path: $s3_path"

    if aws s3 cp "$backup_path_gz" "$s3_path" --storage-class STANDARD_IA; then
        print_success "Backup uploaded to S3"
    else
        print_error "S3 upload failed"
        return 1
    fi
}

################################################################################
# Clean Old Backups
################################################################################

clean_old_backups() {
    if [ "$KEEP_DAYS" -eq 0 ]; then
        print_info "Backup retention disabled (keeping all backups)"
        return 0
    fi

    print_header "Cleaning Old Backups"

    print_info "Removing backups older than $KEEP_DAYS days..."

    local deleted_count=0
    local deleted_size=0

    # Find and delete old backups
    while IFS= read -r file; do
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        deleted_size=$((deleted_size + file_size))
        rm -f "$file"
        deleted_count=$((deleted_count + 1))
        print_info "  Deleted: $(basename "$file")"
    done < <(find "$BACKUP_DIR" -name "property_management_*.sql.gz" -type f -mtime +${KEEP_DAYS} 2>/dev/null)

    if [ $deleted_count -gt 0 ]; then
        local deleted_size_mb=$((deleted_size / 1024 / 1024))
        print_success "Deleted $deleted_count old backup(s) (~${deleted_size_mb} MB freed)"
    else
        print_info "No old backups to delete"
    fi

    # Show remaining backups
    local backup_count=$(find "$BACKUP_DIR" -name "property_management_*.sql.gz" -type f | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    print_info "Total backups: $backup_count (Total size: $total_size)"
}

################################################################################
# Send Email Notification
################################################################################

send_email_notification() {
    if [ -z "$EMAIL_TO" ]; then
        return 0
    fi

    print_header "Sending Email Notification"

    local backup_path_gz="${BACKUP_DIR}/${BACKUP_FILE_GZ}"
    local backup_size=$(du -h "$backup_path_gz" | cut -f1)
    local backup_date=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if mail command is available
    if ! command -v mail >/dev/null 2>&1 && ! command -v sendmail >/dev/null 2>&1; then
        print_warning "Mail command not found - skipping email notification"
        return 0
    fi

    # Compose email
    local subject="Property Management Database Backup - $TIMESTAMP"
    local body=$(cat <<EOF
Property Management System Database Backup

Backup Details:
- Database: $DB_NAME
- Timestamp: $backup_date
- Backup File: $BACKUP_FILE_GZ
- File Size: $backup_size
- Location: $BACKUP_DIR

Status: SUCCESS

This is an automated message from the backup script.
EOF
)

    # Send email
    if echo "$body" | mail -s "$subject" "$EMAIL_TO" 2>/dev/null; then
        print_success "Email notification sent to $EMAIL_TO"
    else
        print_warning "Failed to send email notification"
    fi
}

################################################################################
# Backup Summary
################################################################################

print_summary() {
    print_header "Backup Summary"

    local backup_path_gz="${BACKUP_DIR}/${BACKUP_FILE_GZ}"
    local backup_size=$(du -h "$backup_path_gz" | cut -f1)
    local backup_count=$(find "$BACKUP_DIR" -name "property_management_*.sql.gz" -type f | wc -l)

    echo -e "${GREEN}Backup completed successfully!${NC}\n"

    echo -e "${BLUE}Backup Information:${NC}"
    echo -e "  File: ${YELLOW}$BACKUP_FILE_GZ${NC}"
    echo -e "  Size: ${YELLOW}$backup_size${NC}"
    echo -e "  Location: ${YELLOW}$BACKUP_DIR${NC}"
    echo -e "  Total backups: ${YELLOW}$backup_count${NC}\n"

    if [ -n "$S3_BUCKET" ]; then
        echo -e "  S3 Bucket: ${YELLOW}$S3_BUCKET${NC}\n"
    fi

    echo -e "${BLUE}Restore Instructions:${NC}"
    echo -e "  ${YELLOW}gunzip -c $backup_path_gz | mysql -u $DB_USER -p $DB_NAME${NC}\n"

    echo -e "${BLUE}List Recent Backups:${NC}"
    echo -e "  ${YELLOW}ls -lht $BACKUP_DIR | head -n 10${NC}\n"
}

################################################################################
# Main Execution
################################################################################

main() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}"
        echo "╔═══════════════════════════════════════════════════════════════════╗"
        echo "║                                                                   ║"
        echo "║        Property Management System - Database Backup              ║"
        echo "║                                                                   ║"
        echo "╚═══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    fi

    # Parse command line arguments
    parse_arguments "$@"

    # Execute backup steps
    check_prerequisites
    create_backup
    upload_to_s3
    clean_old_backups
    send_email_notification
    print_summary
}

# Run main function
main "$@"
