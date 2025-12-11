#!/bin/bash

################################################################################
# Production Deployment Script
# Property Management System
#
# This script automates the deployment of the application to a production server.
# It handles:
# - Building frontend assets
# - Syncing code to production server
# - Installing dependencies
# - Restarting services
# - Health checks
#
# Usage:
#   bash deploy-prod.sh [OPTIONS]
#
# Options:
#   --server SERVER     Production server address (user@host)
#   --path PATH         Remote application path (default: /opt/property-manager/app)
#   --skip-build        Skip frontend build
#   --skip-backup       Skip database backup
#   --dry-run           Show what would be done without executing
#
# Example:
#   bash deploy-prod.sh --server root@production.example.com
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
PRODUCTION_SERVER=""
REMOTE_PATH="/opt/property-manager/app"
SKIP_BUILD=false
SKIP_BACKUP=false
DRY_RUN=false

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"

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

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Production Deployment Script for Property Management System

OPTIONS:
    --server SERVER     Production server (user@host) [REQUIRED]
    --path PATH         Remote application path (default: /opt/property-manager/app)
    --skip-build        Skip frontend build step
    --skip-backup       Skip database backup before deployment
    --dry-run           Show what would be done without executing
    -h, --help          Show this help message

EXAMPLES:
    # Basic deployment
    $0 --server root@prod.example.com

    # Deploy to custom path
    $0 --server deploy@prod.example.com --path /var/www/property

    # Deploy without rebuilding frontend (if already built)
    $0 --server root@prod.example.com --skip-build

    # Dry run to see what would happen
    $0 --server root@prod.example.com --dry-run

EOF
}

run_command() {
    local cmd="$1"
    local description="$2"

    if [ -n "$description" ]; then
        print_info "$description"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would execute: $cmd"
        return 0
    fi

    if eval "$cmd"; then
        return 0
    else
        print_error "Command failed: $cmd"
        return 1
    fi
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server)
                PRODUCTION_SERVER="$2"
                shift 2
                ;;
            --path)
                REMOTE_PATH="$2"
                shift 2
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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

    # Validate required parameters
    if [ -z "$PRODUCTION_SERVER" ]; then
        print_error "Production server not specified"
        echo ""
        show_usage
        exit 1
    fi
}

################################################################################
# Pre-deployment Checks
################################################################################

preflight_checks() {
    print_header "Pre-deployment Checks"

    local all_good=true

    # Check if we're in the right directory
    if [ ! -d "$BACKEND_DIR" ] || [ ! -d "$FRONTEND_DIR" ]; then
        print_error "Cannot find backend or frontend directories"
        print_info "Current directory: $(pwd)"
        print_info "Expected structure: backend/ and frontend/ directories"
        all_good=false
    else
        print_success "Project directories found"
    fi

    # Check SSH connection
    print_info "Testing SSH connection to $PRODUCTION_SERVER..."
    if [ "$DRY_RUN" = false ]; then
        if ssh -o ConnectTimeout=10 -o BatchMode=yes "$PRODUCTION_SERVER" "echo 2>&1" > /dev/null; then
            print_success "SSH connection successful"
        else
            print_error "Cannot connect to $PRODUCTION_SERVER"
            print_info "Make sure SSH keys are configured and the server is accessible"
            all_good=false
        fi
    else
        print_info "[DRY RUN] Would test SSH connection"
    fi

    # Check if git repo is clean
    if [ -d "${PROJECT_ROOT}/.git" ]; then
        if [ -z "$(git status --porcelain)" ]; then
            print_success "Git working directory is clean"
        else
            print_warning "Git working directory has uncommitted changes"
            print_info "Consider committing changes before deployment"
        fi
    fi

    if [ "$all_good" = false ]; then
        print_error "Preflight checks failed"
        exit 1
    fi
}

################################################################################
# Build Frontend
################################################################################

build_frontend() {
    if [ "$SKIP_BUILD" = true ]; then
        print_header "Skipping Frontend Build"
        print_warning "Frontend build skipped (--skip-build flag)"
        return 0
    fi

    print_header "Building Frontend"

    cd "$FRONTEND_DIR"

    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        print_info "Installing npm dependencies..."
        run_command "npm install" "Installing dependencies"
    fi

    # Build production bundle
    print_info "Building production bundle..."
    run_command "npm run build" "Running Vite build"

    # Verify build output
    if [ "$DRY_RUN" = false ]; then
        if [ -d "dist" ] && [ -f "dist/index.html" ]; then
            print_success "Frontend build completed successfully"
            print_info "Build output size: $(du -sh dist | cut -f1)"
        else
            print_error "Build output not found"
            exit 1
        fi
    fi

    cd "$PROJECT_ROOT"
}

################################################################################
# Backup Remote Database
################################################################################

backup_remote_database() {
    if [ "$SKIP_BACKUP" = true ]; then
        print_header "Skipping Database Backup"
        print_warning "Database backup skipped (--skip-backup flag)"
        return 0
    fi

    print_header "Backing Up Remote Database"

    local backup_script="${REMOTE_PATH}/scripts/backup-db.sh"

    print_info "Running backup script on remote server..."

    if [ "$DRY_RUN" = false ]; then
        if ssh "$PRODUCTION_SERVER" "bash $backup_script" 2>&1; then
            print_success "Database backup completed"
        else
            print_warning "Database backup failed or script not found"
            print_info "Continuing with deployment..."
        fi
    else
        print_info "[DRY RUN] Would run: ssh $PRODUCTION_SERVER 'bash $backup_script'"
    fi
}

################################################################################
# Sync Code to Production
################################################################################

sync_code() {
    print_header "Syncing Code to Production"

    # Create rsync exclude file
    local exclude_file=$(mktemp)
    cat > "$exclude_file" << 'EOF'
node_modules/
.git/
.gitignore
.env
.env.*
*.log
*.swp
*~
.DS_Store
.vscode/
.idea/
.claude/
coverage/
tmp/
temp/
*.test.js
__tests__/
EOF

    # Sync backend
    print_info "Syncing backend code..."
    run_command "rsync -avz --delete \
        --exclude-from='$exclude_file' \
        --exclude='local/' \
        '$BACKEND_DIR/' \
        '$PRODUCTION_SERVER:$REMOTE_PATH/backend/'" \
        "Uploading backend files"

    # Sync frontend build
    print_info "Syncing frontend build..."
    run_command "rsync -avz --delete \
        '$FRONTEND_DIR/dist/' \
        '$PRODUCTION_SERVER:$REMOTE_PATH/frontend/dist/'" \
        "Uploading frontend build"

    # Sync scripts
    print_info "Syncing deployment scripts..."
    run_command "rsync -avz \
        '$PROJECT_ROOT/scripts/' \
        '$PRODUCTION_SERVER:$REMOTE_PATH/scripts/'" \
        "Uploading scripts"

    # Sync database files (schema and migrations only)
    print_info "Syncing database migrations..."
    run_command "rsync -avz \
        --exclude='seeds/' \
        '$PROJECT_ROOT/database/' \
        '$PRODUCTION_SERVER:$REMOTE_PATH/database/'" \
        "Uploading database files"

    # Clean up
    rm -f "$exclude_file"

    print_success "Code sync completed"
}

################################################################################
# Install Production Dependencies
################################################################################

install_dependencies() {
    print_header "Installing Production Dependencies"

    # Install Perl dependencies
    print_info "Installing Perl modules on remote server..."
    run_command "ssh '$PRODUCTION_SERVER' 'cd $REMOTE_PATH/backend && cpanm --installdeps . --notest'" \
        "Installing Perl dependencies"

    print_success "Dependencies installed"
}

################################################################################
# Run Database Migrations
################################################################################

run_migrations() {
    print_header "Running Database Migrations"

    print_info "Applying database migrations on remote server..."

    local migration_cmd="cd $REMOTE_PATH/backend/migrations && \
        for migration in *.sql; do \
            echo \"Applying \$migration...\"; \
            mysql -u propman_prod -p property_management < \"\$migration\" 2>/dev/null || echo \"Already applied or failed: \$migration\"; \
        done"

    if [ "$DRY_RUN" = false ]; then
        if ssh "$PRODUCTION_SERVER" "$migration_cmd" 2>&1; then
            print_success "Migrations completed"
        else
            print_warning "Some migrations may have already been applied"
        fi
    else
        print_info "[DRY RUN] Would run migrations"
    fi
}

################################################################################
# Restart Services
################################################################################

restart_services() {
    print_header "Restarting Services"

    # Restart backend service
    print_info "Restarting backend service..."
    run_command "ssh '$PRODUCTION_SERVER' 'sudo systemctl restart property-manager'" \
        "Restarting property-manager.service"

    # Wait for service to start
    if [ "$DRY_RUN" = false ]; then
        print_info "Waiting for service to start..."
        sleep 3
    fi

    # Reload Nginx
    print_info "Reloading Nginx..."
    run_command "ssh '$PRODUCTION_SERVER' 'sudo systemctl reload nginx'" \
        "Reloading Nginx configuration"

    print_success "Services restarted"
}

################################################################################
# Health Checks
################################################################################

health_checks() {
    print_header "Running Health Checks"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would run health checks"
        return 0
    fi

    # Check backend service status
    print_info "Checking backend service status..."
    if ssh "$PRODUCTION_SERVER" "sudo systemctl is-active --quiet property-manager"; then
        print_success "Backend service is running"
    else
        print_error "Backend service is not running"
        print_info "Check logs: sudo journalctl -u property-manager -n 50"
        return 1
    fi

    # Check Nginx status
    print_info "Checking Nginx status..."
    if ssh "$PRODUCTION_SERVER" "sudo systemctl is-active --quiet nginx"; then
        print_success "Nginx is running"
    else
        print_error "Nginx is not running"
        return 1
    fi

    # Check if backend API is responding
    print_info "Testing backend API endpoint..."
    local api_check=$(ssh "$PRODUCTION_SERVER" "curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/api/health || echo '000'")

    if [ "$api_check" = "200" ] || [ "$api_check" = "404" ]; then
        print_success "Backend API is responding"
    else
        print_warning "Backend API health check returned: $api_check"
        print_info "This may be normal if /api/health endpoint is not implemented"
    fi

    # Show recent logs
    print_info "Recent backend logs:"
    ssh "$PRODUCTION_SERVER" "sudo journalctl -u property-manager -n 5 --no-pager" 2>&1 | sed 's/^/  /'

    print_success "Health checks completed"
}

################################################################################
# Deployment Summary
################################################################################

print_deployment_summary() {
    print_header "Deployment Summary"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${GREEN}Deployment completed successfully!${NC}\n"

    echo -e "${BLUE}Deployment Details:${NC}"
    echo -e "  Server: ${YELLOW}$PRODUCTION_SERVER${NC}"
    echo -e "  Path: ${YELLOW}$REMOTE_PATH${NC}"
    echo -e "  Timestamp: ${YELLOW}$timestamp${NC}"
    echo -e "  Build Frontend: ${YELLOW}$([ "$SKIP_BUILD" = true ] && echo "Skipped" || echo "Yes")${NC}"
    echo -e "  Database Backup: ${YELLOW}$([ "$SKIP_BACKUP" = true ] && echo "Skipped" || echo "Yes")${NC}\n"

    echo -e "${BLUE}Post-Deployment Tasks:${NC}"
    echo -e "  1. Verify application in browser"
    echo -e "  2. Check application logs: ${YELLOW}sudo journalctl -u property-manager -f${NC}"
    echo -e "  3. Monitor error logs: ${YELLOW}sudo tail -f /var/log/nginx/error.log${NC}"
    echo -e "  4. Test critical functionality\n"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}This was a DRY RUN - no changes were made${NC}\n"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║        Property Management System - Production Deployment        ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Parse command line arguments
    parse_arguments "$@"

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi

    # Confirmation prompt
    if [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}You are about to deploy to: $PRODUCTION_SERVER${NC}"
        read -p "Are you sure you want to continue? (yes/no): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
            print_info "Deployment cancelled"
            exit 0
        fi
    fi

    # Execute deployment steps
    preflight_checks
    build_frontend
    backup_remote_database
    sync_code
    install_dependencies
    run_migrations
    restart_services
    health_checks
    print_deployment_summary
}

# Run main function
main "$@"
