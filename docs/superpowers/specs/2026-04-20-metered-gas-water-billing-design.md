# Metered Gas & Water Billing for Per-Tenant Control

**Date:** 2026-04-20
**Status:** Approved design, ready for implementation plan

## Problem

The current utility billing model uses a **fixed percentage per (tenant, utility)** stored in `tenant_utility_percentages`. A new tenant requires consumption-based billing for gas and water (they have their own meters), while keeping fixed-percentage billing for rain water (part of the water invoice) and for other utilities (salubrity, internet, etc.). Electricity is already meter-based and is out of scope.

## Goals

- Support per-tenant, per-utility opt-in to meter-based calculation for gas and water.
- Preserve the existing fixed-percentage flow for all other tenants and utilities — no regressions, no data migration for existing tenants.
- Make all inputs used for meter-based calculations **auditable**: readings, provider invoice totals, and cost splits are persisted in their own tables.
- Show a detailed calculation breakdown on the generated utility invoice PDF only for metered utilities.

## Non-Goals

- Generalizing `electricity_meters` into a unified `utility_meters` table. Kept separate to avoid disrupting the working electricity flow.
- Supporting metered billing for utilities other than gas and water in this iteration (schema leaves room to extend).
- Changing the tenant-level contract or rent flow.

## Design

### 1. Schema changes

**New column on `tenant_utility_percentages`:**

```sql
ALTER TABLE tenant_utility_percentages
  ADD COLUMN uses_meter BOOLEAN NOT NULL DEFAULT FALSE
  COMMENT 'When TRUE, tenant share for this utility is computed from meter readings instead of fixed percentage';
```

Semantics:
- `uses_meter = FALSE` → existing behavior. `percentage` is the fixed share of the provider invoice.
- `uses_meter = TRUE` and `utility_type = 'gas'` → `percentage` is ignored. Share computed from `gas_readings` and `metered_calculation_inputs`.
- `uses_meter = TRUE` and `utility_type = 'water'` → `percentage` is reinterpreted as the **rain-water fixed percentage**. Consumption share computed from `water_readings` and `metered_calculation_inputs`.
- `uses_meter = TRUE` for any other utility type → reject at API layer for now (only gas and water supported).

**New table: `gas_readings`**

```sql
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
```

**New table: `water_readings`**

Identical shape to `gas_readings` (`reading_value` stores m³).

**New table: `metered_calculation_inputs`**

```sql
CREATE TABLE metered_calculation_inputs (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    calculation_id INT UNSIGNED NOT NULL,
    received_invoice_id INT UNSIGNED NOT NULL,
    utility_type ENUM('gas', 'water') NOT NULL,
    total_units DECIMAL(12,2) NOT NULL COMMENT 'Total m³ on provider invoice (gas: total consumption; water: total consumption m³)',
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
```

Validation rules:
- For `utility_type = 'gas'`: `consumption_amount` and `rain_amount` must be NULL; the gas invoice amount comes from `received_invoices.amount`.
- For `utility_type = 'water'`: `consumption_amount` and `rain_amount` must both be non-null, and `consumption_amount + rain_amount` should equal `received_invoices.amount` (warning, not hard error, to tolerate rounding).

### 2. Calculation engine

When finalizing a `utility_calculation` for a period, for each `(tenant, utility)` pair:

1. Look up the `tenant_utility_percentages` row. If `uses_meter = FALSE`, use existing fixed-% path.
2. If `uses_meter = TRUE`:
   - **Gas:**
     - Fetch tenant's `gas_readings` for the period; compute `tenant_m³ = current - previous`.
     - Fetch `metered_calculation_inputs` for `(calculation_id, 'gas')` to get `total_units`.
     - `effective_percentage = tenant_m³ / total_units * 100`.
     - `amount = effective_percentage / 100 * received_invoice.amount`.
   - **Water:**
     - Fetch tenant's `water_readings`; compute `tenant_m³`.
     - Fetch `metered_calculation_inputs` for `(calculation_id, 'water')` → `total_units`, `consumption_amount`, `rain_amount`.
     - `consumption_share = (tenant_m³ / total_units) * consumption_amount`.
     - `rain_share = (rain_percentage / 100) * rain_amount` where `rain_percentage` is `tenant_utility_percentages.percentage`.
     - `amount = consumption_share + rain_share`.
     - `effective_percentage = amount / received_invoice.amount * 100` (for reporting / PDF display).
3. Persist into `utility_calculation_details` as today (`percentage` = effective %, `amount` = tenant share).

Missing-data errors (no reading, no `metered_calculation_inputs` row) must block finalization with a clear error message.

### 3. Backend (Perl / Dancer2)

- DBIx::Class result classes for `GasReading`, `WaterReading`, `MeteredCalculationInput`.
- REST endpoints:
  - `GET/POST/PUT/DELETE /api/gas-readings` (filterable by tenant and period).
  - `GET/POST/PUT/DELETE /api/water-readings`.
  - `GET/POST/PUT /api/utility-calculations/:id/metered-inputs` (list / create / update inputs per calculation).
- Calculation service extended with the branching logic above.
- Input validation: reject `uses_meter=TRUE` for utilities other than gas/water.

### 4. Frontend (React / Ant Design)

- **Tenant edit page → Utility percentages section:** for each utility row, add a "Uses meter" switch (shown only for gas and water). When enabled for water, relabel the percentage field to "Rain water %".
- **New pages:** Gas Readings and Water Readings — modeled after the existing Electricity Meter Readings page; filter by tenant and period; standard CRUD.
- **Utility Calculation page:** when any tenant in the period has `uses_meter=TRUE` for gas or water, show an additional input block per metered utility:
  - Gas: "Total m³ (din factura furnizor)".
  - Water: "Total m³", "Cost consum (RON)", "Cost apă pluvială (RON)".
  These are persisted to `metered_calculation_inputs`. Calculation cannot be finalized until these inputs are present and all relevant tenant readings exist.

### 5. Invoice PDF — detailed breakdown

The existing invoice table (page 1) is unchanged. Below it, add a conditional **"Detalii calcul contori"** section. Rendered only when the invoice includes at least one utility line item where the tenant has `uses_meter=TRUE` for that utility.

Use CSS `page-break-before: always` so the breakdown starts on page 2 when present; invoices without metered lines remain single-page.

Per metered utility, show:

- **Gas:** previous index, current index, tenant m³, total invoice m³, ratio %, invoice amount, tenant share.
- **Water:** previous index, current index, tenant m³, total invoice m³, consumption cost, tenant consumption share, rain-water cost, rain %, tenant rain share, tenant total, effective % of invoice.

Data fetched by the PDF renderer via a join across `invoices → utility_calculation_details → utility_calculations → metered_calculation_inputs` plus the relevant `(gas|water)_readings` rows for the tenant/period.

The default invoice template HTML is updated to include the conditional block; existing custom templates are left alone (users who cloned the default can adopt the new block manually or by re-cloning).

## Data flow summary (new tenant, monthly cycle)

1. Admin records the provider's gas invoice in `received_invoices` (total amount, period) — unchanged.
2. Admin records the provider's water invoice in `received_invoices` — unchanged.
3. Admin enters the tenant's gas and water meter readings for the period via the new reading pages.
4. Admin opens the period's utility calculation. For gas: enters total m³. For water: enters total m³, consumption cost, rain cost. These land in `metered_calculation_inputs`.
5. Admin finalizes the calculation. Engine computes shares per the rules above and writes `utility_calculation_details`.
6. Invoice is generated. PDF shows the existing line items on page 1 and the detailed breakdown on page 2 for the metered utilities.

## Risks and mitigations

- **Finalization blocked by missing inputs:** Clear validation messages listing which readings / inputs are missing.
- **Rounding drift between `consumption + rain` and provider invoice total:** Surface a warning on the calculation screen but allow finalization.
- **Custom invoice templates will not auto-get the breakdown:** Documented limitation; users update their templates manually.
- **Changing `uses_meter` mid-period:** Allowed for future periods only; already-finalized calculations are immutable (existing behavior).

## Out of scope / future work

- Unifying electricity, gas, water meters into a single abstraction.
- Metered billing for salubrity / internet / other.
- Automatic import of provider invoice totals from PDF/OCR.
