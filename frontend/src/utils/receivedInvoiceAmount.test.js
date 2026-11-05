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

test('tipul "other" nu are limita inferioara', () => {
  assert.equal(minAmountFor('other'), undefined);
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
