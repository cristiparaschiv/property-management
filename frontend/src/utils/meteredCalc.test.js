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
