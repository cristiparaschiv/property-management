-- ============================================================================
-- Schema Verification Script
-- Property Management & Invoicing System
-- ============================================================================
-- Description: Verifies that all tables, indexes, and constraints are correctly created
-- Usage: mysql -u propman -p property_management < verify_schema.sql
-- ============================================================================

USE property_management;

-- ============================================================================
-- Table Count Verification
-- ============================================================================
SELECT 'Verifying Table Count...' AS verification_step;

SELECT
    COUNT(*) AS total_tables,
    CASE
        WHEN COUNT(*) = 14 THEN 'PASS - All 14 tables exist'
        ELSE 'FAIL - Expected 14 tables'
    END AS status
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_TYPE = 'BASE TABLE';

-- ============================================================================
-- List All Tables
-- ============================================================================
SELECT 'Listing All Tables...' AS verification_step;

SELECT
    TABLE_NAME,
    ENGINE,
    TABLE_COLLATION,
    TABLE_ROWS,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS size_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- ============================================================================
-- Verify Foreign Keys
-- ============================================================================
SELECT 'Verifying Foreign Key Constraints...' AS verification_step;

SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'property_management'
  AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

-- ============================================================================
-- Verify Indexes
-- ============================================================================
SELECT 'Verifying Indexes...' AS verification_step;

SELECT
    TABLE_NAME,
    INDEX_NAME,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns,
    NON_UNIQUE,
    INDEX_TYPE
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'property_management'
GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE, INDEX_TYPE
ORDER BY TABLE_NAME, INDEX_NAME;

-- ============================================================================
-- Verify ENUM Columns
-- ============================================================================
SELECT 'Verifying ENUM Columns...' AS verification_step;

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    COLUMN_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'property_management'
  AND DATA_TYPE = 'enum'
ORDER BY TABLE_NAME, COLUMN_NAME;

-- ============================================================================
-- Check Essential Seed Data
-- ============================================================================
SELECT 'Checking Essential Seed Data...' AS verification_step;

SELECT
    'users' AS table_name,
    COUNT(*) AS record_count,
    CASE WHEN COUNT(*) >= 1 THEN 'PASS - Admin user exists' ELSE 'FAIL - No admin user' END AS status
FROM users
WHERE username = 'admin'

UNION ALL

SELECT
    'electricity_meters' AS table_name,
    COUNT(*) AS record_count,
    CASE WHEN COUNT(*) >= 1 THEN 'PASS - General meter exists' ELSE 'FAIL - No General meter' END AS status
FROM electricity_meters
WHERE is_general = TRUE

UNION ALL

SELECT
    'invoice_templates' AS table_name,
    COUNT(*) AS record_count,
    CASE WHEN COUNT(*) >= 1 THEN 'PASS - Default template exists' ELSE 'FAIL - No default template' END AS status
FROM invoice_templates
WHERE is_default = TRUE;

-- ============================================================================
-- Check Table Column Counts
-- ============================================================================
SELECT 'Verifying Column Counts...' AS verification_step;

SELECT
    TABLE_NAME,
    COUNT(*) AS column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'property_management'
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

-- ============================================================================
-- Verify Character Sets
-- ============================================================================
SELECT 'Verifying Character Sets...' AS verification_step;

SELECT
    TABLE_NAME,
    TABLE_COLLATION
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_TYPE = 'BASE TABLE'
  AND TABLE_COLLATION != 'utf8mb4_unicode_ci'
ORDER BY TABLE_NAME;

-- If empty result, all tables use correct collation

-- ============================================================================
-- Database Size Summary
-- ============================================================================
SELECT 'Database Size Summary...' AS verification_step;

SELECT
    SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 AS total_size_mb,
    SUM(DATA_LENGTH) / 1024 / 1024 AS data_size_mb,
    SUM(INDEX_LENGTH) / 1024 / 1024 AS index_size_mb,
    COUNT(*) AS total_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'property_management'
  AND TABLE_TYPE = 'BASE TABLE';

-- ============================================================================
-- Verification Complete
-- ============================================================================
SELECT 'Schema Verification Complete!' AS status;
