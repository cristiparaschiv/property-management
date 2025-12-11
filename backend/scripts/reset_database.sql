-- ============================================================================
-- Property Management Database Reset and Seed Script
-- ============================================================================
-- Purpose: Reset database to a clean state with essential seed data
-- Database: property_management (MariaDB)
-- Safe to run multiple times (idempotent)
-- ============================================================================

-- Disable foreign key checks temporarily to allow table truncation
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================================
-- SECTION 1: Clear all transactional data
-- ============================================================================
-- Order matters: delete child records before parent records to respect FK constraints
-- Even with FK checks disabled, we maintain logical order for clarity

-- Step 1: Clear invoice items (depends on invoices)
TRUNCATE TABLE invoice_items;

-- Step 2: Clear invoices (depends on tenants, invoice_templates, utility_calculations)
TRUNCATE TABLE invoices;

-- Step 3: Clear utility calculation details (depends on utility_calculations, tenants, received_invoices)
TRUNCATE TABLE utility_calculation_details;

-- Step 4: Clear utility calculations
TRUNCATE TABLE utility_calculations;

-- Step 5: Clear received invoices (depends on utility_providers)
TRUNCATE TABLE received_invoices;

-- Step 6: Clear meter readings (depends on electricity_meters)
TRUNCATE TABLE meter_readings;

-- Step 7: Clear tenant utility percentages (depends on tenants)
TRUNCATE TABLE tenant_utility_percentages;

-- Step 8: Clear electricity meters (depends on tenants)
TRUNCATE TABLE electricity_meters;

-- Step 9: Clear tenants
TRUNCATE TABLE tenants;

-- Step 10: Clear utility providers
TRUNCATE TABLE utility_providers;

-- Step 11: Clear invoice templates
TRUNCATE TABLE invoice_templates;

-- Step 12: Clear exchange rates
TRUNCATE TABLE exchange_rates;

-- Step 13: Clear company info
TRUNCATE TABLE company;

-- Step 14: Clear users
TRUNCATE TABLE users;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- SECTION 2: Insert essential seed data
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1: Company Information (required for invoicing)
-- ----------------------------------------------------------------------------
-- Insert default company record with placeholder values
-- Users should update this with actual company information
INSERT INTO company (
    id,
    name,
    cui_cif,
    address,
    city,
    county,
    postal_code,
    bank_name,
    iban,
    phone,
    email,
    representative_name,
    invoice_prefix,
    last_invoice_number
) VALUES (
    1,
    'Property Management SRL',
    'RO12345678',
    'Str. Example Nr. 1',
    'Bucharest',
    'Bucuresti',
    '010101',
    'Example Bank',
    'RO49AAAA1B31007593840000',
    '+40 21 000 0000',
    'contact@propertymanagement.ro',
    'Administrator Name',
    'ARC',
    0
);

-- ----------------------------------------------------------------------------
-- 2.2: Admin User (required for system access)
-- ----------------------------------------------------------------------------
-- Insert admin user with bcrypt hashed password
-- Username: admin
-- Password: (preserved from existing admin user)
-- Hash: $2b$12$LJlrd0zNaTuJ8mlkpjHese3YYYKO5Nq01mj4oG/bR/eC/qq/7iKVC
INSERT INTO users (
    id,
    username,
    password_hash,
    email,
    full_name,
    id_card_series,
    id_card_number,
    id_card_issued_by,
    last_login
) VALUES (
    1,
    'admin',
    '$2b$12$LJlrd0zNaTuJ8mlkpjHese3YYYKO5Nq01mj4oG/bR/eC/qq/7iKVC',
    'admin@property.local',
    'System Administrator',
    NULL,
    NULL,
    NULL,
    NULL
);

-- ----------------------------------------------------------------------------
-- 2.3: General Electricity Meters (required for building-wide consumption)
-- ----------------------------------------------------------------------------
-- Insert general meters for tracking building electricity consumption
-- These meters are not associated with any specific tenant (tenant_id is NULL)
-- Individual tenant meters can be added later via the application

-- GM-001: General Meter - stores readings at the actual reading date
INSERT INTO electricity_meters (
    id,
    name,
    location,
    tenant_id,
    is_general,
    meter_number,
    is_active,
    notes
) VALUES (
    1,
    'General Meter - Building',
    'Main Electrical Panel',
    NULL,
    1,
    'GM-001',
    1,
    'Main building electricity meter for tracking total consumption'
);

-- GM-002: General Beginning of Month - stores readings at exact beginning of month for statistics
-- Purpose: This meter stores the consumption value at the exact start of each month
-- for accurate statistical reporting and monthly consumption calculations
INSERT INTO electricity_meters (
    id,
    name,
    location,
    tenant_id,
    is_general,
    meter_number,
    is_active,
    notes
) VALUES (
    2,
    'General - Început Lună',
    'Main Electrical Panel',
    NULL,
    1,
    'GM-002',
    1,
    'Statistics meter: stores reading value at exact beginning of month for monthly consumption tracking'
);

-- ============================================================================
-- SECTION 3: Verification queries (optional - comment out if not needed)
-- ============================================================================

-- Verify seed data was inserted correctly
SELECT '=== Seed Data Verification ===' AS info;

SELECT 'Company:' AS table_name, COUNT(*) AS record_count FROM company
UNION ALL
SELECT 'Users:', COUNT(*) FROM users
UNION ALL
SELECT 'General Meters:', COUNT(*) FROM electricity_meters WHERE is_general = 1;

-- Display inserted records
SELECT '=== Company Information ===' AS info;
SELECT id, name, cui_cif, city, invoice_prefix, last_invoice_number FROM company;

SELECT '=== Admin User ===' AS info;
SELECT id, username, email, full_name FROM users;

SELECT '=== General Meters ===' AS info;
SELECT id, name, location, meter_number, is_general, is_active FROM electricity_meters;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. This script clears ALL data from all tables
-- 2. Only essential records are preserved:
--    - One company record (to be updated with actual company info)
--    - One admin user (username: admin)
--    - Two general electricity meters:
--      * GM-001: For tracking consumption at reading date
--      * GM-002: For tracking consumption at beginning of month (statistics)
--
-- 3. After running this script, you should:
--    - Update company information with actual data
--    - Add tenants via the application
--    - Add utility providers
--    - Add individual tenant meters
--    - Configure tenant utility percentages
--
-- 4. Invoice Types Supported:
--    a) 'rent' - Rent invoices (EUR-based with exchange rates)
--       - Requires: tenant_id, exchange_rate, subtotal_eur
--    b) 'utility' - Utility invoices (linked to calculations)
--       - Requires: tenant_id, calculation_id
--    c) 'generic' - Generic standalone invoices
--       - tenant_id: NULL (no tenant association)
--       - exchange_rate: NULL (no EUR conversion)
--       - calculation_id: NULL (no utility calculation)
--       - Can use client_name, client_address, client_cui for non-tenant clients
--       - Only requires: invoice_items, invoice_date, due_date, notes
--
-- 5. To run this script:
--    mysql -u propman -psecure_dev_password property_management < reset_database.sql
--
-- 6. Password for admin user:
--    The current password hash is preserved. If you need to change it,
--    use the application's password change functionality or bcrypt tool.
--
-- ============================================================================
