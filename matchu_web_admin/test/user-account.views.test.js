const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ejs = require('ejs');

const views = path.join(__dirname, '..', 'src', 'views', 'users');
const statusLabels = {
  active: 'Đang hoạt động',
  restricted: 'Bị hạn chế',
  suspended: 'Tạm khóa',
  banned: 'Đã cấm',
  deleting: 'Đang xóa',
  deleted: 'Đã xóa'
};
const formatDate = (value) => value instanceof Date ? value.toISOString() : '—';
const maskEmail = (value) => value || '—';
const maskPhone = (value) => value || '—';
const baseUser = {
  uid: 'user-1',
  fullname: 'Nguyễn An',
  nickname: 'nguyenan',
  email: 'an@example.com',
  phonenumber: '+84901234567',
  avatarUrl: 'https://firebasestorage.googleapis.com/v0/b/example/o/avatar.jpg?alt=media',
  gender: 'male',
  birthday: new Date('1995-01-01'),
  bio: 'Xin chào',
  interests: ['Âm nhạc'],
  gem: 15,
  reputationScore: 90,
  trustWarnings: 0,
  totalReports: 1,
  avgChatRating: 4.8,
  totalChatRatings: 10,
  followersCount: 12,
  followingCount: 8,
  followingListVisibility: 'everyone',
  isPrivateAccount: false,
  rank: 2,
  experience: 120,
  totalPosts: 3,
  totalLikes: 25,
  activeStatus: 'offline',
  accountStatus: 'active',
  role: 'user',
  isProfileCompleted: true,
  isFaceVerified: true,
  lastActiveAt: new Date(),
  createdAt: new Date(),
  updatedAt: new Date()
};

test('renders user list with filters and data', async () => {
  const html = await ejs.renderFile(path.join(views, 'index.ejs'), {
    pageTitle: 'Quản lý tài khoản người dùng',
    users: [baseUser],
    statistics: { total: 1, active: 1, restricted: 0, suspended: 0, banned: 0, verified: 1 },
    filters: { q: '', status: '', verification: '', activity: '', risk: '', cursor: '', limit: 20 },
    nextPageUrl: null,
    hasPreviousPage: false,
    scanned: 1,
    scanLimitReached: false,
    statusLabels,
    formatDate,
    maskEmail,
    maskPhone
  });
  assert.match(html, /Nguyễn An/);
  assert.match(html, /Quản lý tài khoản người dùng/);
});

test('renders full user detail and action form', async () => {
  const html = await ejs.renderFile(path.join(views, 'show.ejs'), {
    user: baseUser,
    auth: {
      email: baseUser.email,
      emailVerified: true,
      phoneNumber: baseUser.phonenumber,
      disabled: false,
      providers: ['password'],
      mfaFactors: [],
      lastSignInTime: new Date(),
      tokensValidAfterTime: new Date()
    },
    devices: [],
    counts: {
      posts: 3, reports: 1, postReports: 1, profileReports: 0,
      matchingReports: 0, confirmedViolations: 0
    },
    moderationViolations: [],
    penaltyLogs: [],
    adminActions: [],
    successMessage: null,
    errorMessage: null,
    statusLabels,
    formatDate,
    maskEmail,
    maskPhone,
    allowedFeatures: ['posts', 'comments', 'chat', 'matching', 'calls'],
    canPerformAction: () => true,
    csrfToken: 'a'.repeat(64)
  });
  assert.match(html, /Chi tiết tài khoản/);
  assert.match(html, /name="_csrf"/);
  assert.match(html, /data-user-action="ban"/);
  assert.equal((html.match(/data-avatar-image/g) || []).length, 2);
});
