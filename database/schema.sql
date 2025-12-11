-- ============================================================================
-- Property Management & Invoicing System - Complete Database Schema
-- ============================================================================
-- Database: property_management
-- Character Set: UTF8MB4
-- Collation: utf8mb4_unicode_ci
-- Version: 1.1
-- Date: 2025-12-11
-- ============================================================================

-- Drop database if exists (use with caution in production)
-- DROP DATABASE IF EXISTS property_management;

-- Create database with UTF8MB4 encoding
CREATE DATABASE IF NOT EXISTS property_management
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE property_management;

-- ============================================================================
-- Table: users
-- Description: User authentication and account information
-- ============================================================================
CREATE TABLE users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(255) NULL,
    id_card_series VARCHAR(10) NULL COMMENT 'ID card series (e.g., XY)',
    id_card_number VARCHAR(20) NULL COMMENT 'ID card number',
    id_card_issued_by VARCHAR(100) NULL COMMENT 'ID card issuing authority',
    last_login DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: company
-- Description: Company details for invoice generation (single record expected)
-- ============================================================================
CREATE TABLE company (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    cui_cif VARCHAR(20) NOT NULL,
    j_number VARCHAR(50) NULL COMMENT 'Trade registry number',
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    county VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NULL,
    bank_name VARCHAR(255) NULL,
    iban VARCHAR(50) NULL,
    phone VARCHAR(50) NULL,
    email VARCHAR(255) NULL,
    representative_name VARCHAR(255) NULL COMMENT 'Legal representative name',
    invoice_prefix VARCHAR(10) DEFAULT 'ARC' COMMENT 'Prefix for invoice numbers',
    last_invoice_number INT DEFAULT 0 COMMENT 'Last used invoice number',
    balance DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT 'Company account balance',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_cui_cif (cui_cif)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: tenants
-- Description: Tenant information and contract details
-- ============================================================================
CREATE TABLE tenants (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    cui_cnp VARCHAR(20) NULL COMMENT 'Company CUI or Personal CNP',
    j_number VARCHAR(50) NULL COMMENT 'Trade registry number (for company tenants)',
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    county VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NULL,
    phone VARCHAR(50) NULL,
    email VARCHAR(255) NULL,
    rent_amount_eur DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT 'Monthly rent in EUR',
    contract_start DATE NULL,
    contract_end DATE NULL,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name),
    INDEX idx_is_active (is_active),
    INDEX idx_contract_dates (contract_start, contract_end)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: tenant_utility_percentages
-- Description: Default utility cost percentages per tenant per utility type
-- ============================================================================
CREATE TABLE tenant_utility_percentages (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT UNSIGNED NOT NULL,
    utility_type ENUM('electricity', 'gas', 'water', 'salubrity', 'internet', 'other') NOT NULL,
    percentage DECIMAL(5,2) NOT NULL DEFAULT 0 COMMENT 'Percentage 0.00 to 100.00',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE,
    UNIQUE KEY unique_tenant_utility (tenant_id, utility_type),
    INDEX idx_tenant_id (tenant_id),
    INDEX idx_utility_type (utility_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: utility_providers
-- Description: Utility service providers (electricity, gas, water, etc.)
-- ============================================================================
CREATE TABLE utility_providers (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type ENUM('electricity', 'gas', 'water', 'salubrity', 'internet', 'other') NOT NULL,
    account_number VARCHAR(100) NULL COMMENT 'Customer account number',
    address VARCHAR(255) NULL,
    phone VARCHAR(50) NULL,
    email VARCHAR(255) NULL,
    notes TEXT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name),
    INDEX idx_type (type),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: received_invoices
-- Description: Invoices received from utility providers
-- ============================================================================
CREATE TABLE received_invoices (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    provider_id INT UNSIGNED NOT NULL,
    invoice_number VARCHAR(100) NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    utility_type ENUM('electricity', 'gas', 'water', 'salubrity', 'internet', 'other') NOT NULL,
    period_start DATE NOT NULL COMMENT 'Billing period start date',
    period_end DATE NOT NULL COMMENT 'Billing period end date',
    is_paid BOOLEAN DEFAULT FALSE,
    paid_date DATE NULL,
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (provider_id) REFERENCES utility_providers(id),
    INDEX idx_provider_id (provider_id),
    INDEX idx_invoice_number (invoice_number),
    INDEX idx_invoice_date (invoice_date),
    INDEX idx_period (period_start, period_end),
    INDEX idx_is_paid (is_paid),
    INDEX idx_utility_type (utility_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: electricity_meters
-- Description: Electricity meter definitions (General meter + tenant meters)
-- ============================================================================
CREATE TABLE electricity_meters (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(255) NULL,
    tenant_id INT UNSIGNED NULL COMMENT 'NULL for General meter',
    is_general BOOLEAN DEFAULT FALSE COMMENT 'True for main distribution meter',
    meter_number VARCHAR(100) NULL COMMENT 'Physical meter serial number',
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE SET NULL,
    INDEX idx_name (name),
    INDEX idx_tenant_id (tenant_id),
    INDEX idx_is_general (is_general),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: meter_readings
-- Description: Monthly electricity meter readings
-- ============================================================================
CREATE TABLE meter_readings (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    meter_id INT UNSIGNED NOT NULL,
    reading_date DATE NOT NULL,
    reading_value DECIMAL(12,2) NOT NULL COMMENT 'Current meter reading in kWh',
    previous_reading_value DECIMAL(12,2) NULL COMMENT 'Previous meter reading for reference',
    consumption DECIMAL(12,2) NULL COMMENT 'Calculated consumption (current - previous)',
    period_month TINYINT NOT NULL COMMENT 'Month (1-12)',
    period_year SMALLINT NOT NULL COMMENT 'Year (e.g., 2025)',
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (meter_id) REFERENCES electricity_meters(id) ON DELETE CASCADE,
    UNIQUE KEY unique_meter_period (meter_id, period_month, period_year),
    INDEX idx_meter_id (meter_id),
    INDEX idx_reading_date (reading_date),
    INDEX idx_period (period_year, period_month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: utility_calculations
-- Description: Utility cost calculation sessions per period
-- ============================================================================
CREATE TABLE utility_calculations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    period_month TINYINT NOT NULL COMMENT 'Month (1-12)',
    period_year SMALLINT NOT NULL COMMENT 'Year (e.g., 2025)',
    is_finalized BOOLEAN DEFAULT FALSE COMMENT 'Locked calculations cannot be modified',
    finalized_at DATETIME NULL,
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_period (period_month, period_year),
    INDEX idx_period (period_year, period_month),
    INDEX idx_is_finalized (is_finalized)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: utility_calculation_details
-- Description: Individual tenant shares per utility type in a calculation
-- ============================================================================
CREATE TABLE utility_calculation_details (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    calculation_id INT UNSIGNED NOT NULL,
    tenant_id INT UNSIGNED NOT NULL,
    utility_type ENUM('electricity', 'gas', 'water', 'salubrity', 'internet', 'other') NOT NULL,
    received_invoice_id INT UNSIGNED NULL COMMENT 'Reference to source invoice',
    percentage DECIMAL(5,2) NOT NULL COMMENT 'Percentage used for this calculation',
    amount DECIMAL(10,2) NOT NULL COMMENT 'Calculated tenant share amount',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (calculation_id) REFERENCES utility_calculations(id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id),
    FOREIGN KEY (received_invoice_id) REFERENCES received_invoices(id) ON DELETE SET NULL,
    INDEX idx_calculation_id (calculation_id),
    INDEX idx_tenant_id (tenant_id),
    INDEX idx_utility_type (utility_type),
    INDEX idx_received_invoice_id (received_invoice_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: invoice_templates
-- Description: HTML templates for invoice PDF generation
-- ============================================================================
CREATE TABLE invoice_templates (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    html_template LONGTEXT NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name),
    INDEX idx_is_default (is_default)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: invoices
-- Description: Generated invoices (rent and utility) sent to tenants
-- ============================================================================
CREATE TABLE invoices (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    invoice_number VARCHAR(50) NOT NULL UNIQUE COMMENT 'ARC prefix + sequential number',
    invoice_type ENUM('rent', 'utility', 'generic') NOT NULL,
    tenant_id INT UNSIGNED NULL COMMENT 'NULL for generic invoices',
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    exchange_rate DECIMAL(10,4) NULL COMMENT 'EUR/RON rate for rent invoices',
    exchange_rate_date DATE NULL COMMENT 'Date of exchange rate used',
    exchange_rate_manual BOOLEAN DEFAULT FALSE COMMENT 'True if rate was manually entered',
    subtotal_eur DECIMAL(10,2) NULL COMMENT 'Subtotal in EUR (for rent)',
    subtotal_ron DECIMAL(10,2) NOT NULL COMMENT 'Subtotal in RON',
    vat_amount DECIMAL(10,2) DEFAULT 0 COMMENT 'Total VAT amount',
    total_ron DECIMAL(10,2) NOT NULL COMMENT 'Grand total in RON',
    is_paid BOOLEAN DEFAULT FALSE,
    paid_date DATE NULL,
    notes TEXT NULL,
    template_id INT UNSIGNED NULL COMMENT 'Invoice template used',
    calculation_id INT UNSIGNED NULL COMMENT 'Link to utility calculation (for utility invoices)',
    client_name VARCHAR(255) NULL COMMENT 'Client name for generic invoices',
    client_address VARCHAR(255) NULL COMMENT 'Client address for generic invoices',
    client_cui VARCHAR(20) NULL COMMENT 'Client CUI/CNP for generic invoices',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id),
    FOREIGN KEY (template_id) REFERENCES invoice_templates(id) ON DELETE SET NULL,
    FOREIGN KEY (calculation_id) REFERENCES utility_calculations(id) ON DELETE SET NULL,
    INDEX idx_invoice_number (invoice_number),
    INDEX idx_invoice_type (invoice_type),
    INDEX idx_tenant_id (tenant_id),
    INDEX idx_invoice_date (invoice_date),
    INDEX idx_is_paid (is_paid),
    INDEX idx_calculation_id (calculation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: invoice_items
-- Description: Line items for invoices
-- ============================================================================
CREATE TABLE invoice_items (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT UNSIGNED NOT NULL,
    description VARCHAR(255) NOT NULL,
    quantity DECIMAL(10,2) NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    vat_rate DECIMAL(5,2) DEFAULT 0 COMMENT 'VAT percentage (e.g., 19.00)',
    total DECIMAL(10,2) NOT NULL COMMENT 'Line item total',
    sort_order INT DEFAULT 0 COMMENT 'Display order',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
    INDEX idx_invoice_id (invoice_id),
    INDEX idx_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Table: exchange_rates
-- Description: Cached BNR exchange rates (EUR/RON)
-- ============================================================================
CREATE TABLE exchange_rates (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    rate_date DATE NOT NULL UNIQUE,
    eur_ron DECIMAL(10,4) NOT NULL COMMENT 'EUR to RON exchange rate',
    source VARCHAR(50) DEFAULT 'BNR' COMMENT 'Rate source (e.g., BNR)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_rate_date (rate_date),
    INDEX idx_source (source)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Default Admin User
-- Password: Admin123! (bcrypt hash with cost 12)
-- IMPORTANT: Change this password after first login!
-- ============================================================================
INSERT INTO users (username, email, password_hash)
VALUES (
    'admin',
    'admin@property.local',
    '$2b$12$Q1fwShjRUjSzOSjmbjThQOargn76JQXqLRVesUQiMFxWfqQY8n8Cq'
);

-- ============================================================================
-- Default General Electricity Meters
-- These are required for the electricity calculation system to work
-- ============================================================================
INSERT INTO electricity_meters (name, location, tenant_id, is_general, meter_number, is_active, notes)
VALUES
    ('General Meter - Building', 'Main Electrical Panel', NULL, TRUE, 'GM-001', TRUE,
     'Main building electricity meter for tracking total consumption'),
    ('General - Început Lună', 'Main Electrical Panel', NULL, TRUE, 'GM-002', TRUE,
     'Statistics meter: stores reading value at exact beginning of month for monthly consumption tracking');

-- ============================================================================
-- End of Schema
-- ============================================================================
