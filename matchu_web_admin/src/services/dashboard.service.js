const { firestore } = require('../config/firebase-admin');

const TIME_ZONE = 'Asia/Bangkok';
const TIME_ZONE_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const CACHE_TTL_MS = 60 * 1000;
const RANGE_SCAN_LIMIT = 5000;
const OPEN_CASE_SCAN_LIMIT = 2000;
const RECENT_ACTIVITY_LIMIT = 8;

const cache = new Map();

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') return value.toDate();
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function dateParts(value) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(value);
  return Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value])
  );
}

function dateKey(value) {
  const parts = dateParts(value);
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function startOfBangkokDay(value) {
  const parts = dateParts(value);
  return new Date(
    Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day))
      - TIME_ZONE_OFFSET_MS
  );
}

function createPeriod(rangeDays, now = new Date()) {
  const todayStart = startOfBangkokDay(now);
  const currentStart = new Date(todayStart.getTime() - ((rangeDays - 1) * DAY_MS));
  const previousStart = new Date(currentStart.getTime() - (rangeDays * DAY_MS));
  return {
    rangeDays,
    now,
    currentStart,
    currentEnd: now,
    previousStart,
    previousEnd: currentStart
  };
}

function inRange(value, start, end) {
  const date = toDate(value);
  return Boolean(date && date >= start && date < end);
}

function currentRecords(records, period, field = 'createdAt') {
  return records.filter((record) => (
    inRange(record[field], period.currentStart, period.currentEnd)
  ));
}

function previousRecords(records, period, field = 'createdAt') {
  return records.filter((record) => (
    inRange(record[field], period.previousStart, period.previousEnd)
  ));
}

function changeMetric(current, previous) {
  if (previous === 0) {
    return {
      value: current > 0 ? null : 0,
      direction: current > 0 ? 'new' : 'flat'
    };
  }
  const value = ((current - previous) / previous) * 100;
  return {
    value: Math.round(value * 10) / 10,
    direction: value > 0 ? 'up' : value < 0 ? 'down' : 'flat'
  };
}

function normalizeRecord(document) {
  const data = document.data() || {};
  const normalized = { id: document.id, ...data };
  for (const field of [
    'createdAt', 'updatedAt', 'lastActiveAt', 'endedAt', 'convertedAt',
    'resolvedAt', 'matchedAt', 'expiresAt'
  ]) {
    if (normalized[field]) normalized[field] = toDate(normalized[field]);
  }
  return normalized;
}

async function fetchRange(collectionName, field, period) {
  const snapshot = await firestore
    .collection(collectionName)
    .where(field, '>=', period.previousStart)
    .where(field, '<=', period.currentEnd)
    .orderBy(field, 'asc')
    .limit(RANGE_SCAN_LIMIT)
    .get();
  return {
    records: snapshot.docs.map(normalizeRecord),
    truncated: snapshot.size >= RANGE_SCAN_LIMIT
  };
}

async function fetchOpenCases() {
  const statuses = ['open', 'in_review'];
  const snapshots = await Promise.all(statuses.map((status) => (
    firestore
      .collection('moderationCases')
      .where('status', '==', status)
      .limit(OPEN_CASE_SCAN_LIMIT)
      .get()
  )));
  const records = snapshots.flatMap((snapshot) => snapshot.docs.map(normalizeRecord));
  return {
    records,
    truncated: snapshots.some((snapshot) => snapshot.size >= OPEN_CASE_SCAN_LIMIT)
  };
}

async function countQuery(query) {
  try {
    const snapshot = await query.count().get();
    return snapshot.data().count;
  } catch (_) {
    const snapshot = await query.get();
    return snapshot.size;
  }
}

async function fetchSnapshotCounts() {
  const users = firestore.collection('users');
  const posts = firestore.collection('posts');
  const cases = firestore.collection('moderationCases');
  const safeCount = async (query) => {
    try {
      return await countQuery(query);
    } catch (_) {
      return null;
    }
  };
  const [
    allUsers,
    deletingUsers,
    deletedUsers,
    verifiedUsers,
    allPosts,
    deletedPosts,
    pendingPosts,
    reviewPosts,
    approvedPosts,
    openCases,
    inReviewCases
  ] = await Promise.all([
    safeCount(users),
    safeCount(users.where('accountStatus', '==', 'deleting')),
    safeCount(users.where('accountStatus', '==', 'deleted')),
    safeCount(users.where('isFaceVerified', '==', true)),
    safeCount(posts),
    safeCount(posts.where('deletedAt', '!=', null)),
    safeCount(posts.where('moderationStatus', '==', 'pending_moderation')),
    safeCount(posts.where('moderationStatus', '==', 'review_required')),
    safeCount(posts.where('moderationStatus', '==', 'approved')),
    safeCount(cases.where('status', '==', 'open')),
    safeCount(cases.where('status', '==', 'in_review'))
  ]);
  const rawCounts = {
    allUsers,
    deletingUsers,
    deletedUsers,
    verifiedUsers,
    allPosts,
    deletedPosts,
    pendingPosts,
    reviewPosts,
    approvedPosts,
    openCases,
    inReviewCases
  };
  return {
    totalUsers: allUsers == null || deletingUsers == null || deletedUsers == null
      ? null
      : Math.max(0, allUsers - deletingUsers - deletedUsers),
    verifiedUsers,
    totalPosts: allPosts == null || deletedPosts == null
      ? null
      : Math.max(0, allPosts - deletedPosts),
    approvedPosts,
    pendingPosts,
    reviewPosts,
    openCases: openCases == null || inReviewCases == null
      ? null
      : openCases + inReviewCases,
    partial: Object.values(rawCounts).some((value) => value == null)
  };
}

async function fetchRecentActivity() {
  const snapshot = await firestore
    .collection('adminAuditLogs')
    .orderBy('createdAt', 'desc')
    .limit(RECENT_ACTIVITY_LIMIT)
    .get();
  return {
    records: snapshot.docs.map(normalizeRecord),
    truncated: false
  };
}

function makeSeries(period, sources) {
  const points = [];
  const byDay = (records, field = 'createdAt') => {
    const counts = new Map();
    for (const record of currentRecords(records, period, field)) {
      const key = dateKey(record[field]);
      counts.set(key, (counts.get(key) || 0) + 1);
    }
    return counts;
  };
  const users = byDay(sources.users.records);
  const posts = byDay(sources.posts.records);
  const matches = byDay(sources.matches.records);
  const reports = byDay(sources.reports.records);

  for (let index = 0; index < period.rangeDays; index += 1) {
    const day = new Date(period.currentStart.getTime() + (index * DAY_MS) + TIME_ZONE_OFFSET_MS);
    const key = dateKey(day);
    points.push({
      key,
      label: `${key.slice(8, 10)}/${key.slice(5, 7)}`,
      users: users.get(key) || 0,
      posts: posts.get(key) || 0,
      matches: matches.get(key) || 0,
      reports: reports.get(key) || 0
    });
  }
  return points;
}

function sumPostEngagement(posts) {
  return posts.reduce((total, post) => {
    const stats = post.stats || {};
    total.likes += Number(stats.likeCount) || 0;
    total.comments += Number(stats.commentCount) || 0;
    total.shares += (Number(stats.shareCount) || 0) + (Number(stats.externalShareCount) || 0);
    total.saves += Number(stats.saveCount) || 0;
    return total;
  }, { likes: 0, comments: 0, shares: 0, saves: 0 });
}

function buildReportBreakdown(reports) {
  const categories = new Map();
  for (const report of reports) {
    const key = String(
      report.categoryTitle || report.categoryKey || report.reason || 'Khác'
    ).trim() || 'Khác';
    categories.set(key, (categories.get(key) || 0) + 1);
  }
  return [...categories.entries()]
    .map(([label, count]) => ({ label, count }))
    .sort((left, right) => right.count - left.count)
    .slice(0, 5);
}

function activityPresentation(activity) {
  const action = String(activity.action || '').toUpperCase();
  const labels = {
    LOGIN_SUCCESS: 'Đăng nhập hệ thống',
    LOGOUT: 'Đăng xuất hệ thống',
    POST_APPROVE: 'Duyệt bài viết',
    POST_REJECT: 'Từ chối bài viết',
    POST_REVIEW: 'Chuyển bài sang xem xét',
    POST_DISMISS: 'Bác báo cáo bài viết',
    POST_RESTORE: 'Khôi phục bài viết',
    POST_DELETE_PERMANENTLY: 'Xóa vĩnh viễn bài viết',
    USER_WARN: 'Cảnh báo người dùng',
    USER_RESTRICT: 'Hạn chế tài khoản',
    USER_SUSPEND: 'Tạm khóa tài khoản',
    USER_BAN: 'Cấm tài khoản',
    USER_RESTORE: 'Khôi phục tài khoản'
  };
  const isDanger = /REJECT|DELETE|BAN|SUSPEND|FAILED/.test(action);
  const isWarning = /WARN|RESTRICT|REVIEW/.test(action);
  let targetUrl = null;
  if (activity.targetType === 'user' && activity.targetId) {
    targetUrl = `/users/${encodeURIComponent(activity.targetId)}`;
  } else if (activity.targetType === 'post' && activity.targetId) {
    targetUrl = `/posts/${encodeURIComponent(activity.targetId)}`;
  }
  return {
    id: activity.id,
    label: labels[action] || action.toLowerCase().replaceAll('_', ' ') || 'Hoạt động quản trị',
    adminName: activity.adminEmail || 'Quản trị viên',
    targetType: activity.targetType || '',
    targetId: activity.targetId || '',
    targetUrl,
    createdAt: activity.createdAt,
    tone: isDanger ? 'danger' : isWarning ? 'warning' : 'normal'
  };
}

function buildDashboardModel(sources, counts, period, quality) {
  const usersCurrent = currentRecords(sources.users.records, period);
  const usersPrevious = previousRecords(sources.users.records, period);
  const activeCurrent = currentRecords(sources.activeUsers.records, period, 'lastActiveAt');
  const postsCurrent = currentRecords(sources.posts.records, period);
  const postsPrevious = previousRecords(sources.posts.records, period);
  const matchesCurrent = currentRecords(sources.matches.records, period);
  const matchesPrevious = previousRecords(sources.matches.records, period);
  const reportsCurrent = currentRecords(sources.reports.records, period);
  const reportsPrevious = previousRecords(sources.reports.records, period);
  const gemsCurrent = currentRecords(sources.gems.records, period);

  const mutualMatches = matchesCurrent.filter((room) => (
    room.userALiked === true && room.userBLiked === true
  )).length;
  const convertedMatches = matchesCurrent.filter((room) => (
    room.status === 'converted' || Boolean(room.permanentRoomId)
  )).length;
  const textMatches = matchesCurrent.filter((room) => room.matchingMode !== 'video').length;
  const videoMatches = matchesCurrent.length - textMatches;
  const engagement = sumPostEngagement(postsCurrent);
  const openCases = sources.openCases.records;
  const openCaseCount = counts.openCases == null ? openCases.length : counts.openCases;
  const oldestCaseDate = openCases
    .map((item) => item.createdAt)
    .filter(Boolean)
    .sort((left, right) => left - right)[0] || null;
  const oldestCaseHours = oldestCaseDate
    ? Math.max(0, Math.floor((period.now - oldestCaseDate) / (60 * 60 * 1000)))
    : 0;
  const gemEconomy = gemsCurrent.reduce((result, transaction) => {
    const amount = Number(transaction.amount) || 0;
    if (amount < 0) result.spent += Math.abs(amount);
    else if (amount > 0 && String(transaction.reason || '').includes('refund')) {
      result.refunded += amount;
    } else if (amount > 0) {
      result.issued += amount;
    }
    return result;
  }, { spent: 0, issued: 0, refunded: 0 });

  const userChange = changeMetric(usersCurrent.length, usersPrevious.length);
  const postChange = changeMetric(postsCurrent.length, postsPrevious.length);
  const matchChange = changeMetric(matchesCurrent.length, matchesPrevious.length);
  const reportChange = changeMetric(reportsCurrent.length, reportsPrevious.length);
  const verifiedRate = counts.totalUsers && counts.verifiedUsers != null
    ? (counts.verifiedUsers / counts.totalUsers) * 100
    : null;
  const conversionRate = matchesCurrent.length
    ? (convertedMatches / matchesCurrent.length) * 100
    : 0;

  return {
    period: {
      rangeDays: period.rangeDays,
      from: period.currentStart,
      to: period.currentEnd
    },
    cards: [
      {
        key: 'newUsers',
        label: 'Người dùng mới',
        value: usersCurrent.length,
        icon: 'person-plus',
        tone: 'primary',
        change: userChange,
        href: '/users'
      },
      {
        key: 'activeUsers',
        label: 'Hoạt động trong kỳ',
        value: activeCurrent.length,
        icon: 'activity',
        tone: 'success',
        change: null,
        hint: 'Theo lần hoạt động gần nhất',
        href: '/users'
      },
      {
        key: 'matches',
        label: 'Phiên ghép thành công',
        value: matchesCurrent.length,
        icon: 'heart-pulse',
        tone: 'info',
        change: matchChange,
        href: null
      },
      {
        key: 'openModeration',
        label: 'Nội dung cần xử lý',
        value: (counts.pendingPosts || 0) + (counts.reviewPosts || 0),
        icon: 'shield-exclamation',
        tone: 'danger',
        change: null,
        hint: `${openCaseCount} case đang mở`,
        href: '/posts/moderation'
      }
    ],
    totals: {
      users: counts.totalUsers,
      posts: counts.totalPosts,
      approvedPosts: counts.approvedPosts,
      verifiedRate,
      newPosts: postsCurrent.length,
      newPostsChange: postChange,
      newReports: reportsCurrent.length,
      newReportsChange: reportChange
    },
    series: makeSeries(period, sources),
    matching: {
      total: matchesCurrent.length,
      text: textMatches,
      video: videoMatches,
      mutual: mutualMatches,
      converted: convertedMatches,
      conversionRate,
      funnel: [
        { label: 'Ghép thành công', value: matchesCurrent.length },
        { label: 'Đồng ý kết nối', value: mutualMatches },
        { label: 'Chat dài hạn', value: convertedMatches }
      ]
    },
    moderation: {
      pending: counts.pendingPosts || 0,
      review: counts.reviewPosts || 0,
      openCases: openCaseCount,
      oldestCaseHours,
      reportBreakdown: buildReportBreakdown(reportsCurrent)
    },
    engagement,
    gemEconomy,
    recentActivity: sources.activity.records.map(activityPresentation),
    quality: {
      ...quality,
      generatedAt: period.now
    }
  };
}

async function loadDashboardSources(period) {
  const reportsLoader = async () => {
    const [posts, profiles, matching] = await Promise.all([
      fetchRange('postReports', 'createdAt', period),
      fetchRange('userProfileReports', 'createdAt', period),
      fetchRange('userMatchingReports', 'createdAt', period)
    ]);
    return {
      records: [
        ...posts.records.map((item) => ({ ...item, reportSource: 'post' })),
        ...profiles.records.map((item) => ({ ...item, reportSource: 'profile' })),
        ...matching.records.map((item) => ({ ...item, reportSource: 'matching' }))
      ],
      truncated: posts.truncated || profiles.truncated || matching.truncated
    };
  };
  const loaders = {
    users: () => fetchRange('users', 'createdAt', period),
    activeUsers: () => fetchRange('users', 'lastActiveAt', period),
    posts: () => fetchRange('posts', 'createdAt', period),
    matches: () => fetchRange('tempChats', 'createdAt', period),
    reports: reportsLoader,
    gems: () => fetchRange('gemTransactions', 'createdAt', period),
    openCases: fetchOpenCases,
    activity: fetchRecentActivity
  };
  const empty = { records: [], truncated: false };
  const errors = [];
  const sources = {};
  await Promise.all(Object.entries(loaders).map(async ([name, loader]) => {
    try {
      sources[name] = await loader();
    } catch (error) {
      console.warn(`Dashboard source unavailable: ${name}`, error.message);
      sources[name] = empty;
      errors.push(name);
    }
  }));
  return {
    sources,
    quality: {
      partial: errors.length > 0,
      unavailableSources: errors,
      truncatedSources: Object.entries(sources)
        .filter(([, source]) => source.truncated)
        .map(([name]) => name)
    }
  };
}

async function getDashboardData({ rangeDays = 7, now = new Date(), bypassCache = false } = {}) {
  const cacheKey = String(rangeDays);
  const cached = cache.get(cacheKey);
  if (!bypassCache && cached && Date.now() - cached.createdAt < CACHE_TTL_MS) {
    return cached.value;
  }
  const period = createPeriod(rangeDays, now);
  const [{ sources, quality }, counts] = await Promise.all([
    loadDashboardSources(period),
    fetchSnapshotCounts()
  ]);
  const mergedQuality = counts.partial
    ? {
      ...quality,
      partial: true,
      unavailableSources: [...quality.unavailableSources, 'snapshotCounts']
    }
    : quality;
  const value = buildDashboardModel(sources, counts, period, mergedQuality);
  if (!bypassCache) cache.set(cacheKey, { createdAt: Date.now(), value });
  return value;
}

module.exports = {
  getDashboardData,
  __test: {
    toDate,
    dateKey,
    startOfBangkokDay,
    createPeriod,
    changeMetric,
    makeSeries,
    buildDashboardModel,
    sumPostEngagement,
    buildReportBreakdown,
    activityPresentation
  }
};
