#!/bin/bash
# ============================================================================
# Property Management Database Reset Script (Shell Wrapper)
# ============================================================================
# Purpose: Safely reset the database with backup option
# Usage: ./reset_database.sh [--backup] [--no-confirm]
# ============================================================================

set -e  # Exit on error

# Configuration
DB_NAME="property_management"
DB_USER="propman"
DB_PASS="secure_dev_password"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_SCRIPT="${SCRIPT_DIR}/reset_database.sql"
BACKUP_DIR="${SCRIPT_DIR}/../backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default options
DO_BACKUP=false
SKIP_CONFIRM=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup)
            DO_BACKUP=true
            shift
            ;;
        --no-confirm)
            SKIP_CONFIRM=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --backup       Create a database backup before resetting"
            echo "  --no-confirm   Skip confirmation prompt"
            echo "  --help         Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --backup    # Reset with backup"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if SQL script exists
if [ ! -f "$SQL_SCRIPT" ]; then
    echo -e "${RED}Error: SQL script not found at: $SQL_SCRIPT${NC}"
    exit 1
fi

# Check if MySQL/MariaDB is accessible
if ! mysql -u"$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to database '$DB_NAME'${NC}"
    echo "Please check database credentials and ensure the database exists."
    exit 1
fi

# Display warning
echo -e "${RED}===============================================${NC}"
echo -e "${RED}  DATABASE RESET WARNING${NC}"
echo -e "${RED}===============================================${NC}"
echo ""
echo "This will DELETE ALL DATA from the following database:"
echo "  Database: $DB_NAME"
echo "  Server:   localhost"
echo ""
echo "The following data will be preserved:"
echo "  - One admin user (username: admin)"
echo "  - One company record (placeholder values)"
echo "  - One general electricity meter"
echo ""

if [ "$DO_BACKUP" = true ]; then
    echo -e "${GREEN}A backup will be created before resetting.${NC}"
else
    echo -e "${YELLOW}No backup will be created. Use --backup to create one.${NC}"
fi

echo ""

# Confirmation prompt
if [ "$SKIP_CONFIRM" = false ]; then
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Create backup if requested
if [ "$DO_BACKUP" = true ]; then
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_${TIMESTAMP}.sql"

    echo ""
    echo -e "${YELLOW}Creating backup...${NC}"
    mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup created successfully:${NC}"
        echo "  $BACKUP_FILE"
        echo "  Size: $(du -h "$BACKUP_FILE" | cut -f1)"
    else
        echo -e "${RED}Backup failed! Aborting reset.${NC}"
        exit 1
    fi
fi

# Execute the reset script
echo ""
echo -e "${YELLOW}Executing database reset...${NC}"
mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SQL_SCRIPT"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}===============================================${NC}"
    echo -e "${GREEN}  DATABASE RESET SUCCESSFUL${NC}"
    echo -e "${GREEN}===============================================${NC}"
    echo ""
    echo "Seed data has been inserted:"
    echo "  - Admin user: admin"
    echo "  - Company: Property Management SRL (update this!)"
    echo "  - General Meter: GM-001"
    echo ""
    echo "Next steps:"
    echo "  1. Update company information with actual data"
    echo "  2. Add tenants via the application"
    echo "  3. Add utility providers"
    echo "  4. Configure tenant utility percentages"
    echo ""

    if [ "$DO_BACKUP" = true ]; then
        echo "Backup location: $BACKUP_FILE"
        echo ""
    fi
else
    echo ""
    echo -e "${RED}Database reset failed!${NC}"

    if [ "$DO_BACKUP" = true ]; then
        echo ""
        echo "You can restore from backup using:"
        echo "  mysql -u$DB_USER -p$DB_PASS $DB_NAME < $BACKUP_FILE"
    fi
    exit 1
fi
