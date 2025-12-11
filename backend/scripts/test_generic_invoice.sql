-- ============================================================================
-- Test Script: Generic Invoice Support
-- ============================================================================
-- Purpose: Verify that generic invoices can be created without tenant_id
-- ============================================================================

USE property_management;

-- Display test header
SELECT '=== Testing Generic Invoice Support ===' AS test_header;

-- ============================================================================
-- Test 1: Create a generic invoice without tenant_id
-- ============================================================================
SELECT '--- Test 1: Creating generic invoice without tenant ---' AS test_step;

INSERT INTO invoices (
    invoice_number,
    invoice_type,
    tenant_id,
    invoice_date,
    due_date,
    exchange_rate,
    exchange_rate_date,
    subtotal_eur,
    subtotal_ron,
    vat_amount,
    total_ron,
    notes
) VALUES (
    'ARC-TEST-GENERIC-001',
    'generic',
    NULL,  -- No tenant for generic invoice
    '2025-12-10',
    '2025-12-24',
    NULL,  -- No exchange rate for generic invoice
    NULL,  -- No exchange rate date
    NULL,  -- No EUR subtotal
    1000.00,
    190.00,
    1190.00,
    'Test generic invoice - consulting services'
);

-- Verify the invoice was created
SELECT
    '--- Test 1 Result: Invoice created successfully ---' AS test_result,
    id,
    invoice_number,
    invoice_type,
    tenant_id,
    invoice_date,
    due_date,
    subtotal_ron,
    vat_amount,
    total_ron,
    notes
FROM invoices
WHERE invoice_number = 'ARC-TEST-GENERIC-001';

-- ============================================================================
-- Test 2: Add invoice items to the generic invoice
-- ============================================================================
SELECT '--- Test 2: Adding invoice items to generic invoice ---' AS test_step;

INSERT INTO invoice_items (
    invoice_id,
    description,
    quantity,
    unit_price,
    vat_rate,
    total,
    sort_order
) VALUES
(
    (SELECT id FROM invoices WHERE invoice_number = 'ARC-TEST-GENERIC-001'),
    'Consulting Services - December 2025',
    10.00,
    100.00,
    19.00,
    1190.00,
    1
);

-- Verify the items were added
SELECT
    '--- Test 2 Result: Invoice items added successfully ---' AS test_result,
    ii.id,
    ii.invoice_id,
    ii.description,
    ii.quantity,
    ii.unit_price,
    ii.vat_rate,
    ii.total,
    ii.sort_order
FROM invoice_items ii
INNER JOIN invoices i ON ii.invoice_id = i.id
WHERE i.invoice_number = 'ARC-TEST-GENERIC-001';

-- ============================================================================
-- Test 3: Query generic invoice with left join to tenant
-- ============================================================================
SELECT '--- Test 3: Query generic invoice with tenant join ---' AS test_step;

SELECT
    i.invoice_number,
    i.invoice_type,
    i.tenant_id,
    t.name AS tenant_name,
    i.invoice_date,
    i.due_date,
    i.total_ron,
    i.notes
FROM invoices i
LEFT JOIN tenants t ON i.tenant_id = t.id
WHERE i.invoice_type = 'generic'
ORDER BY i.created_at DESC;

-- ============================================================================
-- Test 4: Verify ENUM values include 'generic'
-- ============================================================================
SELECT '--- Test 4: Verify invoice_type ENUM values ---' AS test_step;

SELECT
    COLUMN_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_NAME = 'invoices'
  AND COLUMN_NAME = 'invoice_type';

-- ============================================================================
-- Test 5: Verify tenant_id can be NULL
-- ============================================================================
SELECT '--- Test 5: Verify tenant_id nullable constraint ---' AS test_step;

SELECT
    COLUMN_NAME,
    IS_NULLABLE,
    COLUMN_TYPE,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_NAME = 'invoices'
  AND COLUMN_NAME = 'tenant_id';

-- ============================================================================
-- Cleanup: Remove test data
-- ============================================================================
SELECT '--- Cleanup: Removing test invoice ---' AS cleanup_step;

DELETE FROM invoice_items
WHERE invoice_id = (SELECT id FROM invoices WHERE invoice_number = 'ARC-TEST-GENERIC-001');

DELETE FROM invoices
WHERE invoice_number = 'ARC-TEST-GENERIC-001';

SELECT '=== All Tests Completed Successfully ===' AS test_footer;

-- ============================================================================
-- SUMMARY:
-- ============================================================================
-- This test verifies:
-- 1. Generic invoices can be created with tenant_id = NULL
-- 2. Invoice items can be added to generic invoices
-- 3. Left joins work correctly for generic invoices without tenants
-- 4. The invoice_type ENUM includes 'generic'
-- 5. The tenant_id column is nullable
--
-- To run this test:
--   mysql -u propman -psecure_dev_password property_management < test_generic_invoice.sql
--
-- ============================================================================
