# Reflectarea live a calculului pe contor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pe ecranul Calcul Utilități, chiriașii cu contor pe gaz/apă își văd procentul și suma calculate live din citirile de index, cu inputuri pe lună mereu vizibile și fără resetarea flag-ului de contor.

**Architecture:** Backend Perl/Dancer2 rămâne autoritativ la finalizare; două rute se hardening/derivare. Frontend React extrage formulele într-un modul pur testabil (`meteredCalc.js`) și le folosește pentru preview live pe ecranul de calcul.

**Tech Stack:** Perl/Dancer2 + DBIx::Class (backend), React 19 + Ant Design 6 + TanStack Query (frontend), Node `--test` (test modul pur frontend), `prove` (teste backend).

## Global Constraints

- Fără modificări de schemă DB — se folosesc coloanele existente `metered_calculation_inputs.total_units`, `.rain_amount`, `.consumption_amount`.
- Fără modificări la PDF sau la template-ul de factură (template default deja randează „Detalii calcul contori").
- Fără commit-uri cu trailer `Co-Authored-By`.
- Formule autoritative (din spec):
  - Gaz: `procent = consum/total_m3 × 100`; `sumă = procent/100 × factură`.
  - Apă: `valoare_apă = factură − pluvială`; `rain_share = rain_pct/100 × pluvială`; `consum_share = consum/total_m3 × valoare_apă`; `sumă = rain_share + consum_share`; `procent_efectiv = sumă/factură × 100`.
- Exemplu numeric de referință (folosit în teste):
  - Gaz: consum 4.3, total 57, factură 300 → procent 7.5439%, sumă 22.6316.
  - Apă: consum 1.1, total 47, factură 1883.58, pluvială 779.14, rain_pct 20 → valoare_apă 1104.44, rain_share 155.828, consum_share 25.8497, sumă 181.6777, procent_efectiv 9.6455%.

**Spec:** `docs/superpowers/specs/2026-07-15-metered-live-reflection-design.md`

## File Structure

- `backend/lib/PropertyManager/Routes/Tenants.pm` — MODIFY: păstrează `uses_meter` la procent scalar.
- `backend/t/integration/03_tenants.t` — MODIFY: subtest pentru păstrarea `uses_meter`.
- `backend/lib/PropertyManager/Routes/MeteredCalculationInputs.pm` — MODIFY: derivă `consumption_amount` pentru apă.
- `backend/t/integration/05_metered_inputs.t` — CREATE: test derivare apă.
- `frontend/src/utils/meteredCalc.js` — CREATE: modul pur cu formulele.
- `frontend/src/utils/meteredCalc.test.js` — CREATE: teste `node --test`.
- `frontend/src/services/gasReadingsService.js` — MODIFY: adaugă `getByPeriod`.
- `frontend/src/services/waterReadingsService.js` — MODIFY: adaugă `getByPeriod`.
- `frontend/src/pages/UtilityCalculations.jsx` — MODIFY: bloc inputuri mereu vizibil + auto-draft + derivare afișată (Task 5); reflectare live în carduri + totaluri (Task 6).

---

### Task 1: Backend — păstrează `uses_meter` la salvarea unui procent scalar

**Files:**
- Modify: `backend/lib/PropertyManager/Routes/Tenants.pm:269-283`
- Test: `backend/t/integration/03_tenants.t`

**Interfaces:**
- Consumes: rută existentă `PUT /api/tenants/:id/percentages`, care acceptă `{ percentages => { <utility> => <scalar|{percentage,uses_meter}> } }`.
- Produces: comportament — o intrare scalară nu mai resetează `uses_meter`, ci păstrează valoarea din DB.

- [ ] **Step 1: Scrie testul care pică**

În `backend/t/integration/03_tenants.t`, adaugă înainte de `done_testing;` (sau la finalul listei de subteste) următorul subtest și mărește `plan tests => N` cu 1 dacă fișierul folosește `plan tests`:

```perl
subtest 'PUT percentages - scalar nu reseteaza uses_meter' => sub {
    plan tests => 3;

    my $tenant = TestHelper::create_test_tenant(
        TestHelper::schema(),
        name => 'Uses Meter Preserve',
    );

    # 1) Seteaza gas cu uses_meter=1 prin hashref
    my $res1 = TestHelper::auth_put(
        $test, "/api/tenants/" . $tenant->id . "/percentages",
        { percentages => { gas => { percentage => 20, uses_meter => 1 } } },
    );
    is($res1->code, 200, 'Set uses_meter=1 OK');

    # 2) Salveaza gas ca scalar (fara uses_meter)
    my $res2 = TestHelper::auth_put(
        $test, "/api/tenants/" . $tenant->id . "/percentages",
        { percentages => { gas => 25 } },
    );
    is($res2->code, 200, 'Scalar update OK');

    # 3) uses_meter trebuie sa ramana 1
    my $data = decode_json($res2->content);
    my ($gas) = grep { $_->{utility_type} eq 'gas' }
        @{ $data->{data}{utility_percentages} };
    is($gas->{uses_meter}, 1, 'uses_meter pastrat dupa scalar');
};
```

- [ ] **Step 2: Rulează testul ca să confirmi că pică**

Run: `cd backend && prove -l t/integration/03_tenants.t`
Expected: FAIL la assert-ul `uses_meter pastrat dupa scalar` (primește 0).

- [ ] **Step 3: Modifică ruta să păstreze `uses_meter`**

În `backend/lib/PropertyManager/Routes/Tenants.pm`, înlocuiește blocul de normalizare (liniile ~269-283):

```perl
    my %normalized;
    foreach my $utility_type (keys %$percentages) {
        my $entry = $percentages->{$utility_type};
        if (ref $entry eq 'HASH') {
            $normalized{$utility_type} = {
                percentage => $entry->{percentage} // 0,
                uses_meter => $entry->{uses_meter} ? 1 : 0,
            };
        } else {
            # Scalar: pastreaza uses_meter existent din DB (nu-l reseta).
            my $existing = schema->resultset('TenantUtilityPercentage')->search({
                tenant_id    => $tenant->id,
                utility_type => $utility_type,
            })->first;
            $normalized{$utility_type} = {
                percentage => $entry // 0,
                uses_meter => ($existing && $existing->uses_meter) ? 1 : 0,
            };
        }
    }
```

- [ ] **Step 4: Rulează testul ca să confirmi că trece**

Run: `cd backend && prove -l t/integration/03_tenants.t`
Expected: PASS (toate subtestele).

- [ ] **Step 5: Commit**

```bash
git add backend/lib/PropertyManager/Routes/Tenants.pm backend/t/integration/03_tenants.t
git commit -m "fix: preserve uses_meter when saving scalar percentage"
```

---

### Task 2: Backend — derivă `consumption_amount` pentru apă din factură − pluvială

**Files:**
- Modify: `backend/lib/PropertyManager/Routes/MeteredCalculationInputs.pm:26-70`
- Test: `backend/t/integration/05_metered_inputs.t` (create)

**Interfaces:**
- Consumes: rută existentă `POST /api/metered-inputs` cu câmpuri `calculation_id, received_invoice_id, utility_type, total_units` și (apă) `rain_amount`.
- Produces: pentru `utility_type='water'`, `consumption_amount` NU mai e cerut de la client; se calculează server-side `= received_invoice.amount − rain_amount` și se persistă. Pentru gaz, `consumption_amount` și `rain_amount` rămân NULL.

- [ ] **Step 1: Scrie testul care pică**

Creează `backend/t/integration/05_metered_inputs.t`:

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";
use TestHelper;
use JSON::XS;

my $test   = TestHelper::app();
my $schema = TestHelper::schema();

# Fixtures: o factura de apa si un calcul
my $water_invoice = TestHelper::create_test_received_invoice(
    $schema,
    utility_type => 'water',
    period_start => '2026-06-01',
    period_end   => '2026-06-30',
    invoice_date => '2026-06-30',
    due_date     => '2026-07-15',
    amount       => 1883.58,
);
my $calc = $schema->resultset('UtilityCalculation')->create({
    period_year => 2026, period_month => 6, is_finalized => 0,
});

subtest 'POST metered-inputs water: consumption_amount derivat = factura - pluviala' => sub {
    plan tests => 3;

    my $res = TestHelper::auth_post($test, '/api/metered-inputs', {
        calculation_id      => $calc->id,
        received_invoice_id => $water_invoice->id,
        utility_type        => 'water',
        total_units         => 47,
        rain_amount         => 779.14,
        # NB: fara consumption_amount
    });
    is($res->code, 200, 'Salvare OK fara consumption_amount');

    my $data = decode_json($res->content);
    my $saved = $data->{data}{input};
    is(sprintf('%.2f', $saved->{rain_amount}), '779.14', 'rain_amount pastrat');
    is(sprintf('%.2f', $saved->{consumption_amount}), '1104.44',
        'consumption_amount derivat = 1883.58 - 779.14');
};

# Curatenie
$schema->resultset('MeteredCalculationInput')->delete_all;
$schema->resultset('UtilityCalculation')->delete_all;
$schema->resultset('ReceivedInvoice')->delete_all;

done_testing;
```

- [ ] **Step 2: Rulează testul ca să confirmi că pică**

Run: `cd backend && prove -l t/integration/05_metered_inputs.t`
Expected: FAIL — ruta întoarce 400 „consumption_amount and rain_amount are required for water".

- [ ] **Step 3: Modifică ruta să deriveze `consumption_amount`**

În `backend/lib/PropertyManager/Routes/MeteredCalculationInputs.pm`, înlocuiește blocul de validare water și corpul `update_or_create` (liniile ~40-67):

```perl
    my $consumption_amount = $d->{consumption_amount};
    my $rain_amount        = $d->{rain_amount};

    if ($d->{utility_type} eq 'water') {
        unless (defined $rain_amount) {
            status 400;
            return { success => 0, error => "rain_amount is required for water" };
        }
        # Derivare: consum = valoarea facturii - pluviala
        my $ri = schema->resultset('ReceivedInvoice')->find($d->{received_invoice_id});
        unless ($ri) {
            status 400;
            return { success => 0, error => "received_invoice_id invalid" };
        }
        $consumption_amount = $ri->amount - $rain_amount;
    } else {
        # gaz: fara split
        $consumption_amount = undef;
        $rain_amount        = undef;
    }

    my $row;
    try {
        $row = schema->resultset('MeteredCalculationInput')->update_or_create(
            {
                calculation_id      => $d->{calculation_id},
                utility_type        => $d->{utility_type},
                received_invoice_id => $d->{received_invoice_id},
                total_units         => $d->{total_units},
                consumption_amount  => $consumption_amount,
                rain_amount         => $rain_amount,
                notes               => $d->{notes},
            },
            { key => 'calc_utility_unique' }
        );
    } catch {
        status 500; return { success => 0, error => "Save failed: $_" };
    };

    return { success => 1, data => { input => { $row->get_columns } } };
```

- [ ] **Step 4: Rulează testul + suita metered ca să confirmi că trece și nu se rup regresii**

Run: `cd backend && prove -l t/integration/05_metered_inputs.t t/unit/07_metered_utility_calculator.t t/unit/08_invoice_generator_metered_breakdown.t`
Expected: PASS pe toate.

- [ ] **Step 5: Commit**

```bash
git add backend/lib/PropertyManager/Routes/MeteredCalculationInputs.pm backend/t/integration/05_metered_inputs.t
git commit -m "feat: derive water consumption_amount from invoice minus rain on metered inputs"
```

---

### Task 3: Frontend — modul pur `meteredCalc.js` cu teste

**Files:**
- Create: `frontend/src/utils/meteredCalc.js`
- Test: `frontend/src/utils/meteredCalc.test.js`

**Interfaces:**
- Produces:
  - `computeGasShare({ consumption, totalUnits, invoiceAmount }) => { percentage, amount, valid }`
  - `computeWaterShare({ consumption, totalUnits, invoiceAmount, rainAmount, rainPct }) => { rainShare, consumptionShare, consumptionCost, amount, percentage, valid }`
  - Când `totalUnits` nu e > 0 → `valid: false` și câmpurile numerice `null`.

- [ ] **Step 1: Scrie testul care pică**

Creează `frontend/src/utils/meteredCalc.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeGasShare, computeWaterShare } from './meteredCalc.js';

const near = (a, b, eps = 0.01) => Math.abs(a - b) <= eps;

test('gas share din exemplul de referinta', () => {
  const r = computeGasShare({ consumption: 4.3, totalUnits: 57, invoiceAmount: 300 });
  assert.ok(r.valid);
  assert.ok(near(r.percentage, 7.5439), `percentage=${r.percentage}`);
  assert.ok(near(r.amount, 22.6316), `amount=${r.amount}`);
});

test('gas consum 0 -> procent 0', () => {
  const r = computeGasShare({ consumption: 0, totalUnits: 57, invoiceAmount: 300 });
  assert.equal(r.percentage, 0);
  assert.equal(r.amount, 0);
});

test('gas total 0 -> invalid', () => {
  const r = computeGasShare({ consumption: 4.3, totalUnits: 0, invoiceAmount: 300 });
  assert.equal(r.valid, false);
  assert.equal(r.percentage, null);
});

test('water share din exemplul de referinta', () => {
  const r = computeWaterShare({
    consumption: 1.1, totalUnits: 47, invoiceAmount: 1883.58,
    rainAmount: 779.14, rainPct: 20,
  });
  assert.ok(r.valid);
  assert.ok(near(r.consumptionCost, 1104.44), `cost=${r.consumptionCost}`);
  assert.ok(near(r.rainShare, 155.828), `rain=${r.rainShare}`);
  assert.ok(near(r.consumptionShare, 25.8497), `cons=${r.consumptionShare}`);
  assert.ok(near(r.amount, 181.6777), `amount=${r.amount}`);
  assert.ok(near(r.percentage, 9.6455), `pct=${r.percentage}`);
});

test('water total 0 -> invalid', () => {
  const r = computeWaterShare({
    consumption: 1.1, totalUnits: 0, invoiceAmount: 1883.58,
    rainAmount: 779.14, rainPct: 20,
  });
  assert.equal(r.valid, false);
  assert.equal(r.amount, null);
});
```

- [ ] **Step 2: Rulează testul ca să confirmi că pică**

Run: `cd frontend && node --test src/utils/meteredCalc.test.js`
Expected: FAIL — `Cannot find module './meteredCalc.js'`.

- [ ] **Step 3: Implementează modulul**

Creează `frontend/src/utils/meteredCalc.js`:

```js
// Formule identice cu backend-ul (UtilityCalculator.pm:_resolve_tenant_share).
// Orice modificare aici trebuie oglindita in Perl si invers.

export function computeGasShare({ consumption, totalUnits, invoiceAmount }) {
  if (!(totalUnits > 0)) {
    return { percentage: null, amount: null, valid: false };
  }
  const percentage = (consumption / totalUnits) * 100;
  const amount = (percentage / 100) * invoiceAmount;
  return { percentage, amount, valid: true };
}

export function computeWaterShare({ consumption, totalUnits, invoiceAmount, rainAmount, rainPct }) {
  if (!(totalUnits > 0)) {
    return {
      rainShare: null, consumptionShare: null, consumptionCost: null,
      amount: null, percentage: null, valid: false,
    };
  }
  const consumptionCost = invoiceAmount - rainAmount;
  const rainShare = (rainPct / 100) * rainAmount;
  const consumptionShare = (consumption / totalUnits) * consumptionCost;
  const amount = rainShare + consumptionShare;
  const percentage = invoiceAmount > 0 ? (amount / invoiceAmount) * 100 : 0;
  return { rainShare, consumptionShare, consumptionCost, amount, percentage, valid: true };
}
```

- [ ] **Step 4: Rulează testul ca să confirmi că trece**

Run: `cd frontend && node --test src/utils/meteredCalc.test.js`
Expected: PASS (5 teste).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/utils/meteredCalc.js frontend/src/utils/meteredCalc.test.js
git commit -m "feat: pure meteredCalc module for gas/water share preview"
```

---

### Task 4: Frontend — `getByPeriod` pentru citiri gaz/apă

**Files:**
- Modify: `frontend/src/services/gasReadingsService.js`
- Modify: `frontend/src/services/waterReadingsService.js`

**Interfaces:**
- Produces: `gasReadingsService.getByPeriod(year, month)` și `waterReadingsService.getByPeriod(year, month)` → răspunsul API `{ success, data: [ ...readings ] }`. Ruta filtrează pe `year`/`month` (vezi `Routes/GasReadings.pm:18-19`).

- [ ] **Step 1: Adaugă `getByPeriod` în `gasReadingsService.js`**

În `frontend/src/services/gasReadingsService.js`, adaugă în obiect după `getAll`:

```js
  getByPeriod: async (year, month) => {
    const response = await api.get('/gas-readings', { params: { year, month } });
    return response.data;
  },
```

- [ ] **Step 2: Adaugă `getByPeriod` în `waterReadingsService.js`**

În `frontend/src/services/waterReadingsService.js`, adaugă în obiect după `getAll`:

```js
  getByPeriod: async (year, month) => {
    const response = await api.get('/water-readings', { params: { year, month } });
    return response.data;
  },
```

- [ ] **Step 3: Verifică lint**

Run: `cd frontend && npm run lint`
Expected: fără erori noi.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/services/gasReadingsService.js frontend/src/services/waterReadingsService.js
git commit -m "feat: getByPeriod for gas/water readings services"
```

---

### Task 5: Frontend — bloc „Contori" mereu vizibil, auto-draft, derivare apă

**Files:**
- Modify: `frontend/src/pages/UtilityCalculations.jsx` (bloc metered inputs `:1113-1237`, handlere `:367-402`, gard `:1114`)

**Interfaces:**
- Consumes: `existingCalculation`, `needsGas`, `needsWater`, `meteredInputs`, `invoicesByType`, `totalsByType`, `createMutation` (toate existente în componentă).
- Produces: blocul de inputuri e vizibil când `needsGas || needsWater` (fără `hasExistingCalculation`); la salvare, dacă nu există calcul, se creează un draft întâi; câmpul apă trimite `rain_amount` + `total_units` (fără `consumption_amount`), afișând derivat `Valoare apă (consum) = factură − pluvială`.

- [ ] **Step 1: Elimină gardul `hasExistingCalculation` din bloc**

În `frontend/src/pages/UtilityCalculations.jsx:1114`, schimbă:

```jsx
      {hasExistingCalculation && (needsGas || needsWater) && (
```
în:
```jsx
      {(needsGas || needsWater) && (
```

- [ ] **Step 2: Adaugă helper de asigurare a draft-ului de calcul**

În `UtilityCalculations.jsx`, imediat înainte de `handleSaveGasMeteredInput` (`:378`), adaugă:

```jsx
  const ensureCalculation = async () => {
    if (existingCalculation?.id) return existingCalculation.id;
    const res = await createMutation.mutateAsync({
      period_year: selectedYear,
      period_month: selectedMonth,
      overrides: tenantPercentages,
    });
    // POST /api/utility-calculations intoarce
    //   { success, data: { calculation: { id, ...columns } } }
    // (Routes/UtilityCalculations.pm:199), iar serviciul intoarce response.data.
    return res?.data?.calculation?.id ?? null;
  };
```

Confirmat: `utilityCalculationsService.create` întoarce `{ success, data: { calculation: { id, ... } } }` (`Routes/UtilityCalculations.pm:199`), deci `res.data.calculation.id` e calea corectă.

- [ ] **Step 3: Actualizează `handleSaveGasMeteredInput` să folosească `ensureCalculation`**

Înlocuiește `handleSaveGasMeteredInput` (`:378-388`):

```jsx
  const handleSaveGasMeteredInput = async () => {
    try {
      const values = await gasForm.validateFields();
      const calcId = await ensureCalculation();
      if (!calcId) { message.error('Nu s-a putut crea calculul lunii'); return; }
      saveMeteredInputMutation.mutate({
        calculation_id: calcId,
        utility_type: 'gas',
        received_invoice_id: values.received_invoice_id,
        total_units: values.total_units,
      });
    } catch (_) { /* validation */ }
  };
```

- [ ] **Step 4: Actualizează `handleSaveWaterMeteredInput` (trimite doar rain_amount)**

Înlocuiește `handleSaveWaterMeteredInput` (`:390-402`):

```jsx
  const handleSaveWaterMeteredInput = async () => {
    try {
      const values = await waterForm.validateFields();
      const calcId = await ensureCalculation();
      if (!calcId) { message.error('Nu s-a putut crea calculul lunii'); return; }
      saveMeteredInputMutation.mutate({
        calculation_id: calcId,
        utility_type: 'water',
        received_invoice_id: values.received_invoice_id,
        total_units: values.total_units,
        rain_amount: values.rain_amount,
      });
    } catch (_) { /* validation */ }
  };
```

- [ ] **Step 5: Înlocuiește câmpul „Cost consum" cu afișaj derivat**

În blocul Apă (`:1211-1217`), șterge `Form.Item` pentru `consumption_amount` și, sub câmpul `rain_amount` (`:1218-1224`), adaugă un afișaj derivat. Pune după `Form.Item` cu `name="rain_amount"`:

```jsx
                <Form.Item
                  noStyle
                  shouldUpdate={(p, c) =>
                    p.received_invoice_id !== c.received_invoice_id || p.rain_amount !== c.rain_amount
                  }
                >
                  {({ getFieldValue }) => {
                    const invId = getFieldValue('received_invoice_id');
                    const inv = (invoicesByType['water'] || []).find((i) => i.id === invId);
                    const rain = Number(getFieldValue('rain_amount')) || 0;
                    const cons = inv ? Number(inv.amount) - rain : null;
                    return (
                      <Form.Item label="Valoare apă (consum)">
                        <span>{cons != null ? `${formatCurrency(cons)} (derivat)` : '—'}</span>
                      </Form.Item>
                    );
                  }}
                </Form.Item>
```

- [ ] **Step 6: Verifică lint**

Run: `cd frontend && npm run lint`
Expected: fără erori noi (verifică că `consumption_amount` nu mai e referit în `useEffect`-ul de la `:354-365`; scoate linia `consumption_amount: ...` din `waterForm.setFieldsValue` acolo).

- [ ] **Step 7: Verificare manuală în aplicație**

Pornește aplicația (skill `/run` sau `cd frontend && npm run dev` + backend), du-te la Calcul Utilități pe o lună cu un chiriaș care are contor pe gaz/apă și facturi introduse:
- Blocul „Contori" apare chiar dacă nu ai apăsat „Salvează Calcul".
- La Apă vezi „Valoare pluvială" și „Valoare apă (consum)" derivat, fără câmpul „Cost consum".
- Salvarea unui input creează calculul automat și arată Tag „Saved".

- [ ] **Step 8: Commit**

```bash
git add frontend/src/pages/UtilityCalculations.jsx
git commit -m "feat: always-visible metered inputs block with auto-draft and derived water cost"
```

---

### Task 6: Frontend — reflectare live în cardul chiriașului + totaluri

**Files:**
- Modify: `frontend/src/pages/UtilityCalculations.jsx` (queries citiri, `tenantCosts` `:265-290`, `companyPortions` `:292-309`, randare card `:979-995`)

**Interfaces:**
- Consumes: `computeGasShare`, `computeWaterShare` din `../utils/meteredCalc`; `gasReadingsService.getByPeriod`, `waterReadingsService.getByPeriod`; `meteredInputs`, `invoicesByType`, `activeTenants`.
- Produces: `tenantCosts[tenantId].utilities[gas|water]` reflectă suma/procentul metered când chiriașul are `uses_meter`; cardul afișează desfășurarea; `companyPortions` folosește procentele efective.

- [ ] **Step 1: Importă modulul și adaugă query-urile de citiri**

Sus în fișier, adaugă importul:

```jsx
import { computeGasShare, computeWaterShare } from '../utils/meteredCalc';
import { gasReadingsService } from '../services/gasReadingsService';
import { waterReadingsService } from '../services/waterReadingsService';
```

Lângă celelalte `useQuery` (după `:74`), adaugă:

```jsx
  const { data: gasReadingsData } = useQuery({
    queryKey: ['gas-readings-period', selectedYear, selectedMonth],
    queryFn: () => gasReadingsService.getByPeriod(selectedYear, selectedMonth),
    enabled: !!selectedYear && !!selectedMonth,
  });
  const { data: waterReadingsData } = useQuery({
    queryKey: ['water-readings-period', selectedYear, selectedMonth],
    queryFn: () => waterReadingsService.getByPeriod(selectedYear, selectedMonth),
    enabled: !!selectedYear && !!selectedMonth,
  });
```

- [ ] **Step 2: Construiește hărți de consum per chiriaș**

După `activeTenants` (`:248`), adaugă:

```jsx
  const gasConsumptionByTenant = useMemo(() => {
    const map = {};
    (gasReadingsData?.data || []).forEach((r) => {
      map[r.tenant_id] = r.consumption != null
        ? Number(r.consumption)
        : Number(r.reading_value || 0) - Number(r.previous_reading_value || 0);
    });
    return map;
  }, [gasReadingsData]);

  const waterConsumptionByTenant = useMemo(() => {
    const map = {};
    (waterReadingsData?.data || []).forEach((r) => {
      map[r.tenant_id] = r.consumption != null
        ? Number(r.consumption)
        : Number(r.reading_value || 0) - Number(r.previous_reading_value || 0);
    });
    return map;
  }, [waterReadingsData]);
```

- [ ] **Step 3: Adaugă helper care întoarce rezultatul metered per (chiriaș, utilitate)**

Înainte de `tenantCosts` (`:265`), adaugă:

```jsx
  // Intoarce { metered: bool, valid, percentage, amount, detail } pentru gaz/apa cu contor.
  const meteredResultFor = (tenant, utilityType) => {
    const up = (tenant.utility_percentages || []).find(
      (x) => x.utility_type === utilityType
    );
    if (!up || !up.uses_meter) return { metered: false };

    if (utilityType === 'gas') {
      const input = meteredInputs.gas;
      const inv = input
        ? (invoicesByType['gas'] || []).find((i) => i.id === input.received_invoice_id)
        : null;
      const r = computeGasShare({
        consumption: gasConsumptionByTenant[tenant.id] || 0,
        totalUnits: input ? Number(input.total_units) : 0,
        invoiceAmount: inv ? Number(inv.amount) : 0,
      });
      return { metered: true, ...r };
    }

    const input = meteredInputs.water;
    const inv = input
      ? (invoicesByType['water'] || []).find((i) => i.id === input.received_invoice_id)
      : null;
    const r = computeWaterShare({
      consumption: waterConsumptionByTenant[tenant.id] || 0,
      totalUnits: input ? Number(input.total_units) : 0,
      invoiceAmount: inv ? Number(inv.amount) : 0,
      rainAmount: input ? Number(input.rain_amount) : 0,
      rainPct: Number(up.percentage) || 0,
    });
    return { metered: true, ...r };
  };
```

- [ ] **Step 4: Integrează metered în `tenantCosts`**

Înlocuiește bucla din `tenantCosts` (`:275-287`) astfel încât utilitățile metered să folosească rezultatul calculat:

```jsx
      UTILITY_TYPE_OPTIONS.forEach((option) => {
        const utilityType = option.value;
        const invoiceTotal = totalsByType[utilityType] || 0;
        const meteredRes = meteredResultFor(tenant, utilityType);

        let percentage, amount;
        if (meteredRes.metered) {
          percentage = meteredRes.valid ? meteredRes.percentage : 0;
          amount = meteredRes.valid ? meteredRes.amount : 0;
        } else {
          percentage = tenantPercentages[tenant.id]?.[utilityType] || 0;
          amount = (invoiceTotal * percentage) / 100;
        }

        costs[tenant.id].utilities[utilityType] = {
          invoice_total: invoiceTotal,
          percentage,
          amount,
          metered: meteredRes.metered,
          metered_valid: meteredRes.metered ? !!meteredRes.valid : true,
          detail: meteredRes.metered ? meteredRes : null,
        };
        costs[tenant.id].total += amount;
      });
```

Adaugă `meteredInputs`, `invoicesByType`, `gasConsumptionByTenant`, `waterConsumptionByTenant` în array-ul de dependențe al `useMemo` pentru `tenantCosts`.

- [ ] **Step 5: `companyPortions` folosește procentul efectiv**

În `companyPortions` (`:298-301`), înlocuiește suma procentelor cu cea din `tenantCosts`:

```jsx
      activeTenants.forEach((tenant) => {
        tenantPctSum += tenantCosts[tenant.id]?.utilities?.[utilityType]?.percentage || 0;
      });
```

Adaugă `tenantCosts` în dependențele `useMemo` pentru `companyPortions` (și scoate `tenantPercentages` dacă nu mai e folosit acolo).

- [ ] **Step 6: Afișează desfășurarea în cardul chiriașului**

În randarea cardului per utilitate (zona `:979-995`, acolo unde se afișează procentul/costul per utilitate), pentru utilitățile cu `utilities[utilityType].metered === true` afișează read-only procentul calculat și desfășurarea, în loc de `InputNumber` editabil. Exemplu de afișaj (adaptat la structura existentă a rândului de utilitate):

```jsx
{u.metered ? (
  u.metered_valid ? (
    <span>
      {u.percentage.toFixed(2)}% → {formatCurrency(u.amount)}
      {u.detail && u.detail.rainShare != null && (
        <><br />
        <small>
          consum {formatCurrency(u.detail.consumptionShare)} + pluvială {formatCurrency(u.detail.rainShare)}
        </small></>
      )}
    </span>
  ) : (
    <Tag color="warning">Lipsește total m³ sau citirea — completați blocul Contori</Tag>
  )
) : (
  /* randarea existenta cu InputNumber editabil pentru procent */
)}
```

Notă implementator: `u` = `tenantCosts[tenant.id].utilities[utilityType]`. Păstrează câmpul editabil pentru utilitățile non-metered exact cum e acum; doar pentru metered îl înlocuiești cu afișaj read-only.

- [ ] **Step 7: Verifică lint**

Run: `cd frontend && npm run lint`
Expected: fără erori noi.

- [ ] **Step 8: Verificare manuală (exemplul de referință)**

Cu backend + frontend pornite, pe o lună cu un chiriaș care are: contor gaz+apă, citire gaz consum 4.3 (total 57, factură gaz 300), citire apă consum 1.1 (total 47, factură apă 1883.58, pluvială 779.14, rain 20%):
- Cardul arată la Gaz `7.54% → 22.63 RON`.
- Cardul arată la Apă `9.65% → 181.68 RON` cu desfășurarea `consum 25.85 + pluvială 155.83`.
- Cota proprietarului scade corespunzător.
- Dacă ștergi total m³, cardul arată avertismentul, nu un număr.

- [ ] **Step 9: Rulează toate testele relevante**

Run:
```bash
cd backend && prove -l t/integration/03_tenants.t t/integration/05_metered_inputs.t t/unit/07_metered_utility_calculator.t t/unit/08_invoice_generator_metered_breakdown.t
cd ../frontend && node --test src/utils/meteredCalc.test.js && npm run lint
```
Expected: PASS pe toate.

- [ ] **Step 10: Commit**

```bash
git add frontend/src/pages/UtilityCalculations.jsx
git commit -m "feat: live metered reflection in tenant cards with correct totals"
```

---

## Self-Review (verificare față de spec)

**Acoperire spec:**
- A (fix reset) → Task 1 (backend) + Task 6 Step 6 (carduri read-only). ✓
- B (bloc mereu vizibil, auto-draft, derivare afișată) → Task 5. ✓
- C (reflectare live + totaluri) → Task 4 (getByPeriod) + Task 6. ✓
- D (derivare backend + modul pur) → Task 2 + Task 3. ✓
- Fără schemă DB / fără PDF → respectat (niciun task nu le atinge). ✓
- Cazuri limită (total 0, consum 0, fără citire) → Task 3 (teste) + Task 6 Step 6/8. ✓

**Consistență tipuri:** `computeGasShare`/`computeWaterShare` folosite identic în Task 3 și Task 6; câmpurile `percentage/amount/valid/rainShare/consumptionShare/consumptionCost` coincid. `getByPeriod(year, month)` definit în Task 4, consumat în Task 6. ✓

**Placeholdere:** pașii cu cod conțin cod complet. Două note explicite de implementator (forma răspunsului `create` în Task 5 Step 2; structura rândului de utilitate din card în Task 6 Step 6) sunt puncte reale de adaptare la cod existent, nu placeholdere de logică — ambele indică exact ce să verifice.

---

### Task 7: Fix — metered amounts must reach the persisted/finalized invoice (not shadowed by flat overrides)

**Problem (found in final review):** `UtilityCalculator::calculate_shares` uses a flat override whenever `overrides->{tenant}{utility}` is defined; the create route posts `overrides` for ALL tenant/utility pairs, so the metered branch never runs via HTTP and `finalize` doesn't recompute. Result: the live card shows metered amounts but the persisted/finalized/PDF invoice bills flat percentages.

**Fix:** (1) frontend excludes metered `(tenant, utility)` pairs from the overrides payload so they fall through to `_resolve_tenant_share`; (2) `_resolve_tenant_share` is non-fatal on missing metered data unless `strict` (so auto-draft creation before inputs exist does not roll back); (3) `finalize` surgically recomputes ONLY metered detail rows (strict) — leaving non-metered details, which carry any ad-hoc overrides, untouched — and blocks with a clear error if metered data is missing.

**Files:**
- Modify: `backend/lib/PropertyManager/Services/UtilityCalculator.pm` (`_resolve_tenant_share` strict param; new `recompute_metered_details`)
- Modify: `backend/lib/PropertyManager/Routes/UtilityCalculations.pm` (`finalize` recompute)
- Modify: `frontend/src/pages/UtilityCalculations.jsx` (`buildSaveOverrides`, used in `handleSaveCalculation` + `ensureCalculation`)
- Test: `backend/t/integration/06_metered_finalize.t` (create)

**Interfaces:**
- Produces: `UtilityCalculator::recompute_metered_details($calculation_id)` — upserts metered `UtilityCalculationDetail` rows (strict); dies with `Missing ...` on absent reading/inputs. `_resolve_tenant_share(..., strict => 0|1)`.

- [ ] **Step 1: Write the failing integration test**

Create `backend/t/integration/06_metered_finalize.t`:

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";
use TestHelper;
use JSON::XS;

my $test   = TestHelper::app();
my $schema = TestHelper::schema();

# Clean slate for the involved tables
for my $rs (qw(UtilityCalculationDetail MeteredCalculationInput UtilityCalculation
               GasReading WaterReading ReceivedInvoice TenantUtilityPercentage)) {
    eval { $schema->resultset($rs)->delete_all };
}

my $tenant = TestHelper::create_test_tenant($schema, name => 'Finalize Metered');
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'gas', percentage => 0, uses_meter => 1 });
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'water', percentage => 20, uses_meter => 1 });

my $gas_inv = TestHelper::create_test_received_invoice($schema,
    utility_type => 'gas', period_start => '2026-06-01', period_end => '2026-06-30',
    invoice_date => '2026-06-30', due_date => '2026-07-15', amount => 300.00);
my $water_inv = TestHelper::create_test_received_invoice($schema,
    utility_type => 'water', period_start => '2026-06-01', period_end => '2026-06-30',
    invoice_date => '2026-06-30', due_date => '2026-07-15', amount => 1883.58);

$schema->resultset('GasReading')->create({ tenant_id => $tenant->id,
    reading_date => '2026-06-30', reading_value => 104.30, previous_reading_value => 100.00,
    consumption => 4.30, period_month => 6, period_year => 2026 });
$schema->resultset('WaterReading')->create({ tenant_id => $tenant->id,
    reading_date => '2026-06-30', reading_value => 101.10, previous_reading_value => 100.00,
    consumption => 1.10, period_month => 6, period_year => 2026 });

my $calc = $schema->resultset('UtilityCalculation')->create({
    period_month => 6, period_year => 2026, is_finalized => 0 });
$schema->resultset('MeteredCalculationInput')->create({ calculation_id => $calc->id,
    received_invoice_id => $gas_inv->id, utility_type => 'gas', total_units => 57.00 });
$schema->resultset('MeteredCalculationInput')->create({ calculation_id => $calc->id,
    received_invoice_id => $water_inv->id, utility_type => 'water', total_units => 47.00,
    consumption_amount => 1104.44, rain_amount => 779.14 });

# Simulate the bug's aftermath: persisted details are WRONG (flat) before finalize.
$schema->resultset('UtilityCalculationDetail')->create({ calculation_id => $calc->id,
    tenant_id => $tenant->id, utility_type => 'gas', received_invoice_id => $gas_inv->id,
    percentage => 0.00, amount => 0.00 });
$schema->resultset('UtilityCalculationDetail')->create({ calculation_id => $calc->id,
    tenant_id => $tenant->id, utility_type => 'water', received_invoice_id => $water_inv->id,
    percentage => 20.00, amount => 376.72 });

subtest 'finalize recomputes metered details to the meter-based amounts' => sub {
    plan tests => 5;

    my $res = TestHelper::auth_post($test, '/api/utility-calculations/' . $calc->id . '/finalize', {});
    is($res->code, 200, 'finalize OK');

    my $gas_d = $schema->resultset('UtilityCalculationDetail')->search({
        calculation_id => $calc->id, tenant_id => $tenant->id, utility_type => 'gas' })->first;
    my $water_d = $schema->resultset('UtilityCalculationDetail')->search({
        calculation_id => $calc->id, tenant_id => $tenant->id, utility_type => 'water' })->first;

    is(sprintf('%.2f', $gas_d->amount),   '22.63',  'gas amount is meter-based (4.3/57 * 300)');
    is(sprintf('%.2f', $gas_d->percentage), '7.54', 'gas percentage is meter-based');
    is(sprintf('%.2f', $water_d->amount), '181.68', 'water amount is meter-based (rain + consum)');
    is(sprintf('%.2f', $water_d->percentage), '9.65', 'water effective percentage');
};

done_testing;
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `docker compose run --rm -T backend prove -l t/integration/06_metered_finalize.t`
Expected: FAIL — finalize does not recompute, so gas amount stays `0.00` (and water `376.72`), not `22.63`/`181.68`.

- [ ] **Step 3: Add `strict` to `_resolve_tenant_share`**

In `backend/lib/PropertyManager/Services/UtilityCalculator.pm`, in `_resolve_tenant_share`, read the flag and make the three data-missing `die`s conditional. Change the signature/args extraction to include `strict`, and replace the three guards:

```perl
    my ($tenant_id, $utility_type, $invoice, $year, $month, $calculation_id, $strict) =
        @args{qw(tenant_id utility_type invoice year month calculation_id strict)};
```

Then replace the guard blocks (metered branch) so each yields 0 when not strict:

```perl
    my $inputs = $self->{schema}->resultset('MeteredCalculationInput')->search({
        calculation_id => $calculation_id,
        utility_type   => $utility_type,
    })->first;

    unless ($inputs) {
        die "Missing metered inputs for $utility_type in calculation $calculation_id\n" if $strict;
        return { percentage => 0, amount => 0 };
    }

    my $reading_rs = $utility_type eq 'gas' ? 'GasReading' : 'WaterReading';
    my $reading = $self->{schema}->resultset($reading_rs)->search({
        tenant_id    => $tenant_id,
        period_year  => $year,
        period_month => $month,
    })->first;

    unless ($reading) {
        die "Missing $utility_type reading for tenant $tenant_id / $year-$month\n" if $strict;
        return { percentage => 0, amount => 0 };
    }

    my $tenant_units = defined $reading->consumption
        ? $reading->consumption
        : ($reading->reading_value - ($reading->previous_reading_value // 0));

    my $total_units = $inputs->total_units;
    unless ($total_units > 0) {
        die "total_units must be > 0 for metered $utility_type\n" if $strict;
        return { percentage => 0, amount => 0 };
    }
```

Leave the rest of the metered math (gas ratio; water consumption/rain) unchanged.

- [ ] **Step 4: Thread `strict` through `calculate_shares`**

In `backend/lib/PropertyManager/Services/UtilityCalculator.pm`, in `calculate_shares`, read the flag near the top:

```perl
    my $strict = $params{strict} ? 1 : 0;
```

and pass it in the `_resolve_tenant_share` call (the `else` branch):

```perl
            } else {
                $share = $self->_resolve_tenant_share(
                    tenant_id      => $tenant_id,
                    utility_type   => $utility_type,
                    invoice        => $invoice,
                    year           => $year,
                    month          => $month,
                    calculation_id => $calculation_id,
                    strict         => $strict,
                );
            }
```

- [ ] **Step 5: Add `recompute_metered_details` to the calculator**

In `backend/lib/PropertyManager/Services/UtilityCalculator.pm`, add this public method (e.g. just before the final `1;` of the package body, after `get_invoices_for_period`):

```perl
=head2 recompute_metered_details

Recompute and upsert ONLY the metered (gas/water uses_meter) UtilityCalculationDetail
rows for a calculation, using strict resolution (dies on missing reading/inputs).
Non-metered details are left untouched so ad-hoc percentage overrides survive.

=cut

sub recompute_metered_details {
    my ($self, $calculation_id) = @_;
    my $schema = $self->{schema};

    my $calc = $schema->resultset('UtilityCalculation')->find($calculation_id)
        or die "Calculation $calculation_id not found\n";
    my $year  = $calc->period_year;
    my $month = $calc->period_month;

    my @tenants = $schema->resultset('Tenant')->search({ is_active => 1 })->all;
    foreach my $tenant (@tenants) {
        foreach my $ut (qw(gas water)) {
            my $up = $schema->resultset('TenantUtilityPercentage')->search({
                tenant_id => $tenant->id, utility_type => $ut,
            })->first;
            next unless $up && $up->uses_meter;

            my $mci = $schema->resultset('MeteredCalculationInput')->search({
                calculation_id => $calculation_id, utility_type => $ut,
            })->first;
            die "Missing metered inputs for $ut in calculation $calculation_id\n" unless $mci;

            my $invoice = $schema->resultset('ReceivedInvoice')->find($mci->received_invoice_id)
                or die "Metered input for $ut references a missing invoice\n";

            my $share = $self->_resolve_tenant_share(
                tenant_id      => $tenant->id,
                utility_type   => $ut,
                invoice        => $invoice,
                year           => $year,
                month          => $month,
                calculation_id => $calculation_id,
                strict         => 1,
            );

            my %vals = (
                received_invoice_id => $invoice->id,
                percentage          => sprintf('%.2f', $share->{percentage}),
                amount              => sprintf('%.2f', $share->{amount}),
            );

            my $detail = $schema->resultset('UtilityCalculationDetail')->search({
                calculation_id => $calculation_id,
                tenant_id      => $tenant->id,
                utility_type   => $ut,
            })->first;

            if ($detail) {
                $detail->update(\%vals);
            } else {
                $schema->resultset('UtilityCalculationDetail')->create({
                    calculation_id => $calculation_id,
                    tenant_id      => $tenant->id,
                    utility_type   => $ut,
                    %vals,
                });
            }
        }
    }
    return 1;
}
```

- [ ] **Step 6: Make `finalize` recompute metered details**

In `backend/lib/PropertyManager/Routes/UtilityCalculations.pm`, replace the body of `post '/:id/finalize'` after the `is_finalized` 409 check (the `$calc->update({...})` block) with a recompute wrapped in a transaction:

```perl
    my ($error, $missing_data);
    try {
        schema->txn_do(sub {
            $calculator->recompute_metered_details($calc->id);
            $calc->update({
                is_finalized => 1,
                finalized_at => DateTime->now,
            });
        });
    } catch {
        $error = $_;
        $missing_data = ($error =~ /Missing|references a missing|must be > 0/);
        error("Failed to finalize calculation: $error");
    };

    if ($error) {
        status($missing_data ? 422 : 500);
        return { success => 0, error => "$error" };
    }

    return { success => 1, data => { calculation => { $calc->get_columns } } };
```

Ensure `$calculator` is the same service instance used by the `POST ''` route (it is a module-level `my $calculator = ...` in this file — reuse it; do not create a new one).

- [ ] **Step 7: Run the integration test (GREEN) + metered regressions**

Run:
```bash
docker compose run --rm -T backend prove -l t/integration/06_metered_finalize.t t/unit/07_metered_utility_calculator.t t/unit/08_invoice_generator_metered_breakdown.t t/integration/05_metered_inputs.t
```
Expected: PASS on all. (07 calls `calculate_shares` without `strict`, so the non-fatal path must not change its existing assertions.)

- [ ] **Step 8: Frontend — exclude metered pairs from the overrides payload**

In `frontend/src/pages/UtilityCalculations.jsx`, add a helper near `handleSaveCalculation` (before it):

```jsx
  // Build the overrides payload for create/finalize, EXCLUDING metered
  // (tenant, gas|water) pairs so the backend computes those from meters
  // instead of a flat percentage.
  const buildSaveOverrides = () => {
    const out = {};
    activeTenants.forEach((tenant) => {
      const perUtil = {};
      UTILITY_TYPE_OPTIONS.forEach((option) => {
        const ut = option.value;
        const up = (tenant.utility_percentages || []).find((x) => x.utility_type === ut);
        if (up && up.uses_meter && (ut === 'gas' || ut === 'water')) return; // metered → backend computes
        perUtil[ut] = tenantPercentages[tenant.id]?.[ut] || 0;
      });
      out[tenant.id] = perUtil;
    });
    return out;
  };
```

Then use it in `handleSaveCalculation`:

```jsx
  const handleSaveCalculation = () => {
    createMutation.mutate({
      period_year: selectedYear,
      period_month: selectedMonth,
      overrides: buildSaveOverrides(),
    });
  };
```

and in `ensureCalculation` (replace `overrides: tenantPercentages` with `overrides: buildSaveOverrides()`):

```jsx
    const res = await createMutation.mutateAsync({
      period_year: selectedYear,
      period_month: selectedMonth,
      overrides: buildSaveOverrides(),
    });
```

- [ ] **Step 9: Frontend gates**

Run: `cd frontend && npm run lint && npm run build`
Expected: no new lint errors for `UtilityCalculations.jsx`; build succeeds.

- [ ] **Step 10: Commit**

```bash
git add backend/lib/PropertyManager/Services/UtilityCalculator.pm backend/lib/PropertyManager/Routes/UtilityCalculations.pm frontend/src/pages/UtilityCalculations.jsx backend/t/integration/06_metered_finalize.t
git commit -m "fix: metered amounts persist to finalized calculation and invoice"
```
