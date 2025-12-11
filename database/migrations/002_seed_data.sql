-- ============================================================================
-- Migration: 002_seed_data.sql
-- Description: Essential seed data for Property Management System
-- Date: 2025-12-09
-- ============================================================================

USE property_management;

-- ============================================================================
-- Seed Data: Default Admin User
-- ============================================================================
-- Password: changeme
-- BCrypt hash generated with cost factor 12
-- IMPORTANT: Change this password immediately after first login!

INSERT INTO users (username, email, password_hash)
VALUES (
    'admin',
    'admin@property.local',
    '$2b$12$LJlrd0zNaTuJ8mlkpjHese3YYYKO5Nq01mj4oG/bR/eC/qq/7iKVC'
)
ON DUPLICATE KEY UPDATE username=username;

-- ============================================================================
-- Seed Data: General Electricity Meter
-- ============================================================================
-- The General meter represents the main distribution meter
-- Difference calculation: General - Sum(all other meters)

INSERT INTO electricity_meters (name, location, tenant_id, is_general, is_active, notes)
VALUES (
    'General',
    'Main distribution board',
    NULL,
    TRUE,
    TRUE,
    'Main electricity meter - represents total property consumption'
)
ON DUPLICATE KEY UPDATE name=name;

-- ============================================================================
-- Seed Data: Default Invoice Template
-- ============================================================================
-- Standard Romanian invoice template with proper formatting
-- Template variables: {{company.*}}, {{tenant.*}}, {{invoice.*}}, {{items}}

INSERT INTO invoice_templates (name, html_template, is_default)
VALUES (
    'Standard Romanian Invoice',
    '<!DOCTYPE html>
<html lang="ro">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Factura {{invoice.invoice_number}}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: Arial, sans-serif;
            font-size: 11pt;
            line-height: 1.4;
            color: #333;
            padding: 20mm;
        }
        .header {
            margin-bottom: 30px;
            border-bottom: 2px solid #333;
            padding-bottom: 20px;
        }
        .company-info {
            margin-bottom: 15px;
        }
        .company-name {
            font-size: 18pt;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .invoice-title {
            text-align: center;
            font-size: 16pt;
            font-weight: bold;
            margin: 20px 0;
        }
        .info-section {
            display: table;
            width: 100%;
            margin-bottom: 20px;
        }
        .info-column {
            display: table-cell;
            width: 50%;
            vertical-align: top;
            padding-right: 10px;
        }
        .info-label {
            font-weight: bold;
            display: inline-block;
            width: 150px;
        }
        table.items {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        table.items th {
            background-color: #333;
            color: white;
            padding: 10px;
            text-align: left;
            font-weight: bold;
        }
        table.items td {
            padding: 8px 10px;
            border-bottom: 1px solid #ddd;
        }
        table.items tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .text-right {
            text-align: right;
        }
        .text-center {
            text-align: center;
        }
        .totals {
            margin-top: 20px;
            float: right;
            width: 300px;
        }
        .total-row {
            display: flex;
            justify-content: space-between;
            padding: 5px 0;
        }
        .total-row.grand-total {
            font-size: 14pt;
            font-weight: bold;
            border-top: 2px solid #333;
            margin-top: 10px;
            padding-top: 10px;
        }
        .footer {
            clear: both;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            font-size: 9pt;
        }
        .exchange-rate-info {
            margin: 15px 0;
            padding: 10px;
            background-color: #f0f0f0;
            border-left: 4px solid #333;
        }
    </style>
</head>
<body>
    <!-- Header Section -->
    <div class="header">
        <div class="company-info">
            <div class="company-name">{{company.name}}</div>
            <div>CUI/CIF: {{company.cui_cif}}</div>
            <div>J: {{company.j_number}}</div>
            <div>{{company.address}}, {{company.city}}, {{company.county}}, {{company.postal_code}}</div>
            <div>Telefon: {{company.phone}} | Email: {{company.email}}</div>
            <div>Banca: {{company.bank_name}} | IBAN: {{company.iban}}</div>
        </div>
    </div>

    <!-- Invoice Title -->
    <div class="invoice-title">
        FACTURA nr. {{invoice.invoice_number}}
    </div>

    <!-- Invoice Information -->
    <div class="info-section">
        <div class="info-column">
            <div><span class="info-label">Data facturii:</span> {{invoice.invoice_date}}</div>
            <div><span class="info-label">Data scadenta:</span> {{invoice.due_date}}</div>
            <div><span class="info-label">Tip factura:</span> {{invoice.invoice_type}}</div>
        </div>
        <div class="info-column">
            <strong>Client:</strong><br>
            {{tenant.name}}<br>
            CUI/CNP: {{tenant.cui_cnp}}<br>
            {{tenant.address}}<br>
            {{tenant.city}}, {{tenant.county}}<br>
            Telefon: {{tenant.phone}}<br>
            Email: {{tenant.email}}
        </div>
    </div>

    <!-- Exchange Rate Information (for rent invoices) -->
    {{#if invoice.exchange_rate}}
    <div class="exchange-rate-info">
        <strong>Curs valutar BNR:</strong> 1 EUR = {{invoice.exchange_rate}} RON (Data: {{invoice.exchange_rate_date}})<br>
        <strong>Total EUR:</strong> {{invoice.subtotal_eur}} EUR
    </div>
    {{/if}}

    <!-- Invoice Items Table -->
    <table class="items">
        <thead>
            <tr>
                <th style="width: 10%;">Nr.</th>
                <th style="width: 40%;">Descriere</th>
                <th style="width: 10%;" class="text-center">Cant.</th>
                <th style="width: 15%;" class="text-right">Pret unitar</th>
                <th style="width: 10%;" class="text-center">TVA %</th>
                <th style="width: 15%;" class="text-right">Total</th>
            </tr>
        </thead>
        <tbody>
            {{#each items}}
            <tr>
                <td class="text-center">{{@index_plus_1}}</td>
                <td>{{description}}</td>
                <td class="text-center">{{quantity}}</td>
                <td class="text-right">{{unit_price}} RON</td>
                <td class="text-center">{{vat_rate}}%</td>
                <td class="text-right">{{total}} RON</td>
            </tr>
            {{/each}}
        </tbody>
    </table>

    <!-- Totals Section -->
    <div class="totals">
        <div class="total-row">
            <span>Subtotal:</span>
            <span>{{invoice.subtotal_ron}} RON</span>
        </div>
        <div class="total-row">
            <span>TVA:</span>
            <span>{{invoice.vat_amount}} RON</span>
        </div>
        <div class="total-row grand-total">
            <span>TOTAL DE PLATA:</span>
            <span>{{invoice.total_ron}} RON</span>
        </div>
    </div>

    <!-- Footer Section -->
    <div class="footer">
        <div><strong>Informatii de plata:</strong></div>
        <div>Banca: {{company.bank_name}}</div>
        <div>IBAN: {{company.iban}}</div>
        <div>Beneficiar: {{company.name}}</div>
        <div style="margin-top: 10px;">
            <strong>Nota:</strong> Plata se va efectua pana la data scadenta mentionata.
        </div>
        {{#if invoice.notes}}
        <div style="margin-top: 10px;">
            <strong>Observatii:</strong> {{invoice.notes}}
        </div>
        {{/if}}
        <div style="margin-top: 20px; text-align: center; font-size: 8pt; color: #666;">
            Factura generata automat | {{company.name}} | {{invoice.invoice_date}}
        </div>
    </div>
</body>
</html>',
    TRUE
)
ON DUPLICATE KEY UPDATE name=name;

-- ============================================================================
-- Seed Data Complete
-- ============================================================================
-- Next steps:
-- 1. Login with username: admin, password: changeme
-- 2. Change the admin password immediately
-- 3. Add company information
-- 4. Add tenants and configure utility percentages
-- ============================================================================
