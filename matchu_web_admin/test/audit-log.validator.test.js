const test = require('node:test');
const assert = require('node:assert/strict');

const {
  validateAuditLogQuery,
  __test
} = require('../src/validators/audit-log.validator');

test('normalizes audit filters and Bangkok date boundaries', () => {
  const result = validateAuditLogQuery({
    q: '  USER_SUSPEND  ',
    category: 'users',
    result: 'success',
    from: '2026-07-28',
    to: '2026-07-29',
    limit: '50'
  });

  assert.equal(result.error, null);
  assert.equal(result.value.q, 'USER_SUSPEND');
  assert.equal(result.value.limit, 50);
  assert.equal(result.value.fromDate.toISOString(), '2026-07-27T17:00:00.000Z');
  assert.equal(result.value.toDate.toISOString(), '2026-07-29T16:59:59.999Z');
});

test('rejects impossible dates, reversed ranges and unknown filters', () => {
  assert.ok(validateAuditLogQuery({ from: '2026-02-31' }).error);
  assert.ok(validateAuditLogQuery({ from: '2026-08-01', to: '2026-07-01' }).error);
  assert.ok(validateAuditLogQuery({ category: 'billing' }).error);
  assert.ok(validateAuditLogQuery({ unexpected: 'value' }).error);
});

test('creates the exact start and end of a Vietnam calendar day', () => {
  assert.equal(
    __test.bangkokBoundary('2026-01-01', false).toISOString(),
    '2025-12-31T17:00:00.000Z'
  );
  assert.equal(
    __test.bangkokBoundary('2026-01-01', true).toISOString(),
    '2026-01-01T16:59:59.999Z'
  );
});
