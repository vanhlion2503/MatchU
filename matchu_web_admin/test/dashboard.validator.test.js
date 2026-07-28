const test = require('node:test');
const assert = require('node:assert/strict');

const { validateDashboardQuery } = require('../src/validators/dashboard.validator');

test('uses a safe default dashboard range', () => {
  const result = validateDashboardQuery({});
  assert.equal(result.error, undefined);
  assert.equal(result.value.range, 7);
});

test('accepts supported ranges and converts query strings', () => {
  const result = validateDashboardQuery({ range: '30' });
  assert.equal(result.error, undefined);
  assert.equal(result.value.range, 30);
});

test('rejects unsupported ranges and unknown parameters', () => {
  assert.ok(validateDashboardQuery({ range: '365' }).error);
  assert.ok(validateDashboardQuery({ range: '7', unsafe: 'true' }).error);
});
