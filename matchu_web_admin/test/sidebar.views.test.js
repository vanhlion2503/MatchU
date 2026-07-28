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
