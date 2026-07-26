# Utility Wizard — Plan A: Engine Foundation

**Date:** 2026-07-26
**Status:** Approved design, ready for implementation plan
**Part of:** the "utility calculation wizard (sandbox)" initiative. This is the
**first of two** specs. Plan B (`...-plan-b-wizard-ui-design.md`) builds the
wizard UI on top of this foundation.
**Scope:** Backend only. No UI. Harden and generalize the shared calculation
engine and add the schema the wizard will need — without changing the behaviour
of the existing Utility Calculations screen on any real historical data.

---

## 1. Problem

The wizard (Plan B) reuses the existing calculation engine rather than
reimplementing it. Before any UI is built on top, the engine has two latent
correctness bugs and lacks two capabilities the wizard requires:

1. **Bug #1 — only one provider invoice per utility per period is billed.**
   `UtilityCalculator::calculate_shares` overwrites `%tenant_shares{tenant}{utility}`
   on each invoice iteration (`UtilityCalculator.pm:126-131`). With two invoices
   of the same utility type in one period, only the last survives; the rest is
   silently absorbed. Verified: two gas invoices (100 + 200) at 50% bill 100,
   not 150.

2. **Bug #2 — an invoice whose service period spans two calendar months is
   billed in both.** `get_invoices_for_period` matches any *overlapping* period,
   so a single mid-May→mid-June invoice is billed fully in May *and* fully in
   June. Verified.

3. **No billed-state on received invoices.** The wizard needs to bill *unbilled*
   invoices (so a June invoice arriving in July is picked up by July's calc
   alongside July's own — two invoices, summed), and to prevent billing the same
   invoice twice. There is nowhere to record that an invoice has been billed.

4. **No sandbox isolation.** The wizard persists its own calculations to compare
   against the real ones for the same period; today a period can hold only one
   calculation and the create path deletes any existing one.

## 2. Goals

- Fix bug #1: sum every provider invoice of a utility, never overwrite.
- Decouple invoice **selection** from **allocation**: the engine allocates a
  caller-supplied list of invoices; each caller decides how to select them.
- Add the schema the wizard needs (`is_sandbox`, `billed_in_calculation_id`),
  additive and unused by the existing flow.
- **Hard parity guarantee:** every one of the 7 finalized historical periods
  produces byte-identical per-tenant, per-utility, and company totals before and
  after this change. Finalized calculations are immutable; any change to their
  output is a bug.

## 3. Non-goals

- No UI. No new user-facing endpoints (the wizard's endpoints are Plan B).
- The existing Utility Calculations screen and its routes keep their current
  behaviour and selection logic (period overlap). This spec does not migrate
  them onto billed-state selection — that is the wizard's model only.
- No change to invoice generation, PDF, or the reopen flow (Plan B).

## 4. Design

### 4.1 Decouple invoice selection from allocation

`calculate_shares` currently fetches its own invoices via
`get_invoices_for_period`. Change it to accept an optional explicit list:

```
$calculator->calculate_shares(
    year           => $year,
    month          => $month,
    overrides      => \%overrides,
    strict         => 0|1,
    calculation_id => $id,
    invoices       => \@invoices,   # NEW, optional
);
```

- When `invoices` is supplied, allocate exactly those.
- When omitted, fall back to `get_invoices_for_period($year, $month)` — so the
  existing route (`Routes/UtilityCalculations.pm`, which does not pass
  `invoices`) is unchanged.

This keeps *selection policy* in the routes: the existing route selects by
period overlap; the wizard route (Plan B) selects unbilled invoices. The engine
only knows how to allocate a set of invoices.

`get_invoices_for_period` stays as-is (used by the old route and available as a
default). Bug #2 is not "fixed" in the old route — it is *avoided* in the wizard
because the wizard never selects by overlap. This is intentional: the old route
is out of scope and, per §5, no historical period actually triggers bug #2.

### 4.2 Fix bug #1 — sum, don't overwrite

In `calculate_shares`, accumulate each tenant's share across all invoices of a
utility instead of replacing it:

- **Non-metered (`_resolve_tenant_share` fixed-% path):** a tenant's utility
  amount becomes `Σ over invoices ( percentage/100 × invoice.amount )`, and the
  effective percentage is reported against the summed invoice total for that
  utility. Two 50% invoices of 100 and 200 → 150 (50% of 300).
- **Metered gas/water:** each invoice contributes `ratio × invoice.amount`
  (gas) or its consumption+rain share (water), summed across the utility's
  invoices. **Metered-multi-invoice caveat:** `metered_calculation_inputs` is
  keyed `(calculation_id, utility_type)` — one row per utility, not per invoice.
  When a utility has more than one invoice in a period, the metered input's
  `total_units` / `consumption_amount` / `rain_amount` describe the *combined*
  provider billing, and the allocation base is the **sum** of the invoices'
  amounts. The implementation plan must add a focused test for metered + two
  invoices; if the combined-input model proves insufficient, that edge is
  escalated rather than guessed.
- `utility_calculation_details` still stores one row per `(calc, tenant,
  utility)` with the summed amount and effective percentage. `received_invoice_id`
  on the detail becomes ambiguous when a utility has multiple invoices; store the
  **first** invoice's id (matching today's single-row-per-utility detail model)
  and rely on billed-state (§4.4) for the full invoice→calc linkage.

### 4.3 Schema: `utility_calculations.is_sandbox`

```sql
ALTER TABLE `utility_calculations`
  ADD COLUMN `is_sandbox` TINYINT(1) NOT NULL DEFAULT 0
    COMMENT 'Wizard sandbox calculation, isolated from the real calc for the period'
    AFTER `is_finalized`;
```

Additive, defaults 0. The existing flow always writes/reads `is_sandbox = 0`;
its "find calc for period" queries gain `is_sandbox => 0` so a sandbox calc for
the same period never collides. (Plan B scopes its queries to `is_sandbox => 1`.)

### 4.4 Schema: `received_invoices.billed_in_calculation_id`

```sql
ALTER TABLE `received_invoices`
  ADD COLUMN `billed_in_calculation_id` INT UNSIGNED DEFAULT NULL
    COMMENT 'The calculation that billed this invoice; NULL = unbilled'
    AFTER `is_paid`,
  ADD KEY `idx_billed_in_calculation_id` (`billed_in_calculation_id`),
  ADD CONSTRAINT `ri_billed_calc_fk`
    FOREIGN KEY (`billed_in_calculation_id`)
    REFERENCES `utility_calculations` (`id`) ON DELETE SET NULL;
```

- NULL = unbilled (all existing rows).
- Set to the calc id when a calc that billed the invoice is **finalized**
  (the setting/clearing logic is exercised by the wizard in Plan B; Plan A adds
  the column, the FK, and a service method `mark_invoices_billed(calc_id,
  \@invoice_ids)` / `clear_invoices_billed(calc_id)` with tests).
- `ON DELETE SET NULL`: deleting a calc releases its invoices back to unbilled.

Plan A does **not** wire billed-state into the existing route (which keeps its
period-overlap selection). It only provides the column and the mechanism.

### 4.5 Result classes

Add the two columns to `Schema/Result/UtilityCalculation.pm` and
`Schema/Result/ReceivedInvoice.pm`, plus the `billed_in_calculation` /
`billed_received_invoices` relations.

## 5. Parity guarantee (the acceptance test)

The historical dump (`analysis/domistra_backup_20260715_122336.sql`) has
**zero** periods with more than one invoice per utility and **zero**
period-spanning invoices (verified during review). Therefore:

- The bug #1 fix changes output **only** in the multi-invoice case, which does
  not occur in history → historical output is unchanged.
- The selection decoupling leaves the old route on `get_invoices_for_period` →
  unchanged.

**Acceptance:** a test loads each of the 7 finalized periods' inputs and asserts
`calculate_shares` produces the same per-tenant, per-utility, company, and total
figures as the stored `utility_calculation_details`. This must pass before and
after the change. New tests additionally prove the multi-invoice summation
(bug #1) and the billed-state mechanism.

## 6. Testing

- **Parity:** the 7-period regression above (the headline gate).
- **Bug #1:** two invoices per utility (non-metered) sum; effective % against
  the summed total.
- **Bug #1 metered:** two gas invoices; two water invoices — combined-input
  allocation (or documented escalation).
- **Selection decoupling:** engine with an explicit `invoices` list allocates
  exactly those; omitting it falls back to period overlap (old behaviour).
- **billed-state:** `mark_invoices_billed` / `clear_invoices_billed`; FK
  `ON DELETE SET NULL` releases invoices when a calc is deleted.
- Full existing metered/tenant/finalize suite stays green.

## 7. Migration & rollout

Two additive `ALTER TABLE`s (both nullable/defaulted), reversible. No data
backfill. No behaviour change to the live flow. Ship independently of Plan B —
it fixes bugs #1/#2-exposure in the current screen on its own.

## 8. Open items to confirm at plan time

- Metered utility with two invoices in one period (§4.2) — confirm the
  combined-input model or escalate.
- Whether to also set `billed_in_calculation_id` from the **existing** route on
  finalize (keeps data consistent if both flows run) or leave it wizard-only.
  Default: wizard-only, to keep the old flow byte-identical.
