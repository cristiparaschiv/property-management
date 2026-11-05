/**
 * Rules for the amount of a received invoice.
 *
 * A negative amount is a storno / credit note: the supplier is giving money
 * back. Only "other" invoices may go negative, because the tenant-billed
 * utility types feed the percentage splits that reach tenant invoices, where
 * a negative has no defined meaning yet. The API enforces the same rule.
 */

const NEGATIVE_ALLOWED_FOR = 'other';

// Lower bound for the amount input. undefined means "no lower bound";
// anything but "other" - including nothing selected yet - stays at zero.
export const minAmountFor = (utilityType) =>
  utilityType === NEGATIVE_ALLOWED_FOR ? undefined : 0;

// Validation message for an entered amount, or null when it is acceptable.
// An empty amount is the "required" rule's business, not ours.
export const amountError = (amount, utilityType) => {
  if (amount === undefined || amount === null) return null;
  if (amount >= 0) return null;
  if (utilityType === NEGATIVE_ALLOWED_FOR) return null;
  return 'Sumele negative sunt permise doar pentru facturile de tip „Altele”';
};
