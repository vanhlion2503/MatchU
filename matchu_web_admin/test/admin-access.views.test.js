const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ejs = require('ejs');

const view = path.join(__dirname, '..', 'src', 'views', 'admins', 'index.ejs');

function locals(profiles) {
  return {
    profiles,
    statistics: { total: 2, active: 1, inactive: 1, superAdmins: 1 },
    filters: { q: '', role: '', status: '' },
    currentAdmin: {
      uid: 'super-1',
      email: 'super@matchu.test',
      role: 'super_admin'
    },
    csrfToken: 'csrf-token',
    roles: ['super_admin', 'moderator', 'support', 'analyst'],
    roleLabels: {
      super_admin: 'Super Admin',
      moderator: 'Kiểm duyệt viên',
      support: 'Hỗ trợ người dùng',
      analyst: 'Phân tích viên'
    },
    roleDescriptions: {
      super_admin: 'Toàn quyền quản trị.',
      moderator: 'Kiểm duyệt nội dung.',
      support: 'Hỗ trợ tài khoản.',
      analyst: 'Xem số liệu.'
    },
    statusLabels: {
      active: 'Đang hoạt động',
      inactive: 'Đã vô hiệu hóa'
    },
    permissionGroups: [{
      key: 'overview',
      label: 'Tổng quan',
      icon: 'grid',
      permissions: [{
        key: 'dashboard.read',
        label: 'Xem tổng quan',
        description: 'Truy cập dashboard.'
      }, {
        key: 'admins.manage',
        label: 'Quản lý admin',
        description: 'Quản lý tài khoản admin.',
        sensitive: true
      }]
    }],
    permissionLabels: {
      'dashboard.read': 'Xem tổng quan',
      'admins.manage': 'Quản lý admin'
    },
    rolePresets: {
      moderator: ['dashboard.read']
    },
    formatDate: () => '29/07/2026 09:00',
    canManageProfile: (profile) => profile.uid !== 'super-1'
  };
}

test('renders admin statistics, protected forms and permission controls', async () => {
  const html = await ejs.renderFile(view, locals([{
    uid: 'super-1',
    email: 'super@matchu.test',
    displayName: 'Super Admin',
    avatarUrl: null,
    role: 'super_admin',
    permissions: [],
    status: 'active',
    statusReason: '',
    lastLoginAt: new Date(),
    updatedAt: new Date(),
    createdAt: new Date()
  }, {
    uid: 'moderator-1',
    email: 'moderator@matchu.test',
    displayName: 'Moderator',
    avatarUrl: null,
    role: 'moderator',
    permissions: ['dashboard.read'],
    status: 'inactive',
    statusReason: 'Đã điều chuyển',
    lastLoginAt: null,
    updatedAt: new Date(),
    createdAt: new Date()
  }]));

  assert.match(html, /QUẢN TRỊ & PHÂN QUYỀN/);
  assert.match(html, /Cấp quyền admin/);
  assert.match(html, /action="\/admins"/);
  assert.match(html, /name="_csrf" value="csrf-token"/);
  assert.match(html, /name="mode" value="create" checked/);
  assert.match(html, /name="email"/);
  assert.match(html, /name="displayName"/);
  assert.match(html, /name="password"/);
  assert.match(html, /name="passwordConfirmation"/);
  assert.match(html, /data-generate-password/);
  assert.match(html, /Mật khẩu chỉ được gửi đến Firebase Authentication/);
  assert.match(html, /name="mode" value="existing"/);
  assert.match(html, /value="admins.manage"/);
  assert.match(html, /data-admin-uid="moderator-1"/);
  assert.match(html, /data-admin-status/);
  assert.match(html, /Tài khoản hiện tại/);
  assert.match(html, /Đã điều chuyển/);
});

test('renders a useful empty state', async () => {
  const html = await ejs.renderFile(view, locals([]));
  assert.match(html, /Không tìm thấy tài khoản admin/);
  assert.match(html, /cấp quyền cho một tài khoản mới/);
});
