const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ejs = require('ejs');

const views = path.join(__dirname, '..', 'src', 'views', 'reports');
const caseId = `post_${'a'.repeat(40)}`;
const reportCase = {
  caseId,
  type: 'post',
  targetId: 'post-1',
  contextId: '',
  reportedUid: 'user-1',
  postId: 'post-1',
  roomId: '',
  status: 'open',
  priority: 'high',
  reportCount: 2,
  categoryKeys: ['spam'],
  caseSources: ['community_reports', 'content_moderation'],
  contentModerationRequired: true,
  moderationStatus: 'review_required',
  moderationSource: 'gemini_video',
  moderationSummary: 'Cần kiểm tra thêm.',
  moderationReason: 'Độ tin cậy chưa đủ cao.',
  latestReasonKey: 'repeated_posts',
  latestReportAt: new Date(),
  assignedAdminId: '',
  assignedAdminEmail: '',
  resolution: '',
  resolutionReason: '',
  updatedAt: new Date(),
  reportedUser: { uid: 'user-1', fullname: 'Nguyễn An', accountStatus: 'active' },
  post: {
    postId: 'post-1',
    authorId: 'user-1',
    content: 'Nội dung bài viết bị báo cáo',
    author: { name: 'Nguyễn An', nickname: 'an' },
    mediaUrl: '',
    moderationStatus: 'review_required',
    moderationSource: 'gemini_video',
    videoModeration: {
      primaryViolationCategory: 'spam',
      overallSeverity: 2,
      safeSummary: 'Cần kiểm tra thêm.',
      humanReviewReason: 'Độ tin cậy chưa đủ cao.'
    }
  }
};
const common = {
  typeLabels: { post: 'Bài viết', comment: 'Bình luận', profile: 'Hồ sơ người dùng', matching: 'Matching' },
  statusLabels: { open: 'Chờ xử lý', in_review: 'Đang xem xét', resolved: 'Đã xử lý', dismissed: 'Đã bác' },
  priorityLabels: { normal: 'Thông thường', medium: 'Trung bình', high: 'Cao', critical: 'Khẩn cấp' },
  resolutionLabels: {
    action_taken: 'Đã thực hiện biện pháp',
    content_removed: 'Đã gỡ nội dung',
    account_penalized: 'Đã xử lý tài khoản',
    no_action: 'Không cần biện pháp bổ sung',
    not_violation: 'Không xác định vi phạm'
  },
  formatDate: (value) => value instanceof Date ? value.toISOString() : '—',
  formatNumber: (value) => String(value),
  canPerformAction: () => true
};

test('renders unified report queue and filters', async () => {
  const html = await ejs.renderFile(path.join(views, 'index.ejs'), {
    cases: [reportCase],
    statistics: { total: 1, open: 1, inReview: 0, resolved: 0, dismissed: 0 },
    filters: { q: '', type: '', status: '', source: '', priority: '', assignee: '', cursor: '', limit: 20 },
    nextPageUrl: null,
    hasPreviousPage: false,
    scanned: 1,
    scanLimitReached: false,
    ...common
  });
  assert.match(html, /Quản lý báo cáo/);
  assert.match(html, /Nội dung bài viết bị báo cáo/);
  assert.match(html, /AI/);
  assert.match(html, new RegExp(`/reports/${caseId}`));
});

test('renders report evidence, target links and protected actions', async () => {
  const html = await ejs.renderFile(path.join(views, 'show.ejs'), {
    reportCase,
    reports: [{
      id: 'report-1',
      type: 'post',
      reporterUid: 'reporter-1',
      reporter: { fullname: 'Người báo cáo', accountStatus: 'active' },
      categoryTitle: 'Spam',
      reasonTitle: 'Đăng lặp lại',
      customReason: '',
      description: 'Báo cáo kiểm thử',
      postContentPreview: 'Ảnh chụp nội dung',
      imageUrls: ['https://storage.googleapis.com/evidence.jpg'],
      createdAt: new Date()
    }],
    actions: [],
    matchingContext: null,
    csrfToken: 'a'.repeat(64),
    successMessage: null,
    errorMessage: null,
    ...common
  });
  assert.match(html, /Bằng chứng cộng đồng/);
  assert.match(html, /Tín hiệu kiểm duyệt hệ thống/);
  assert.match(html, /Người báo cáo/);
  assert.match(html, /name="_csrf"/);
  assert.match(html, /data-report-action="resolve"/);
});

test('renders a reported comment with live and snapshotted media evidence', async () => {
  const commentCase = {
    ...reportCase,
    subjectType: 'comment',
    contextId: 'comment-1',
    commentId: 'comment-1',
    contentModerationRequired: false,
    comment: {
      commentId: 'comment-1',
      userId: 'user-1',
      content: 'Bình luận đang bị báo cáo',
      parentId: 'parent-1',
      imageUrl: 'https://storage.googleapis.com/comment.jpg',
      voiceUrl: 'https://storage.googleapis.com/comment.m4a',
      isEdited: true,
      deletedAt: null
    }
  };
  const html = await ejs.renderFile(path.join(views, 'show.ejs'), {
    reportCase: commentCase,
    reports: [{
      id: 'comment-report-1',
      type: 'post',
      source: 'commentReports',
      reporterUid: 'reporter-1',
      reporter: { fullname: 'Người báo cáo', accountStatus: 'active' },
      categoryTitle: 'Quấy rối',
      reasonTitle: 'Công kích cá nhân',
      customReason: '',
      description: '',
      commentContentPreview: 'Bản chụp bình luận',
      commentAuthorName: 'Tác giả bình luận',
      commentAuthorNickname: '',
      commentImageUrl: 'https://storage.googleapis.com/snapshot.jpg',
      commentVoiceUrl: 'https://storage.googleapis.com/snapshot.m4a',
      postContentPreview: '',
      imageUrls: [],
      createdAt: new Date()
    }],
    actions: [],
    matchingContext: null,
    csrfToken: 'a'.repeat(64),
    successMessage: null,
    errorMessage: null,
    ...common
  });

  assert.match(html, /Bình luận đang bị báo cáo/);
  assert.match(html, /Nội dung bình luận khi được báo cáo/);
  assert.match(html, /snapshot\.jpg/);
  assert.match(html, /snapshot\.m4a/);
  assert.match(html, /Mở bài viết/);
});
