-- ============================================================================
-- Demo Data for Property Management System
-- ============================================================================
-- This script populates the database with realistic Romanian demo data
-- Run daily via cronjob to reset the demo environment
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- Clear existing data (preserve users table structure, reset admin)
TRUNCATE TABLE backup_history;
TRUNCATE TABLE google_drive_config;
TRUNCATE TABLE notifications;
TRUNCATE TABLE activity_logs;
TRUNCATE TABLE invoice_items;
TRUNCATE TABLE invoices;
TRUNCATE TABLE utility_calculation_details;
TRUNCATE TABLE utility_calculations;
TRUNCATE TABLE meter_readings;
TRUNCATE TABLE electricity_meters;
TRUNCATE TABLE received_invoices;
TRUNCATE TABLE utility_providers;
TRUNCATE TABLE tenant_utility_percentages;
TRUNCATE TABLE tenants;
TRUNCATE TABLE exchange_rates;
TRUNCATE TABLE invoice_templates;
TRUNCATE TABLE company;
TRUNCATE TABLE login_attempts;
DELETE FROM users;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- Users - Demo admin account
-- Password: Admin123!
-- ============================================================================
INSERT INTO users (id, username, email, password_hash, full_name, id_card_series, id_card_number, id_card_issued_by)
VALUES (
    1,
    'demo',
    'demo@domistra.ro',
    '$2b$12$Q1fwShjRUjSzOSjmbjThQOargn76JQXqLRVesUQiMFxWfqQY8n8Cq',
    'Administrator Demo',
    'BV',
    '123456',
    'SPCLEP Brasov'
);

-- ============================================================================
-- Company Information
-- ============================================================================
INSERT INTO company (id, name, cui_cif, j_number, address, city, county, postal_code, bank_name, iban, phone, email, representative_name, invoice_prefix, last_invoice_number, balance)
VALUES (
    1,
    'DOMISTRA IMOBILIARE SRL',
    'RO12345678',
    'J08/1234/2020',
    'Strada Republicii nr. 25, Etaj 2, Ap. 5',
    'Brașov',
    'Brașov',
    '500030',
    'Banca Transilvania',
    'RO49BTRLRONCRT0123456789',
    '+40 268 123 456',
    'office@domistra.ro',
    'Ion Popescu',
    'DMT',
    47,
    15750.50
);

-- ============================================================================
-- Utility Providers
-- ============================================================================
INSERT INTO utility_providers (id, name, type, account_number, address, phone, email, is_active) VALUES
(1, 'Electrica Furnizare SA', 'electricity', 'EF-2024-78945', 'Str. Gării nr. 15, Brașov', '0800 800 048', 'clienti@electrica.ro', 1),
(2, 'Distrigaz Sud Rețele SRL', 'gas', 'DG-BV-456123', 'Str. Zizinului nr. 100, Brașov', '0800 800 928', 'contact@distrigaz.ro', 1),
(3, 'Compania Apa Brașov SA', 'water', 'CAB-123456-2024', 'Str. Vlad Țepeș nr. 13, Brașov', '0268 333 200', 'office@apabrasov.ro', 1),
(4, 'Brantner Environment SRL', 'salubrity', 'BR-BV-2024-789', 'Str. Ecologiei nr. 5, Brașov', '0268 547 000', 'brasov@brantner.ro', 1),
(5, 'RCS & RDS SA', 'internet', 'DIGI-BV-654321', 'Str. Dr. N. Lupu nr. 4, Brașov', '031 400 4444', 'suport@rcs-rds.ro', 1),
(6, 'E.ON Energie România SA', 'gas', 'EON-456789', 'Bd. Eroilor nr. 8, Brașov', '0800 800 366', 'contact@eon-energie.ro', 1),
(7, 'Hidroelectrica SA', 'electricity', 'HE-2024-11223', 'Str. Dealului nr. 20, Brașov', '021 303 2500', 'info@hidroelectrica.ro', 0);

-- ============================================================================
-- Tenants
-- ============================================================================
INSERT INTO tenants (id, name, cui_cnp, j_number, address, city, county, postal_code, phone, email, rent_amount_eur, contract_start, contract_end, is_active, notes) VALUES
(1, 'SC ALPHA TECH SOLUTIONS SRL', 'RO45678901', 'J08/567/2019', 'Str. Lungă nr. 45, Spațiu Comercial 1', 'Brașov', 'Brașov', '500035', '+40 722 111 222', 'office@alphatech.ro', 850.00, '2023-01-01', '2025-12-31', 1, 'Chiriaș de încredere, plăți la timp'),
(2, 'SC BETA CONSULTING GROUP SRL', 'RO56789012', 'J08/890/2020', 'Str. Lungă nr. 45, Spațiu Comercial 2', 'Brașov', 'Brașov', '500035', '+40 733 222 333', 'contact@betaconsulting.ro', 1200.00, '2023-06-01', '2026-05-31', 1, 'Companie IT, consum mare de electricitate'),
(3, 'SC GAMMA RETAIL SRL', 'RO67890123', 'J08/123/2021', 'Str. Lungă nr. 45, Spațiu Comercial 3', 'Brașov', 'Brașov', '500035', '+40 744 333 444', 'manager@gammaretail.ro', 950.00, '2024-01-01', '2026-12-31', 1, 'Magazin retail, program extins'),
(4, 'SC DELTA SERVICES SRL', 'RO78901234', 'J08/456/2022', 'Str. Lungă nr. 45, Spațiu Comercial 4', 'Brașov', 'Brașov', '500035', '+40 755 444 555', 'info@deltaservices.ro', 650.00, '2024-03-01', '2027-02-28', 1, 'Servicii curățenie'),
(5, 'PFA Ionescu Maria', '2850315080012', NULL, 'Str. Lungă nr. 45, Birou 5', 'Brașov', 'Brașov', '500035', '+40 766 555 666', 'maria.ionescu@gmail.com', 400.00, '2024-06-01', '2025-05-31', 1, 'Birou individual, notar'),
(6, 'SC EPSILON DESIGN STUDIO SRL', 'RO89012345', 'J08/789/2023', 'Str. Lungă nr. 45, Spațiu Comercial 6', 'Brașov', 'Brașov', '500035', '+40 777 666 777', 'hello@epsilondesign.ro', 750.00, '2024-09-01', '2027-08-31', 1, 'Studio design grafic'),
(7, 'SC ZETA MEDICAL CENTER SRL', 'RO90123456', 'J08/234/2022', 'Str. Lungă nr. 45, Spațiu Comercial 7', 'Brașov', 'Brașov', '500035', '+40 788 777 888', 'receptie@zetamedical.ro', 1500.00, '2023-03-01', '2028-02-29', 1, 'Cabinet medical, program L-V'),
(8, 'SC OMEGA LOGISTICS SRL', 'RO01234567', 'J08/567/2021', 'Str. Lungă nr. 45, Depozit 1', 'Brașov', 'Brașov', '500035', '+40 799 888 999', 'dispatch@omegalogistics.ro', 500.00, '2022-01-01', '2024-12-31', 0, 'Contract expirat, în negociere pentru reînnoire');

-- ============================================================================
-- Tenant Utility Percentages
-- ============================================================================
INSERT INTO tenant_utility_percentages (tenant_id, utility_type, percentage) VALUES
-- Alpha Tech (15% electricity based on meter, 10% others)
(1, 'electricity', 15.00),
(1, 'gas', 10.00),
(1, 'water', 12.00),
(1, 'salubrity', 12.50),
(1, 'internet', 0.00),
-- Beta Consulting (25% electricity - high IT usage)
(2, 'electricity', 25.00),
(2, 'gas', 15.00),
(2, 'water', 15.00),
(2, 'salubrity', 12.50),
(2, 'internet', 0.00),
-- Gamma Retail (20% - extended hours)
(3, 'electricity', 20.00),
(3, 'gas', 12.00),
(3, 'water', 13.00),
(3, 'salubrity', 12.50),
(3, 'internet', 0.00),
-- Delta Services (10%)
(4, 'electricity', 10.00),
(4, 'gas', 8.00),
(4, 'water', 10.00),
(4, 'salubrity', 12.50),
(4, 'internet', 0.00),
-- PFA Ionescu (5% - small office)
(5, 'electricity', 5.00),
(5, 'gas', 5.00),
(5, 'water', 5.00),
(5, 'salubrity', 12.50),
(5, 'internet', 0.00),
-- Epsilon Design (10%)
(6, 'electricity', 10.00),
(6, 'gas', 10.00),
(6, 'water', 10.00),
(6, 'salubrity', 12.50),
(6, 'internet', 0.00),
-- Zeta Medical (15%)
(7, 'electricity', 15.00),
(7, 'gas', 40.00),
(7, 'water', 35.00),
(7, 'salubrity', 25.00),
(7, 'internet', 0.00);

-- ============================================================================
-- Electricity Meters
-- ============================================================================
INSERT INTO electricity_meters (id, name, location, tenant_id, is_general, meter_number, is_active, notes) VALUES
(1, 'General Meter - Building', 'Panou electric principal', NULL, 1, 'GM-001', 1, 'Contor general clădire'),
(2, 'General - Început Lună', 'Panou electric principal', NULL, 1, 'GM-002', 1, 'Citire referință început lună'),
(3, 'Contor Alpha Tech', 'Spațiu Comercial 1', 1, 0, 'AT-001', 1, 'Contor individual'),
(4, 'Contor Beta Consulting', 'Spațiu Comercial 2', 2, 0, 'BC-001', 1, 'Contor individual'),
(5, 'Contor Gamma Retail', 'Spațiu Comercial 3', 3, 0, 'GR-001', 1, 'Contor individual'),
(6, 'Contor Delta Services', 'Spațiu Comercial 4', 4, 0, 'DS-001', 1, 'Contor individual'),
(7, 'Contor PFA Ionescu', 'Birou 5', 5, 0, 'PI-001', 1, 'Contor individual'),
(8, 'Contor Epsilon Design', 'Spațiu Comercial 6', 6, 0, 'ED-001', 1, 'Contor individual'),
(9, 'Contor Zeta Medical', 'Spațiu Comercial 7', 7, 0, 'ZM-001', 1, 'Contor individual');

-- ============================================================================
-- Exchange Rates (Last 6 months)
-- ============================================================================
INSERT INTO exchange_rates (rate_date, eur_ron, source) VALUES
('2024-07-01', 4.9720, 'BNR'),
('2024-07-15', 4.9685, 'BNR'),
('2024-08-01', 4.9745, 'BNR'),
('2024-08-15', 4.9760, 'BNR'),
('2024-09-01', 4.9755, 'BNR'),
('2024-09-15', 4.9740, 'BNR'),
('2024-10-01', 4.9765, 'BNR'),
('2024-10-15', 4.9780, 'BNR'),
('2024-11-01', 4.9770, 'BNR'),
('2024-11-15', 4.9795, 'BNR'),
('2024-12-01', 4.9760, 'BNR'),
('2024-12-15', 4.9785, 'BNR'),
('2024-12-20', 4.9773, 'BNR');

-- ============================================================================
-- Received Invoices (Last 6 months of utility bills)
-- ============================================================================
INSERT INTO received_invoices (id, provider_id, invoice_number, invoice_date, due_date, amount, utility_type, period_start, period_end, is_paid, paid_date, notes) VALUES
-- July 2024
(1, 1, 'EF-2024-07-001', '2024-07-05', '2024-07-20', 3250.45, 'electricity', '2024-06-01', '2024-06-30', 1, '2024-07-18', 'Factură electricitate iunie'),
(2, 2, 'DG-2024-07-001', '2024-07-03', '2024-07-18', 1845.30, 'gas', '2024-06-01', '2024-06-30', 1, '2024-07-15', 'Factură gaz iunie'),
(3, 3, 'CAB-2024-07-001', '2024-07-08', '2024-07-23', 892.15, 'water', '2024-06-01', '2024-06-30', 1, '2024-07-20', 'Factură apă iunie'),
(4, 4, 'BR-2024-07-001', '2024-07-10', '2024-07-25', 456.00, 'salubrity', '2024-06-01', '2024-06-30', 1, '2024-07-22', 'Factură salubritate iunie'),
-- August 2024
(5, 1, 'EF-2024-08-001', '2024-08-05', '2024-08-20', 3180.90, 'electricity', '2024-07-01', '2024-07-31', 1, '2024-08-17', 'Factură electricitate iulie'),
(6, 2, 'DG-2024-08-001', '2024-08-03', '2024-08-18', 1420.50, 'gas', '2024-07-01', '2024-07-31', 1, '2024-08-16', 'Factură gaz iulie - sezon cald'),
(7, 3, 'CAB-2024-08-001', '2024-08-08', '2024-08-23', 945.80, 'water', '2024-07-01', '2024-07-31', 1, '2024-08-21', 'Factură apă iulie'),
(8, 4, 'BR-2024-08-001', '2024-08-10', '2024-08-25', 456.00, 'salubrity', '2024-07-01', '2024-07-31', 1, '2024-08-23', 'Factură salubritate iulie'),
-- September 2024
(9, 1, 'EF-2024-09-001', '2024-09-05', '2024-09-20', 3420.15, 'electricity', '2024-08-01', '2024-08-31', 1, '2024-09-18', 'Factură electricitate august'),
(10, 2, 'DG-2024-09-001', '2024-09-03', '2024-09-18', 1580.75, 'gas', '2024-08-01', '2024-08-31', 1, '2024-09-16', 'Factură gaz august'),
(11, 3, 'CAB-2024-09-001', '2024-09-08', '2024-09-23', 1025.40, 'water', '2024-08-01', '2024-08-31', 1, '2024-09-20', 'Factură apă august'),
(12, 4, 'BR-2024-09-001', '2024-09-10', '2024-09-25', 456.00, 'salubrity', '2024-08-01', '2024-08-31', 1, '2024-09-22', 'Factură salubritate august'),
-- October 2024
(13, 1, 'EF-2024-10-001', '2024-10-05', '2024-10-20', 3650.30, 'electricity', '2024-09-01', '2024-09-30', 1, '2024-10-18', 'Factură electricitate septembrie'),
(14, 2, 'DG-2024-10-001', '2024-10-03', '2024-10-18', 2150.40, 'gas', '2024-09-01', '2024-09-30', 1, '2024-10-17', 'Factură gaz septembrie - început încălzire'),
(15, 3, 'CAB-2024-10-001', '2024-10-08', '2024-10-23', 978.60, 'water', '2024-09-01', '2024-09-30', 1, '2024-10-21', 'Factură apă septembrie'),
(16, 4, 'BR-2024-10-001', '2024-10-10', '2024-10-25', 486.00, 'salubrity', '2024-09-01', '2024-09-30', 1, '2024-10-24', 'Factură salubritate septembrie - tarif actualizat'),
-- November 2024
(17, 1, 'EF-2024-11-001', '2024-11-05', '2024-11-20', 3890.75, 'electricity', '2024-10-01', '2024-10-31', 1, '2024-11-18', 'Factură electricitate octombrie'),
(18, 2, 'DG-2024-11-001', '2024-11-03', '2024-11-18', 2890.60, 'gas', '2024-10-01', '2024-10-31', 1, '2024-11-16', 'Factură gaz octombrie - sezon rece'),
(19, 3, 'CAB-2024-11-001', '2024-11-08', '2024-11-23', 912.35, 'water', '2024-10-01', '2024-10-31', 1, '2024-11-20', 'Factură apă octombrie'),
(20, 4, 'BR-2024-11-001', '2024-11-10', '2024-11-25', 486.00, 'salubrity', '2024-10-01', '2024-10-31', 1, '2024-11-22', 'Factură salubritate octombrie'),
-- December 2024
(21, 1, 'EF-2024-12-001', '2024-12-05', '2024-12-20', 4125.50, 'electricity', '2024-11-01', '2024-11-30', 1, '2024-12-18', 'Factură electricitate noiembrie'),
(22, 2, 'DG-2024-12-001', '2024-12-03', '2024-12-18', 3450.80, 'gas', '2024-11-01', '2024-11-30', 0, NULL, 'Factură gaz noiembrie - vârf consum'),
(23, 3, 'CAB-2024-12-001', '2024-12-08', '2024-12-23', 875.90, 'water', '2024-11-01', '2024-11-30', 0, NULL, 'Factură apă noiembrie'),
(24, 4, 'BR-2024-12-001', '2024-12-10', '2024-12-25', 486.00, 'salubrity', '2024-11-01', '2024-11-30', 0, NULL, 'Factură salubritate noiembrie'),
(25, 5, 'DIGI-2024-12-001', '2024-12-01', '2024-12-15', 299.00, 'internet', '2024-12-01', '2024-12-31', 1, '2024-12-10', 'Internet clădire - decembrie');

-- ============================================================================
-- Meter Readings (Last 6 months)
-- ============================================================================
INSERT INTO meter_readings (meter_id, reading_date, reading_value, previous_reading_value, consumption, period_month, period_year) VALUES
-- General Meter readings
(1, '2024-07-31', 125450.00, 122100.00, 3350.00, 7, 2024),
(1, '2024-08-31', 128720.00, 125450.00, 3270.00, 8, 2024),
(1, '2024-09-30', 132250.00, 128720.00, 3530.00, 9, 2024),
(1, '2024-10-31', 136020.00, 132250.00, 3770.00, 10, 2024),
(1, '2024-11-30', 140050.00, 136020.00, 4030.00, 11, 2024),
(1, '2024-12-20', 143280.00, 140050.00, 3230.00, 12, 2024),

-- General - Start of month meter
(2, '2024-07-01', 122100.00, 118850.00, 3250.00, 7, 2024),
(2, '2024-08-01', 125450.00, 122100.00, 3350.00, 8, 2024),
(2, '2024-09-01', 128720.00, 125450.00, 3270.00, 9, 2024),
(2, '2024-10-01', 132250.00, 128720.00, 3530.00, 10, 2024),
(2, '2024-11-01', 136020.00, 132250.00, 3770.00, 11, 2024),
(2, '2024-12-01', 140050.00, 136020.00, 4030.00, 12, 2024),

-- Alpha Tech readings (15% share)
(3, '2024-07-31', 15820.00, 15318.00, 502.00, 7, 2024),
(3, '2024-08-31', 16310.00, 15820.00, 490.00, 8, 2024),
(3, '2024-09-30', 16840.00, 16310.00, 530.00, 9, 2024),
(3, '2024-10-31', 17405.00, 16840.00, 565.00, 10, 2024),
(3, '2024-11-30', 18010.00, 17405.00, 605.00, 11, 2024),
(3, '2024-12-20', 18495.00, 18010.00, 485.00, 12, 2024),

-- Beta Consulting readings (25% share - higher usage)
(4, '2024-07-31', 28450.00, 27612.00, 838.00, 7, 2024),
(4, '2024-08-31', 29268.00, 28450.00, 818.00, 8, 2024),
(4, '2024-09-30', 30150.00, 29268.00, 882.00, 9, 2024),
(4, '2024-10-31', 31093.00, 30150.00, 943.00, 10, 2024),
(4, '2024-11-30', 32100.00, 31093.00, 1007.00, 11, 2024),
(4, '2024-12-20', 32908.00, 32100.00, 808.00, 12, 2024),

-- Gamma Retail readings (20% share)
(5, '2024-07-31', 21350.00, 20680.00, 670.00, 7, 2024),
(5, '2024-08-31', 22004.00, 21350.00, 654.00, 8, 2024),
(5, '2024-09-30', 22710.00, 22004.00, 706.00, 9, 2024),
(5, '2024-10-31', 23464.00, 22710.00, 754.00, 10, 2024),
(5, '2024-11-30', 24270.00, 23464.00, 806.00, 11, 2024),
(5, '2024-12-20', 24916.00, 24270.00, 646.00, 12, 2024),

-- Delta Services readings (10% share)
(6, '2024-07-31', 9850.00, 9515.00, 335.00, 7, 2024),
(6, '2024-08-31', 10177.00, 9850.00, 327.00, 8, 2024),
(6, '2024-09-30', 10530.00, 10177.00, 353.00, 9, 2024),
(6, '2024-10-31', 10907.00, 10530.00, 377.00, 10, 2024),
(6, '2024-11-30', 11310.00, 10907.00, 403.00, 11, 2024),
(6, '2024-12-20', 11633.00, 11310.00, 323.00, 12, 2024),

-- PFA Ionescu readings (5% share - small office)
(7, '2024-07-31', 4150.00, 3982.00, 168.00, 7, 2024),
(7, '2024-08-31', 4314.00, 4150.00, 164.00, 8, 2024),
(7, '2024-09-30', 4490.00, 4314.00, 176.00, 9, 2024),
(7, '2024-10-31', 4679.00, 4490.00, 189.00, 10, 2024),
(7, '2024-11-30', 4880.00, 4679.00, 201.00, 11, 2024),
(7, '2024-12-20', 5042.00, 4880.00, 162.00, 12, 2024),

-- Epsilon Design readings (10% share)
(8, '2024-09-30', 1850.00, 1500.00, 350.00, 9, 2024),
(8, '2024-10-31', 2228.00, 1850.00, 378.00, 10, 2024),
(8, '2024-11-30', 2632.00, 2228.00, 404.00, 11, 2024),
(8, '2024-12-20', 2955.00, 2632.00, 323.00, 12, 2024),

-- Zeta Medical readings (15% share)
(9, '2024-07-31', 18420.00, 17917.00, 503.00, 7, 2024),
(9, '2024-08-31', 18911.00, 18420.00, 491.00, 8, 2024),
(9, '2024-09-30', 19441.00, 18911.00, 530.00, 9, 2024),
(9, '2024-10-31', 20007.00, 19441.00, 566.00, 10, 2024),
(9, '2024-11-30', 20612.00, 20007.00, 605.00, 11, 2024),
(9, '2024-12-20', 21097.00, 20612.00, 485.00, 12, 2024);

-- ============================================================================
-- Utility Calculations
-- ============================================================================
INSERT INTO utility_calculations (id, period_month, period_year, is_finalized, finalized_at, notes) VALUES
(1, 7, 2024, 1, '2024-08-05 10:30:00', 'Calcul utilități pentru iulie 2024'),
(2, 8, 2024, 1, '2024-09-05 11:15:00', 'Calcul utilități pentru august 2024'),
(3, 9, 2024, 1, '2024-10-05 09:45:00', 'Calcul utilități pentru septembrie 2024'),
(4, 10, 2024, 1, '2024-11-05 14:20:00', 'Calcul utilități pentru octombrie 2024'),
(5, 11, 2024, 1, '2024-12-05 10:00:00', 'Calcul utilități pentru noiembrie 2024'),
(6, 12, 2024, 0, NULL, 'Calcul utilități pentru decembrie 2024 - în curs');

-- ============================================================================
-- Utility Calculation Details (Partial - October 2024 example)
-- ============================================================================
INSERT INTO utility_calculation_details (calculation_id, tenant_id, utility_type, received_invoice_id, percentage, amount) VALUES
-- October calculation (ID=4)
(4, 1, 'electricity', 13, 15.00, 547.55),
(4, 1, 'gas', 14, 10.00, 215.04),
(4, 1, 'water', 15, 12.00, 117.43),
(4, 1, 'salubrity', 16, 12.50, 60.75),

(4, 2, 'electricity', 13, 25.00, 912.58),
(4, 2, 'gas', 14, 15.00, 322.56),
(4, 2, 'water', 15, 15.00, 146.79),
(4, 2, 'salubrity', 16, 12.50, 60.75),

(4, 3, 'electricity', 13, 20.00, 730.06),
(4, 3, 'gas', 14, 12.00, 258.05),
(4, 3, 'water', 15, 13.00, 127.22),
(4, 3, 'salubrity', 16, 12.50, 60.75),

(4, 4, 'electricity', 13, 10.00, 365.03),
(4, 4, 'gas', 14, 8.00, 172.03),
(4, 4, 'water', 15, 10.00, 97.86),
(4, 4, 'salubrity', 16, 12.50, 60.75),

(4, 5, 'electricity', 13, 5.00, 182.52),
(4, 5, 'gas', 14, 5.00, 107.52),
(4, 5, 'water', 15, 5.00, 48.93),
(4, 5, 'salubrity', 16, 12.50, 60.75),

(4, 6, 'electricity', 13, 10.00, 365.03),
(4, 6, 'gas', 14, 10.00, 215.04),
(4, 6, 'water', 15, 10.00, 97.86),
(4, 6, 'salubrity', 16, 12.50, 60.75),

(4, 7, 'electricity', 13, 15.00, 547.55),
(4, 7, 'gas', 14, 40.00, 860.16),
(4, 7, 'water', 15, 35.00, 342.51),
(4, 7, 'salubrity', 16, 25.00, 121.50);

-- ============================================================================
-- Invoice Templates
-- ============================================================================
INSERT INTO invoice_templates (id, name, html_template, is_default) VALUES
(1, 'Standard A4', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; font-size: 12px; margin: 20px; }
        .header { display: flex; justify-content: space-between; margin-bottom: 30px; }
        .company-info { max-width: 300px; }
        .invoice-title { font-size: 24px; font-weight: bold; color: #333; }
        .invoice-number { font-size: 14px; color: #666; margin-top: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f5f5f5; }
        .totals { text-align: right; margin-top: 20px; }
        .total-row { font-weight: bold; font-size: 14px; }
    </style>
</head>
<body>
    <div class="header">
        <div class="company-info">
            <strong>{{company_name}}</strong><br>
            CUI: {{company_cui}}<br>
            {{company_address}}<br>
            {{company_city}}, {{company_county}}
        </div>
        <div>
            <div class="invoice-title">FACTURA</div>
            <div class="invoice-number">{{invoice_number}}</div>
            <div>Data: {{invoice_date}}</div>
            <div>Scadență: {{due_date}}</div>
        </div>
    </div>
    <div class="client-info">
        <strong>Client:</strong><br>
        {{client_name}}<br>
        {{client_address}}<br>
        CUI/CNP: {{client_cui}}
    </div>
    <table>
        <thead>
            <tr>
                <th>Nr.</th>
                <th>Descriere</th>
                <th>Cantitate</th>
                <th>Preț unitar</th>
                <th>TVA</th>
                <th>Total</th>
            </tr>
        </thead>
        <tbody>
            {{#items}}
            <tr>
                <td>{{index}}</td>
                <td>{{description}}</td>
                <td>{{quantity}}</td>
                <td>{{unit_price}} RON</td>
                <td>{{vat_rate}}%</td>
                <td>{{total}} RON</td>
            </tr>
            {{/items}}
        </tbody>
    </table>
    <div class="totals">
        <div>Subtotal: {{subtotal}} RON</div>
        <div>TVA: {{vat_amount}} RON</div>
        <div class="total-row">TOTAL: {{total}} RON</div>
    </div>
</body>
</html>', 1),
(2, 'Minimalist', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Helvetica, sans-serif; font-size: 11px; margin: 30px; color: #333; }
        .header { border-bottom: 2px solid #000; padding-bottom: 20px; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px 5px; border-bottom: 1px solid #eee; }
        th { text-align: left; font-weight: normal; color: #888; }
        .total { font-size: 16px; font-weight: bold; margin-top: 30px; text-align: right; }
    </style>
</head>
<body>
    <div class="header">
        <h1>{{invoice_number}}</h1>
    </div>
    <!-- Template content -->
</body>
</html>', 0);

-- ============================================================================
-- Invoices (Rent + Utility invoices)
-- ============================================================================
INSERT INTO invoices (id, invoice_number, invoice_type, tenant_id, invoice_date, due_date, exchange_rate, exchange_rate_date, subtotal_eur, subtotal_ron, vat_amount, total_ron, is_paid, paid_date, template_id, calculation_id, client_name, client_address, client_cui) VALUES
-- Rent invoices - October 2024
(1, 'DMT-2024-0001', 'rent', 1, '2024-10-01', '2024-10-15', 4.9765, '2024-10-01', 850.00, 4230.03, 0.00, 4230.03, 1, '2024-10-12', 1, NULL, NULL, NULL, NULL),
(2, 'DMT-2024-0002', 'rent', 2, '2024-10-01', '2024-10-15', 4.9765, '2024-10-01', 1200.00, 5971.80, 0.00, 5971.80, 1, '2024-10-14', 1, NULL, NULL, NULL, NULL),
(3, 'DMT-2024-0003', 'rent', 3, '2024-10-01', '2024-10-15', 4.9765, '2024-10-01', 950.00, 4727.68, 0.00, 4727.68, 1, '2024-10-13', 1, NULL, NULL, NULL, NULL),
(4, 'DMT-2024-0004', 'rent', 4, '2024-10-01', '2024-10-15', 4.9765, '2024-10-01', 650.00, 3234.73, 0.00, 3234.73, 1, '2024-10-10', 1, NULL, NULL, NULL, NULL),
(5, 'DMT-2024-0005', 'rent', 5, '2024-10-01', '2024-10-15', 4.9765, '2024-10-01', 400.00, 1990.60, 0.00, 1990.60, 1, '2024-10-08', 1, NULL, NULL, NULL, NULL),
(6, 'DMT-2024-0006', 'rent', 6, '2024-10-01', '2024-10-15', 4.9765, '2024-10-01', 750.00, 3732.38, 0.00, 3732.38, 1, '2024-10-15', 1, NULL, NULL, NULL, NULL),
(7, 'DMT-2024-0007', 'rent', 7, '2024-10-01', '2024-10-15', 4.9765, '2024-10-01', 1500.00, 7464.75, 0.00, 7464.75, 1, '2024-10-11', 1, NULL, NULL, NULL, NULL),

-- Utility invoices - October 2024
(8, 'DMT-2024-0008', 'utility', 1, '2024-10-10', '2024-10-25', NULL, NULL, NULL, 940.77, 0.00, 940.77, 1, '2024-10-22', 1, 4, NULL, NULL, NULL),
(9, 'DMT-2024-0009', 'utility', 2, '2024-10-10', '2024-10-25', NULL, NULL, NULL, 1442.68, 0.00, 1442.68, 1, '2024-10-24', 1, 4, NULL, NULL, NULL),
(10, 'DMT-2024-0010', 'utility', 3, '2024-10-10', '2024-10-25', NULL, NULL, NULL, 1176.08, 0.00, 1176.08, 1, '2024-10-23', 1, 4, NULL, NULL, NULL),
(11, 'DMT-2024-0011', 'utility', 4, '2024-10-10', '2024-10-25', NULL, NULL, NULL, 695.67, 0.00, 695.67, 1, '2024-10-20', 1, 4, NULL, NULL, NULL),
(12, 'DMT-2024-0012', 'utility', 5, '2024-10-10', '2024-10-25', NULL, NULL, NULL, 399.72, 0.00, 399.72, 1, '2024-10-18', 1, 4, NULL, NULL, NULL),
(13, 'DMT-2024-0013', 'utility', 6, '2024-10-10', '2024-10-25', NULL, NULL, NULL, 738.68, 0.00, 738.68, 1, '2024-10-25', 1, 4, NULL, NULL, NULL),
(14, 'DMT-2024-0014', 'utility', 7, '2024-10-10', '2024-10-25', NULL, NULL, NULL, 1871.72, 0.00, 1871.72, 1, '2024-10-21', 1, 4, NULL, NULL, NULL),

-- Rent invoices - November 2024
(15, 'DMT-2024-0015', 'rent', 1, '2024-11-01', '2024-11-15', 4.9770, '2024-11-01', 850.00, 4230.45, 0.00, 4230.45, 1, '2024-11-14', 1, NULL, NULL, NULL, NULL),
(16, 'DMT-2024-0016', 'rent', 2, '2024-11-01', '2024-11-15', 4.9770, '2024-11-01', 1200.00, 5972.40, 0.00, 5972.40, 1, '2024-11-13', 1, NULL, NULL, NULL, NULL),
(17, 'DMT-2024-0017', 'rent', 3, '2024-11-01', '2024-11-15', 4.9770, '2024-11-01', 950.00, 4728.15, 0.00, 4728.15, 1, '2024-11-12', 1, NULL, NULL, NULL, NULL),
(18, 'DMT-2024-0018', 'rent', 4, '2024-11-01', '2024-11-15', 4.9770, '2024-11-01', 650.00, 3235.05, 0.00, 3235.05, 1, '2024-11-10', 1, NULL, NULL, NULL, NULL),
(19, 'DMT-2024-0019', 'rent', 5, '2024-11-01', '2024-11-15', 4.9770, '2024-11-01', 400.00, 1990.80, 0.00, 1990.80, 1, '2024-11-08', 1, NULL, NULL, NULL, NULL),
(20, 'DMT-2024-0020', 'rent', 6, '2024-11-01', '2024-11-15', 4.9770, '2024-11-01', 750.00, 3732.75, 0.00, 3732.75, 1, '2024-11-15', 1, NULL, NULL, NULL, NULL),
(21, 'DMT-2024-0021', 'rent', 7, '2024-11-01', '2024-11-15', 4.9770, '2024-11-01', 1500.00, 7465.50, 0.00, 7465.50, 1, '2024-11-11', 1, NULL, NULL, NULL, NULL),

-- Utility invoices - November 2024
(22, 'DMT-2024-0022', 'utility', 1, '2024-11-10', '2024-11-25', NULL, NULL, NULL, 1085.45, 0.00, 1085.45, 1, '2024-11-22', 1, 5, NULL, NULL, NULL),
(23, 'DMT-2024-0023', 'utility', 2, '2024-11-10', '2024-11-25', NULL, NULL, NULL, 1658.92, 0.00, 1658.92, 1, '2024-11-24', 1, 5, NULL, NULL, NULL),
(24, 'DMT-2024-0024', 'utility', 3, '2024-11-10', '2024-11-25', NULL, NULL, NULL, 1354.18, 0.00, 1354.18, 1, '2024-11-23', 1, 5, NULL, NULL, NULL),
(25, 'DMT-2024-0025', 'utility', 4, '2024-11-10', '2024-11-25', NULL, NULL, NULL, 802.56, 0.00, 802.56, 1, '2024-11-20', 1, 5, NULL, NULL, NULL),
(26, 'DMT-2024-0026', 'utility', 5, '2024-11-10', '2024-11-25', NULL, NULL, NULL, 462.15, 0.00, 462.15, 1, '2024-11-18', 1, 5, NULL, NULL, NULL),
(27, 'DMT-2024-0027', 'utility', 6, '2024-11-10', '2024-11-25', NULL, NULL, NULL, 852.34, 0.00, 852.34, 1, '2024-11-25', 1, 5, NULL, NULL, NULL),
(28, 'DMT-2024-0028', 'utility', 7, '2024-11-10', '2024-11-25', NULL, NULL, NULL, 2145.88, 0.00, 2145.88, 1, '2024-11-21', 1, 5, NULL, NULL, NULL),

-- Rent invoices - December 2024
(29, 'DMT-2024-0029', 'rent', 1, '2024-12-01', '2024-12-15', 4.9760, '2024-12-01', 850.00, 4229.60, 0.00, 4229.60, 1, '2024-12-12', 1, NULL, NULL, NULL, NULL),
(30, 'DMT-2024-0030', 'rent', 2, '2024-12-01', '2024-12-15', 4.9760, '2024-12-01', 1200.00, 5971.20, 0.00, 5971.20, 1, '2024-12-14', 1, NULL, NULL, NULL, NULL),
(31, 'DMT-2024-0031', 'rent', 3, '2024-12-01', '2024-12-15', 4.9760, '2024-12-01', 950.00, 4727.20, 0.00, 4727.20, 1, '2024-12-10', 1, NULL, NULL, NULL, NULL),
(32, 'DMT-2024-0032', 'rent', 4, '2024-12-01', '2024-12-15', 4.9760, '2024-12-01', 650.00, 3234.40, 0.00, 3234.40, 1, '2024-12-13', 1, NULL, NULL, NULL, NULL),
(33, 'DMT-2024-0033', 'rent', 5, '2024-12-01', '2024-12-15', 4.9760, '2024-12-01', 400.00, 1990.40, 0.00, 1990.40, 0, NULL, 1, NULL, NULL, NULL, NULL),
(34, 'DMT-2024-0034', 'rent', 6, '2024-12-01', '2024-12-15', 4.9760, '2024-12-01', 750.00, 3732.00, 0.00, 3732.00, 0, NULL, 1, NULL, NULL, NULL, NULL),
(35, 'DMT-2024-0035', 'rent', 7, '2024-12-01', '2024-12-15', 4.9760, '2024-12-01', 1500.00, 7464.00, 0.00, 7464.00, 1, '2024-12-11', 1, NULL, NULL, NULL, NULL),

-- Generic invoices
(36, 'DMT-2024-0036', 'generic', NULL, '2024-10-20', '2024-11-04', NULL, NULL, NULL, 2500.00, 475.00, 2975.00, 1, '2024-11-02', 1, NULL, 'SC CONSTRUCT PRO SRL', 'Str. Industriilor nr. 10, Brașov', 'RO12345678'),
(37, 'DMT-2024-0037', 'generic', NULL, '2024-11-15', '2024-11-30', NULL, NULL, NULL, 1850.00, 351.50, 2201.50, 1, '2024-11-28', 1, NULL, 'PFA Georgescu Andrei', 'Str. Mihai Viteazu nr. 45, Brașov', '1780512080025'),
(38, 'DMT-2024-0038', 'generic', NULL, '2024-12-10', '2024-12-25', NULL, NULL, NULL, 3200.00, 608.00, 3808.00, 0, NULL, 1, NULL, 'SC TECH SOLUTIONS SRL', 'Bd. 15 Noiembrie nr. 78, Brașov', 'RO98765432');

-- ============================================================================
-- Invoice Items
-- ============================================================================
INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, vat_rate, total, sort_order) VALUES
-- Rent invoice items
(1, 'Chirie spațiu comercial - Octombrie 2024', 1.00, 4230.03, 0.00, 4230.03, 1),
(2, 'Chirie spațiu comercial - Octombrie 2024', 1.00, 5971.80, 0.00, 5971.80, 1),
(3, 'Chirie spațiu comercial - Octombrie 2024', 1.00, 4727.68, 0.00, 4727.68, 1),
(4, 'Chirie spațiu comercial - Octombrie 2024', 1.00, 3234.73, 0.00, 3234.73, 1),
(5, 'Chirie birou - Octombrie 2024', 1.00, 1990.60, 0.00, 1990.60, 1),
(6, 'Chirie spațiu comercial - Octombrie 2024', 1.00, 3732.38, 0.00, 3732.38, 1),
(7, 'Chirie spațiu comercial - Octombrie 2024', 1.00, 7464.75, 0.00, 7464.75, 1),

-- Utility invoice items (example for tenant 1 - October)
(8, 'Electricitate - Octombrie 2024', 1.00, 547.55, 0.00, 547.55, 1),
(8, 'Gaz - Octombrie 2024', 1.00, 215.04, 0.00, 215.04, 2),
(8, 'Apă - Octombrie 2024', 1.00, 117.43, 0.00, 117.43, 3),
(8, 'Salubritate - Octombrie 2024', 1.00, 60.75, 0.00, 60.75, 4),

-- Generic invoice items
(36, 'Servicii reparații instalații sanitare', 1.00, 1500.00, 19.00, 1785.00, 1),
(36, 'Materiale instalații', 1.00, 1000.00, 19.00, 1190.00, 2),
(37, 'Servicii consultanță juridică', 5.00, 370.00, 19.00, 2201.50, 1),
(38, 'Servicii IT - mentenanță lunară', 1.00, 2000.00, 19.00, 2380.00, 1),
(38, 'Licențe software', 4.00, 300.00, 19.00, 1428.00, 2);

-- ============================================================================
-- Activity Logs
-- ============================================================================
INSERT INTO activity_logs (user_id, action_type, entity_type, entity_id, entity_name, description, metadata, ip_address, created_at) VALUES
(1, 'login', 'user', 1, 'demo', 'Utilizator autentificat în sistem', '{"browser": "Chrome 120"}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(1, 'create', 'invoice', 29, 'DMT-2024-0029', 'Factură de chirie creată pentru Alpha Tech', '{"type": "rent", "amount": 4229.60}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 4 DAY)),
(1, 'create', 'invoice', 30, 'DMT-2024-0030', 'Factură de chirie creată pentru Beta Consulting', '{"type": "rent", "amount": 5971.20}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 4 DAY)),
(1, 'payment', 'invoice', 29, 'DMT-2024-0029', 'Factură marcată ca plătită', '{"paid_date": "2024-12-12"}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(1, 'create', 'received_invoice', 21, 'EF-2024-12-001', 'Factură primită înregistrată de la Electrica', '{"amount": 4125.50}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(1, 'update', 'tenant', 3, 'Gamma Retail', 'Date chiriaș actualizate', '{"field": "email"}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(1, 'create', 'meter_reading', NULL, NULL, 'Citiri contoare electricitate înregistrate pentru decembrie', '{"meters_count": 9}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(1, 'payment', 'received_invoice', 21, 'EF-2024-12-001', 'Factură primită marcată ca plătită', '{"paid_date": "2024-12-18"}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(1, 'create', 'invoice', 38, 'DMT-2024-0038', 'Factură generică creată pentru Tech Solutions', '{"type": "generic", "amount": 3808.00}', '192.168.1.100', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(1, 'login', 'user', 1, 'demo', 'Utilizator autentificat în sistem', '{"browser": "Chrome 120"}', '192.168.1.100', NOW());

-- ============================================================================
-- Notifications
-- ============================================================================
INSERT INTO notifications (user_id, type, category, title, message, entity_type, entity_id, link, is_read, is_dismissed, created_at) VALUES
(NULL, 'warning', 'due_soon', 'Factură scadentă curând', 'Factura DG-2024-12-001 de la Distrigaz Sud Rețele SRL scade pe 2024-12-18', 'received_invoice', 22, '/received-invoices', 0, 0, DATE_SUB(NOW(), INTERVAL 2 DAY)),
(NULL, 'warning', 'due_soon', 'Factură scadentă curând', 'Factura CAB-2024-12-001 de la Compania Apa Brașov SA scade pe 2024-12-23', 'received_invoice', 23, '/received-invoices', 0, 0, DATE_SUB(NOW(), INTERVAL 1 DAY)),
(NULL, 'warning', 'unpaid_issued', 'Factură emisă neplătită', 'Factura DMT-2024-0033 către PFA Ionescu Maria nu a fost încă plătită', 'invoice', 33, '/invoices', 0, 0, NOW()),
(NULL, 'warning', 'unpaid_issued', 'Factură emisă neplătită', 'Factura DMT-2024-0034 către Epsilon Design Studio nu a fost încă plătită', 'invoice', 34, '/invoices', 0, 0, NOW()),
(NULL, 'info', 'system', 'Date demo resetate', 'Baza de date demo a fost resetată cu succes.', NULL, NULL, NULL, 0, 0, NOW());

-- ============================================================================
-- Google Drive Config (empty - not connected)
-- ============================================================================
INSERT INTO google_drive_config (id) VALUES (1);

-- ============================================================================
-- End of Demo Data
-- ============================================================================
