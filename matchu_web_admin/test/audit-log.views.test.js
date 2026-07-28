const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ejs = require('ejs');

const view = path.join(__dirname, '..', 'src', 'views', 'audit-logs', 'index.ejs');

function baseLocals(logs) {
  return {
    logs,
    statistics: {
      total: 128,
      last24Hours: 12,
      failures24Hours: 2,
      denied24Hours: 1,
      activeAdmins24Hours: 3,
      recentTruncated: false
    },
    adminOptions: [{ uid: 'admin-1', displayName: 'Super Admin', status: 'active' }],
    filters: {
      q: '',
      adminId: '',
      category: '',
      result: '',
      targetType: '',
      from: '',
      to: '',
      limit: 25,
      cursor: ''
    },
    activeFilterCount: 0,
    categoryLabels: {
      auth: 'Xác thực',
      users: 'Người dùng',
      posts: 'Bài viết',
      reports: 'Báo cáo',
      notifications: 'Thông báo',
      system: 'Hệ thống'
    },
    categoryIcons: { users: 'person' },
    resultLabels: { success: 'Thành công', failure: 'Thất bại', denied: 'Bị từ chối' },
    targetTypeLabels: { user: 'Người dùng' },
    formatDateTime: () => '29/07/2026, 09:15:30',
    formatIsoDate: () => '2026-07-29T02:15:30.000Z',
    formatValue: (value) => String(value),
    formatMetadata: (metadata) => JSON.stringify(metadata, null, 2),
    formatNumber: (value) => String(value),
    firstPageUrl: '/admin-logs',
    nextPageUrl: null,
    hasPreviousPage: false,
    scanned: logs.length,
    scanLimitReached: false
  };
}

test('renders a detailed, read-only audit timeline', async () => {
  const html = await ejs.renderFile(view, baseLocals([{
    id: 'audit-event-1',
    createdAt: new Date('2026-07-29T02:15:30.000Z'),
    action: 'USER_SUSPEND',
    actionLabel: 'Tạm khóa tài khoản',
    category: 'users',
    categoryLabel: 'Người dùng',
    tone: 'danger',
    summary: 'Vi phạm chính sách',
    adminName: 'Super Admin',
    adminEmail: 'admin@matchu.test',
    adminId: 'admin-1',
    adminRole: 'super_admin',
    targetType: 'user',
    targetTypeLabel: 'Người dùng',
    targetId: 'user-1',
    targetUrl: '/users/user-1',
    result: 'success',
    resultLabel: 'Thành công',
    ipAddress: '203.0.113.9',
    requestId: 'request-1',
    userAgentInfo: { label: 'Google Chrome 126 · Máy tính', raw: 'Chrome/126' },
    metadata: { reason: 'Vi phạm chính sách' },
    changes: [{
      label: 'Trạng thái tài khoản',
      before: 'active',
      after: 'suspended'
    }]
  }]));

  assert.match(html, /AN TOÀN & TRUY VẾT/);
  assert.match(html, /Nhật ký chỉ đọc/);
  assert.match(html, /Tạm khóa tài khoản/);
  assert.match(html, /audit-result-success/);
  assert.match(html, /Thay đổi dữ liệu/);
  assert.match(html, /request-1/);
  assert.match(html, /data-copy-value="audit-event-1"/);
});

test('renders a useful empty state and scan-limit warning', async () => {
  const locals = baseLocals([]);
  locals.scanLimitReached = true;
  const html = await ejs.renderFile(view, locals);
  assert.match(html, /Không tìm thấy sự kiện phù hợp/);
  assert.match(html, /Đã đạt giới hạn quét an toàn/);
});
