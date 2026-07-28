const test = require('node:test');
const assert = require('node:assert/strict');

process.env.NODE_ENV = 'test';

const { __test } = require('../src/services/admin-access.service');

function document(id, data) {
  return { id, data: () => data };
}

test('normalizes legacy admin profiles and allowlists permissions', () => {
  const profile = __test.normalizeProfile(document('admin-1', {
    email: 'ops@matchu.test',
    displayName: 'Ops Admin',
    role: 'moderator',
    permissions: ['users.read', 'unknown.permission', 'users.read'],
    status: 'active',
    lastLoginAt: { toDate: () => new Date('2026-07-29T01:00:00.000Z') }
  }));

  assert.equal(profile.uid, 'admin-1');
  assert.deepEqual(profile.permissions, ['users.read']);
  assert.equal(profile.status, 'active');
  assert.equal(profile.lastLoginAt.toISOString(), '2026-07-29T01:00:00.000Z');
});

test('super admin permissions are represented as implicit full access', () => {
  assert.deepEqual(
    __test.normalizePermissions('super_admin', ['users.read', 'admins.manage']),
    []
  );
});

test('prevents delegated managers from escalating or delegating admin management', () => {
  const manager = {
    uid: 'manager-1',
    role: 'moderator',
    permissions: ['admins.manage', 'dashboard.read', 'users.read']
  };

  assert.throws(
    () => __test.ensureCanAssign(manager, 'super_admin', []),
    /Super Admin/
  );
  assert.throws(
    () => __test.ensureCanAssign(
      manager,
      'support',
      ['dashboard.read', 'admins.manage']
    ),
    /quyền quản lý admin/
  );
  assert.throws(
    () => __test.ensureCanAssign(
      manager,
      'support',
      ['dashboard.read', 'reports.resolve']
    ),
    /đang sở hữu/
  );
});

test('prevents self-management and changes to higher-scope targets', () => {
  const manager = {
    uid: 'manager-1',
    role: 'moderator',
    permissions: ['admins.manage', 'dashboard.read', 'users.read']
  };
  const self = {
    uid: 'manager-1',
    role: 'moderator',
    permissions: ['admins.manage', 'dashboard.read', 'users.read']
  };
  const higherTarget = {
    uid: 'manager-2',
    role: 'moderator',
    permissions: ['dashboard.read', 'reports.resolve']
  };

  assert.equal(__test.canManageTarget(manager, self), false);
  assert.equal(__test.canManageTarget(manager, higherTarget), false);
  assert.throws(
    () => __test.ensureCanAssign(manager, 'moderator', manager.permissions, self),
    /chính mình/
  );
});

test('filters admin profiles by search, role and status', () => {
  const profile = {
    uid: 'admin-1',
    email: 'moderator@matchu.test',
    displayName: 'Kiểm duyệt Nội dung',
    role: 'moderator',
    status: 'active'
  };

  assert.equal(__test.matchesFilters(profile, {
    q: 'nội dung',
    role: 'moderator',
    status: 'active'
  }), true);
  assert.equal(__test.matchesFilters(profile, {
    q: '',
    role: 'support',
    status: ''
  }), false);
});
