const test = require('node:test');
const assert = require('node:assert/strict');

process.env.NODE_ENV = 'test';

const {
  presentAuditLog,
  toSafeMetadata,
  deriveResult
} = require('../src/utils/audit-log');
const { __test } = require('../src/services/audit-log.service');

test('presents legacy audit records with Vietnamese labels and safe links', () => {
  const log = presentAuditLog({
    id: 'audit-1',
    action: 'USER_SUSPEND',
    targetType: 'user',
    targetId: 'user/unsafe',
    adminEmail: 'admin@matchu.test',
    metadata: { reason: 'Vi phạm nhiều lần' }
  });

  assert.equal(log.actionLabel, 'Tạm khóa tài khoản');
  assert.equal(log.category, 'users');
  assert.equal(log.result, 'success');
  assert.equal(log.tone, 'danger');
  assert.equal(log.targetUrl, '/users/user%2Funsafe');
  assert.equal(log.summary, 'Vi phạm nhiều lần');
});

test('distinguishes failed events from the successful retry-failed operation', () => {
  assert.equal(deriveResult('POST_REJECT_FAILED'), 'failure');
  assert.equal(deriveResult('ADMIN_LOGIN_DENIED'), 'denied');
  assert.equal(deriveResult('NOTIFICATION_RETRY_FAILED'), 'success');
});

test('redacts nested credentials and produces before/after changes', () => {
  const metadata = toSafeMetadata({
    reason: 'Kiểm tra',
    idToken: 'should-not-leak',
    nested: { privateKey: 'secret', safe: true },
    before: { accountStatus: 'active', gem: 10 },
    after: { accountStatus: 'suspended', gem: 10 }
  });
  const log = presentAuditLog({
    action: 'USER_SUSPEND',
    metadata
  });

  assert.equal(metadata.idToken, '[ĐÃ ẨN]');
  assert.equal(metadata.nested.privateKey, '[ĐÃ ẨN]');
  assert.equal(metadata.nested.safe, true);
  assert.deepEqual(log.changes, [{
    key: 'accountStatus',
    label: 'Trạng thái tài khoản',
    before: 'active',
    after: 'suspended'
  }]);
});

test('matches local filters for legacy records without normalized Firestore fields', () => {
  const log = presentAuditLog({
    id: 'audit-123',
    action: 'REPORT_RESOLVE_FAILED',
    adminId: 'admin-1',
    adminEmail: 'ops@matchu.test',
    targetType: 'report_case',
    targetId: 'report-9',
    ipAddress: '203.0.113.9'
  });
  const base = {
    q: '',
    adminId: '',
    category: '',
    result: '',
    targetType: ''
  };

  assert.equal(__test.matchesFilters(log, { ...base, category: 'reports', result: 'failure' }), true);
  assert.equal(__test.matchesFilters(log, { ...base, q: '203.0.113.9' }), true);
  assert.equal(__test.matchesFilters(log, { ...base, targetType: 'user' }), false);
});
