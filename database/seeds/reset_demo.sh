#!/bin/bash
# ============================================================================
# Demo Database Reset Script
# ============================================================================
# This script resets the demo database with fresh dummy data
# Designed to be run via cronjob daily at midnight
#
# Usage: ./reset_demo.sh
# Cron:  0 0 * * * /path/to/reset_demo.sh >> /var/log/demo_reset.log 2>&1
# ============================================================================

set -e

# Configuration - adjust these values for your environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/demo_data.sql"

# Docker container name - adjust if different
CONTAINER_NAME="property-db"

# Database credentials - should match your docker-compose.yml
DB_NAME="property_management"
DB_USER="root"
DB_PASSWORD="${MYSQL_ROOT_PASSWORD:-your_root_password}"

# Log timestamp
echo "========================================"
echo "Demo Reset Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "ERROR: SQL file not found: $SQL_FILE"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '${CONTAINER_NAME}' is not running"
    exit 1
fi

# Execute the SQL file
echo "Loading demo data into database..."
docker exec -i "${CONTAINER_NAME}" mysql -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < "${SQL_FILE}"

if [ $? -eq 0 ]; then
    echo "SUCCESS: Demo data loaded successfully"
    echo "Tables reset:"
    echo "  - users (demo account restored)"
    echo "  - company"
    echo "  - tenants + utility_percentages"
    echo "  - utility_providers"
    echo "  - received_invoices"
    echo "  - electricity_meters + meter_readings"
    echo "  - utility_calculations + details"
    echo "  - invoices + invoice_items"
    echo "  - activity_logs"
    echo "  - notifications"
else
    echo "ERROR: Failed to load demo data"
    exit 1
fi

echo "========================================"
echo "Demo Reset Completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
