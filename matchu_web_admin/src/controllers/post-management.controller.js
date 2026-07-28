const {
  getPostStatistics,
  listPosts,
  getPostDetail,
  executePostModerationAction
} = require('../services/post-management.service');
const { writeAuditLog } = require('../services/audit-log.service');
const {
  recordTargetModerationOutcome
} = require('../services/report-management.service');
const {
  validatePostListQuery,
  validatePostId,
  validatePostAction
} = require('../validators/post-management.validator');
const { POST_ACTION_PERMISSIONS } = require('../config/constants');
const AppError = require('../utils/app-error');

const POST_TYPE_LABELS = Object.freeze({
  post: 'Bài thường',
  quote: 'Trích dẫn',
  repost: 'Đăng lại'
});
const VISIBILITY_LABELS = Object.freeze({
  public: 'Công khai',
  followers: 'Người theo dõi',
  private: 'Riêng tư'
});
const MODERATION_LABELS = Object.freeze({
  approved: 'Đã duyệt',
  pending_moderation: 'Đang xử lý',
  review_required: 'Cần duyệt thủ công',
  rejected: 'Đã từ chối'
});
const PRIORITY_LABELS = Object.freeze({
  normal: 'Thông thường',
  medium: 'Trung bình',
  high: 'Cao',
  critical: 'Khẩn cấp'
});
const ACTION_MESSAGES = Object.freeze({
  approve: 'Đã duyệt và cập nhật trạng thái bài viết.',
  reject: 'Đã gỡ bài viết và thông báo cho tác giả.',
  review: 'Đã chuyển bài viết sang hàng đợi xem xét thủ công.',
  dismiss: 'Đã bác báo cáo và giữ bài viết.',
  restore: 'Đã khôi phục bài viết.',
  delete_permanently: 'Đã xóa vĩnh viễn bài viết và dữ liệu liên quan.'
});

function formatDate(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) return '—';
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Ho_Chi_Minh'
  }).format(value);
}

function formatNumber(value) {
  return Number(value || 0).toLocaleString('vi-VN');
}

function listQueryString(filters, overrides = {}) {
  const params = new URLSearchParams();
  const merged = { ...filters, ...overrides };
  const keys = [
    'q', 'type', 'media', 'visibility', 'moderation', 'lifecycle',
    'report', 'priority', 'cursor', 'limit'
  ];
  for (const key of keys) {
    if (merged[key] !== '' && merged[key] !== null && merged[key] !== undefined) {
      params.set(key, String(merged[key]));
    }
  }
  return params.toString();
}

function canPerformAction(currentAdmin, action) {
  const permissions = POST_ACTION_PERMISSIONS[action] || [];
  return currentAdmin?.role === 'super_admin'
    || permissions.some((permission) => currentAdmin?.permissions?.includes(permission));
}

function commonViewData(req) {
  return {
    typeLabels: POST_TYPE_LABELS,
    visibilityLabels: VISIBILITY_LABELS,
    moderationLabels: MODERATION_LABELS,
    priorityLabels: PRIORITY_LABELS,
    formatDate,
    formatNumber,
    canAccessReports: req.admin?.role === 'super_admin'
      || req.admin?.permissions?.includes('reports.read'),
    canPerformAction: (action) => canPerformAction(req.admin, action)
  };
}

function validatedPostId(value) {
  const result = validatePostId(value);
  if (result.error) throw new AppError('Mã bài viết không hợp lệ.', 400, 'INVALID_POST_ID');
  return result.value;
}

async function index(req, res) {
  const { error, value: filters } = validatePostListQuery(req.query);
  if (error) throw new AppError('Bộ lọc danh sách bài viết không hợp lệ.', 400);

  const [{ posts, nextCursor, scanned, scanLimitReached }, statistics] = await Promise.all([
    listPosts(filters),
    getPostStatistics()
  ]);
  return res.render('posts/index', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Quản lý bài viết',
    posts,
    statistics,
    filters,
    nextPageUrl: nextCursor
      ? `/posts?${listQueryString(filters, { cursor: nextCursor })}`
      : null,
    hasPreviousPage: Boolean(filters.cursor),
    scanned,
    scanLimitReached,
    successMessage: String(req.query.success || '').slice(0, 300) || null,
    errorMessage: String(req.query.error || '').slice(0, 300) || null,
    ...commonViewData(req)
  });
}

async function show(req, res) {
  const postId = validatedPostId(req.params.postId);
  const detail = await getPostDetail(postId);
  const returnCaseId = req.query.from === 'reports'
    && /^(post|profile|matching)_[a-f0-9]{40}$/.test(String(req.query.caseId || ''))
    ? String(req.query.caseId)
    : '';
  return res.render('posts/show', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Chi tiết bài viết',
    ...detail,
    successMessage: String(req.query.success || '').slice(0, 300) || null,
    errorMessage: String(req.query.error || '').slice(0, 300) || null,
    backUrl: returnCaseId
      ? `/reports/${encodeURIComponent(returnCaseId)}`
      : req.query.from === 'moderation'
        ? '/reports?type=post&source=content_moderation'
        : '/posts',
    returnCaseId,
    ...commonViewData(req)
  });
}

async function action(req, res) {
  const postId = validatedPostId(req.params.postId);
  const { error, value } = validatePostAction(req.body);
  if (error) {
    return res.redirect(
      `/posts/${encodeURIComponent(postId)}?from=moderation&error=${encodeURIComponent(
        `Dữ liệu xử lý không hợp lệ: ${error.details[0].message}`
      )}`
    );
  }

  try {
    const result = await executePostModerationAction(postId, value, req.admin);
    try {
      await recordTargetModerationOutcome({
        type: 'post',
        targetId: postId,
        action: value.action,
        reason: value.reason,
        currentAdmin: req.admin
      });
    } catch (syncError) {
      console.error('Unable to synchronize report case outcome:', syncError.message);
    }
    await writeAuditLog({
      admin: req.admin,
      action: `POST_${value.action.toUpperCase()}`,
      targetType: 'post',
      targetId: postId,
      metadata: {
        actionId: result.actionId,
        caseId: result.caseId,
        reason: value.reason,
        reportCount: result.reportCount,
        before: result.before,
        after: result.after,
        deletionCounts: result.deletionCounts || null
      },
      req
    });
    if (value.action === 'delete_permanently') {
      const returnCaseId = /^(post|profile|matching)_[a-f0-9]{40}$/.test(
        String(req.body.returnCaseId || '')
      ) ? String(req.body.returnCaseId) : '';
      if (returnCaseId) {
        return res.redirect(
          `/reports/${encodeURIComponent(returnCaseId)}?success=${encodeURIComponent(
            ACTION_MESSAGES[value.action]
          )}`
        );
      }
      return res.redirect(
        `/posts?lifecycle=deleted&success=${encodeURIComponent(ACTION_MESSAGES[value.action])}`
      );
    }
    const returnCaseId = /^(post|profile|matching)_[a-f0-9]{40}$/.test(
      String(req.body.returnCaseId || '')
    ) ? String(req.body.returnCaseId) : '';
    if (returnCaseId) {
      return res.redirect(
        `/reports/${encodeURIComponent(returnCaseId)}?success=${encodeURIComponent(
          ACTION_MESSAGES[value.action] || 'Đã cập nhật bài viết.'
        )}`
      );
    }
    return res.redirect(
      `/posts/${encodeURIComponent(postId)}?from=moderation&success=${encodeURIComponent(
        ACTION_MESSAGES[value.action] || 'Đã cập nhật bài viết.'
      )}`
    );
  } catch (error) {
    await writeAuditLog({
      admin: req.admin,
      action: `POST_${value.action.toUpperCase()}_FAILED`,
      targetType: 'post',
      targetId: postId,
      metadata: { errorCode: error.code || 'UNKNOWN' },
      req
    });
    if (!(error instanceof AppError)) throw error;
    return res.redirect(
      `/posts/${encodeURIComponent(postId)}?from=moderation&error=${encodeURIComponent(error.message)}`
    );
  }
}

module.exports = { index, show, action };
