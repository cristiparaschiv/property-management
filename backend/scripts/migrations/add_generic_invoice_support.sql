-- ============================================================================
-- Migration: Add Generic Invoice Support
-- ============================================================================
-- Purpose: Allow invoices to be created without tenant association
-- Changes:
--   1. Add 'generic' to invoice_type ENUM
--   2. Make tenant_id nullable (for generic invoices)
--   3. Update foreign key constraint to allow NULL tenant_id
-- Date: 2025-12-10
-- ============================================================================

-- Use the property_management database
USE property_management;

-- Start transaction for safety
START TRANSACTION;

-- ============================================================================
-- Step 1: Drop the foreign key constraint on tenant_id
-- ============================================================================
-- We need to drop and recreate the constraint to allow NULL values
ALTER TABLE invoices DROP FOREIGN KEY invoices_ibfk_1;

-- ============================================================================
-- Step 2: Modify invoice_type ENUM to include 'generic'
-- ============================================================================
-- This adds 'generic' as a valid invoice type alongside 'rent' and 'utility'
ALTER TABLE invoices
    MODIFY COLUMN invoice_type ENUM('rent', 'utility', 'generic') NOT NULL
    COMMENT 'Type of invoice: rent (EUR-based), utility (calculation-based), generic (standalone)';

-- ============================================================================
-- Step 3: Make tenant_id nullable
-- ============================================================================
-- Generic invoices don't require a tenant association
ALTER TABLE invoices
    MODIFY COLUMN tenant_id INT(10) UNSIGNED NULL
    COMMENT 'Tenant ID - required for rent/utility invoices, NULL for generic invoices';

-- ============================================================================
-- Step 4: Recreate the foreign key constraint with NULL support
-- ============================================================================
-- Add the foreign key back, now allowing NULL values
ALTER TABLE invoices
    ADD CONSTRAINT invoices_ibfk_1
    FOREIGN KEY (tenant_id)
    REFERENCES tenants(id);

-- ============================================================================
-- Verification: Display updated schema
-- ============================================================================
SELECT '=== Migration Complete - Verification ===' AS info;

-- Show the updated column definitions
SELECT
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_NAME = 'invoices'
  AND COLUMN_NAME IN ('invoice_type', 'tenant_id')
ORDER BY ORDINAL_POSITION;

-- Show foreign key constraint
SELECT
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_NAME = 'invoices'
  AND CONSTRAINT_NAME = 'invoices_ibfk_1';

-- Commit the transaction
COMMIT;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- Generic Invoice Requirements:
--   - invoice_type: 'generic'
--   - tenant_id: NULL (no tenant association)
--   - exchange_rate: NULL (no EUR conversion needed)
--   - calculation_id: NULL (no utility calculation needed)
--   - Required fields: invoice_number, invoice_date, due_date,
--                     invoice_items (via invoice_items table)
--
-- To run this migration:
--   mysql -u propman -psecure_dev_password property_management < add_generic_invoice_support.sql
--
-- To rollback (if needed before committing):
--   ROLLBACK;
--
-- ============================================================================
