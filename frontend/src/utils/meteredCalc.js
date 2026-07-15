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
