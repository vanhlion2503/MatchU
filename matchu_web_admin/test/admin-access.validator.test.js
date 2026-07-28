const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validateListQuery,
  validateGrant,
  validateAccessUpdate,
  validateStatusUpdate
} = require('../src/validators/admin-access.validator');

test('normalizes a valid admin grant and removes CSRF metadata', () => {
  const result = validateGrant({
    _csrf: 'csrf-token',
    identifier: '  moderator@matchu.test  ',
    role: 'moderator',
    permissions: ['dashboard.read', 'users.read', 'users.warn']
  });

  assert.equal(result.error, undefined);
  assert.equal(result.value.identifier, 'moderator@matchu.test');
  assert.deepEqual(result.value.permissions, ['dashboard.read', 'users.read', 'users.warn']);
  assert.equal(result.value._csrf, undefined);
});

test('requires dashboard access for every non-super admin', () => {
  const result = validateAccessUpdate({
    role: 'support',
    permissions: ['users.read']
  });

  assert.ok(result.error);
  assert.match(result.error.message, /quyền xem tổng quan/);
});

test('allows super admin without a redundant permission array', () => {
  const result = validateGrant({
    identifier: 'super-admin-uid',
    role: 'super_admin'
  });

  assert.equal(result.error, undefined);
  assert.deepEqual(result.value.permissions, []);
});

test('rejects unknown roles, permissions and list filters', () => {
  assert.ok(validateGrant({
    identifier: 'admin@matchu.test',
    role: 'owner',
    permissions: ['dashboard.read']
  }).error);
  assert.ok(validateGrant({
    identifier: 'admin@matchu.test',
    role: 'analyst',
    permissions: ['dashboard.read', 'billing.manage']
  }).error);
  assert.ok(validateListQuery({ unexpected: 'value' }).error);
});

test('requires an audit reason when deactivating admin access', () => {
  assert.ok(validateStatusUpdate({
    _csrf: 'token',
    status: 'inactive',
    reason: ''
  }).error);
  const result = validateStatusUpdate({
    _csrf: 'token',
    status: 'inactive',
    reason: 'Điều chuyển sang bộ phận khác'
  });
  assert.equal(result.error, undefined);
  assert.equal(result.value._csrf, undefined);
});
