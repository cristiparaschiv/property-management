# Metered Gas & Water Billing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-tenant meter-based billing for gas and water (with a rain-water fixed-% add-on for water), keeping the existing fixed-percentage flow intact for every other tenant and utility. Render a detailed calculation breakdown on the generated utility invoice PDF for metered tenants.

**Architecture:** Three new tables (`gas_readings`, `water_readings`, `metered_calculation_inputs`) and one new column (`tenant_utility_percentages.uses_meter`). Backend (Dancer2) gets new Schema::Result classes, REST routes that mirror `MeterReadings.pm`, and a branch in `UtilityCalculator` that dispatches on the flag. Frontend adds a toggle in the tenant edit dialog, two new reading pages modeled on `MeterReadings.jsx`, and a metered-inputs block in `UtilityCalculations.jsx`. The default invoice template HTML is extended with a conditional "Detalii calcul contori" section rendered from data already computed at finalization time.

**Tech Stack:** Perl 5 / Dancer2 / DBIx::Class / MariaDB backend. React 18 / Vite / Ant Design / Axios frontend. `wkhtmltopdf` for PDFs. `prove` / Test::More for Perl tests.

**Spec:** `docs/superpowers/specs/2026-04-20-metered-gas-water-billing-design.md`

---

## File Structure

**New files (backend):**
- `database/migrations/003_metered_gas_water_billing.sql` — all schema changes in one migration.
- `backend/lib/PropertyManager/Schema/Result/GasReading.pm`
- `backend/lib/PropertyManager/Schema/Result/WaterReading.pm`
- `backend/lib/PropertyManager/Schema/Result/MeteredCalculationInput.pm`
- `backend/lib/PropertyManager/Routes/GasReadings.pm`
- `backend/lib/PropertyManager/Routes/WaterReadings.pm`
- `backend/lib/PropertyManager/Routes/MeteredCalculationInputs.pm`
- `backend/t/unit/07_metered_utility_calculator.t`

**Modified files (backend):**
- `database/schema.sql` — append new tables and column (so fresh installs match).
- `backend/lib/PropertyManager/Schema/Result/TenantUtilityPercentage.pm` — add `uses_meter` column.
- `backend/lib/PropertyManager/Schema/Result/Tenant.pm` — `has_many` relations for new tables.
- `backend/lib/PropertyManager/Schema/Result/UtilityCalculation.pm` — `has_many metered_inputs`.
- `backend/lib/PropertyManager/Schema/Result/ReceivedInvoice.pm` — `has_many metered_inputs`.
- `backend/lib/PropertyManager/App.pm` — register the 3 new route modules.
- `backend/lib/PropertyManager/Services/UtilityCalculator.pm` — branch on `uses_meter` for gas/water.
- `backend/lib/PropertyManager/Services/InvoiceGenerator.pm` — pass breakdown data to templates.
- `backend/templates/` default invoice template(s) — add conditional "Detalii calcul contori" section.

**New files (frontend):**
- `frontend/src/services/gasReadingsService.js`
- `frontend/src/services/waterReadingsService.js`
- `frontend/src/services/meteredInputsService.js`
- `frontend/src/pages/GasReadings.jsx`
- `frontend/src/pages/WaterReadings.jsx`

**Modified files (frontend):**
- `frontend/src/App.jsx` — routes for the two new pages.
- `frontend/src/layouts/` — nav menu entry for Gas / Water readings (same section as Meter Readings).
- `frontend/src/pages/Tenants.jsx` — `uses_meter` switch in the utility-percentages sub-form; rain-water label tweak.
- `frontend/src/pages/UtilityCalculations.jsx` — metered-inputs block on the calculation/finalization screen.
- `frontend/src/services/tenantsService.js` — pass `uses_meter` through save payloads if not already generic.

Each file has a single responsibility: Result classes describe tables, Routes handle HTTP, Services do business logic, React pages render one screen each.

---

## Task 1: Database migration and schema.sql sync

**Files:**
- Create: `database/migrations/003_metered_gas_water_billing.sql`
- Modify: `database/schema.sql`

- [ ] **Step 1: Write the migration file**

Create `database/migrations/003_metered_gas_water_billing.sql` with:

```sql
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
```

- [ ] **Step 2: Append the same statements to `database/schema.sql`**

Add the three `CREATE TABLE` statements (without the `USE` line) to `database/schema.sql` just before the `-- End of Schema` marker. Add the `ALTER TABLE tenant_utility_percentages` change **inline** on the existing `CREATE TABLE tenant_utility_percentages` block instead — add a new column line:

```sql
    uses_meter BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'When TRUE, use meter readings instead of fixed percentage',
```

Insert it right after the `percentage` column.

- [ ] **Step 3: Apply migration to local dev database**

Run from the repo root:

```bash
docker-compose exec -T db mysql -uroot -p"${DB_ROOT_PASSWORD:-rootpassword}" property_management < database/migrations/003_metered_gas_water_billing.sql
```

Expected: no errors. Then verify:

```bash
docker-compose exec -T db mysql -uroot -p"${DB_ROOT_PASSWORD:-rootpassword}" -e "USE property_management; SHOW TABLES LIKE '%reading%'; SHOW TABLES LIKE '%metered%'; SHOW COLUMNS FROM tenant_utility_percentages LIKE 'uses_meter';"
```

Expected: `gas_readings`, `water_readings`, `meter_readings` listed; `metered_calculation_inputs` listed; `uses_meter` column present with type `tinyint(1)`.

- [ ] **Step 4: Commit**

```bash
git add database/migrations/003_metered_gas_water_billing.sql database/schema.sql
git commit -m "db: add metered gas/water tables and uses_meter flag"
```

---

## Task 2: DBIx::Class result class — `GasReading`

**Files:**
- Create: `backend/lib/PropertyManager/Schema/Result/GasReading.pm`

- [ ] **Step 1: Create the result class**

```perl
package PropertyManager::Schema::Result::GasReading;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('gas_readings');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    tenant_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    reading_date => { data_type => 'date', is_nullable => 0 },
    reading_value => { data_type => 'decimal', size => [12, 2], is_nullable => 0 },
    previous_reading_value => { data_type => 'decimal', size => [12, 2], is_nullable => 1 },
    consumption => { data_type => 'decimal', size => [12, 2], is_nullable => 1 },
    period_month => { data_type => 'tinyint', is_nullable => 0 },
    period_year  => { data_type => 'smallint', is_nullable => 0 },
    notes => { data_type => 'text', is_nullable => 1 },
    created_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP',
    },
    updated_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(gas_tenant_period_unique => ['tenant_id', 'period_month', 'period_year']);

__PACKAGE__->belongs_to(
    tenant => 'PropertyManager::Schema::Result::Tenant',
    'tenant_id'
);

1;
```

- [ ] **Step 2: Smoke-test schema load**

```bash
cd backend && perl -I lib -MPropertyManager::Schema -e 'PropertyManager::Schema->load_namespaces; print "ok\n"'
```

Expected: `ok`. Any `Can't locate` / `compilation error` means fix and re-run.

- [ ] **Step 3: Commit**

```bash
git add backend/lib/PropertyManager/Schema/Result/GasReading.pm
git commit -m "schema: add GasReading result class"
```

---

## Task 3: DBIx::Class result class — `WaterReading`

**Files:**
- Create: `backend/lib/PropertyManager/Schema/Result/WaterReading.pm`

- [ ] **Step 1: Create the result class**

Identical to Task 2's `GasReading.pm` with these substitutions:
- `package PropertyManager::Schema::Result::WaterReading;`
- `__PACKAGE__->table('water_readings');`
- `__PACKAGE__->add_unique_constraint(water_tenant_period_unique => ['tenant_id', 'period_month', 'period_year']);`

All other fields, relationships, and defaults are identical.

- [ ] **Step 2: Smoke-test schema load**

```bash
cd backend && perl -I lib -MPropertyManager::Schema -e 'PropertyManager::Schema->load_namespaces; print "ok\n"'
```

Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add backend/lib/PropertyManager/Schema/Result/WaterReading.pm
git commit -m "schema: add WaterReading result class"
```

---

## Task 4: DBIx::Class result class — `MeteredCalculationInput`

**Files:**
- Create: `backend/lib/PropertyManager/Schema/Result/MeteredCalculationInput.pm`

- [ ] **Step 1: Create the result class**

```perl
package PropertyManager::Schema::Result::MeteredCalculationInput;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('metered_calculation_inputs');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    calculation_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    received_invoice_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    utility_type => {
        data_type => 'enum',
        extra => { list => ['gas', 'water'] },
        is_nullable => 0,
    },
    total_units => { data_type => 'decimal', size => [12, 2], is_nullable => 0 },
    consumption_amount => { data_type => 'decimal', size => [10, 2], is_nullable => 1 },
    rain_amount => { data_type => 'decimal', size => [10, 2], is_nullable => 1 },
    notes => { data_type => 'text', is_nullable => 1 },
    created_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP',
    },
    updated_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(calc_utility_unique => ['calculation_id', 'utility_type']);

__PACKAGE__->belongs_to(
    calculation => 'PropertyManager::Schema::Result::UtilityCalculation',
    'calculation_id'
);

__PACKAGE__->belongs_to(
    received_invoice => 'PropertyManager::Schema::Result::ReceivedInvoice',
    'received_invoice_id'
);

1;
```

- [ ] **Step 2: Smoke-test schema load**

```bash
cd backend && perl -I lib -MPropertyManager::Schema -e 'PropertyManager::Schema->load_namespaces; print "ok\n"'
```

Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add backend/lib/PropertyManager/Schema/Result/MeteredCalculationInput.pm
git commit -m "schema: add MeteredCalculationInput result class"
```

---

## Task 5: Wire up relations and `uses_meter` column

**Files:**
- Modify: `backend/lib/PropertyManager/Schema/Result/TenantUtilityPercentage.pm`
- Modify: `backend/lib/PropertyManager/Schema/Result/Tenant.pm`
- Modify: `backend/lib/PropertyManager/Schema/Result/UtilityCalculation.pm`
- Modify: `backend/lib/PropertyManager/Schema/Result/ReceivedInvoice.pm`

- [ ] **Step 1: Add `uses_meter` column to `TenantUtilityPercentage`**

In `TenantUtilityPercentage.pm`, inside `add_columns`, after the existing `percentage` entry, insert:

```perl
    uses_meter => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
```

- [ ] **Step 2: Add has_many relations on `Tenant.pm`**

Open `backend/lib/PropertyManager/Schema/Result/Tenant.pm`, locate the existing relationships block, and add:

```perl
__PACKAGE__->has_many(
    gas_readings => 'PropertyManager::Schema::Result::GasReading',
    'tenant_id'
);

__PACKAGE__->has_many(
    water_readings => 'PropertyManager::Schema::Result::WaterReading',
    'tenant_id'
);
```

- [ ] **Step 3: Add has_many on `UtilityCalculation.pm`**

```perl
__PACKAGE__->has_many(
    metered_inputs => 'PropertyManager::Schema::Result::MeteredCalculationInput',
    'calculation_id'
);
```

- [ ] **Step 4: Add has_many on `ReceivedInvoice.pm`**

```perl
__PACKAGE__->has_many(
    metered_inputs => 'PropertyManager::Schema::Result::MeteredCalculationInput',
    'received_invoice_id'
);
```

- [ ] **Step 5: Smoke-test**

```bash
cd backend && perl -I lib -MPropertyManager::Schema -e '
    my $s = PropertyManager::Schema->load_namespaces;
    print join(",", sort PropertyManager::Schema->sources), "\n";
'
```

Expected output includes `GasReading,MeteredCalculationInput,WaterReading` among others.

- [ ] **Step 6: Commit**

```bash
git add backend/lib/PropertyManager/Schema/Result/
git commit -m "schema: wire relations and uses_meter flag"
```

---

## Task 6: REST routes — `GasReadings`

**Files:**
- Create: `backend/lib/PropertyManager/Routes/GasReadings.pm`
- Modify: `backend/lib/PropertyManager/App.pm`

- [ ] **Step 1: Create `GasReadings.pm` modeled on `MeterReadings.pm`**

Full file:

```perl
package PropertyManager::Routes::GasReadings;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);
use Try::Tiny;

prefix '/api/gas-readings';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    $search->{tenant_id} = query_parameters->get('tenant_id') if query_parameters->get('tenant_id');
    $search->{period_year} = query_parameters->get('year') if query_parameters->get('year');
    $search->{period_month} = query_parameters->get('month') if query_parameters->get('month');

    my @rows = schema->resultset('GasReading')->search($search, {
        order_by => [{ -desc => 'period_year' }, { -desc => 'period_month' }, 'tenant_id'],
        prefetch => 'tenant',
    })->all;

    my @data = map {
        my %r = $_->get_columns;
        $r{tenant_name} = $_->tenant ? $_->tenant->name : 'N/A';
        \%r;
    } @rows;

    return { success => 1, data => \@data };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $row = schema->resultset('GasReading')->find(route_parameters->get('id'));
    unless ($row) { status 404; return { success => 0, error => 'Reading not found' }; }
    return { success => 1, data => { reading => { $row->get_columns } } };
};

post '' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $d = request->data;
    for my $f (qw(tenant_id reading_date reading_value period_month period_year)) {
        unless (defined $d->{$f}) { status 400; return { success => 0, error => "$f is required" }; }
    }
    if ($d->{reading_value} < 0) {
        status 400; return { success => 0, error => 'reading_value must be non-negative' };
    }

    my $created;
    try {
        # compute previous + consumption from last reading
        my $prev = schema->resultset('GasReading')->search(
            { tenant_id => $d->{tenant_id} },
            { order_by => [{ -desc => 'period_year' }, { -desc => 'period_month' }], rows => 1 }
        )->first;

        my $prev_value = $prev ? $prev->reading_value : undef;
        my $consumption = defined $prev_value ? ($d->{reading_value} - $prev_value) : undef;

        $created = schema->resultset('GasReading')->create({
            tenant_id => $d->{tenant_id},
            reading_date => $d->{reading_date},
            reading_value => $d->{reading_value},
            previous_reading_value => $prev_value,
            consumption => $consumption,
            period_month => $d->{period_month},
            period_year  => $d->{period_year},
            notes => $d->{notes},
        });
    } catch {
        status 500; return { success => 0, error => "Create failed: $_" };
    };

    return { success => 1, data => { reading => { $created->get_columns } } };
};

put '/:id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $row = schema->resultset('GasReading')->find(route_parameters->get('id'));
    unless ($row) { status 404; return { success => 0, error => 'Reading not found' }; }

    my $d = request->data;
    try {
        $row->update({
            map { $_ => $d->{$_} } grep { exists $d->{$_} }
            qw(reading_date reading_value period_month period_year notes)
        });
        if (exists $d->{reading_value} && defined $row->previous_reading_value) {
            $row->update({ consumption => $row->reading_value - $row->previous_reading_value });
        }
    } catch {
        status 500; return { success => 0, error => "Update failed: $_" };
    };

    return { success => 1, data => { reading => { $row->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $row = schema->resultset('GasReading')->find(route_parameters->get('id'));
    unless ($row) { status 404; return { success => 0, error => 'Reading not found' }; }
    $row->delete;
    return { success => 1 };
};

1;
```

- [ ] **Step 2: Register in `App.pm`**

In `backend/lib/PropertyManager/App.pm` after the existing `use PropertyManager::Routes::MeterReadings;` line, add:

```perl
use PropertyManager::Routes::GasReadings;
```

- [ ] **Step 3: Syntax check**

```bash
cd backend && perl -I lib -c lib/PropertyManager/Routes/GasReadings.pm
```

Expected: `lib/PropertyManager/Routes/GasReadings.pm syntax OK`.

- [ ] **Step 4: Restart backend and smoke-test**

```bash
docker-compose restart backend
sleep 2
curl -s -X GET http://localhost/api/gas-readings -H 'Cookie: ...'  # expected 401 without auth
```

Expected: HTTP 401 (route reachable). A 404 would mean the route wasn't registered.

- [ ] **Step 5: Commit**

```bash
git add backend/lib/PropertyManager/Routes/GasReadings.pm backend/lib/PropertyManager/App.pm
git commit -m "api: CRUD routes for gas readings"
```

---

## Task 7: REST routes — `WaterReadings`

**Files:**
- Create: `backend/lib/PropertyManager/Routes/WaterReadings.pm`
- Modify: `backend/lib/PropertyManager/App.pm`

- [ ] **Step 1: Create `WaterReadings.pm`**

Identical to Task 6's file with these substitutions:
- Package name: `PropertyManager::Routes::WaterReadings`
- Prefix: `prefix '/api/water-readings';`
- Resultset name: `'WaterReading'` (replace all occurrences of `'GasReading'`)

All other logic identical.

- [ ] **Step 2: Register in `App.pm`**

Add line: `use PropertyManager::Routes::WaterReadings;`

- [ ] **Step 3: Syntax check and restart**

```bash
cd backend && perl -I lib -c lib/PropertyManager/Routes/WaterReadings.pm && docker-compose restart backend
```

- [ ] **Step 4: Commit**

```bash
git add backend/lib/PropertyManager/Routes/WaterReadings.pm backend/lib/PropertyManager/App.pm
git commit -m "api: CRUD routes for water readings"
```

---

## Task 8: REST routes — `MeteredCalculationInputs`

**Files:**
- Create: `backend/lib/PropertyManager/Routes/MeteredCalculationInputs.pm`
- Modify: `backend/lib/PropertyManager/App.pm`

- [ ] **Step 1: Create the route module**

```perl
package PropertyManager::Routes::MeteredCalculationInputs;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);
use Try::Tiny;

prefix '/api/metered-inputs';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    $search->{calculation_id} = query_parameters->get('calculation_id')
        if query_parameters->get('calculation_id');
    $search->{utility_type} = query_parameters->get('utility_type')
        if query_parameters->get('utility_type');

    my @rows = schema->resultset('MeteredCalculationInput')->search($search)->all;
    return { success => 1, data => [ map { +{ $_->get_columns } } @rows ] };
};

post '' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $d = request->data;
    for my $f (qw(calculation_id received_invoice_id utility_type total_units)) {
        unless (defined $d->{$f}) { status 400; return { success => 0, error => "$f is required" }; }
    }

    unless ($d->{utility_type} eq 'gas' or $d->{utility_type} eq 'water') {
        status 400;
        return { success => 0, error => "utility_type must be 'gas' or 'water'" };
    }

    if ($d->{utility_type} eq 'water') {
        unless (defined $d->{consumption_amount} && defined $d->{rain_amount}) {
            status 400;
            return { success => 0, error => "consumption_amount and rain_amount are required for water" };
        }
    }

    my $row;
    try {
        $row = schema->resultset('MeteredCalculationInput')->update_or_create(
            {
                calculation_id => $d->{calculation_id},
                utility_type   => $d->{utility_type},
                received_invoice_id => $d->{received_invoice_id},
                total_units    => $d->{total_units},
                consumption_amount => $d->{consumption_amount},
                rain_amount    => $d->{rain_amount},
                notes          => $d->{notes},
            },
            { key => 'calc_utility_unique' }
        );
    } catch {
        status 500; return { success => 0, error => "Save failed: $_" };
    };

    return { success => 1, data => { input => { $row->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $row = schema->resultset('MeteredCalculationInput')->find(route_parameters->get('id'));
    unless ($row) { status 404; return { success => 0, error => 'Input not found' }; }
    $row->delete;
    return { success => 1 };
};

1;
```

- [ ] **Step 2: Register in `App.pm`**

Add: `use PropertyManager::Routes::MeteredCalculationInputs;`

- [ ] **Step 3: Syntax check and restart**

```bash
cd backend && perl -I lib -c lib/PropertyManager/Routes/MeteredCalculationInputs.pm && docker-compose restart backend
```

- [ ] **Step 4: Commit**

```bash
git add backend/lib/PropertyManager/Routes/MeteredCalculationInputs.pm backend/lib/PropertyManager/App.pm
git commit -m "api: CRUD routes for metered calculation inputs"
```

---

## Task 9: Failing tests for metered calculator (TDD)

**Files:**
- Create: `backend/t/unit/07_metered_utility_calculator.t`

- [ ] **Step 1: Read existing calculator tests for style**

```bash
cat backend/t/unit/03_utility_calculator.t | head -80
```

Match its style (Test::More, `prove`, mock schema pattern if used).

- [ ] **Step 2: Write failing tests covering all three cases**

Create `backend/t/unit/07_metered_utility_calculator.t`:

```perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use PropertyManager::Services::UtilityCalculator;
use Test::DBIxClass::Schema;  # or whatever helper 03_utility_calculator.t uses

# --- Helpers ---
sub build_schema_with_fixtures {
    # Load the same test schema helper used by 03_utility_calculator.t.
    # Seed:
    #   - tenant A (fixed% water 10, fixed% gas 15, uses_meter=0)
    #   - tenant B (water uses_meter=1, water rain %=5; gas uses_meter=1)
    #   - received invoice gas: amount=300 RON, period 2026-04
    #   - received invoice water: amount=200 RON, period 2026-04
    #   - utility_calculation for 2026-04
    #   - metered_calculation_inputs:
    #       gas: total_units=100
    #       water: total_units=80, consumption_amount=160, rain_amount=40
    #   - gas_readings for B: previous=0 via first reading 200, then current 220 (tenant_m3=20)
    #   - water_readings for B: prev 500, curr 520 (tenant_m3=20)
    ...
}

subtest 'fixed-percentage tenant unchanged' => sub {
    my $schema = build_schema_with_fixtures();
    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    my $r = $calc->calculate_shares(year => 2026, month => 4);
    my ($a) = grep { $_->{tenant_id} == 1 } @{ $r->{tenant_shares} };
    is($a->{utilities}{gas}{amount}, '45.00',
       'tenant A gas = 15% * 300 = 45 (fixed)');
    is($a->{utilities}{water}{amount}, '20.00',
       'tenant A water = 10% * 200 = 20 (fixed)');
};

subtest 'metered gas tenant' => sub {
    my $schema = build_schema_with_fixtures();
    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    my $r = $calc->calculate_shares(year => 2026, month => 4);
    my ($b) = grep { $_->{tenant_id} == 2 } @{ $r->{tenant_shares} };
    # tenant_m3=20, total_m3=100, ratio=20%, amount=20%*300=60
    is($b->{utilities}{gas}{amount}, '60.00', 'tenant B gas = 20/100 * 300 = 60');
    is($b->{utilities}{gas}{percentage}, '20.00', 'effective % stored');
};

subtest 'metered water with rain add-on' => sub {
    my $schema = build_schema_with_fixtures();
    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    my $r = $calc->calculate_shares(year => 2026, month => 4);
    my ($b) = grep { $_->{tenant_id} == 2 } @{ $r->{tenant_shares} };
    # consumption share = 20/80 * 160 = 40
    # rain share       = 5% * 40 = 2
    # total            = 42
    is($b->{utilities}{water}{amount}, '42.00',
       'tenant B water = consumption (40) + rain (2)');
    # effective % on invoice total = 42/200 = 21%
    is($b->{utilities}{water}{percentage}, '21.00', 'effective % = 21');
};

subtest 'missing metered inputs blocks finalization' => sub {
    my $schema = build_schema_with_fixtures();
    # Delete the water metered_calculation_inputs row
    $schema->resultset('MeteredCalculationInput')->search(
        { utility_type => 'water' }
    )->delete;
    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    eval { $calc->calculate_shares(year => 2026, month => 4); };
    like($@, qr/metered/i, 'missing metered inputs raises error');
};

subtest 'missing tenant reading blocks finalization' => sub {
    my $schema = build_schema_with_fixtures();
    $schema->resultset('GasReading')->search({ tenant_id => 2 })->delete;
    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    eval { $calc->calculate_shares(year => 2026, month => 4); };
    like($@, qr/reading/i, 'missing reading raises error');
};

done_testing();
```

The `build_schema_with_fixtures` body should mirror whatever fixture helper exists for `03_utility_calculator.t`. If none exists, use SQLite in-memory with `PropertyManager::Schema->deploy` and hand-create rows via the resultsets.

- [ ] **Step 3: Run the tests and confirm they fail**

```bash
cd backend && prove -I lib t/unit/07_metered_utility_calculator.t
```

Expected: FAIL. The errors should be about the calculator not branching on `uses_meter` (wrong amounts) or method signatures, not Perl syntax/missing modules. If the failure is syntax/missing fixture helper, fix those before moving on.

- [ ] **Step 4: Commit the failing tests**

```bash
git add backend/t/unit/07_metered_utility_calculator.t
git commit -m "test: failing tests for metered gas/water calculator"
```

---

## Task 10: Implement metered branch in `UtilityCalculator`

**Files:**
- Modify: `backend/lib/PropertyManager/Services/UtilityCalculator.pm`

- [ ] **Step 1: Add helper `_resolve_tenant_share`**

Inside the `foreach my $tenant (@tenants)` loop in `calculate_shares` (currently lines ~72–93), replace the percentage-lookup block with a call to a new helper. Keep the `$overrides` fast-path.

Add at the end of the package (before `1;`):

```perl
sub _resolve_tenant_share {
    my ($self, %args) = @_;
    my ($tenant_id, $utility_type, $invoice, $year, $month, $calculation_id) =
        @args{qw(tenant_id utility_type invoice year month calculation_id)};

    my $pct_record = $self->{schema}->resultset('TenantUtilityPercentage')->search(
        { tenant_id => $tenant_id, utility_type => $utility_type }
    )->first;

    my $fixed_pct = $pct_record ? $pct_record->percentage : 0;
    my $uses_meter = $pct_record ? $pct_record->uses_meter : 0;

    # Non-metered or non-gas/water → existing behavior
    unless ($uses_meter && ($utility_type eq 'gas' || $utility_type eq 'water')) {
        my $amount = ($invoice->amount * $fixed_pct) / 100;
        return { percentage => $fixed_pct, amount => $amount };
    }

    # Metered: we need calculation_id + metered_calculation_inputs + reading
    die "calculation_id required for metered billing" unless $calculation_id;

    my $inputs = $self->{schema}->resultset('MeteredCalculationInput')->search({
        calculation_id => $calculation_id,
        utility_type   => $utility_type,
    })->first;

    die "Missing metered inputs for $utility_type in calculation $calculation_id"
        unless $inputs;

    my $reading_rs = $utility_type eq 'gas' ? 'GasReading' : 'WaterReading';
    my $reading = $self->{schema}->resultset($reading_rs)->search({
        tenant_id    => $tenant_id,
        period_year  => $year,
        period_month => $month,
    })->first;

    die "Missing $utility_type reading for tenant $tenant_id / $year-$month"
        unless $reading;

    my $tenant_units = defined $reading->consumption
        ? $reading->consumption
        : ($reading->reading_value - ($reading->previous_reading_value // 0));

    my $total_units = $inputs->total_units;
    die "total_units must be > 0" unless $total_units > 0;

    if ($utility_type eq 'gas') {
        my $ratio = $tenant_units / $total_units;
        my $amount = $ratio * $invoice->amount;
        return {
            percentage => sprintf('%.2f', $ratio * 100),
            amount     => $amount,
        };
    }

    # water
    my $consumption_share = ($tenant_units / $total_units) * $inputs->consumption_amount;
    my $rain_share        = ($fixed_pct / 100) * $inputs->rain_amount;
    my $amount            = $consumption_share + $rain_share;
    my $effective_pct     = $invoice->amount > 0
        ? ($amount / $invoice->amount) * 100
        : 0;
    return {
        percentage => sprintf('%.2f', $effective_pct),
        amount     => $amount,
    };
}
```

- [ ] **Step 2: Thread `calculation_id` through `calculate_shares`**

At the top of `calculate_shares` add:

```perl
my $calculation_id = $params{calculation_id};
# If not provided, try to look it up by period:
unless ($calculation_id) {
    my $calc = $self->{schema}->resultset('UtilityCalculation')->search(
        { period_year => $year, period_month => $month }
    )->first;
    $calculation_id = $calc ? $calc->id : undef;
}
```

- [ ] **Step 3: Replace in-loop percentage logic with helper call**

Inside the invoice loop, replace the per-tenant block (the current `$percentage = ...; $amount = ($total_amount * $percentage)/100;` region) with:

```perl
my $share;
if ($overrides->{$tenant_id} && defined $overrides->{$tenant_id}{$utility_type}) {
    my $p = $overrides->{$tenant_id}{$utility_type};
    $share = { percentage => $p, amount => ($total_amount * $p) / 100 };
} else {
    $share = $self->_resolve_tenant_share(
        tenant_id      => $tenant_id,
        utility_type   => $utility_type,
        invoice        => $invoice,
        year           => $year,
        month          => $month,
        calculation_id => $calculation_id,
    );
}

next if $share->{amount} == 0;

$tenant_shares{$tenant_id}{$utility_type} = {
    amount         => sprintf("%.2f", $share->{amount}),
    percentage     => sprintf("%.2f", $share->{percentage}),
    invoice_id     => $invoice_id,
    invoice_number => $invoice->invoice_number,
};
```

Adjust the surrounding variables (`$invoice_tenant_shares`, `$company_pct`) so company-portion math uses the **sum of effective percentages** rather than the old fixed-% sum. Specifically, build `$total_tenant_pct` from `$share->{percentage}` accumulated across tenants for this invoice.

- [ ] **Step 4: Run the failing tests — expect them to pass**

```bash
cd backend && prove -I lib t/unit/07_metered_utility_calculator.t
```

Expected: all subtests pass.

- [ ] **Step 5: Run the full unit suite to guard against regressions**

```bash
cd backend && prove -I lib t/unit/
```

Expected: all tests pass including `03_utility_calculator.t` (fixed-% path).

- [ ] **Step 6: Commit**

```bash
git add backend/lib/PropertyManager/Services/UtilityCalculator.pm
git commit -m "calc: branch on uses_meter for gas/water billing"
```

---

## Task 11: Frontend service modules

**Files:**
- Create: `frontend/src/services/gasReadingsService.js`
- Create: `frontend/src/services/waterReadingsService.js`
- Create: `frontend/src/services/meteredInputsService.js`

- [ ] **Step 1: Read `meterReadingsService.js` to match style**

```bash
cat frontend/src/services/meterReadingsService.js
```

Match its exports (`listReadings`, `getReading`, `createReading`, `updateReading`, `deleteReading`) and axios usage (from `./api`).

- [ ] **Step 2: Write `gasReadingsService.js`**

```js
import api from './api';

export const listGasReadings = (params = {}) =>
  api.get('/gas-readings', { params }).then((r) => r.data);

export const getGasReading = (id) =>
  api.get(`/gas-readings/${id}`).then((r) => r.data);

export const createGasReading = (payload) =>
  api.post('/gas-readings', payload).then((r) => r.data);

export const updateGasReading = (id, payload) =>
  api.put(`/gas-readings/${id}`, payload).then((r) => r.data);

export const deleteGasReading = (id) =>
  api.delete(`/gas-readings/${id}`).then((r) => r.data);
```

- [ ] **Step 3: Write `waterReadingsService.js`**

Identical to step 2 with `gas` → `water` in every identifier/path.

- [ ] **Step 4: Write `meteredInputsService.js`**

```js
import api from './api';

export const listMeteredInputs = (params = {}) =>
  api.get('/metered-inputs', { params }).then((r) => r.data);

export const saveMeteredInput = (payload) =>
  api.post('/metered-inputs', payload).then((r) => r.data);

export const deleteMeteredInput = (id) =>
  api.delete(`/metered-inputs/${id}`).then((r) => r.data);
```

- [ ] **Step 5: Commit**

```bash
git add frontend/src/services/gasReadingsService.js frontend/src/services/waterReadingsService.js frontend/src/services/meteredInputsService.js
git commit -m "frontend: service modules for gas/water readings and metered inputs"
```

---

## Task 12: Frontend page — `GasReadings.jsx`

**Files:**
- Create: `frontend/src/pages/GasReadings.jsx`
- Modify: `frontend/src/App.jsx` (add route)
- Modify: nav menu layout file

- [ ] **Step 1: Read `MeterReadings.jsx` end-to-end**

```bash
cat frontend/src/pages/MeterReadings.jsx
```

Use it as the structural template.

- [ ] **Step 2: Create `GasReadings.jsx`**

A single-page CRUD modeled on `MeterReadings.jsx` with these differences:
- Page title: "Indexuri Gaz" (Romanian) or "Gas Readings"
- Selector at the top is **Tenant** (fetched via `tenantsService.listTenants`), not Meter.
- Columns: tenant name, period (year/month), reading_value (m³), previous, consumption, notes, actions.
- Create/Edit modal form fields: `tenant_id`, `period_year`, `period_month`, `reading_date`, `reading_value`, `notes`.
- CRUD via `gasReadingsService`.
- Filters: tenant, year, month (mirror MeterReadings filter UX).

Reuse Ant Design components: `Table`, `Modal`, `Form`, `InputNumber`, `Select`, `DatePicker`, `Button`, `Popconfirm`.

- [ ] **Step 3: Register route in `App.jsx`**

Find the existing `<Route path="/meter-readings" ...>` line and add after it:

```jsx
<Route path="/gas-readings" element={<GasReadings />} />
```

Add the import at the top: `import GasReadings from './pages/GasReadings';`

- [ ] **Step 4: Add nav menu entry**

Locate the nav layout file (grep for `meter-readings` in `frontend/src/layouts/`) and add a sibling menu item pointing to `/gas-readings` with a reasonable icon (e.g., `FireOutlined` from `@ant-design/icons`).

- [ ] **Step 5: Manual smoke test**

```bash
docker-compose restart frontend
```

Navigate to http://localhost/gas-readings, create a reading for an existing tenant, reload, confirm it persists. Delete it.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/pages/GasReadings.jsx frontend/src/App.jsx frontend/src/layouts/
git commit -m "frontend: Gas Readings page and navigation"
```

---

## Task 13: Frontend page — `WaterReadings.jsx`

**Files:**
- Create: `frontend/src/pages/WaterReadings.jsx`
- Modify: `frontend/src/App.jsx`
- Modify: nav menu layout

Follow Task 12 step-for-step with `gas` → `water` substitutions. Page title "Indexuri Apă". Icon suggestion: `CloudOutlined` or `ExperimentOutlined`.

Commit:

```bash
git add frontend/src/pages/WaterReadings.jsx frontend/src/App.jsx frontend/src/layouts/
git commit -m "frontend: Water Readings page and navigation"
```

---

## Task 14: Tenant edit — `uses_meter` toggle

**Files:**
- Modify: `frontend/src/pages/Tenants.jsx`

- [ ] **Step 1: Locate the utility-percentages form section**

```bash
grep -n 'utility_percentages\|utility_type\|percentage' frontend/src/pages/Tenants.jsx | head -30
```

Find the block rendering one row per `utility_type`.

- [ ] **Step 2: Add a `Switch` for `uses_meter`**

For **each utility row**, add after the percentage input (Ant Design `Switch`):

```jsx
<Form.Item
  name={['utility_percentages', utilityType, 'uses_meter']}
  valuePropName="checked"
  label="Meter-based"
  tooltip={utilityType === 'water'
    ? 'When enabled, the percentage field represents the rain-water share only.'
    : 'When enabled, the share is computed from meter readings.'}
  hidden={!['gas', 'water'].includes(utilityType)}
>
  <Switch />
</Form.Item>
```

- [ ] **Step 3: Relabel percentage for water when `uses_meter` is true**

Use a `Form.Item` `shouldUpdate` wrapper that watches `utility_percentages.water.uses_meter` and changes the label from "Procent apă" to "Procent apă pluvială" (rain water %). If the form already uses a simple label, a conditional `label` prop on the percentage Form.Item is enough.

- [ ] **Step 4: Ensure the save payload includes `uses_meter`**

Check `tenantsService.saveTenant` (or equivalent) — if it passes the whole form body through, nothing to do. Otherwise extend it to include `uses_meter` per utility row. Grep to confirm:

```bash
grep -n 'utility_percentages' frontend/src/services/tenantsService.js
```

- [ ] **Step 5: Manual smoke test**

Create a new tenant, toggle "Meter-based" on for gas and water, save, reopen: confirm the toggle persisted. Verify the API call payload in DevTools Network tab includes `uses_meter: true`.

Also verify via DB:

```bash
docker-compose exec -T db mysql -uroot -p"${DB_ROOT_PASSWORD:-rootpassword}" -e \
  "USE property_management; SELECT tenant_id, utility_type, percentage, uses_meter FROM tenant_utility_percentages ORDER BY tenant_id, utility_type;"
```

- [ ] **Step 6: Commit**

```bash
git add frontend/src/pages/Tenants.jsx frontend/src/services/tenantsService.js
git commit -m "frontend: uses_meter toggle in tenant edit form"
```

---

## Task 15: Utility calculations screen — metered inputs block

**Files:**
- Modify: `frontend/src/pages/UtilityCalculations.jsx`

- [ ] **Step 1: Read the current calc screen**

```bash
wc -l frontend/src/pages/UtilityCalculations.jsx
```

Identify where the period is picked and where the "finalize" action is triggered.

- [ ] **Step 2: Fetch existing metered inputs for the period's calculation**

Add a `useEffect` keyed on the selected calculation that calls `listMeteredInputs({ calculation_id })` and stores the result in component state (`meteredInputs` keyed by utility).

- [ ] **Step 3: Detect which utilities need metered inputs**

For the current period, fetch `tenant_utility_percentages` (already loaded somewhere in the screen) and check whether any tenant has `uses_meter=true` for gas and/or water. Store `needsGas` and `needsWater` flags.

- [ ] **Step 4: Render the block**

Below the existing calculation summary and above the finalize button, render:

```jsx
{(needsGas || needsWater) && (
  <Card title="Metered inputs" style={{ marginTop: 16 }}>
    {needsGas && (
      <Form layout="inline" onFinish={(v) => saveMeteredInput({
        calculation_id: calculationId,
        received_invoice_id: v.received_invoice_id,
        utility_type: 'gas',
        total_units: v.total_units,
      }).then(reloadMeteredInputs)}>
        <Form.Item name="received_invoice_id" label="Factură gaz" rules={[{ required: true }]}>
          <Select options={gasInvoiceOptions} style={{ width: 260 }} />
        </Form.Item>
        <Form.Item name="total_units" label="Total m³" rules={[{ required: true }]}>
          <InputNumber min={0} step={0.01} />
        </Form.Item>
        <Button htmlType="submit" type="primary">Salvează</Button>
      </Form>
    )}
    {needsWater && (
      <Form layout="inline" onFinish={(v) => saveMeteredInput({
        calculation_id: calculationId,
        received_invoice_id: v.received_invoice_id,
        utility_type: 'water',
        total_units: v.total_units,
        consumption_amount: v.consumption_amount,
        rain_amount: v.rain_amount,
      }).then(reloadMeteredInputs)}>
        <Form.Item name="received_invoice_id" label="Factură apă" rules={[{ required: true }]}>
          <Select options={waterInvoiceOptions} style={{ width: 260 }} />
        </Form.Item>
        <Form.Item name="total_units" label="Total m³" rules={[{ required: true }]}>
          <InputNumber min={0} step={0.01} />
        </Form.Item>
        <Form.Item name="consumption_amount" label="Cost consum (RON)" rules={[{ required: true }]}>
          <InputNumber min={0} step={0.01} />
        </Form.Item>
        <Form.Item name="rain_amount" label="Cost apă pluvială (RON)" rules={[{ required: true }]}>
          <InputNumber min={0} step={0.01} />
        </Form.Item>
        <Button htmlType="submit" type="primary">Salvează</Button>
      </Form>
    )}
    <div style={{ marginTop: 8, color: '#888' }}>
      Current saved: {JSON.stringify(meteredInputs)}
    </div>
  </Card>
)}
```

Replace the debug `JSON.stringify` with a proper table in polish pass (Task 17).

- [ ] **Step 5: Disable finalize when required inputs are missing**

Add validation before the finalize API call: if `needsGas` is true and `meteredInputs.gas` is absent, block with a `message.error('Missing gas metered inputs')`. Same for water. Same for missing readings (detect by calling the calculator preview endpoint and surfacing backend 500s with the message from `die` in Task 10).

- [ ] **Step 6: Manual smoke test**

Create a period calculation for 2026-04. Toggle `uses_meter` on both gas and water for a tenant. Add the corresponding gas and water readings. Enter metered inputs. Finalize. Confirm `utility_calculation_details` has the expected amounts.

- [ ] **Step 7: Commit**

```bash
git add frontend/src/pages/UtilityCalculations.jsx
git commit -m "frontend: metered inputs block on utility calculations screen"
```

---

## Task 16: Invoice PDF — pass breakdown data to template

**Files:**
- Modify: `backend/lib/PropertyManager/Services/InvoiceGenerator.pm`

- [ ] **Step 1: Read the current invoice generator**

```bash
grep -n 'sub \|template\|render' backend/lib/PropertyManager/Services/InvoiceGenerator.pm | head
```

Find where template vars are assembled.

- [ ] **Step 2: Build a `metered_breakdown` structure when a utility invoice references a metered tenant**

For each `utility_calculation_detail` row on the invoice:

```perl
my $tup = $schema->resultset('TenantUtilityPercentage')->search({
    tenant_id => $tenant_id, utility_type => $detail->utility_type,
})->first;

next unless $tup && $tup->uses_meter
    && ($detail->utility_type eq 'gas' || $detail->utility_type eq 'water');

my $inputs = $schema->resultset('MeteredCalculationInput')->search({
    calculation_id => $detail->calculation_id,
    utility_type   => $detail->utility_type,
})->first;

my $reading_rs = $detail->utility_type eq 'gas' ? 'GasReading' : 'WaterReading';
my $reading = $schema->resultset($reading_rs)->search({
    tenant_id => $tenant_id,
    period_year => $calc->period_year,
    period_month => $calc->period_month,
})->first;

my $item = {
    utility_type  => $detail->utility_type,
    previous_index => $reading->previous_reading_value,
    current_index  => $reading->reading_value,
    tenant_units   => $reading->consumption,
    total_units    => $inputs->total_units,
    ratio_pct      => sprintf('%.2f',
        $inputs->total_units > 0
            ? ($reading->consumption / $inputs->total_units) * 100
            : 0),
    invoice_amount => $detail->received_invoice_id
        ? $schema->resultset('ReceivedInvoice')->find($detail->received_invoice_id)->amount
        : undef,
    tenant_amount  => $detail->amount,
    effective_pct  => $detail->percentage,
};

if ($detail->utility_type eq 'water') {
    $item->{consumption_cost}  = $inputs->consumption_amount;
    $item->{rain_cost}         = $inputs->rain_amount;
    $item->{rain_percentage}   = $tup->percentage;
    $item->{consumption_share} =
        ($reading->consumption / $inputs->total_units) * $inputs->consumption_amount;
    $item->{rain_share} = ($tup->percentage / 100) * $inputs->rain_amount;
}

push @{ $template_vars->{metered_breakdown} }, $item;
```

- [ ] **Step 3: Unit-test the assembly**

If the project's test suite has coverage for `InvoiceGenerator` (check `backend/t/unit/04_invoice_generator.t`), extend it with a scenario where a tenant has `uses_meter=1` and assert `metered_breakdown` is populated with the expected shape.

Run:

```bash
cd backend && prove -I lib t/unit/04_invoice_generator.t
```

- [ ] **Step 4: Commit**

```bash
git add backend/lib/PropertyManager/Services/InvoiceGenerator.pm backend/t/unit/04_invoice_generator.t
git commit -m "invoice: pass metered breakdown data to template"
```

---

## Task 17: Invoice PDF — template "Detalii calcul contori" section

**Files:**
- Modify: default invoice template (find via `SELECT id,name FROM invoice_templates WHERE is_default=1` or `backend/templates/`).

- [ ] **Step 1: Locate the default template file/row**

```bash
grep -rn 'utility\|factura\|invoice' backend/templates/ 2>/dev/null | head
docker-compose exec -T db mysql -uroot -p"${DB_ROOT_PASSWORD:-rootpassword}" -e \
  "USE property_management; SELECT id, name, is_default FROM invoice_templates;"
```

If templates live in the DB, export the default row to a file, edit there, then re-import.

- [ ] **Step 2: Add the breakdown section HTML**

Append (after the existing `</table>` that closes the line-items table):

```html
{{#metered_breakdown}}
  {{#first}}
    <div class="metered-breakdown" style="page-break-before: always; margin-top: 24px;">
      <h3>Detalii calcul contori</h3>
  {{/first}}

  {{#gas}}
    <div class="metered-item" style="margin: 12px 0; padding: 8px; border: 1px solid #ddd;">
      <h4>Gaz</h4>
      <p>Index anterior: {{previous_index}} m³<br>
         Index curent: {{current_index}} m³<br>
         Consum: {{tenant_units}} m³ din total {{total_units}} m³ pe factura furnizor<br>
         Cotă: {{ratio_pct}}%<br>
         Sumă: {{ratio_pct}}% × {{invoice_amount}} RON = <b>{{tenant_amount}} RON</b>
      </p>
    </div>
  {{/gas}}

  {{#water}}
    <div class="metered-item" style="margin: 12px 0; padding: 8px; border: 1px solid #ddd;">
      <h4>Apă</h4>
      <p>Index anterior: {{previous_index}} m³<br>
         Index curent: {{current_index}} m³<br>
         Consum propriu: {{tenant_units}} m³ din total {{total_units}} m³<br>
         Cotă consum: {{tenant_units}}/{{total_units}} × {{consumption_cost}} RON = {{consumption_share}} RON<br>
         Apă pluvială: {{rain_percentage}}% × {{rain_cost}} RON = {{rain_share}} RON<br>
         Total: <b>{{tenant_amount}} RON</b> (cotă efectivă pe factura furnizor: {{effective_pct}}%)
      </p>
    </div>
  {{/water}}

  {{#last}}
    </div>
  {{/last}}
{{/metered_breakdown}}
```

Use whichever templating engine the codebase already uses (Mustache, TT2, raw substitution). The `{{#gas}}...{{/gas}}` / `{{#water}}...{{/water}}` blocks assume a field-based discriminator; if the template engine doesn't support per-type sections, generate the correct HTML branch inside `InvoiceGenerator.pm` (Task 16) and expose it as a pre-rendered `breakdown_html` variable. Verify engine behavior:

```bash
grep -rn 'Template::Toolkit\|Text::Xslate\|Mustache' backend/lib backend/cpanfile
```

- [ ] **Step 3: Regenerate a sample PDF**

```bash
# Trigger PDF regeneration for an existing utility invoice that has a metered tenant
curl -X POST http://localhost/api/invoices/<id>/regenerate-pdf -H 'Cookie: ...'
open /tmp/test-invoice.pdf   # visual check
```

Expected: page 1 unchanged; page 2 shows the new "Detalii calcul contori" section with correct numbers.

- [ ] **Step 4: Verify fixed-% tenants still get single-page invoices**

Generate a PDF for a tenant that has no `uses_meter` flags. Confirm no "Detalii calcul contori" section appears and layout is unchanged.

- [ ] **Step 5: Commit**

```bash
git add backend/templates/ database/seeds/  # whichever paths changed
git commit -m "invoice: detailed metered breakdown on invoice PDF"
```

---

## Task 18: End-to-end verification

- [ ] **Step 1: Apply migrations to a fresh dev DB** (optional but recommended)

```bash
docker-compose down -v
docker-compose up -d
sleep 15
docker-compose exec -T db mysql -uroot -p"${DB_ROOT_PASSWORD:-rootpassword}" property_management < database/migrations/003_metered_gas_water_billing.sql
```

- [ ] **Step 2: Run the full test suite**

```bash
cd backend && ./t/run_tests.sh
```

Expected: all tests pass.

- [ ] **Step 3: Manual e2e walkthrough**

1. Log in as admin.
2. Create a new tenant. Toggle `uses_meter` on for both gas and water. Set water `percentage` to e.g. `5.00` (rain share). Save.
3. Create gas + water received invoices for 2026-04 with known amounts.
4. Enter gas and water readings for the tenant for 2026-04.
5. Open Utility Calculations for 2026-04. Enter total m³ for gas; total m³ + consumption cost + rain cost for water. Save metered inputs.
6. Finalize calculation.
7. Generate the tenant's utility invoice PDF. Verify page 1 line items match the formulas and page 2 shows the breakdown.
8. Repeat with a fixed-% tenant to confirm no regressions.

- [ ] **Step 4: Final commit**

If any polish fixes were needed above, commit them:

```bash
git add -p
git commit -m "polish: fixes from end-to-end verification"
```

---

## Review checklist (run before handoff)

- [ ] `tenant_utility_percentages.uses_meter` defaults to FALSE — existing tenants unaffected.
- [ ] Fixed-% calculation path produces identical results to pre-change for non-metered tenants (verified by `03_utility_calculator.t`).
- [ ] Metered calculation raises clear errors when readings or `metered_calculation_inputs` rows are missing.
- [ ] Water formula: `(tenant_m³ / total_m³) * consumption_cost + (rain_% / 100) * rain_cost`.
- [ ] Gas formula: `(tenant_m³ / total_m³) * invoice_amount`.
- [ ] `utility_calculation_details.percentage` stores the **effective** percentage for metered rows, not the stored rain %.
- [ ] Invoice PDF page 1 unchanged for all tenants; page 2 breakdown present only when at least one line item is metered.
- [ ] Default invoice template updated; custom user-cloned templates are left alone (documented limitation).
