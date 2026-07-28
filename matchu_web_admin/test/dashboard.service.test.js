const test = require('node:test');
const assert = require('node:assert/strict');

process.env.NODE_ENV = 'test';
const { __test } = require('../src/services/dashboard.service');

function source(records = []) {
  return { records, truncated: false };
}

function emptySources(overrides = {}) {
  return {
    users: source(),
    activeUsers: source(),
    posts: source(),
    matches: source(),
    reports: source(),
    gems: source(),
    openCases: source(),
    activity: source(),
    ...overrides
  };
}

test('creates calendar periods in the Bangkok timezone', () => {
  const now = new Date('2026-07-28T10:00:00.000Z');
  const period = __test.createPeriod(7, now);
  assert.equal(period.currentStart.toISOString(), '2026-07-21T17:00:00.000Z');
  assert.equal(period.previousStart.toISOString(), '2026-07-14T17:00:00.000Z');
  assert.equal(__test.dateKey(now), '2026-07-28');
});

test('calculates comparison changes without dividing by zero', () => {
  assert.deepEqual(__test.changeMetric(10, 5), { value: 100, direction: 'up' });
  assert.deepEqual(__test.changeMetric(3, 0), { value: null, direction: 'new' });
  assert.deepEqual(__test.changeMetric(0, 0), { value: 0, direction: 'flat' });
});

test('builds dashboard metrics from existing Firestore-shaped records', () => {
  const now = new Date('2026-07-28T10:00:00.000Z');
  const period = __test.createPeriod(7, now);
  const previousDate = new Date('2026-07-18T03:00:00.000Z');
  const currentDate = new Date('2026-07-27T03:00:00.000Z');
  const sources = emptySources({
    users: source([
      { id: 'old-user', createdAt: previousDate },
      { id: 'new-user', createdAt: currentDate }
    ]),
    activeUsers: source([
      { id: 'new-user', lastActiveAt: currentDate }
    ]),
    posts: source([
      {
        id: 'post-1',
        createdAt: currentDate,
        stats: { likeCount: 4, commentCount: 2, shareCount: 1, saveCount: 3 }
      }
    ]),
    matches: source([
      {
        id: 'room-1',
        createdAt: currentDate,
        matchingMode: 'video',
        userALiked: true,
        userBLiked: true,
        status: 'converted',
        permanentRoomId: 'chat-1'
      }
    ]),
    reports: source([
      { id: 'report-1', createdAt: currentDate, categoryTitle: 'Spam' },
      { id: 'report-2', createdAt: currentDate, categoryTitle: 'Spam' }
    ]),
    gems: source([
      { id: 'gem-1', createdAt: currentDate, amount: -2, reason: 'video_matching' },
      { id: 'gem-2', createdAt: currentDate, amount: 2, reason: 'video_matching_refund' }
    ]),
    openCases: source([
      { id: 'case-1', createdAt: new Date('2026-07-26T00:00:00.000Z') }
    ])
  });
  const counts = {
    totalUsers: 10,
    verifiedUsers: 4,
    totalPosts: 8,
    approvedPosts: 7,
    pendingPosts: 1,
    reviewPosts: 2,
    openCases: 3
  };

  const dashboard = __test.buildDashboardModel(
    sources,
    counts,
    period,
    { partial: false, unavailableSources: [], truncatedSources: [] }
  );

  assert.equal(dashboard.cards[0].value, 1);
  assert.equal(dashboard.cards[1].value, 1);
  assert.equal(dashboard.cards[2].value, 1);
  assert.equal(dashboard.cards[3].value, 3);
  assert.equal(dashboard.matching.converted, 1);
  assert.equal(dashboard.matching.conversionRate, 100);
  assert.deepEqual(dashboard.engagement, {
    likes: 4,
    comments: 2,
    shares: 1,
    saves: 3
  });
  assert.deepEqual(dashboard.gemEconomy, { spent: 2, issued: 0, refunded: 2 });
  assert.equal(dashboard.moderation.reportBreakdown[0].count, 2);
  assert.equal(dashboard.totals.verifiedRate, 40);
});

test('normalizes recent audit activity into safe drill-down links', () => {
  const activity = __test.activityPresentation({
    id: 'audit-1',
    action: 'USER_SUSPEND',
    targetType: 'user',
    targetId: 'user/unsafe',
    adminEmail: 'admin@matchu.test'
  });
  assert.equal(activity.label, 'Tạm khóa tài khoản');
  assert.equal(activity.tone, 'danger');
  assert.equal(activity.targetUrl, '/users/user%2Funsafe');
});
