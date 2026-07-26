# Utility Wizard — Plan B: Wizard UI, Compare & Reopen

**Date:** 2026-07-26
**Status:** Approved design, ready for implementation plan
**Depends on:** Plan A (`...-plan-a-engine-foundation-design.md`) — the engine
must accept an explicit invoice list, sum multiple invoices per utility, and the
`is_sandbox` / `billed_in_calculation_id` columns must exist.
**Scope:** A new, self-contained "wizard" page and its backend endpoints that
guide a period's utility calculation through explicit gates, persist to isolated
sandbox storage, let you diff against the real calculation, and support
reopen + regenerate-in-place. The existing Utility Calculations screen and its
routes are left untouched.

---

## 1. Problem

The current calculation flow has four verbs (`Salvează %`, `Salvează Calcul`,
save meter inputs, `Finalizează`) that must be performed in an undocumented,
order-dependent sequence, each with a silent failure mode. This has repeatedly
produced wrong or missing charges (electricity dropped, metered inputs not
applied, the full meter index billed when a reading was missing). The fix is a
**guided, linear flow with precondition gates** — a finalize you cannot reach
until the inputs are complete and valid — built as a **parallel sandbox** so the
working screen is never at risk and results can be compared before cutover.

## 2. Goals

- A step-by-step wizard that makes the correct sequence the only sequence.
- **Gates** that block on genuinely dangerous gaps (a metered tenant with no
  reading) while allowing legitimate exceptions (a utility invoice that hasn't
  arrived — bill it later).
- **Isolation:** the wizard persists sandbox calculations (`is_sandbox = 1`)
  that never collide with the real calculation for the period.
- **Compare:** a tenant-by-tenant, utility-by-utility diff of a sandbox calc
  against the real calc for the same period, to validate parity before trusting
  the wizard.
- **Late invoices handled:** a June invoice arriving in July is billed in July
  (unbilled-invoice selection), summed with July's own invoice (Plan A #1 fix).
- **Reopen & regenerate** a finalized sandbox calc, reusing the same invoice
  numbers, while it is safe to do so (draft invoices only).

## 3. Non-goals

- No changes to the existing Utility Calculations screen or its routes.
- No storno / credit-note concept (reopen is draft-only; §4.6).
- No proration, no VAT (out of scope company-wide), no multi-property.
- No automatic cutover. Promotion of a sandbox calc to "real" is a deliberate,
  later step (§4.7), not part of the core flow.

## 4. Design

### 4.1 Surfaces

- **Frontend:** a new route `/utility-wizard` and `pages/UtilityWizard/` (a
  small directory of focused step components + a shared wizard controller —
  deliberately *not* one 1,400-line file). Uses the existing services and the
  `MoneyInput` / gate patterns.
- **Backend:** new routes under `prefix '/api/utility-wizard'`, operating only
  on `is_sandbox = 1` calculations, reusing `UtilityCalculator` and
  `InvoiceGenerator`. No existing route is modified.

### 4.2 Utility-payer derivation

A tenant is a **utility-payer for a period** if they are active and have at
least one utility allocation with `percentage > 0` or `uses_meter = 1`. Derived,
no schema flag (confirmed in Plan A design review; revisit only if an explicit
per-tenant on/off is wanted). The rent-only tenant (e.g. Foodamina) is correctly
excluded.

### 4.3 The steps and gates

| # | Step | Gate |
|---|------|------|
| 1 | **Period** | pick month/year; loads or creates the sandbox calc for `(period, is_sandbox=1)` |
| 2 | **Tenants** | show derived utility-payers; confirm the set (informational) |
| 3 | **Received invoices** | list **unbilled** invoices grouped by utility; select which to bill now. A utility with no unbilled invoice can be marked **"nefacturat luna aceasta"** and skipped. **Soft gate** — proceed allowed. |
| 4 | **Readings** | for every metered `(tenant, utility)` a reading for the month must exist; flag negative / implausible consumption. **Hard gate** — blocks finalize. |
| 5 | **Metered inputs** | per metered utility: total m³ and (water) rainwater value; consumption value derived. **Hard gate** for metered utilities that have a selected invoice. |
| 6 | **Allocation** | per-tenant, per-utility percentages (the current right-panel logic, linearised and validated); live preview of amounts using the Plan A engine over the *selected* invoices. |
| 7 | **Review & finalize** | shows the full breakdown + the **compare panel** (§4.4); **Finalize** persists details, marks the selected invoices `billed_in_calculation_id = calc.id`. |
| 8 | **Generate invoices** | one issued invoice per tenant; regenerate reuses numbers (§4.6). |

The wizard controller enforces that finalize is disabled until steps 4–5 hard
gates pass, with an explicit "what's missing" list (the disabled-until-complete
pattern that would have prevented the electricity saga).

### 4.4 Compare panel

For the selected period, if a **real** calc (`is_sandbox = 0`, from the old
flow) exists, show a diff table: per tenant × utility, `real amount` vs
`sandbox amount`, with deltas highlighted. Since both use the same engine, a
non-zero delta means the wizard fed different inputs (different invoice
selection, different percentages, a recovered electricity share) — which is the
signal to inspect. If no real calc exists for the period, the panel says so
(nothing to compare — a fresh month).

### 4.5 Invoice selection & late invoices

Step 3 lists invoices where `billed_in_calculation_id IS NULL`. Selecting them
and finalizing marks them billed. A June invoice entered in July is still
unbilled in July → it appears in July's step 3 alongside July's own invoice;
selecting both bills both, and the Plan A engine sums them. This is how the late
invoice reaches "two invoices per utility" without touching June's finalized
calc.

### 4.6 Reopen & regenerate (draft-only, reuse numbers)

- **Reopen** a finalized sandbox calc → set `is_finalized = 0`; its details and
  metered inputs remain; its invoices' `billed_in_calculation_id` stays (still
  billed by this calc). The wizard returns to the allocation step.
- **Guard:** reopen-then-regenerate is **blocked if any issued invoice for the
  calc is paid** (`is_paid = 1`). We track paid, not "sent"; the sent case rests
  on operator discipline and is a documented limitation.
- **Regenerate** recomputes and, for each existing issued invoice, **updates it
  in place**: same `invoice_number`, same `invoice_date`, new line items /
  `subtotal_ron` / `total_ron`, regenerated PDF. No new number is minted; the
  fiscal series is preserved. Tenants that gained/lost a share get an
  item/amount update, not a new invoice.

### 4.7 Promotion (cutover) — deliberately minimal

A "Promovează" action flips a finalized sandbox calc to `is_sandbox = 0`,
replacing the real calc for that period (deleting the old real calc if present).
This is how a validated wizard result becomes the system of record. It is a
single explicit action, out of the core loop, and can be deferred until after
the wizard is trusted. Until promotion, the old screen remains the source of
truth and is untouched.

## 5. Data flow

1. Enter received invoices (existing screen) — unbilled by default.
2. Enter readings and metered inputs (wizard steps 4–5, or existing screens).
3. Wizard step 3 selects unbilled invoices; steps 4–6 gate and allocate.
4. Finalize → engine computes over selected invoices → details persisted with
   `is_sandbox = 1`; selected invoices marked billed.
5. Compare against the real calc if one exists.
6. Generate invoices; reopen/regenerate in place while draft.
7. (Later) Promote to replace the real calc.

## 6. Error handling & edge cases

- **Metered tenant, no reading:** hard gate blocks finalize with a clear list.
- **Negative / implausible consumption:** flagged at step 4 (out-of-range vs the
  tenant's own history, or below a general meter's sub-meter sum).
- **Utility invoice missing:** soft — mark "nefacturat", proceed; it stays
  unbilled and surfaces next month.
- **Reopen when paid:** blocked with a clear message.
- **Over-allocation (>100%):** non-blocking warning (owner has override power).
- **Deleting a sandbox calc:** releases its invoices to unbilled (Plan A FK).

## 7. Testing

- **Parity (the point of the sandbox):** an integration test that runs the
  wizard's finalize path for each historical period's inputs and asserts the
  sandbox result equals the stored real result — the automated form of the
  compare panel.
- Gate tests: hard gate blocks finalize on a missing reading; soft gate allows
  proceed on a missing invoice; over-allocation warns.
- Late-invoice test: unbilled June invoice billed in July, summed with July's.
- Reopen/regenerate: in-place update keeps number/date, changes amounts;
  blocked when paid.
- Promotion: replaces the real calc; old real calc removed.
- Frontend: the allocation/preview logic extracted to a pure, tested module
  (mirroring `meteredCalc`); step components covered by build+lint at minimum.

## 8. Build order within Plan B

1. Backend wizard endpoints (period/load, invoice selection, finalize, compare,
   reopen, regenerate, promote) with tests — headless, testable without UI.
2. Wizard page shell + step navigation + gate controller.
3. Step components (period, tenants, invoices, readings, metered, allocation,
   review, generate).
4. Compare panel.
5. Reopen / regenerate / promote UI.

## 9. Open items to confirm at plan time

- Whether steps 4–5 (readings, metered inputs) enter data directly in the wizard
  or link out to the existing Gas/Water/Meter reading screens. Default: link out
  for entry, gate on presence in the wizard (less duplication).
- Whether "Promotion" (§4.7) ships in Plan B or is a small Plan C once the
  wizard is trusted. Default: include a minimal promote; defer polish.
- Exact "implausible reading" thresholds (§6) — needs one rule from the owner.
