#!/bin/bash

################################################################################
# Development Environment Setup Script
# Property Management System
#
# This script automates the setup of a development environment including:
# - Database creation and configuration
# - Perl dependency installation
# - Node.js dependency installation
# - Database schema and seed data loading
#
# Usage: bash setup-dev.sh
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
DATABASE_DIR="${PROJECT_ROOT}/database"

# Database configuration
DB_NAME="property_management"
DB_USER="propman"
DB_PASS="secure_dev_password"
DB_HOST="localhost"

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
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

################################################################################
# Preflight Checks
################################################################################

preflight_checks() {
    print_header "Preflight Checks"

    local all_good=true

    # Check Perl
    if command_exists perl; then
        print_success "Perl installed: $(perl --version | head -n 2 | tail -n 1)"
    else
        print_error "Perl is not installed"
        all_good=false
    fi

    # Check cpanm
    if command_exists cpanm; then
        print_success "cpanm installed"
    else
        print_warning "cpanm is not installed - will attempt to install"
    fi

    # Check Node.js
    if command_exists node; then
        print_success "Node.js installed: $(node --version)"
    else
        print_error "Node.js is not installed"
        all_good=false
    fi

    # Check npm
    if command_exists npm; then
        print_success "npm installed: $(npm --version)"
    else
        print_error "npm is not installed"
        all_good=false
    fi

    # Check MySQL/MariaDB
    if command_exists mysql; then
        print_success "MySQL client installed"
    else
        print_error "MySQL client is not installed"
        all_good=false
    fi

    # Check if MySQL server is running
    if systemctl is-active --quiet mariadb || systemctl is-active --quiet mysql; then
        print_success "MySQL/MariaDB server is running"
    else
        print_warning "MySQL/MariaDB server is not running - attempting to start"
        if sudo systemctl start mariadb 2>/dev/null || sudo systemctl start mysql 2>/dev/null; then
            print_success "MySQL/MariaDB server started"
        else
            print_error "Could not start MySQL/MariaDB server"
            all_good=false
        fi
    fi

    if [ "$all_good" = false ]; then
        print_error "Preflight checks failed. Please install missing dependencies."
        exit 1
    fi

    print_success "All preflight checks passed"
}

################################################################################
# Database Setup
################################################################################

setup_database() {
    print_header "Database Setup"

    print_info "Creating database and user..."

    # Create SQL script for database setup
    local setup_sql=$(cat <<EOF
-- Create database
CREATE DATABASE IF NOT EXISTS ${DB_NAME}
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Create user
CREATE USER IF NOT EXISTS '${DB_USER}'@'${DB_HOST}'
  IDENTIFIED BY '${DB_PASS}';

-- Grant privileges
GRANT ALL PRIVILEGES ON ${DB_NAME}.*
  TO '${DB_USER}'@'${DB_HOST}';

FLUSH PRIVILEGES;
EOF
)

    # Try to create database as root
    if echo "${setup_sql}" | sudo mysql; then
        print_success "Database and user created successfully"
    else
        print_error "Failed to create database. Trying with password prompt..."
        echo "${setup_sql}" | mysql -u root -p
    fi

    # Load schema
    print_info "Loading database schema..."
    if mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < "${DATABASE_DIR}/schema.sql"; then
        print_success "Database schema loaded"
    else
        print_error "Failed to load database schema"
        exit 1
    fi

    # Load seed data
    print_info "Loading development seed data..."
    if mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < "${DATABASE_DIR}/seeds/development.sql"; then
        print_success "Seed data loaded"
    else
        print_error "Failed to load seed data"
        exit 1
    fi

    # Create General electricity meter if not exists
    print_info "Ensuring General electricity meter exists..."
    local meter_sql="INSERT IGNORE INTO electricity_meters (id, name, location, tenant_id, is_general, meter_number, is_active) VALUES (1, 'General', 'Main Distribution', NULL, TRUE, 'MTR-GENERAL-001', TRUE);"
    echo "${meter_sql}" | mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}"
    print_success "General meter verified"

    # Apply migrations
    print_info "Applying database migrations..."
    local migration_count=0
    for migration in "${BACKEND_DIR}"/migrations/*.sql; do
        if [ -f "$migration" ]; then
            print_info "  Applying $(basename "$migration")..."
            if mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < "$migration" 2>/dev/null; then
                migration_count=$((migration_count + 1))
            else
                print_warning "  Migration $(basename "$migration") may have already been applied or failed"
            fi
        fi
    done
    if [ $migration_count -gt 0 ]; then
        print_success "Applied $migration_count migration(s)"
    else
        print_info "No new migrations to apply"
    fi
}

################################################################################
# Backend Setup
################################################################################

setup_backend() {
    print_header "Backend Setup (Perl Dependencies)"

    cd "${BACKEND_DIR}"

    # Install cpanm if not available
    if ! command_exists cpanm; then
        print_info "Installing cpanm..."
        curl -L https://cpanmin.us | perl - --sudo App::cpanminus
    fi

    # Install dependencies from cpanfile
    print_info "Installing Perl modules (this may take several minutes)..."
    if cpanm --installdeps . --notest; then
        print_success "Perl dependencies installed"
    else
        print_error "Failed to install some Perl dependencies"
        print_info "Continuing anyway - missing modules may cause runtime errors"
    fi

    # Verify config.yml
    if [ -f "config.yml" ]; then
        print_success "Backend configuration file exists"
    else
        print_error "config.yml not found in backend directory"
        exit 1
    fi

    # Create log directory
    if [ ! -d "/var/log/property-manager" ]; then
        print_info "Creating log directory..."
        sudo mkdir -p /var/log/property-manager
        sudo chown -R $USER:$USER /var/log/property-manager
        print_success "Log directory created"
    fi

    # Create PDF temp directory
    if [ ! -d "/tmp/property_invoices" ]; then
        print_info "Creating PDF temp directory..."
        mkdir -p /tmp/property_invoices
        print_success "PDF temp directory created"
    fi
}

################################################################################
# Frontend Setup
################################################################################

setup_frontend() {
    print_header "Frontend Setup (Node.js Dependencies)"

    cd "${FRONTEND_DIR}"

    # Check if node_modules exists
    if [ -d "node_modules" ]; then
        print_warning "node_modules already exists - removing for clean install"
        rm -rf node_modules package-lock.json
    fi

    # Install dependencies
    print_info "Installing npm packages..."
    if npm install; then
        print_success "npm dependencies installed"
    else
        print_error "Failed to install npm dependencies"
        exit 1
    fi

    # Verify vite.config.js
    if [ -f "vite.config.js" ]; then
        print_success "Vite configuration file exists"
    else
        print_error "vite.config.js not found in frontend directory"
        exit 1
    fi
}

################################################################################
# Create Admin User
################################################################################

create_admin_user() {
    print_header "Creating Admin User"

    print_info "Creating default admin user..."

    # Check if admin user already exists
    local user_exists=$(mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -sN -e "SELECT COUNT(*) FROM users WHERE username='admin';")

    if [ "$user_exists" -gt 0 ]; then
        print_warning "Admin user already exists - skipping"
    else
        # Password: admin123 (bcrypt hash)
        local admin_sql="INSERT INTO users (username, password_hash, email) VALUES ('admin', '\$2b\$12\$LvbVkC7K6hEFqNlNfEQsLe3Q5wZ7Y8xD9mP4kN2jH1rT6vB8nF0Xy', 'admin@example.com');"
        echo "${admin_sql}" | mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}"
        print_success "Admin user created"
        print_info "  Username: admin"
        print_info "  Password: admin123"
    fi
}

################################################################################
# Final Instructions
################################################################################

print_instructions() {
    print_header "Setup Complete!"

    echo -e "${GREEN}Development environment is ready!${NC}\n"

    echo -e "${BLUE}Next Steps:${NC}\n"

    echo -e "1. Start the backend server (Terminal 1):"
    echo -e "   ${YELLOW}cd ${BACKEND_DIR}${NC}"
    echo -e "   ${YELLOW}plackup -p 5000 bin/app.psgi${NC}\n"

    echo -e "2. Start the frontend server (Terminal 2):"
    echo -e "   ${YELLOW}cd ${FRONTEND_DIR}${NC}"
    echo -e "   ${YELLOW}npm run dev${NC}\n"

    echo -e "3. Open your browser:"
    echo -e "   ${YELLOW}http://localhost:5173${NC}\n"

    echo -e "4. Login credentials:"
    echo -e "   Username: ${YELLOW}admin${NC}"
    echo -e "   Password: ${YELLOW}admin123${NC}\n"

    echo -e "${BLUE}Additional Resources:${NC}"
    echo -e "   - API Documentation: ${YELLOW}http://localhost:5000/api${NC}"
    echo -e "   - Backend README: ${YELLOW}${BACKEND_DIR}/README.md${NC}"
    echo -e "   - Deployment Guide: ${YELLOW}${PROJECT_ROOT}/DEPLOYMENT.md${NC}\n"

    echo -e "${GREEN}Happy coding! 🚀${NC}\n"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║         Property Management System - Development Setup           ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    preflight_checks
    setup_database
    setup_backend
    setup_frontend
    create_admin_user
    print_instructions
}

# Run main function
main "$@"
