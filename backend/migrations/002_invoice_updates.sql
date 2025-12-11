-- Migration: Invoice updates for exchange rate manual entry and invoice number format
-- Purpose:
--   1. Add exchange_rate_manual flag to track manually entered exchange rates
--   2. Support new invoice number format (ARC 451 instead of ARC00451)
-- Date: 2025-12-10

-- Step 1: Add exchange_rate_manual column to invoices table
ALTER TABLE invoices
ADD COLUMN exchange_rate_manual BOOLEAN NOT NULL DEFAULT 0
COMMENT 'Flag indicating if exchange rate was manually entered (1) or fetched from BNR (0)';

-- Step 2: Add index for querying manually entered exchange rates
CREATE INDEX idx_invoices_exchange_rate_manual
ON invoices(exchange_rate_manual);

-- Note: Invoice number format change from 'ARC00451' to 'ARC 451' is handled in code
-- The invoice_number VARCHAR(50) column is already large enough to support both formats
-- The code now handles both old format (ARC00451) and new format (ARC 451) when parsing

-- Verification queries (run these manually to verify):
-- 1. Check the new column was added:
-- DESCRIBE invoices;

-- 2. Verify default value for existing records:
-- SELECT COUNT(*) as total_invoices,
--        SUM(CASE WHEN exchange_rate_manual = 0 THEN 1 ELSE 0 END) as automatic_rates,
--        SUM(CASE WHEN exchange_rate_manual = 1 THEN 1 ELSE 0 END) as manual_rates
-- FROM invoices;

-- 3. Check invoice number formats:
-- SELECT invoice_number,
--        CASE
--            WHEN invoice_number REGEXP '^[A-Z]+[0-9]+$' THEN 'Old format (no space)'
--            WHEN invoice_number REGEXP '^[A-Z]+ [0-9]+$' THEN 'New format (with space)'
--            ELSE 'Unknown format'
--        END as format_type
-- FROM invoices
-- ORDER BY created_at DESC
-- LIMIT 20;
