const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validateListQuery,
  validateUserAction
} = require('../src/validators/user-account.validator');

test('normalizes list query with safe defaults', () => {
  const { error, value } = validateListQuery({ q: '  An  ', limit: '50' });
  assert.equal(error, undefined);
  assert.equal(value.q, 'An');
  assert.equal(value.limit, 50);
  assert.equal(value.status, '');
});

test('rejects unknown account status', () => {
  const { error } = validateListQuery({ status: 'unknown-status' });
  assert.ok(error);
});

test('requires reason and features for restriction', () => {
  const missing = validateUserAction({ action: 'restrict', durationDays: 7 });
  assert.ok(missing.error);

  const valid = validateUserAction({
    action: 'restrict',
    reason: 'Spam lặp lại nhiều lần',
    durationDays: '7',
    features: 'posts'
  });
  assert.equal(valid.error, undefined);
  assert.deepEqual(valid.value.features, ['posts']);
  assert.equal(valid.value.durationDays, 7);
});

test('rejects zero balance adjustment', () => {
  const { error } = validateUserAction({
    action: 'adjust_gem',
    reason: 'Điều chỉnh theo yêu cầu hỗ trợ',
    amount: 0
  });
  assert.ok(error);
});

test('accepts empty hidden amount for non-financial action', () => {
  const { error, value } = validateUserAction({
    action: 'restore',
    reason: '',
    amount: '',
    durationDays: ''
  });
  assert.equal(error, undefined);
  assert.equal(value.action, 'restore');
});
