const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ejs = require('ejs');

const sidebar = path.join(__dirname, '..', 'src', 'views', 'partials', 'sidebar.ejs');
const baseLocals = {
  currentPath: '/dashboard',
  hasPermission: (permission) => permission === 'reports.read'
};

test('shows the pending report count as a red navigation badge', async () => {
  const html = await ejs.renderFile(sidebar, {
    ...baseLocals,
    pendingReportCount: 12
  });

  assert.match(html, /sidebar-report-badge/);
  assert.match(html, />12<\/strong>/);
  assert.match(html, /12 báo cáo đang chờ xử lý/);
});

test('hides the report badge when there are no pending reports', async () => {
  const html = await ejs.renderFile(sidebar, {
    ...baseLocals,
    pendingReportCount: 0
  });

  assert.doesNotMatch(html, /sidebar-report-badge/);
});

test('caps large pending report counts while preserving the exact accessible value', async () => {
  const html = await ejs.renderFile(sidebar, {
    ...baseLocals,
    pendingReportCount: 123
  });

  assert.match(html, />99\+<\/strong>/);
  assert.match(html, /123 báo cáo đang chờ xử lý/);
});

test('shows a red badge and moderation shortcut for posts requiring review', async () => {
  const html = await ejs.renderFile(sidebar, {
    currentPath: '/dashboard',
    hasPermission: (permission) => permission === 'posts.read',
    pendingPostModerationCount: 7
  });

  assert.match(html, /href="\/posts\?queue=moderation"/);
  assert.match(html, /sidebar-post-badge/);
  assert.match(html, />7<\/strong>/);
  assert.match(html, /7 bài viết cần kiểm duyệt/);
});

test('shows the notification module only with read permission', async () => {
  const visible = await ejs.renderFile(sidebar, {
    currentPath: '/notifications',
    hasPermission: (permission) => permission === 'notifications.read',
    pendingReportCount: 0,
    pendingPostModerationCount: 0
  });
  assert.match(visible, /href="\/notifications"/);
  assert.match(visible, /nav-link active/);

  const hidden = await ejs.renderFile(sidebar, {
    ...baseLocals,
    pendingReportCount: 0,
    pendingPostModerationCount: 0
  });
  assert.doesNotMatch(hidden, /href="\/notifications"/);
});

test('does not show unused comment and reputation placeholder navigation items', async () => {
  const html = await ejs.renderFile(sidebar, {
    currentPath: '/dashboard',
    hasPermission: () => true,
    pendingReportCount: 0,
    pendingPostModerationCount: 0
  });
  assert.doesNotMatch(html, /<span>Bình luận<\/span>/);
  assert.doesNotMatch(html, /<span>Điểm uy tín<\/span>/);
});
