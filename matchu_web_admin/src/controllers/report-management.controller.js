const {
  getReportStatistics,
  listReportCases,
  getReportCaseDetail,
  executeReportAction
} = require('../services/report-management.service');
const { writeAuditLog } = require('../services/audit-log.service');
const {
  validateReportListQuery,
  validateReportCaseId,
  validateReportAction
} = require('../validators/report-management.validator');
const { REPORT_ACTION_PERMISSIONS } = require('../config/constants');
const AppError = require('../utils/app-error');

const TYPE_LABELS = Object.freeze({
  post: 'Bài viết',
  comment: 'Bình luận',
  profile: 'Hồ sơ người dùng',
  matching: 'Matching'
});
const STATUS_LABELS = Object.freeze({
  open: 'Chờ xử lý',
  in_review: 'Đang xem xét',
  resolved: 'Đã xử lý',
  dismissed: 'Đã bác'
});
const PRIORITY_LABELS = Object.freeze({
  normal: 'Thông thường',
  medium: 'Trung bình',
  high: 'Cao',
  critical: 'Khẩn cấp'
});
const RESOLUTION_LABELS = Object.freeze({
  action_taken: 'Đã thực hiện biện pháp',
  content_removed: 'Đã gỡ nội dung',
  account_penalized: 'Đã xử lý tài khoản',
  no_action: 'Không cần biện pháp bổ sung',
  not_violation: 'Không xác định vi phạm'
});
const ACTION_MESSAGES = Object.freeze({
  assign_to_me: 'Đã nhận xử lý hồ sơ báo cáo.',
  start_review: 'Đã chuyển hồ sơ sang trạng thái đang xem xét.',
  resolve: 'Đã kết luận hồ sơ báo cáo.',
  dismiss: 'Đã bác hồ sơ báo cáo.',
  reopen: 'Đã mở lại hồ sơ báo cáo.'
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

function validatedCaseId(value) {
  const result = validateReportCaseId(value);
  if (result.error) {
    throw new AppError('Mã hồ sơ báo cáo không hợp lệ.', 400, 'INVALID_REPORT_CASE_ID');
  }
  return result.value;
}

function canPerformAction(currentAdmin, action) {
  const permissions = REPORT_ACTION_PERMISSIONS[action] || [];
  return currentAdmin?.role === 'super_admin'
    || permissions.some((permission) => currentAdmin?.permissions?.includes(permission));
}

function listQueryString(filters, overrides = {}) {
  const params = new URLSearchParams();
  const merged = { ...filters, ...overrides };
  for (const key of ['q', 'type', 'status', 'source', 'priority', 'assignee', 'cursor', 'limit']) {
    if (merged[key] !== '' && merged[key] !== null && merged[key] !== undefined) {
      params.set(key, String(merged[key]));
    }
  }
  return params.toString();
}

function commonViewData(req) {
  return {
    typeLabels: TYPE_LABELS,
    statusLabels: STATUS_LABELS,
    priorityLabels: PRIORITY_LABELS,
    resolutionLabels: RESOLUTION_LABELS,
    formatDate,
    formatNumber,
    canPerformAction: (action) => canPerformAction(req.admin, action)
  };
}

async function index(req, res) {
  const { error, value: filters } = validateReportListQuery(req.query);
  if (error) throw new AppError('Bộ lọc báo cáo không hợp lệ.', 400);

  const [{ cases, nextCursor, scanned, scanLimitReached }, statistics] = await Promise.all([
    listReportCases(filters, req.admin),
    getReportStatistics()
  ]);
  return res.render('reports/index', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Quản lý báo cáo',
    cases,
    statistics,
    filters,
    nextPageUrl: nextCursor
      ? `/reports?${listQueryString(filters, { cursor: nextCursor })}`
      : null,
    hasPreviousPage: Boolean(filters.cursor),
    scanned,
    scanLimitReached,
    ...commonViewData(req)
  });
}

async function show(req, res) {
  const caseId = validatedCaseId(req.params.caseId);
  const detail = await getReportCaseDetail(caseId);
  return res.render('reports/show', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Chi tiết hồ sơ báo cáo',
    ...detail,
    successMessage: String(req.query.success || '').slice(0, 300) || null,
    errorMessage: String(req.query.error || '').slice(0, 300) || null,
    ...commonViewData(req)
  });
}

async function action(req, res) {
  const caseId = validatedCaseId(req.params.caseId);
  const { error, value } = validateReportAction(req.body);
  if (error) {
    return res.redirect(
      `/reports/${encodeURIComponent(caseId)}?error=${encodeURIComponent(
        `Dữ liệu xử lý không hợp lệ: ${error.details[0].message}`
      )}`
    );
  }

  try {
    const result = await executeReportAction(caseId, value, req.admin);
    await writeAuditLog({
      admin: req.admin,
      action: `REPORT_${value.action.toUpperCase()}`,
      targetType: 'report_case',
      targetId: caseId,
      metadata: {
        actionId: result.actionId,
        reason: value.reason || null,
        resolution: result.resolution || null,
        beforeStatus: result.beforeStatus,
        afterStatus: result.afterStatus
      },
      req
    });
    return res.redirect(
      `/reports/${encodeURIComponent(caseId)}?success=${encodeURIComponent(
        ACTION_MESSAGES[value.action] || 'Đã cập nhật hồ sơ báo cáo.'
      )}`
    );
  } catch (error) {
    await writeAuditLog({
      admin: req.admin,
      action: `REPORT_${value.action.toUpperCase()}_FAILED`,
      targetType: 'report_case',
      targetId: caseId,
      metadata: { errorCode: error.code || 'UNKNOWN' },
      req
    });
    if (!(error instanceof AppError)) throw error;
    return res.redirect(
      `/reports/${encodeURIComponent(caseId)}?error=${encodeURIComponent(error.message)}`
    );
  }
}

module.exports = { index, show, action };
