-- ============================================================================
-- Database and User Creation Script
-- Property Management & Invoicing System
-- ============================================================================
-- Description: Creates the database and application user with appropriate privileges
-- Date: 2025-12-09
-- ============================================================================

-- Create database with UTF8MB4 encoding
CREATE DATABASE IF NOT EXISTS property_management
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Create application user for localhost (development)
CREATE USER IF NOT EXISTS 'propman'@'localhost' IDENTIFIED BY 'secure_dev_password';

-- Grant all privileges on property_management database to propman user
GRANT ALL PRIVILEGES ON property_management.* TO 'propman'@'localhost';

-- Create application user for Docker/network access (production)
CREATE USER IF NOT EXISTS 'propman'@'%' IDENTIFIED BY 'secure_prod_password';

-- Grant all privileges on property_management database
GRANT ALL PRIVILEGES ON property_management.* TO 'propman'@'%';

-- Flush privileges to ensure changes take effect
FLUSH PRIVILEGES;

-- Verify database creation
USE property_management;

-- Display confirmation
SELECT
    'Database created successfully!' AS status,
    DATABASE() AS database_name,
    @@character_set_database AS charset,
    @@collation_database AS collation;

-- ============================================================================
-- IMPORTANT SECURITY NOTES:
-- ============================================================================
-- 1. Change 'secure_dev_password' and 'secure_prod_password' to strong passwords
-- 2. For production, consider using 'propman'@'app_server_ip' instead of 'propman'@'%'
-- 3. Store credentials securely in environment variables (.env file)
-- 4. Never commit passwords to version control
-- ============================================================================

-- ============================================================================
-- Usage Instructions:
-- ============================================================================
-- Development (localhost):
--   mysql -u root -p < create_database.sql
--
-- Production (change passwords first!):
--   Edit this file to set strong passwords
--   mysql -u root -p < create_database.sql
--
-- Verify users created:
--   mysql -u root -p -e "SELECT User, Host FROM mysql.user WHERE User='propman';"
--
-- Test connection:
--   mysql -u propman -p property_management
-- ============================================================================
