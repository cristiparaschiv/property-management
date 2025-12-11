#!/bin/bash

# ============================================================================
# Database Setup Script
# Property Management & Invoicing System
# ============================================================================
# Description: Automated database setup with interactive prompts
# Usage: ./setup.sh [production|development]
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database configuration
DB_NAME="property_management"
DB_USER="propman"
DB_HOST="localhost"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Functions
# ============================================================================

print_header() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}  Property Management System - Database Setup${NC}"
    echo -e "${BLUE}======================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_mysql() {
    if ! command -v mysql &> /dev/null; then
        print_error "MySQL/MariaDB client not found. Please install it first."
        exit 1
    fi
    print_success "MySQL/MariaDB client found"
}

# ============================================================================
# Main Setup Process
# ============================================================================

print_header

# Check environment argument
ENVIRONMENT="${1:-development}"

if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "development" ]]; then
    print_error "Invalid environment. Use 'production' or 'development'"
    echo "Usage: ./setup.sh [production|development]"
    exit 1
fi

print_info "Setup mode: ${ENVIRONMENT}"
echo ""

# Check MySQL client
check_mysql

# Prompt for MySQL root password
echo ""
print_info "Please enter MySQL root password:"
read -s MYSQL_ROOT_PASSWORD
echo ""

# Test MySQL connection
print_info "Testing MySQL connection..."
if ! mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &> /dev/null; then
    print_error "Cannot connect to MySQL. Please check your root password."
    exit 1
fi
print_success "MySQL connection successful"

# ============================================================================
# Step 1: Create Database and User
# ============================================================================
echo ""
print_info "Step 1: Creating database and user..."

if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "USE ${DB_NAME};" 2> /dev/null; then
    print_warning "Database '${DB_NAME}' already exists"
    read -p "Do you want to drop and recreate it? (yes/no): " RECREATE
    if [[ "$RECREATE" == "yes" ]]; then
        print_info "Dropping existing database..."
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE ${DB_NAME};"
        print_success "Database dropped"
    else
        print_info "Using existing database"
    fi
fi

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" < "${SCRIPT_DIR}/create_database.sql"
print_success "Database and user created"

# ============================================================================
# Step 2: Run Initial Schema Migration
# ============================================================================
echo ""
print_info "Step 2: Creating database schema..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" ${DB_NAME} < "${SCRIPT_DIR}/migrations/001_initial_schema.sql"
print_success "Schema created (14 tables)"

# ============================================================================
# Step 3: Load Essential Seed Data
# ============================================================================
echo ""
print_info "Step 3: Loading essential seed data..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" ${DB_NAME} < "${SCRIPT_DIR}/migrations/002_seed_data.sql"
print_success "Seed data loaded (admin user, General meter, default template)"

# ============================================================================
# Step 4: Load Development Data (if development mode)
# ============================================================================
if [[ "$ENVIRONMENT" == "development" ]]; then
    echo ""
    print_info "Step 4: Loading development sample data..."
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" ${DB_NAME} < "${SCRIPT_DIR}/seeds/development.sql"
    print_success "Development data loaded (tenants, invoices, etc.)"
fi

# ============================================================================
# Step 5: Verify Schema
# ============================================================================
echo ""
print_info "Step 5: Verifying database schema..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" ${DB_NAME} < "${SCRIPT_DIR}/verify_schema.sql" > /tmp/verify_output.txt 2>&1
print_success "Schema verification complete (see /tmp/verify_output.txt for details)"

# ============================================================================
# Setup Complete
# ============================================================================
echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}  Database Setup Complete!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo ""
print_info "Database Information:"
echo "  Database: ${DB_NAME}"
echo "  Host: ${DB_HOST}"
echo "  User: ${DB_USER}"
echo ""
print_info "Default Login Credentials:"
echo "  Username: admin"
echo "  Password: changeme"
echo ""
print_warning "IMPORTANT: Change the admin password immediately after first login!"
echo ""

if [[ "$ENVIRONMENT" == "development" ]]; then
    print_info "Sample Data Loaded:"
    echo "  - 1 Company (IMOBILIARA DEMO SRL)"
    echo "  - 3 Tenants with utility percentages"
    echo "  - 5 Utility Providers"
    echo "  - 10 Received Invoices"
    echo "  - 4 Electricity Meters"
    echo "  - 6 Sample Invoices"
    echo ""
fi

print_info "Next Steps:"
echo "  1. Test database connection: mysql -u ${DB_USER} -p ${DB_NAME}"
echo "  2. Configure backend application with database credentials"
echo "  3. Login and change admin password"
if [[ "$ENVIRONMENT" == "production" ]]; then
    echo "  4. Add company information"
    echo "  5. Add tenants and configure utility percentages"
fi
echo ""

print_success "Setup complete!"
