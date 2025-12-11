-- ============================================================================
-- Development Seed Data
-- Description: Sample data for development and testing
-- Date: 2025-12-09
-- ============================================================================

USE property_management;

-- ============================================================================
-- Sample Company Data
-- ============================================================================
INSERT INTO company (name, cui_cif, j_number, address, city, county, postal_code, bank_name, iban, phone, email)
VALUES (
    'IMOBILIARA DEMO SRL',
    'RO12345678',
    'J40/1234/2020',
    'Str. Exemplu Nr. 123, Bl. A1, Sc. 2, Ap. 45',
    'Bucuresti',
    'Bucuresti',
    '012345',
    'Banca Transilvania',
    'RO49AAAA1B31007593840000',
    '+40 21 123 4567',
    'contact@imobiliara-demo.ro'
)
ON DUPLICATE KEY UPDATE name=name;

-- ============================================================================
-- Sample Tenants
-- ============================================================================
INSERT INTO tenants (name, cui_cnp, j_number, address, city, county, postal_code, phone, email, rent_amount_eur, contract_start, contract_end, is_active)
VALUES
    (
        'POPESCU ION',
        '1234567890123',
        NULL,  -- Individual, no J number
        'Str. Tenant 1, Nr. 10',
        'Bucuresti',
        'Bucuresti',
        '011111',
        '+40 722 111 111',
        'ion.popescu@email.ro',
        500.00,
        '2024-01-01',
        '2025-12-31',
        TRUE
    ),
    (
        'IONESCU MARIA',
        '2987654321098',
        NULL,  -- Individual, no J number
        'Str. Tenant 2, Nr. 20',
        'Bucuresti',
        'Bucuresti',
        '022222',
        '+40 722 222 222',
        'maria.ionescu@email.ro',
        450.00,
        '2024-03-01',
        '2025-12-31',
        TRUE
    ),
    (
        'SC TECH SOLUTIONS SRL',
        'RO98765432',
        'J40/5678/2019',  -- Company tenant with J number
        'Str. Tenant 3, Nr. 30',
        'Bucuresti',
        'Bucuresti',
        '033333',
        '+40 21 333 3333',
        'contact@techsolutions.ro',
        750.00,
        '2024-06-01',
        '2026-05-31',
        TRUE
    )
ON DUPLICATE KEY UPDATE name=name;

-- ============================================================================
-- Sample Tenant Utility Percentages
-- ============================================================================
-- Tenant 1: 30% of utilities
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage)
VALUES
    (1, 'electricity', 30.00),
    (1, 'gas', 30.00),
    (1, 'water', 30.00),
    (1, 'salubrity', 30.00),
    (1, 'internet', 33.33)
ON DUPLICATE KEY UPDATE percentage=percentage;

-- Tenant 2: 25% of utilities
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage)
VALUES
    (2, 'electricity', 25.00),
    (2, 'gas', 25.00),
    (2, 'water', 25.00),
    (2, 'salubrity', 25.00),
    (2, 'internet', 33.33)
ON DUPLICATE KEY UPDATE percentage=percentage;

-- Tenant 3: 35% of utilities
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage)
VALUES
    (3, 'electricity', 35.00),
    (3, 'gas', 35.00),
    (3, 'water', 35.00),
    (3, 'salubrity', 35.00),
    (3, 'internet', 33.34)
ON DUPLICATE KEY UPDATE percentage=percentage;

-- Remaining 10% (electricity, gas, water, salubrity) reserved for company
-- Internet totals exactly 100%

-- ============================================================================
-- Sample Utility Providers
-- ============================================================================
INSERT INTO utility_providers (name, type, account_number, address, phone, email, is_active)
VALUES
    (
        'Enel Energie',
        'electricity',
        'RO123456789',
        'Bd. Unirii Nr. 1, Bucuresti',
        '0800 123 456',
        'clienti@enel.ro',
        TRUE
    ),
    (
        'Engie Romania',
        'gas',
        'RO987654321',
        'Calea Victoriei Nr. 200, Bucuresti',
        '0800 987 654',
        'contact@engie.ro',
        TRUE
    ),
    (
        'Apa Nova Bucuresti',
        'water',
        'CLIENT123456',
        'Str. Grigore Mora Nr. 1-3, Bucuresti',
        '021 9212',
        'contact@apanova.ro',
        TRUE
    ),
    (
        'Salubrizare Sud',
        'salubrity',
        'SALUBRITATE999',
        'Sos. Mihai Bravu Nr. 281, Bucuresti',
        '021 444 5555',
        'contact@salubrizare-sud.ro',
        TRUE
    ),
    (
        'RCS & RDS (Digi)',
        'internet',
        'CLIENT777888',
        'Str. Dr. Staicovici Nr. 75, Bucuresti',
        '031 400 4000',
        'contact@rcs-rds.ro',
        TRUE
    )
ON DUPLICATE KEY UPDATE name=name;

-- ============================================================================
-- Sample Received Invoices (November 2025)
-- ============================================================================
INSERT INTO received_invoices (provider_id, invoice_number, invoice_date, due_date, amount, utility_type, period_start, period_end, is_paid, paid_date)
VALUES
    (1, 'ENEL-2025-11-001', '2025-11-05', '2025-11-20', 850.50, 'electricity', '2025-10-01', '2025-10-31', TRUE, '2025-11-15'),
    (2, 'ENGIE-2025-11-001', '2025-11-03', '2025-11-18', 450.75, 'gas', '2025-10-01', '2025-10-31', TRUE, '2025-11-12'),
    (3, 'APANOVA-2025-11-001', '2025-11-02', '2025-11-17', 320.00, 'water', '2025-10-01', '2025-10-31', TRUE, '2025-11-10'),
    (4, 'SALUB-2025-11-001', '2025-11-01', '2025-11-15', 180.00, 'salubrity', '2025-10-01', '2025-10-31', TRUE, '2025-11-08'),
    (5, 'DIGI-2025-11-001', '2025-11-01', '2025-11-15', 120.00, 'internet', '2025-10-01', '2025-10-31', TRUE, '2025-11-05')
ON DUPLICATE KEY UPDATE invoice_number=invoice_number;

-- Sample unpaid invoices for December 2025
INSERT INTO received_invoices (provider_id, invoice_number, invoice_date, due_date, amount, utility_type, period_start, period_end, is_paid, paid_date)
VALUES
    (1, 'ENEL-2025-12-001', '2025-12-05', '2025-12-20', 920.00, 'electricity', '2025-11-01', '2025-11-30', FALSE, NULL),
    (2, 'ENGIE-2025-12-001', '2025-12-03', '2025-12-18', 520.00, 'gas', '2025-11-01', '2025-11-30', FALSE, NULL),
    (3, 'APANOVA-2025-12-001', '2025-12-02', '2025-12-17', 340.00, 'water', '2025-11-01', '2025-11-30', FALSE, NULL),
    (4, 'SALUB-2025-12-001', '2025-12-01', '2025-12-15', 180.00, 'salubrity', '2025-11-01', '2025-11-30', FALSE, NULL),
    (5, 'DIGI-2025-12-001', '2025-12-01', '2025-12-15', 120.00, 'internet', '2025-11-01', '2025-11-30', FALSE, NULL)
ON DUPLICATE KEY UPDATE invoice_number=invoice_number;

-- ============================================================================
-- Sample Electricity Meters
-- ============================================================================
-- General meter already created in 002_seed_data.sql

-- Tenant-specific meters
INSERT INTO electricity_meters (name, location, tenant_id, is_general, meter_number, is_active)
VALUES
    ('Apartment A - Popescu', 'Apartment A, Floor 3', 1, FALSE, 'MTR-A-001234', TRUE),
    ('Apartment B - Ionescu', 'Apartment B, Floor 2', 2, FALSE, 'MTR-B-005678', TRUE),
    ('Office - Tech Solutions', 'Office Space, Floor 1', 3, FALSE, 'MTR-C-009012', TRUE)
ON DUPLICATE KEY UPDATE name=name;

-- ============================================================================
-- Sample Meter Readings (October 2025)
-- ============================================================================
INSERT INTO meter_readings (meter_id, reading_date, reading_value, consumption, period_month, period_year)
VALUES
    -- General meter
    (1, '2025-10-31', 125000.00, 1500.00, 10, 2025),
    -- Tenant meters
    (2, '2025-10-31', 45000.00, 450.00, 10, 2025),
    (3, '2025-10-31', 38000.00, 375.00, 10, 2025),
    (4, '2025-10-31', 52500.00, 525.00, 10, 2025)
ON DUPLICATE KEY UPDATE reading_value=reading_value;

-- Meter readings for November 2025
INSERT INTO meter_readings (meter_id, reading_date, reading_value, consumption, period_month, period_year)
VALUES
    -- General meter
    (1, '2025-11-30', 126650.00, 1650.00, 11, 2025),
    -- Tenant meters
    (2, '2025-11-30', 45490.00, 490.00, 11, 2025),
    (3, '2025-11-30', 38410.00, 410.00, 11, 2025),
    (4, '2025-11-30', 53080.00, 580.00, 11, 2025)
ON DUPLICATE KEY UPDATE reading_value=reading_value;

-- Difference for November: 1650 - (490 + 410 + 580) = 170 kWh (common areas/loss)

-- ============================================================================
-- Sample Exchange Rates (BNR)
-- ============================================================================
INSERT INTO exchange_rates (rate_date, eur_ron, source)
VALUES
    ('2025-10-01', 4.9750, 'BNR'),
    ('2025-10-15', 4.9680, 'BNR'),
    ('2025-11-01', 4.9820, 'BNR'),
    ('2025-11-15', 4.9755, 'BNR'),
    ('2025-12-01', 4.9790, 'BNR'),
    ('2025-12-09', 4.9765, 'BNR')
ON DUPLICATE KEY UPDATE eur_ron=eur_ron;

-- ============================================================================
-- Sample Utility Calculation (November 2025)
-- ============================================================================
INSERT INTO utility_calculations (period_month, period_year, is_finalized, finalized_at, notes)
VALUES
    (11, 2025, TRUE, '2025-12-01 10:30:00', 'November 2025 utility calculation - finalized')
ON DUPLICATE KEY UPDATE period_month=period_month;

-- Calculation details for each tenant
INSERT INTO utility_calculation_details (calculation_id, tenant_id, utility_type, received_invoice_id, percentage, amount)
VALUES
    -- Tenant 1 (Popescu) - 30% of utilities
    (1, 1, 'electricity', 6, 30.00, 276.00),  -- 920.00 * 0.30
    (1, 1, 'gas', 7, 30.00, 156.00),          -- 520.00 * 0.30
    (1, 1, 'water', 8, 30.00, 102.00),        -- 340.00 * 0.30
    (1, 1, 'salubrity', 9, 30.00, 54.00),     -- 180.00 * 0.30
    (1, 1, 'internet', 10, 33.33, 39.996),    -- 120.00 * 0.3333

    -- Tenant 2 (Ionescu) - 25% of utilities
    (1, 2, 'electricity', 6, 25.00, 230.00),  -- 920.00 * 0.25
    (1, 2, 'gas', 7, 25.00, 130.00),          -- 520.00 * 0.25
    (1, 2, 'water', 8, 25.00, 85.00),         -- 340.00 * 0.25
    (1, 2, 'salubrity', 9, 25.00, 45.00),     -- 180.00 * 0.25
    (1, 2, 'internet', 10, 33.33, 39.996),    -- 120.00 * 0.3333

    -- Tenant 3 (Tech Solutions) - 35% of utilities
    (1, 3, 'electricity', 6, 35.00, 322.00),  -- 920.00 * 0.35
    (1, 3, 'gas', 7, 35.00, 182.00),          -- 520.00 * 0.35
    (1, 3, 'water', 8, 35.00, 119.00),        -- 340.00 * 0.35
    (1, 3, 'salubrity', 9, 35.00, 63.00),     -- 180.00 * 0.35
    (1, 3, 'internet', 10, 33.34, 40.008)     -- 120.00 * 0.3334
ON DUPLICATE KEY UPDATE amount=amount;

-- Company reserved portion (10% of electricity, gas, water, salubrity):
-- Electricity: 92.00 (10%)
-- Gas: 52.00 (10%)
-- Water: 34.00 (10%)
-- Salubrity: 18.00 (10%)
-- Internet: 0.00 (0%)
-- Total company portion: 196.00 RON

-- ============================================================================
-- Sample Rent Invoices (November 2025)
-- ============================================================================
INSERT INTO invoices (invoice_number, invoice_type, tenant_id, invoice_date, due_date, exchange_rate, exchange_rate_date, subtotal_eur, subtotal_ron, vat_amount, total_ron, is_paid, paid_date, template_id)
VALUES
    ('ARC00001', 'rent', 1, '2025-11-01', '2025-11-10', 4.9820, '2025-11-01', 500.00, 2491.00, 0.00, 2491.00, TRUE, '2025-11-08', 1),
    ('ARC00002', 'rent', 2, '2025-11-01', '2025-11-10', 4.9820, '2025-11-01', 450.00, 2241.90, 0.00, 2241.90, TRUE, '2025-11-09', 1),
    ('ARC00003', 'rent', 3, '2025-11-01', '2025-11-10', 4.9820, '2025-11-01', 750.00, 3736.50, 0.00, 3736.50, TRUE, '2025-11-07', 1)
ON DUPLICATE KEY UPDATE invoice_number=invoice_number;

-- Invoice items for rent invoices
INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, vat_rate, total, sort_order)
VALUES
    (1, 'Chirie lunara - Noiembrie 2025', 1.00, 2491.00, 0.00, 2491.00, 1),
    (2, 'Chirie lunara - Noiembrie 2025', 1.00, 2241.90, 0.00, 2241.90, 1),
    (3, 'Chirie lunara - Noiembrie 2025', 1.00, 3736.50, 0.00, 3736.50, 1)
ON DUPLICATE KEY UPDATE description=description;

-- ============================================================================
-- Sample Utility Invoices (November 2025)
-- ============================================================================
INSERT INTO invoices (invoice_number, invoice_type, tenant_id, invoice_date, due_date, subtotal_ron, vat_amount, total_ron, is_paid, template_id, calculation_id)
VALUES
    ('ARC00004', 'utility', 1, '2025-12-01', '2025-12-10', 628.00, 0.00, 628.00, FALSE, 1, 1),
    ('ARC00005', 'utility', 2, '2025-12-01', '2025-12-10', 530.00, 0.00, 530.00, FALSE, 1, 1),
    ('ARC00006', 'utility', 3, '2025-12-01', '2025-12-10', 726.00, 0.00, 726.00, FALSE, 1, 1)
ON DUPLICATE KEY UPDATE invoice_number=invoice_number;

-- Invoice items for utility invoices (Tenant 1)
INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, vat_rate, total, sort_order)
VALUES
    (4, 'Energie electrica - Noiembrie 2025', 1.00, 276.00, 0.00, 276.00, 1),
    (4, 'Gaz natural - Noiembrie 2025', 1.00, 156.00, 0.00, 156.00, 2),
    (4, 'Apa si canal - Noiembrie 2025', 1.00, 102.00, 0.00, 102.00, 3),
    (4, 'Salubritate - Noiembrie 2025', 1.00, 54.00, 0.00, 54.00, 4),
    (4, 'Internet - Noiembrie 2025', 1.00, 40.00, 0.00, 40.00, 5)
ON DUPLICATE KEY UPDATE description=description;

-- Invoice items for utility invoices (Tenant 2)
INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, vat_rate, total, sort_order)
VALUES
    (5, 'Energie electrica - Noiembrie 2025', 1.00, 230.00, 0.00, 230.00, 1),
    (5, 'Gaz natural - Noiembrie 2025', 1.00, 130.00, 0.00, 130.00, 2),
    (5, 'Apa si canal - Noiembrie 2025', 1.00, 85.00, 0.00, 85.00, 3),
    (5, 'Salubritate - Noiembrie 2025', 1.00, 45.00, 0.00, 45.00, 4),
    (5, 'Internet - Noiembrie 2025', 1.00, 40.00, 0.00, 40.00, 5)
ON DUPLICATE KEY UPDATE description=description;

-- Invoice items for utility invoices (Tenant 3)
INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, vat_rate, total, sort_order)
VALUES
    (6, 'Energie electrica - Noiembrie 2025', 1.00, 322.00, 0.00, 322.00, 1),
    (6, 'Gaz natural - Noiembrie 2025', 1.00, 182.00, 0.00, 182.00, 2),
    (6, 'Apa si canal - Noiembrie 2025', 1.00, 119.00, 0.00, 119.00, 3),
    (6, 'Salubritate - Noiembrie 2025', 1.00, 63.00, 0.00, 63.00, 4),
    (6, 'Internet - Noiembrie 2025', 1.00, 40.00, 0.00, 40.00, 5)
ON DUPLICATE KEY UPDATE description=description;

-- ============================================================================
-- Development Seed Data Complete
-- ============================================================================
-- Summary:
-- - 1 Company (IMOBILIARA DEMO SRL)
-- - 3 Active Tenants with utility percentages
-- - 5 Utility Providers
-- - 10 Received Invoices (5 paid from Nov, 5 unpaid from Dec)
-- - 4 Electricity Meters (1 General + 3 Tenant)
-- - Meter Readings for Oct and Nov 2025
-- - 6 Exchange Rates
-- - 1 Finalized Utility Calculation (November 2025)
-- - 6 Generated Invoices (3 rent + 3 utility)
-- ============================================================================
