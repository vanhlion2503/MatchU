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

test('accepts a strong email-password account and strips unused existing identifier', () => {
  const result = validateGrant({
    _csrf: 'csrf-token',
    mode: 'create',
    identifier: 'should-be-removed',
    email: '  New.Admin@MatchU.Test  ',
    displayName: '  New Admin  ',
    password: 'Aa1#bcdef',
    passwordConfirmation: 'Aa1#bcdef',
    role: 'support',
    permissions: ['dashboard.read', 'users.read']
  });

  assert.equal(result.error, undefined);
  assert.equal(result.value.email, 'new.admin@matchu.test');
  assert.equal(result.value.displayName, 'New Admin');
  assert.equal(result.value.identifier, undefined);
});

test('rejects weak or mismatched passwords for newly created accounts', () => {
  const base = {
    mode: 'create',
    email: 'new.admin@matchu.test',
    displayName: 'New Admin',
    role: 'analyst',
    permissions: ['dashboard.read']
  };

  assert.ok(validateGrant({
    ...base,
    password: 'abcdefgh',
    passwordConfirmation: 'abcdefgh'
  }).error);
  assert.ok(validateGrant({
    ...base,
    password: 'Aa1#bcdef',
    passwordConfirmation: 'Bb2@fghij'
  }).error);
  assert.ok(validateGrant({
    ...base,
    password: 'Aa1#bcde',
    passwordConfirmation: 'Aa1#bcde'
  }).error);
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
