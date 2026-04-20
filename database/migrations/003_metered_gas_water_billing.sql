-- Migration 003: Metered gas & water billing
USE property_management;

ALTER TABLE tenant_utility_percentages
  ADD COLUMN uses_meter BOOLEAN NOT NULL DEFAULT FALSE
  COMMENT 'When TRUE, tenant share for this utility is computed from meter readings instead of fixed percentage';

CREATE TABLE gas_readings (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT UNSIGNED NOT NULL,
    reading_date DATE NOT NULL,
    reading_value DECIMAL(12,2) NOT NULL COMMENT 'Gas meter index in m³',
    previous_reading_value DECIMAL(12,2) NULL,
    consumption DECIMAL(12,2) NULL COMMENT 'current - previous',
    period_month TINYINT NOT NULL,
    period_year SMALLINT NOT NULL,
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE,
    UNIQUE KEY unique_tenant_period (tenant_id, period_month, period_year),
    INDEX idx_tenant_id (tenant_id),
    INDEX idx_period (period_year, period_month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE water_readings (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT UNSIGNED NOT NULL,
    reading_date DATE NOT NULL,
    reading_value DECIMAL(12,2) NOT NULL COMMENT 'Water meter index in m³',
    previous_reading_value DECIMAL(12,2) NULL,
    consumption DECIMAL(12,2) NULL,
    period_month TINYINT NOT NULL,
    period_year SMALLINT NOT NULL,
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE,
    UNIQUE KEY unique_tenant_period (tenant_id, period_month, period_year),
    INDEX idx_tenant_id (tenant_id),
    INDEX idx_period (period_year, period_month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE metered_calculation_inputs (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    calculation_id INT UNSIGNED NOT NULL,
    received_invoice_id INT UNSIGNED NOT NULL,
    utility_type ENUM('gas', 'water') NOT NULL,
    total_units DECIMAL(12,2) NOT NULL,
    consumption_amount DECIMAL(10,2) NULL COMMENT 'Water only: cost of consumption portion of invoice',
    rain_amount DECIMAL(10,2) NULL COMMENT 'Water only: cost of rain-water portion of invoice',
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (calculation_id) REFERENCES utility_calculations(id) ON DELETE CASCADE,
    FOREIGN KEY (received_invoice_id) REFERENCES received_invoices(id) ON DELETE CASCADE,
    UNIQUE KEY unique_calc_utility (calculation_id, utility_type),
    INDEX idx_calculation_id (calculation_id),
    INDEX idx_received_invoice_id (received_invoice_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
