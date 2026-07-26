const {
  listUsers,
  getUserStatistics,
  getUserDetail,
  executeUserAction
} = require('../services/user-account.service');
const { writeAuditLog } = require('../services/audit-log.service');
const {
  validateListQuery,
  validateUserAction,
  allowedFeatures
} = require('../validators/user-account.validator');
const { USER_ACTION_PERMISSIONS } = require('../config/constants');
const AppError = require('../utils/app-error');

const STATUS_LABELS = Object.freeze({
  active: 'Đang hoạt động',
  restricted: 'Bị hạn chế',
  suspended: 'Tạm khóa',
  banned: 'Đã cấm',
  deleting: 'Đang xóa',
  deleted: 'Đã xóa'
});

const ACTION_MESSAGES = Object.freeze({
  warn: 'Đã gửi cảnh báo cho người dùng.',
  restrict: 'Đã áp dụng hạn chế tài khoản.',
  suspend: 'Đã tạm khóa tài khoản và thu hồi các phiên đăng nhập.',
  ban: 'Đã cấm tài khoản và thu hồi các phiên đăng nhập.',
  restore: 'Đã khôi phục tài khoản.',
  revoke_sessions: 'Đã thu hồi toàn bộ phiên đăng nhập.',
  reset_face_verification: 'Đã đặt lại trạng thái xác minh khuôn mặt.',
  send_password_reset: 'Đã gửi email đặt lại mật khẩu.',
  adjust_gem: 'Đã điều chỉnh số dư gem.',
  adjust_reputation: 'Đã điều chỉnh điểm uy tín.'
});

function formatDate(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) return '—';
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Ho_Chi_Minh'
  }).format(value);
}

function maskEmail(value) {
  const email = String(value || '').trim();
  const [name, domain] = email.split('@');
  if (!name || !domain) return email || '—';
  const visible = name.slice(0, Math.min(2, name.length));
  return `${visible}${'*'.repeat(Math.max(2, name.length - visible.length))}@${domain}`;
}

function maskPhone(value) {
  const phone = String(value || '').trim();
  if (!phone) return '—';
  if (phone.length <= 4) return phone;
  return `${'*'.repeat(phone.length - 4)}${phone.slice(-4)}`;
}

function listQueryString(filters, overrides = {}) {
  const params = new URLSearchParams();
  const merged = { ...filters, ...overrides };
  for (const key of ['q', 'status', 'verification', 'activity', 'risk', 'cursor', 'limit']) {
    if (merged[key] !== '' && merged[key] !== null && merged[key] !== undefined) {
      params.set(key, String(merged[key]));
    }
  }
  return params.toString();
}

function canPerformAction(admin, action) {
  const permission = USER_ACTION_PERMISSIONS[action];
  return admin?.role === 'super_admin'
    || Boolean(permission && admin?.permissions?.includes(permission));
}

async function index(req, res) {
  const { error, value: filters } = validateListQuery(req.query);
  if (error) throw new AppError('Bộ lọc danh sách người dùng không hợp lệ.', 400);

  const [{ users, nextCursor, scanned, scanLimitReached }, statistics] = await Promise.all([
    listUsers(filters),
    getUserStatistics()
  ]);

  return res.render('users/index', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Quản lý tài khoản người dùng',
    users,
    statistics,
    filters,
    nextPageUrl: nextCursor
      ? `/users?${listQueryString(filters, { cursor: nextCursor })}`
      : null,
    hasPreviousPage: Boolean(filters.cursor),
    scanned,
    scanLimitReached,
    statusLabels: STATUS_LABELS,
    formatDate,
    maskEmail,
    maskPhone
  });
}

async function show(req, res) {
  const detail = await getUserDetail(req.params.uid);
  const successMessage = String(req.query.success || '').slice(0, 300);
  const errorMessage = String(req.query.error || '').slice(0, 300);
  return res.render('users/show', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Chi tiết tài khoản',
    ...detail,
    successMessage: successMessage || null,
    errorMessage: errorMessage || null,
    statusLabels: STATUS_LABELS,
    formatDate,
    maskEmail,
    maskPhone,
    allowedFeatures,
    canPerformAction: (action) => canPerformAction(req.admin, action)
  });
}

async function action(req, res) {
  const uid = req.params.uid;
  const { error, value } = validateUserAction(req.body);
  if (error) {
    const message = encodeURIComponent(`Dữ liệu xử lý không hợp lệ: ${error.details[0].message}`);
    return res.redirect(`/users/${encodeURIComponent(uid)}?error=${message}`);
  }

  try {
    const result = await executeUserAction(uid, value, req.admin);
    await writeAuditLog({
      admin: req.admin,
      action: `USER_${value.action.toUpperCase()}`,
      targetType: 'user',
      targetId: uid,
      metadata: {
        actionId: result.actionId,
        reason: value.reason || null,
        reportId: value.reportId || null,
        features: value.features || [],
        durationDays: value.durationDays || null,
        amount: value.amount || null,
        before: result.before,
        after: result.after
      },
      req
    });
    const message = encodeURIComponent(ACTION_MESSAGES[value.action] || 'Đã cập nhật tài khoản.');
    return res.redirect(`/users/${encodeURIComponent(uid)}?success=${message}`);
  } catch (error) {
    await writeAuditLog({
      admin: req.admin,
      action: `USER_${value.action.toUpperCase()}_FAILED`,
      targetType: 'user',
      targetId: uid,
      metadata: {
        errorCode: error.code || 'UNKNOWN',
        reportId: value.reportId || null
      },
      req
    });
    if (!(error instanceof AppError)) throw error;
    return res.redirect(
      `/users/${encodeURIComponent(uid)}?error=${encodeURIComponent(error.message)}`
    );
  }
}

module.exports = { index, show, action };
