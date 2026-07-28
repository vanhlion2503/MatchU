const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ejs = require('ejs');

const view = path.join(__dirname, '..', 'src', 'views', 'dashboard', 'index.ejs');

test('renders the operational dashboard with charts and drill-downs', async () => {
  const now = new Date('2026-07-28T10:00:00.000Z');
  const html = await ejs.renderFile(view, {
    pageTitle: 'Trung tâm điều hành',
    selectedRange: 7,
    allowedRanges: [7, 30, 90],
    chartDataJson: JSON.stringify({
      series: [{ label: '28/07', users: 2, posts: 1, matches: 1, reports: 0 }]
    }),
    formatNumber: (value) => value == null ? '—' : String(value),
    formatPercent: (value) => value == null ? '—' : `${value}%`,
    formatDateTime: (value) => value instanceof Date ? value.toISOString() : '—',
    dashboard: {
      period: { from: new Date('2026-07-21T17:00:00.000Z'), to: now },
      series: [{ label: '28/07', users: 2, posts: 1, matches: 1, reports: 0 }],
      quality: {
        partial: false,
        truncatedSources: [],
        generatedAt: now
      },
      cards: [{
        label: 'Người dùng mới',
        value: 2,
        icon: 'person-plus',
        tone: 'primary',
        change: { value: 100, direction: 'up' },
        href: '/users'
      }],
      totals: {
        users: 12,
        posts: 8,
        verifiedRate: 50,
        newReports: 1,
        newPosts: 3
      },
      moderation: {
        pending: 1,
        review: 2,
        openCases: 3,
        oldestCaseHours: 28,
        reportBreakdown: [{ label: 'Spam', count: 1 }]
      },
      matching: {
        total: 4,
        text: 3,
        video: 1,
        conversionRate: 25,
        funnel: [
          { label: 'Ghép thành công', value: 4 },
          { label: 'Đồng ý kết nối', value: 2 },
          { label: 'Chat dài hạn', value: 1 }
        ]
      },
      engagement: { likes: 5, comments: 2, shares: 1, saves: 3 },
      gemEconomy: { spent: 4, issued: 2, refunded: 1 },
      recentActivity: [{
        label: 'Duyệt bài viết',
        targetUrl: '/posts/post-1',
        targetId: 'post-1',
        adminName: 'admin@matchu.test',
        tone: 'normal',
        createdAt: now
      }]
    }
  });

  assert.match(html, /MATCHU CONTROL CENTER/);
  assert.match(html, /Nhịp hoạt động nền tảng/);
  assert.match(html, /MATCHING FUNNEL/);
  assert.match(html, /Hàng đợi kiểm duyệt/);
  assert.match(html, /GEM ECONOMY/);
  assert.match(html, /\/posts\/post-1/);
  assert.match(html, /dashboardChartData/);
  assert.match(html, /\/js\/dashboard\.js/);
});

test('renders partial-data and empty states without failing', async () => {
  const now = new Date('2026-07-28T10:00:00.000Z');
  const html = await ejs.renderFile(view, {
    pageTitle: 'Trung tâm điều hành',
    selectedRange: 30,
    allowedRanges: [7, 30, 90],
    chartDataJson: '{"series":[]}',
    formatNumber: (value) => value == null ? '—' : String(value),
    formatPercent: (value) => value == null ? '—' : `${value}%`,
    formatDateTime: () => '—',
    dashboard: {
      period: { from: now, to: now },
      series: [],
      quality: { partial: true, truncatedSources: ['posts'], generatedAt: now },
      cards: [],
      totals: { users: null, posts: null, verifiedRate: null, newReports: 0, newPosts: 0 },
      moderation: {
        pending: 0,
        review: 0,
        openCases: 0,
        oldestCaseHours: 0,
        reportBreakdown: []
      },
      matching: {
        total: 0,
        text: 0,
        video: 0,
        conversionRate: 0,
        funnel: [
          { label: 'Ghép thành công', value: 0 },
          { label: 'Đồng ý kết nối', value: 0 },
          { label: 'Chat dài hạn', value: 0 }
        ]
      },
      engagement: { likes: 0, comments: 0, shares: 0, saves: 0 },
      gemEconomy: { spent: 0, issued: 0, refunded: 0 },
      recentActivity: []
    }
  });

  assert.match(html, /Dữ liệu một phần/);
  assert.match(html, /Không phát sinh báo cáo mới/);
  assert.match(html, /Chưa có hoạt động quản trị/);
});
