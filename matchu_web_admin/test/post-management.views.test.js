const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ejs = require('ejs');

const views = path.join(__dirname, '..', 'src', 'views', 'posts');
const typeLabels = { post: 'Bài thường', quote: 'Trích dẫn', repost: 'Đăng lại' };
const visibilityLabels = { public: 'Công khai', followers: 'Người theo dõi', private: 'Riêng tư' };
const moderationLabels = {
  approved: 'Đã duyệt',
  pending_moderation: 'Đang xử lý',
  review_required: 'Cần duyệt thủ công',
  rejected: 'Đã từ chối'
};
const priorityLabels = {
  normal: 'Thông thường',
  medium: 'Trung bình',
  high: 'Cao',
  critical: 'Khẩn cấp'
};
const formatDate = (value) => value instanceof Date ? value.toISOString() : '—';
const formatNumber = (value) => Number(value || 0).toLocaleString('vi-VN');
const basePost = {
  postId: 'post-1',
  authorId: 'user-1',
  postType: 'post',
  content: 'Nội dung bài viết kiểm thử',
  media: [{
    type: 'image',
    url: 'https://firebasestorage.googleapis.com/v0/b/example/o/post.jpg?alt=media',
    thumbnailUrl: '',
    storagePath: '',
    mimeType: 'image/jpeg'
  }],
  mediaTypes: ['image'],
  tags: ['matchu'],
  visibility: 'public',
  requestedVisibility: null,
  moderationStatus: 'review_required',
  moderationSource: 'gemini_video',
  moderationMessageVi: '',
  moderationPolicyVersion: 'video_moderation_v1',
  videoStoragePath: '',
  videoModeration: {
    decision: 'review_required',
    confidence: 0.68,
    overallSeverity: 2,
    primaryViolationCategory: 'privacy_doxxing',
    needsHumanReview: true,
    safeSummary: 'Cần kiểm tra thêm.',
    humanReviewReason: 'Không đủ chắc chắn.',
    violations: [{ category: 'privacy_doxxing', severity: 2 }]
  },
  adminModeration: null,
  stats: {
    likeCount: 3,
    commentCount: 2,
    shareCount: 1,
    externalShareCount: 0,
    saveCount: 4
  },
  trendScore: 2.5,
  recommendationStatus: 'ready',
  author: {
    name: 'Nguyễn An',
    nickname: 'nguyenan',
    avatar: '',
    isVerified: true
  },
  referencePost: null,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
  deletedAt: null,
  reportCount: 1,
  reportCategories: ['spam'],
  latestReportAt: new Date(),
  moderationCase: null,
  reportState: 'open',
  priority: 'high'
};
const common = {
  typeLabels,
  visibilityLabels,
  moderationLabels,
  priorityLabels,
  formatDate,
  formatNumber,
  canAccessReports: true,
  canPerformAction: () => true
};

test('renders post list with operational filters', async () => {
  const html = await ejs.renderFile(path.join(views, 'index.ejs'), {
    pageTitle: 'Quản lý bài viết',
    posts: [basePost],
    statistics: { total: 1, approved: 0, pending: 0, reviewRequired: 1, rejected: 0, reportCount: 1 },
    filters: {
      q: '', type: '', media: '', visibility: '', moderation: '',
      lifecycle: '', report: '', queue: 'moderation', priority: '', cursor: '', limit: 20
    },
    nextPageUrl: null,
    hasPreviousPage: false,
    scanned: 1,
    scanLimitReached: false,
    ...common
  });
  assert.match(html, /Quản lý bài viết/);
  assert.match(html, /Nội dung bài viết kiểm thử/);
  assert.match(html, /Cần duyệt thủ công/);
  assert.match(html, /Hàng đợi kiểm duyệt bài viết/);
  assert.match(html, /from=post_moderation/);
});

test('renders post detail, evidence and protected moderation form', async () => {
  const html = await ejs.renderFile(path.join(views, 'show.ejs'), {
    pageTitle: 'Chi tiết bài viết',
    post: basePost,
    authorAccount: {
      uid: 'user-1',
      fullname: 'Nguyễn An',
      nickname: 'nguyenan',
      avatarUrl: '',
      accountStatus: 'active',
      reputationScore: 80,
      totalReports: 1,
      trustWarnings: 0
    },
    reports: [{
      id: 'report-1',
      fromUid: 'reporter-1',
      categoryTitle: 'Spam',
      categoryKey: 'spam',
      reasonTitle: 'Đăng lặp lại',
      reasonKey: 'repeated_posts',
      customReason: '',
      description: 'Nội dung báo cáo',
      imageUrls: ['https://firebasestorage.googleapis.com/v0/b/example/o/evidence.jpg?alt=media'],
      createdAt: new Date(),
      reporter: { name: 'Người báo cáo', nickname: 'reporter', accountStatus: 'active' }
    }],
    moderationCase: {
      status: 'open',
      priority: 'high',
      assignedAdminEmail: '',
      assignedAdminId: '',
      resolution: '',
      resolutionReason: '',
      createdAt: new Date(),
      updatedAt: null
    },
    caseActions: [],
    commentCount: 2,
    successMessage: null,
    errorMessage: null,
    backUrl: '/reports?type=post&source=content_moderation',
    csrfToken: 'a'.repeat(64),
    ...common
  });
  assert.match(html, /Kết quả kiểm duyệt video/);
  assert.match(html, /Báo cáo cộng đồng/);
  assert.match(html, /name="_csrf"/);
  assert.match(html, /data-post-action="reject"/);
});

test('renders permanent delete only for soft-deleted posts', async () => {
  const html = await ejs.renderFile(path.join(views, 'show.ejs'), {
    pageTitle: 'Chi tiết bài viết',
    post: { ...basePost, deletedAt: new Date() },
    authorAccount: null,
    reports: [],
    moderationCase: null,
    caseActions: [],
    commentCount: 0,
    successMessage: null,
    errorMessage: null,
    backUrl: '/posts',
    csrfToken: 'a'.repeat(64),
    ...common
  });
  assert.match(html, /data-post-action="delete_permanently"/);
  assert.match(html, /name="confirmation"/);
});
