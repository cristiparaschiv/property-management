import { test } from 'node:test';
import assert from 'node:assert/strict';
import { minAmountFor, amountError } from './receivedInvoiceAmount.js';

// Storno invoices are negative. Only "other" may go negative - the
// tenant-billed types feed the percentage splits behind tenant invoices.

test('tipurile facturate chiriasilor nu coboara sub zero', () => {
  for (const type of ['electricity', 'gas', 'water', 'internet', 'salubrity']) {
    assert.equal(minAmountFor(type), 0, type);
  }
});

// Must be a real negative number, never undefined: MoneyInput declares
// `min = 0` as a destructuring default, and a default fires on undefined, so
// an undefined lower bound silently becomes 0 and keeps blocking the minus.
test('tipul "other" primeste o limita inferioara negativa, nu undefined', () => {
  const min = minAmountFor('other');
  assert.notEqual(min, undefined, 'undefined ar fi inlocuit de valoarea implicita 0');
  assert.ok(min < 0, `limita trebuie sa fie negativa, este ${min}`);
});

// The composition that actually failed in production.
test('limita pentru "other" supravietuieste valorii implicite din MoneyInput', () => {
  const asMoneyInputSeesIt = ({ min = 0 }) => min;
  assert.ok(asMoneyInputSeesIt({ min: minAmountFor('other') }) < 0);
});

test('fara tip selectat ramane limita prudenta', () => {
  assert.equal(minAmountFor(undefined), 0);
});

test('suma negativa este acceptata pentru "other"', () => {
  assert.equal(amountError(-12100, 'other'), null);
});

test('suma negativa este respinsa pentru gaze', () => {
  const err = amountError(-12100, 'gas');
  assert.ok(err, 'trebuie sa returneze un mesaj');
  assert.match(err, /Altele/);
});

test('sumele pozitive si zero trec pentru orice tip', () => {
  assert.equal(amountError(100, 'gas'), null);
  assert.equal(amountError(0, 'gas'), null);
  assert.equal(amountError(100, 'other'), null);
});

test('o suma lipsa nu este raportata aici', () => {
  assert.equal(amountError(undefined, 'gas'), null);
  assert.equal(amountError(null, 'gas'), null);
});
