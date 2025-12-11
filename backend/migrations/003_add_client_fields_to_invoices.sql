-- ============================================================================
-- Migration: Add Client Fields to Invoices
-- ============================================================================
-- Purpose: Add client information fields for generic invoices
-- Changes:
--   1. Add client_name column (for invoices without tenant)
--   2. Add client_address column
--   3. Add client_cui column
-- Prerequisites: Run add_generic_invoice_support.sql first
-- Date: 2025-12-10
-- ============================================================================

-- Use the property_management database
USE property_management;

-- Start transaction for safety
START TRANSACTION;

-- ============================================================================
-- Step 1: Add client_name column
-- ============================================================================
-- This stores the client name for generic invoices (when tenant_id is NULL)
ALTER TABLE invoices
    ADD COLUMN client_name VARCHAR(255) NULL
    COMMENT 'Client name for generic invoices (when no tenant association)'
    AFTER calculation_id;

-- ============================================================================
-- Step 2: Add client_address column
-- ============================================================================
-- This stores the client address for generic invoices
ALTER TABLE invoices
    ADD COLUMN client_address VARCHAR(255) NULL
    COMMENT 'Client address for generic invoices'
    AFTER client_name;

-- ============================================================================
-- Step 3: Add client_cui column
-- ============================================================================
-- This stores the client CUI/CIF for generic invoices
ALTER TABLE invoices
    ADD COLUMN client_cui VARCHAR(20) NULL
    COMMENT 'Client CUI/CIF for generic invoices'
    AFTER client_address;

-- ============================================================================
-- Verification: Display updated schema
-- ============================================================================
SELECT '=== Migration Complete - Verification ===' AS info;

-- Show the new column definitions
SELECT
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_NAME = 'invoices'
  AND COLUMN_NAME IN ('client_name', 'client_address', 'client_cui')
ORDER BY ORDINAL_POSITION;

-- Show sample of invoices table structure
DESCRIBE invoices;

-- Commit the transaction
COMMIT;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- Generic Invoice Client Fields Usage:
--   For generic invoices (invoice_type = 'generic', tenant_id = NULL):
--     - client_name: Required - name of client receiving invoice
--     - client_address: Optional - full address of client
--     - client_cui: Optional - CUI/CIF tax identifier
--
--   For tenant-based invoices (invoice_type = 'rent' or 'utility'):
--     - These fields remain NULL
--     - Client information comes from the tenant record
--
-- To run this migration:
--   mysql -u propman -psecure_dev_password property_management < 003_add_client_fields_to_invoices.sql
--
-- To rollback (if needed before committing):
--   ROLLBACK;
--   Or manually:
--   ALTER TABLE invoices DROP COLUMN client_cui;
--   ALTER TABLE invoices DROP COLUMN client_address;
--   ALTER TABLE invoices DROP COLUMN client_name;
--
-- ============================================================================
