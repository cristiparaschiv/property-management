-- ============================================================================
-- Migration 004: Add balance tracking to companies table
-- ============================================================================
-- Purpose: Add balance field to track company's running financial balance
-- Date: 2025-12-10
-- ============================================================================

-- Add balance column to companies table
ALTER TABLE company
ADD COLUMN balance DECIMAL(12,2) NOT NULL DEFAULT 0.00
AFTER last_invoice_number;

-- Add comment for documentation
ALTER TABLE company
MODIFY COLUMN balance DECIMAL(12,2) NOT NULL DEFAULT 0.00
COMMENT 'Running balance: increases with paid invoices, decreases with paid received invoices';

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. This field tracks the company's running financial balance
-- 2. Balance increases when issued invoices are marked as paid
-- 3. Balance decreases when received invoices (expenses) are marked as paid
-- 4. Default value is 0.00 for existing company records
-- 5. To run this migration:
--    mysql -u propman -psecure_dev_password property_management < 004_add_company_balance.sql
-- ============================================================================
