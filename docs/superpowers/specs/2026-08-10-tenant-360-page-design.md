# Tenant 360 — Read-only Tenant Detail Page

**Date:** 2026-08-10
**Status:** Approved design, ready for implementation plan
**Scope:** A new read-only "tenant 360" page reached by clicking a tenant row on
`/tenants`. Shows the tenant's details, KPIs, four analytical charts, their
invoices, and a statement ledger. One new aggregate backend endpoint; the two
tabular sections reuse existing endpoints. No new write paths.

---

## 1. Problem

On `/tenants`, clicking a row currently does the same thing as the edit quick
action — it opens the edit form. There is no way to *view* a tenant: their
billing history, how promptly they pay, what utilities they carry, or which
data is missing. The polished screenshots in `analysis/` already sketch this
view; this spec turns the single-tenant parts of them into a real page.

## 2. Goals

- Clicking a tenant row opens a read-only detail page; editing stays an explicit
  action, so "look at" and "change" are no longer conflated.
- Surface, in one place: tenant details, headline KPIs, four charts (payment
  behaviour, utility allocation, metered consumption, data completeness), the
  tenant's invoices, and their statement of account.
- Compute the analytics server-side in one call (no N+1 from the browser).

## 3. Non-goals

- **Read-only.** No editing, no new mutations. Edits continue through the
  existing edit form.
- The **multi-tenant / portfolio** cards in the screenshots ("tenants by
  outstanding", "metered vs billed", "consumption by tenant" small-multiples)
  are a dashboard concern, not a single-tenant 360 — excluded here.
- No schema changes.

## 4. Interaction & routing

- New route **`/tenants/:id`** → `TenantDetail` page.
- On `/tenants`: **row click navigates to `/tenants/:id`** (replacing
  row-click-opens-edit). The pencil **edit** quick action and the other quick
  actions stay. A back affordance returns to the list.
- Deep-linkable and refresh-safe (state comes from the URL param).

## 5. Backend — one new aggregate endpoint

`GET /api/tenants/:id/overview` (auth required, read-only). Returns the
analytical read-model, computed with grouped SQL rather than per-row loops:

```jsonc
{
  "success": 1,
  "data": {
    "tenant": { /* tenant columns + utility_percentages[] */ },
    "kpis": {
      "billed_ron": 12480.07,
      "paid_ron": 9200.00,
      "outstanding_ron": 3280.07,
      "open_count": 3,
      "oldest_unpaid_days": 198,      // max(today - due_date) over unpaid; null if none
      "avg_days_to_pay": 34            // avg(paid_date - invoice_date) over paid; null if none
    },
    "payment_behaviour": [             // one point per PAID invoice
      { "invoice_date": "2026-01-15", "days_to_pay": 22 }
    ],
    "utility_allocation": [            // finalized calcs only
      { "utility_type": "electricity", "total_ron": 12488.07 },
      { "utility_type": "gas", "total_ron": 9730.29 }
      // a utility with a standing rate but 0 billed is included as total_ron 0
    ],
    "metered_consumption": {           // per utility the tenant is metered for
      "electricity": [ { "period": "2026-06", "value": 701 }, { "period": "2026-05", "value": null } ]
      // value is null for a period with NO reading — a gap, never 0
    },
    "data_completeness": {
      "empty_fields": ["j_number", "postal_code", "phone", "contract_start", "contract_end", "notes"],
      "not_modelled": ["deposit", "area_sqm", "lease_term", "signed_contract", "contact_person", "iban"]
    }
  }
}
```

**Definitions / rules:**
- KPIs are over **all** the tenant's invoices (rent + utility + generic).
- `utility_allocation` sums `utility_calculation_details.amount` grouped by
  `utility_type` for this tenant, across `is_finalized = 1` calculations only.
- `metered_consumption` reads the tenant's period readings (electricity via
  `meter_readings`/`electricity_meters`, gas via `gas_readings`, water via
  `water_readings`) for the utilities where the tenant `uses_meter`. **A period
  with no reading is emitted as `null`, never `0`** — the same distinction whose
  absence caused earlier billing bugs.
- `data_completeness.empty_fields` is derived from the tenant record (null/empty
  columns); `not_modelled` is a static list of things the schema can't yet hold.

**Testable in isolation:** an integration test seeds a tenant with invoices,
finalized calcs, and readings (including one missing period) and asserts each
block.

## 6. Backend — tables reuse existing endpoints

- Invoices table → `GET /api/invoices?tenant_id=:id` (already filters by tenant).
- Statement ledger → `GET /api/dashboard/reports/tenant-statement/:tenant_id`
  (already returns a chronological invoice+payment ledger with running balance).

No changes to these endpoints.

## 7. Frontend — page structure

New `pages/TenantDetail/` (a small directory of focused components + the page
shell — not one large file). Charts use Recharts, already used on the Dashboard;
formatting uses the existing `formatCurrency` / `formatDate`.

Top to bottom:
1. **Header** — tenant name + type/status tag · `Editează` (navigates to the
   existing edit form) · back to `/tenants`.
2. **Details card** — address, CUI / J-number, contact, utility percentages
   (read-only).
3. **KPI row** — Billed · Paid · Outstanding (+ open count) · Oldest unpaid
   (aging days) · Avg days-to-pay.
4. **Charts grid (2×2):**
   - *Comportament de plată* — scatter, days-to-pay vs issue date. Unpaid
     invoices are intentionally absent (no lag); caption says so.
   - *Alocare utilități* — horizontal bar, RON per utility.
   - *Consum contorizat* — line(s) per metered utility; a `null` period is a
     gap in the line, not a zero.
   - *Completitudine date* — the empty-fields and not-modelled lists.
5. **Tabs** — `Facturi` (invoices table) · `Fișă cont` (statement ledger).

Each section handles its own empty state (no invoices → zeroed KPIs + empty
charts with a short "nimic de afișat"; not metered → consumption card says so).

## 8. Error handling & edge cases

- Tenant not found → 404 handled with a friendly page state.
- No invoices → KPIs are 0 / null, charts show empty states (not errors).
- No finalized calcs → `utility_allocation` empty.
- Not metered / no readings → `metered_consumption` empty or all-null series.
- Missing period in a metered series → `null` (gap), asserted in tests.
- The page is wrapped by the existing route-level `ErrorBoundary`.

## 9. Testing

- **Backend:** integration test for `/overview` — KPI math (billed/paid/
  outstanding/open/aging/avg-days), allocation sums per utility over finalized
  calcs, a consumption series with a deliberately missing period asserted as
  `null`, and data-completeness flags. Reuses `TestHelper`.
- **Frontend:** any non-trivial KPI/series shaping extracted to a small pure
  module and unit-tested (mirroring `meteredCalc`); build + lint gates. No
  mutation paths (read-only page).

## 10. Build order

1. Backend `/overview` endpoint + service method + test (headless, first).
2. Route + page shell + header + details card + KPI row (data from `/overview`).
3. The four chart cards.
4. Invoices tab + statement ledger tab (existing endpoints).
5. Wire the `/tenants` row click to navigate; keep edit as a quick action.

## 11. Open items to confirm at plan time

- Whether `metered_consumption` covers only electricity (as the screenshot) or
  all metered utilities for the tenant. Default: all the tenant is metered for.
- The exact `not_modelled` list (align with the schema-extension doc's proposed
  fields).
