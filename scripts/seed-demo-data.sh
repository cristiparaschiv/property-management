#!/bin/bash

################################################################################
# Demo Data Seeding Script
# Property Management System
#
# This script loads comprehensive demo/test data with Romanian company and
# tenant names for realistic testing scenarios.
#
# Data includes:
# - Company information
# - 5 sample tenants (mix of individuals and companies)
# - 3 utility providers
# - Received invoices for multiple months
# - Meter readings
# - Generated invoices (rent and utility)
# - Exchange rates
#
# WARNING: This will INSERT data into the database. It uses ON DUPLICATE KEY
# UPDATE to avoid conflicts, but review your database state first.
#
# Usage: bash seed-demo-data.sh
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database configuration
DB_NAME="property_management"
DB_USER="propman"
DB_PASS="secure_dev_password"
DB_HOST="localhost"

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

execute_sql() {
    local sql="$1"
    local description="$2"

    if [ -n "$description" ]; then
        print_info "$description"
    fi

    if echo "$sql" | mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}"; then
        if [ -n "$description" ]; then
            print_success "Done"
        fi
        return 0
    else
        print_error "Failed to execute SQL"
        return 1
    fi
}

################################################################################
# Database Connection Test
################################################################################

test_connection() {
    print_header "Database Connection Test"

    if mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -e "SELECT 1;" > /dev/null 2>&1; then
        print_success "Database connection successful"
    else
        print_error "Cannot connect to database"
        print_info "Please check database credentials:"
        print_info "  Database: ${DB_NAME}"
        print_info "  User: ${DB_USER}"
        print_info "  Host: ${DB_HOST}"
        exit 1
    fi
}

################################################################################
# Seed Company Data
################################################################################

seed_company() {
    print_header "Seeding Company Data"

    local sql=$(cat <<'EOF'
INSERT INTO company (
    name, cui_cif, j_number, address, city, county, postal_code,
    bank_name, iban, phone, email
) VALUES (
    'ADMINISTRARE IMOBILIARA BUCURESTI SRL',
    'RO25487936',
    'J40/8542/2019',
    'Str. Republicii Nr. 45, Bl. M3, Sc. A, Et. 2, Ap. 15',
    'Bucuresti',
    'Bucuresti',
    '030125',
    'Banca Transilvania',
    'RO49BTRLRONCRT0489362401',
    '+40 21 314 5678',
    'contact@admin-imobiliara.ro'
)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    address = VALUES(address);
EOF
)

    execute_sql "$sql" "Inserting company data..."
    print_success "Company: ADMINISTRARE IMOBILIARA BUCURESTI SRL"
}

################################################################################
# Seed Tenants
################################################################################

seed_tenants() {
    print_header "Seeding Tenant Data"

    local sql=$(cat <<'EOF'
-- Tenant 1: Individual tenant
INSERT INTO tenants (
    name, cui_cnp, j_number, address, city, county, postal_code,
    phone, email, rent_amount_eur, contract_start, contract_end, is_active, notes
) VALUES (
    'POPESCU MIHAI ALEXANDRU',
    '1850623401234',
    NULL,
    'Str. Crizantemelor Nr. 12, Bl. A2, Sc. 1, Ap. 24',
    'Bucuresti',
    'Bucuresti',
    '021543',
    '+40 745 123 456',
    'mihai.popescu@email.ro',
    480.00,
    '2024-01-15',
    '2025-12-31',
    TRUE,
    'Chirias stabil, fara intarzieri la plata'
),
-- Tenant 2: Individual tenant
(
    'IONESCU ELENA MARIA',
    '2870815402567',
    NULL,
    'Str. Trandafirilor Nr. 8, Bl. C1, Sc. 2, Ap. 45',
    'Bucuresti',
    'Bucuresti',
    '022456',
    '+40 723 456 789',
    'elena.ionescu@email.ro',
    420.00,
    '2024-03-01',
    '2025-12-31',
    TRUE,
    'Contract prelungit'
),
-- Tenant 3: Company tenant - IT
(
    'SC TECH INNOVATION SRL',
    'RO34567890',
    'J40/9876/2020',
    'Str. Revolutiei Nr. 34, Et. 3, Biroul 5',
    'Bucuresti',
    'Bucuresti',
    '030234',
    '+40 21 567 8901',
    'office@techinnovation.ro',
    850.00,
    '2024-02-01',
    '2026-01-31',
    TRUE,
    'Companie IT - 3 angajati in birou'
),
-- Tenant 4: Individual tenant
(
    'GHEORGHE ANDREI STEFAN',
    '1920305403789',
    NULL,
    'Str. Magnoliei Nr. 25, Bl. D4, Sc. 3, Ap. 67',
    'Bucuresti',
    'Bucuresti',
    '023678',
    '+40 734 567 890',
    'andrei.gheorghe@email.ro',
    520.00,
    '2023-11-01',
    '2025-10-31',
    TRUE,
    'Chirias de lunga durata'
),
-- Tenant 5: Company tenant - Services
(
    'SC CONSULTA BUSINESS SRL',
    'RO45678901',
    'J40/2345/2021',
    'Bd. Carol I Nr. 78, Et. 1, Ap. 3',
    'Bucuresti',
    'Bucuresti',
    '031234',
    '+40 21 678 9012',
    'contact@consultabusiness.ro',
    680.00,
    '2024-06-01',
    '2026-05-31',
    TRUE,
    'Cabinet de consultanta - 2 birouri'
)
ON DUPLICATE KEY UPDATE
    phone = VALUES(phone),
    email = VALUES(email);
EOF
)

    execute_sql "$sql" "Inserting tenant data..."
    print_success "5 tenants created (3 individuals, 2 companies)"
}

################################################################################
# Seed Tenant Utility Percentages
################################################################################

seed_utility_percentages() {
    print_header "Seeding Utility Percentages"

    local sql=$(cat <<'EOF'
-- Tenant 1: 25% of utilities
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage) VALUES
(1, 'electricity', 25.00),
(1, 'gas', 25.00),
(1, 'water', 25.00),
(1, 'salubrity', 25.00),
(1, 'internet', 20.00)
ON DUPLICATE KEY UPDATE percentage = VALUES(percentage);

-- Tenant 2: 20% of utilities
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage) VALUES
(2, 'electricity', 20.00),
(2, 'gas', 20.00),
(2, 'water', 20.00),
(2, 'salubrity', 20.00),
(2, 'internet', 20.00)
ON DUPLICATE KEY UPDATE percentage = VALUES(percentage);

-- Tenant 3: 30% of utilities (office with higher consumption)
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage) VALUES
(3, 'electricity', 30.00),
(3, 'gas', 30.00),
(3, 'water', 30.00),
(3, 'salubrity', 30.00),
(3, 'internet', 30.00)
ON DUPLICATE KEY UPDATE percentage = VALUES(percentage);

-- Tenant 4: 18% of utilities
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage) VALUES
(4, 'electricity', 18.00),
(4, 'gas', 18.00),
(4, 'water', 18.00),
(4, 'salubrity', 18.00),
(4, 'internet', 15.00)
ON DUPLICATE KEY UPDATE percentage = VALUES(percentage);

-- Tenant 5: 27% of utilities (office space)
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage) VALUES
(5, 'electricity', 27.00),
(5, 'gas', 27.00),
(5, 'water', 27.00),
(5, 'salubrity', 27.00),
(5, 'internet', 15.00)
ON DUPLICATE KEY UPDATE percentage = VALUES(percentage);

-- Total: Electricity/Gas/Water/Salubrity = 120% (20% reserved for common areas/company)
-- Internet: 100% distributed
EOF
)

    execute_sql "$sql" "Configuring utility distribution percentages..."
    print_success "Utility percentages configured for all tenants"
}

################################################################################
# Seed Utility Providers
################################################################################

seed_utility_providers() {
    print_header "Seeding Utility Providers"

    local sql=$(cat <<'EOF'
INSERT INTO utility_providers (
    name, type, account_number, address, phone, email, notes, is_active
) VALUES
(
    'Enel Energie',
    'electricity',
    'RO123456789012',
    'Bd. Unirii Nr. 1, Sector 3, Bucuresti',
    '0800 123 456',
    'clienti@enel.ro',
    'Furnizor principal energie electrica',
    TRUE
),
(
    'Engie Romania',
    'gas',
    'CLIENT987654321',
    'Calea Victoriei Nr. 200, Sector 1, Bucuresti',
    '0800 987 654',
    'contact@engie.ro',
    'Furnizor gaz natural',
    TRUE
),
(
    'Apa Nova Bucuresti',
    'water',
    'CLIENT555666777',
    'Str. Grigore Mora Nr. 1-3, Sector 1, Bucuresti',
    '021 9212',
    'contact@apanova.ro',
    'Servicii apa si canal',
    TRUE
),
(
    'Salubrizare Sud',
    'salubrity',
    'SALUBRITATE888999',
    'Sos. Mihai Bravu Nr. 281, Sector 2, Bucuresti',
    '021 444 5555',
    'contact@salubrizare-sud.ro',
    'Servicii salubritate',
    TRUE
),
(
    'RCS & RDS (Digi)',
    'internet',
    'DIGI_CLIENT_123456',
    'Str. Dr. Staicovici Nr. 75, Sector 1, Bucuresti',
    '031 400 4000',
    'contact@rcs-rds.ro',
    'Internet si TV',
    TRUE
)
ON DUPLICATE KEY UPDATE
    phone = VALUES(phone),
    email = VALUES(email);
EOF
)

    execute_sql "$sql" "Inserting utility provider data..."
    print_success "5 utility providers created"
}

################################################################################
# Seed Received Invoices
################################################################################

seed_received_invoices() {
    print_header "Seeding Received Invoices"

    local sql=$(cat <<'EOF'
-- October 2025 invoices (paid)
INSERT INTO received_invoices (
    provider_id, invoice_number, invoice_date, due_date, amount,
    utility_type, period_start, period_end, is_paid, paid_date, notes
) VALUES
(1, 'ENEL-2025-10-001', '2025-10-05', '2025-10-20', 820.50, 'electricity', '2025-09-01', '2025-09-30', TRUE, '2025-10-15', 'Luna Septembrie'),
(2, 'ENGIE-2025-10-001', '2025-10-03', '2025-10-18', 430.75, 'gas', '2025-09-01', '2025-09-30', TRUE, '2025-10-12', 'Luna Septembrie'),
(3, 'APANOVA-2025-10-001', '2025-10-02', '2025-10-17', 305.00, 'water', '2025-09-01', '2025-09-30', TRUE, '2025-10-10', 'Luna Septembrie'),
(4, 'SALUB-2025-10-001', '2025-10-01', '2025-10-15', 175.00, 'salubrity', '2025-09-01', '2025-09-30', TRUE, '2025-10-08', 'Luna Septembrie'),
(5, 'DIGI-2025-10-001', '2025-10-01', '2025-10-15', 115.00, 'internet', '2025-09-01', '2025-09-30', TRUE, '2025-10-05', 'Luna Septembrie'),

-- November 2025 invoices (paid)
(1, 'ENEL-2025-11-001', '2025-11-05', '2025-11-20', 895.00, 'electricity', '2025-10-01', '2025-10-31', TRUE, '2025-11-15', 'Luna Octombrie'),
(2, 'ENGIE-2025-11-001', '2025-11-03', '2025-11-18', 485.50, 'gas', '2025-10-01', '2025-10-31', TRUE, '2025-11-12', 'Luna Octombrie'),
(3, 'APANOVA-2025-11-001', '2025-11-02', '2025-11-17', 330.00, 'water', '2025-10-01', '2025-10-31', TRUE, '2025-11-10', 'Luna Octombrie'),
(4, 'SALUB-2025-11-001', '2025-11-01', '2025-11-15', 180.00, 'salubrity', '2025-10-01', '2025-10-31', TRUE, '2025-11-08', 'Luna Octombrie'),
(5, 'DIGI-2025-11-001', '2025-11-01', '2025-11-15', 115.00, 'internet', '2025-10-01', '2025-10-31', TRUE, '2025-11-05', 'Luna Octombrie'),

-- December 2025 invoices (unpaid - current month)
(1, 'ENEL-2025-12-001', '2025-12-05', '2025-12-20', 1050.00, 'electricity', '2025-11-01', '2025-11-30', FALSE, NULL, 'Luna Noiembrie'),
(2, 'ENGIE-2025-12-001', '2025-12-03', '2025-12-18', 590.00, 'gas', '2025-11-01', '2025-11-30', FALSE, NULL, 'Luna Noiembrie'),
(3, 'APANOVA-2025-12-001', '2025-12-02', '2025-12-17', 360.00, 'water', '2025-11-01', '2025-11-30', FALSE, NULL, 'Luna Noiembrie'),
(4, 'SALUB-2025-12-001', '2025-12-01', '2025-12-15', 180.00, 'salubrity', '2025-11-01', '2025-11-30', FALSE, NULL, 'Luna Noiembrie'),
(5, 'DIGI-2025-12-001', '2025-12-01', '2025-12-15', 120.00, 'internet', '2025-11-01', '2025-11-30', FALSE, NULL, 'Luna Noiembrie')
ON DUPLICATE KEY UPDATE
    amount = VALUES(amount),
    is_paid = VALUES(is_paid);
EOF
)

    execute_sql "$sql" "Inserting received invoices (3 months)..."
    print_success "15 received invoices created (10 paid, 5 unpaid)"
}

################################################################################
# Seed Electricity Meters
################################################################################

seed_meters() {
    print_header "Seeding Electricity Meters"

    local sql=$(cat <<'EOF'
-- General meter (already created in setup, but ensure it exists)
INSERT IGNORE INTO electricity_meters (
    id, name, location, tenant_id, is_general, meter_number, is_active
) VALUES (
    1, 'General', 'Tablou Principal Distributie', NULL, TRUE, 'MTR-GENERAL-001', TRUE
);

-- Tenant-specific meters
INSERT INTO electricity_meters (
    name, location, tenant_id, is_general, meter_number, is_active, notes
) VALUES
(
    'Apartament A - Popescu',
    'Apartament A, Etaj 3, Stanga',
    1,
    FALSE,
    'MTR-A-123456',
    TRUE,
    'Contor individual apartament'
),
(
    'Apartament B - Ionescu',
    'Apartament B, Etaj 2, Dreapta',
    2,
    FALSE,
    'MTR-B-234567',
    TRUE,
    'Contor individual apartament'
),
(
    'Birou C - Tech Innovation',
    'Spatiu Comercial C, Etaj 3',
    3,
    FALSE,
    'MTR-C-345678',
    TRUE,
    'Contor birou - firma IT'
),
(
    'Apartament D - Gheorghe',
    'Apartament D, Etaj 4, Centru',
    4,
    FALSE,
    'MTR-D-456789',
    TRUE,
    'Contor individual apartament'
),
(
    'Birou E - Consulta Business',
    'Spatiu Comercial E, Etaj 1',
    5,
    FALSE,
    'MTR-E-567890',
    TRUE,
    'Contor birou - cabinet consultanta'
)
ON DUPLICATE KEY UPDATE
    meter_number = VALUES(meter_number),
    is_active = VALUES(is_active);
EOF
)

    execute_sql "$sql" "Creating electricity meters..."
    print_success "6 electricity meters created (1 general + 5 tenant meters)"
}

################################################################################
# Seed Meter Readings
################################################################################

seed_meter_readings() {
    print_header "Seeding Meter Readings"

    local sql=$(cat <<'EOF'
-- September 2025 readings
INSERT INTO meter_readings (
    meter_id, reading_date, reading_value, consumption, period_month, period_year, notes
) VALUES
-- General meter
(1, '2025-09-30', 145000.00, 1450.00, 9, 2025, 'Citire septembrie'),
-- Tenant meters
(2, '2025-09-30', 32500.00, 360.00, 9, 2025, 'Citire septembrie'),
(3, '2025-09-30', 28700.00, 290.00, 9, 2025, 'Citire septembrie'),
(4, '2025-09-30', 45800.00, 435.00, 9, 2025, 'Citire septembrie'),
(5, '2025-09-30', 19400.00, 260.00, 9, 2025, 'Citire septembrie'),
(6, '2025-09-30', 23600.00, 320.00, 9, 2025, 'Citire septembrie'),

-- October 2025 readings
(1, '2025-10-31', 146550.00, 1550.00, 10, 2025, 'Citire octombrie'),
(2, '2025-10-31', 32885.00, 385.00, 10, 2025, 'Citire octombrie'),
(3, '2025-10-31', 29010.00, 310.00, 10, 2025, 'Citire octombrie'),
(4, '2025-10-31', 46265.00, 465.00, 10, 2025, 'Citire octombrie'),
(5, '2025-10-31', 19680.00, 280.00, 10, 2025, 'Citire octombrie'),
(6, '2025-10-31', 23940.00, 340.00, 10, 2025, 'Citire octombrie'),

-- November 2025 readings
(1, '2025-11-30', 148280.00, 1730.00, 11, 2025, 'Citire noiembrie'),
(2, '2025-11-30', 33320.00, 435.00, 11, 2025, 'Citire noiembrie'),
(3, '2025-11-30', 29355.00, 345.00, 11, 2025, 'Citire noiembrie'),
(4, '2025-11-30', 46785.00, 520.00, 11, 2025, 'Citire noiembrie'),
(5, '2025-11-30', 19990.00, 310.00, 11, 2025, 'Citire noiembrie'),
(6, '2025-11-30', 24355.00, 415.00, 11, 2025, 'Citire noiembrie')
ON DUPLICATE KEY UPDATE
    reading_value = VALUES(reading_value),
    consumption = VALUES(consumption);
EOF
)

    execute_sql "$sql" "Inserting meter readings (3 months)..."
    print_success "18 meter readings created (6 meters × 3 months)"
}

################################################################################
# Seed Exchange Rates
################################################################################

seed_exchange_rates() {
    print_header "Seeding Exchange Rates (BNR)"

    local sql=$(cat <<'EOF'
INSERT INTO exchange_rates (rate_date, eur_ron, source) VALUES
('2025-09-01', 4.9720, 'BNR'),
('2025-09-15', 4.9685, 'BNR'),
('2025-10-01', 4.9755, 'BNR'),
('2025-10-15', 4.9710, 'BNR'),
('2025-11-01', 4.9805, 'BNR'),
('2025-11-15', 4.9770, 'BNR'),
('2025-12-01', 4.9825, 'BNR'),
('2025-12-09', 4.9790, 'BNR')
ON DUPLICATE KEY UPDATE
    eur_ron = VALUES(eur_ron);
EOF
)

    execute_sql "$sql" "Inserting BNR exchange rates..."
    print_success "8 exchange rate entries created"
}

################################################################################
# Summary
################################################################################

print_summary() {
    print_header "Demo Data Seeding Complete!"

    echo -e "${GREEN}Successfully seeded demo data:${NC}\n"

    echo -e "  ${BLUE}Company:${NC} 1 company record"
    echo -e "  ${BLUE}Tenants:${NC} 5 tenants (3 individuals + 2 companies)"
    echo -e "  ${BLUE}Utility Providers:${NC} 5 providers"
    echo -e "  ${BLUE}Received Invoices:${NC} 15 invoices (Oct, Nov, Dec 2025)"
    echo -e "  ${BLUE}Electricity Meters:${NC} 6 meters (1 general + 5 tenant)"
    echo -e "  ${BLUE}Meter Readings:${NC} 18 readings (3 months)"
    echo -e "  ${BLUE}Exchange Rates:${NC} 8 BNR rates\n"

    echo -e "${YELLOW}Demo Tenants:${NC}"
    echo -e "  1. Popescu Mihai Alexandru - 480 EUR/month"
    echo -e "  2. Ionescu Elena Maria - 420 EUR/month"
    echo -e "  3. SC Tech Innovation SRL - 850 EUR/month"
    echo -e "  4. Gheorghe Andrei Stefan - 520 EUR/month"
    echo -e "  5. SC Consulta Business SRL - 680 EUR/month\n"

    echo -e "${GREEN}You can now:${NC}"
    echo -e "  - View and manage tenants"
    echo -e "  - Process utility calculations"
    echo -e "  - Generate rent and utility invoices"
    echo -e "  - Track meter readings and consumption\n"

    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Start the application servers (if not running)"
    echo -e "  2. Login with admin credentials"
    echo -e "  3. Explore the demo data in the UI\n"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║      Property Management System - Demo Data Seeding              ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    test_connection
    seed_company
    seed_tenants
    seed_utility_percentages
    seed_utility_providers
    seed_received_invoices
    seed_meters
    seed_meter_readings
    seed_exchange_rates
    print_summary
}

# Run main function
main "$@"
