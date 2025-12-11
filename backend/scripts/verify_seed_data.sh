#!/bin/bash
# ============================================================================
# Property Management Database Seed Data Verification Script
# ============================================================================
# Purpose: Verify that the database has been properly seeded
# Usage: ./verify_seed_data.sh
# ============================================================================

# Don't exit on error for count comparisons
# set -e disabled to allow proper test counting

# Configuration
DB_NAME="property_management"
DB_USER="propman"
DB_PASS="secure_dev_password"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Database Seed Data Verification${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Test database connection
echo -n "Testing database connection... "
if mysql -u"$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Cannot connect to database '$DB_NAME'"
    exit 1
fi

echo ""
echo -e "${BLUE}Checking seed data...${NC}"
echo ""

# Function to check record count
check_count() {
    local table=$1
    local expected=$2
    local description=$3
    local where_clause=$4

    if [ -n "$where_clause" ]; then
        local count=$(mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM $table WHERE $where_clause;")
    else
        local count=$(mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM $table;")
    fi

    printf "  %-40s" "$description"
    if [ "$count" -eq "$expected" ]; then
        echo -e "${GREEN}PASS${NC} (found: $count)"
        return 0
    else
        echo -e "${RED}FAIL${NC} (expected: $expected, found: $count)"
        return 1
    fi
}

# Initialize pass/fail counters
PASSED=0
FAILED=0

# Check company record
if check_count "company" 1 "Company record exists"; then
    ((PASSED++))
else
    ((FAILED++))
fi

# Check admin user
if check_count "users" 1 "Admin user exists"; then
    ((PASSED++))
else
    ((FAILED++))
fi

# Check general meter
if check_count "electricity_meters" 1 "General meter exists" "is_general=1"; then
    ((PASSED++))
else
    ((FAILED++))
fi

# Check that transactional tables are empty
if check_count "tenants" 0 "Tenants table is empty"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if check_count "invoices" 0 "Invoices table is empty"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if check_count "meter_readings" 0 "Meter readings table is empty"; then
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}Checking seed data details...${NC}"
echo ""

# Check company details
echo -e "${YELLOW}Company Information:${NC}"
mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT
    CONCAT('  ID: ', id) as '',
    CONCAT('  Name: ', name) as ' ',
    CONCAT('  CUI/CIF: ', cui_cif) as '  ',
    CONCAT('  City: ', city) as '   ',
    CONCAT('  Invoice Prefix: ', invoice_prefix) as '    '
FROM company WHERE id = 1;
" 2>/dev/null | grep -v "^$" | head -5

echo ""
echo -e "${YELLOW}Admin User:${NC}"
mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT
    CONCAT('  Username: ', username) as '',
    CONCAT('  Email: ', email) as ' ',
    CONCAT('  Full Name: ', IFNULL(full_name, 'N/A')) as '  '
FROM users WHERE id = 1;
" 2>/dev/null | grep -v "^$" | head -3

echo ""
echo -e "${YELLOW}General Meter:${NC}"
mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT
    CONCAT('  Name: ', name) as '',
    CONCAT('  Location: ', IFNULL(location, 'N/A')) as ' ',
    CONCAT('  Meter Number: ', IFNULL(meter_number, 'N/A')) as '  ',
    CONCAT('  Active: ', IF(is_active=1, 'Yes', 'No')) as '   '
FROM electricity_meters WHERE id = 1;
" 2>/dev/null | grep -v "^$" | head -4

echo ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Verification Summary${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo -e "  Tests passed: ${GREEN}$PASSED${NC}"
echo -e "  Tests failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed! Database is properly seeded.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Update company information with real data"
    echo "  2. Add tenants via the application"
    echo "  3. Add utility providers"
    echo "  4. Create tenant meters"
    exit 0
else
    echo -e "${RED}Some checks failed. Please review the output above.${NC}"
    echo ""
    echo "Consider running the reset script again:"
    echo "  ./reset_database.sh --backup"
    exit 1
fi
