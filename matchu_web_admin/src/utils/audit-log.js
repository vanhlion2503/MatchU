const ACTION_DEFINITIONS = Object.freeze({
  ADMIN_LOGIN: ['Đăng nhập hệ thống', 'auth', 'normal'],
  ADMIN_LOGIN_DENIED: ['Đăng nhập bị từ chối', 'auth', 'danger'],
  ADMIN_LOGOUT: ['Đăng xuất hệ thống', 'auth', 'normal'],
  LOGIN_SUCCESS: ['Đăng nhập hệ thống', 'auth', 'normal'],
  LOGOUT: ['Đăng xuất hệ thống', 'auth', 'normal'],
  USER_WARN: ['Cảnh báo người dùng', 'users', 'warning'],
  USER_RESTRICT: ['Hạn chế tài khoản', 'users', 'warning'],
  USER_SUSPEND: ['Tạm khóa tài khoản', 'users', 'danger'],
  USER_BAN: ['Cấm tài khoản', 'users', 'danger'],
  USER_RESTORE: ['Khôi phục tài khoản', 'users', 'success'],
  USER_REVOKE_SESSIONS: ['Thu hồi toàn bộ phiên đăng nhập', 'users', 'warning'],
  USER_RESET_FACE_VERIFICATION: ['Đặt lại xác minh khuôn mặt', 'users', 'warning'],
  USER_SEND_PASSWORD_RESET: ['Gửi email đặt lại mật khẩu', 'users', 'normal'],
  USER_ADJUST_GEM: ['Điều chỉnh Gem', 'users', 'warning'],
  USER_ADJUST_REPUTATION: ['Điều chỉnh điểm uy tín', 'users', 'warning'],
  POST_APPROVE: ['Duyệt bài viết', 'posts', 'success'],
  POST_REJECT: ['Từ chối bài viết', 'posts', 'danger'],
  POST_REVIEW: ['Chuyển bài sang xem xét', 'posts', 'warning'],
  POST_DISMISS: ['Bác báo cáo bài viết', 'posts', 'normal'],
  POST_RESTORE: ['Khôi phục bài viết', 'posts', 'success'],
  POST_DELETE_PERMANENTLY: ['Xóa vĩnh viễn bài viết', 'posts', 'danger'],
  REPORT_ASSIGN_TO_ME: ['Nhận xử lý hồ sơ báo cáo', 'reports', 'normal'],
  REPORT_START_REVIEW: ['Bắt đầu xem xét hồ sơ', 'reports', 'warning'],
  REPORT_RESOLVE: ['Kết luận hồ sơ báo cáo', 'reports', 'success'],
  REPORT_DISMISS: ['Bác hồ sơ báo cáo', 'reports', 'normal'],
  REPORT_REOPEN: ['Mở lại hồ sơ báo cáo', 'reports', 'warning'],
  NOTIFICATION_PUBLISHED: ['Phát hành chiến dịch thông báo', 'notifications', 'success'],
  NOTIFICATION_DRAFT_CREATED: ['Tạo bản nháp thông báo', 'notifications', 'normal'],
  NOTIFICATION_DRAFT_UPDATED: ['Cập nhật bản nháp thông báo', 'notifications', 'normal'],
  NOTIFICATION_CANCEL: ['Hủy chiến dịch thông báo', 'notifications', 'warning'],
  NOTIFICATION_RETRY_FAILED: ['Thử lại các lô gửi thất bại', 'notifications', 'warning']
});

const CATEGORY_LABELS = Object.freeze({
  auth: 'Xác thực',
  users: 'Người dùng',
  posts: 'Bài viết',
  reports: 'Báo cáo',
  notifications: 'Thông báo',
  system: 'Hệ thống'
});

const RESULT_LABELS = Object.freeze({
  success: 'Thành công',
  failure: 'Thất bại',
  denied: 'Bị từ chối'
});

const TARGET_TYPE_LABELS = Object.freeze({
  admin: 'Quản trị viên',
  user: 'Người dùng',
  post: 'Bài viết',
  report_case: 'Hồ sơ báo cáo',
  notification_campaign: 'Chiến dịch thông báo'
});

const CHANGE_FIELD_LABELS = Object.freeze({
  accountStatus: 'Trạng thái tài khoản',
  trustWarnings: 'Số cảnh báo',
  gem: 'Gem',
  reputationScore: 'Điểm uy tín',
  isFaceVerified: 'Xác minh khuôn mặt',
  moderationStatus: 'Trạng thái kiểm duyệt',
  visibility: 'Quyền xem',
  deletedAt: 'Thời điểm xóa',
  permanentlyDeleted: 'Xóa vĩnh viễn'
});

const SENSITIVE_KEY = /authorization|cookie|credential|id.?token|password|passcode|private.?key|refresh.?token|secret|session/i;
const MAX_METADATA_DEPTH = 5;
const MAX_METADATA_KEYS = 80;
const MAX_ARRAY_ITEMS = 50;
const MAX_STRING_LENGTH = 1200;

function cleanAction(value) {
  return String(value || '')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .slice(0, 120);
}

function stripFailureSuffix(action) {
  return action.endsWith('_FAILED') && action !== 'NOTIFICATION_RETRY_FAILED'
    ? action.slice(0, -7)
    : action;
}

function deriveResult(action, explicitResult) {
  if (RESULT_LABELS[explicitResult]) return explicitResult;
  if (action === 'ADMIN_LOGIN_DENIED') return 'denied';
  return action.endsWith('_FAILED') && action !== 'NOTIFICATION_RETRY_FAILED'
    ? 'failure'
    : 'success';
}

function deriveCategory(action, explicitCategory) {
  if (CATEGORY_LABELS[explicitCategory]) return explicitCategory;
  const prefix = stripFailureSuffix(action).split('_')[0];
  return {
    ADMIN: 'auth',
    LOGIN: 'auth',
    LOGOUT: 'auth',
    USER: 'users',
    POST: 'posts',
    REPORT: 'reports',
    NOTIFICATION: 'notifications'
  }[prefix] || 'system';
}

function fallbackActionLabel(action) {
  if (!action) return 'Hoạt động quản trị';
  return stripFailureSuffix(action)
    .toLowerCase()
    .split('_')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function targetUrl(targetType, targetId) {
  if (!targetId) return null;
  const encoded = encodeURIComponent(targetId);
  return {
    user: `/users/${encoded}`,
    post: `/posts/${encoded}`,
    report_case: `/reports/${encoded}`,
    notification_campaign: `/notifications/${encoded}`
  }[targetType] || null;
}

function toSafeMetadata(value, depth = 0, seen = new WeakSet()) {
  if (value == null || typeof value === 'boolean' || typeof value === 'number') return value;
  if (typeof value === 'string') {
    return value.length > MAX_STRING_LENGTH
      ? `${value.slice(0, MAX_STRING_LENGTH)}…`
      : value;
  }
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.toISOString();
  }
  if (typeof value?.toDate === 'function') {
    const date = value.toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date.toISOString() : null;
  }
  if (depth >= MAX_METADATA_DEPTH) return '[Đã rút gọn]';
  if (typeof value !== 'object') return String(value).slice(0, MAX_STRING_LENGTH);
  if (seen.has(value)) return '[Tham chiếu vòng]';
  seen.add(value);
  if (Array.isArray(value)) {
    return value
      .slice(0, MAX_ARRAY_ITEMS)
      .map((item) => toSafeMetadata(item, depth + 1, seen));
  }
  const result = {};
  for (const [key, item] of Object.entries(value).slice(0, MAX_METADATA_KEYS)) {
    result[key] = SENSITIVE_KEY.test(key)
      ? '[ĐÃ ẨN]'
      : toSafeMetadata(item, depth + 1, seen);
  }
  return result;
}

function valuesEqual(left, right) {
  return JSON.stringify(toSafeMetadata(left)) === JSON.stringify(toSafeMetadata(right));
}

function buildChanges(metadata) {
  const before = metadata?.before;
  const after = metadata?.after;
  if (!before || !after || typeof before !== 'object' || typeof after !== 'object') return [];
  const keys = [...new Set([...Object.keys(before), ...Object.keys(after)])];
  return keys
    .filter((key) => !valuesEqual(before[key], after[key]))
    .map((key) => ({
      key,
      label: CHANGE_FIELD_LABELS[key] || key,
      before: toSafeMetadata(before[key]),
      after: toSafeMetadata(after[key])
    }));
}

function actionSummary(metadata, result) {
  if (result === 'failure' && metadata?.errorCode) return `Mã lỗi: ${metadata.errorCode}`;
  if (metadata?.reason) return String(metadata.reason).slice(0, 180);
  if (metadata?.resolution) return `Kết luận: ${metadata.resolution}`;
  return '';
}

function parseUserAgent(value) {
  const userAgent = String(value || '').slice(0, 600);
  if (!userAgent) return { label: 'Không xác định', raw: '' };
  const browsers = [
    [/Edg\/([\d.]+)/, 'Microsoft Edge'],
    [/OPR\/([\d.]+)/, 'Opera'],
    [/Chrome\/([\d.]+)/, 'Google Chrome'],
    [/Firefox\/([\d.]+)/, 'Firefox'],
    [/Version\/([\d.]+).*Safari\//, 'Safari'],
    [/curl\/([\d.]+)/i, 'curl'],
    [/PostmanRuntime\/([\d.]+)/, 'Postman']
  ];
  const match = browsers
    .map(([pattern, name]) => ({ match: userAgent.match(pattern), name }))
    .find((item) => item.match);
  const device = /iphone|ipad|android|mobile/i.test(userAgent) ? 'Di động' : 'Máy tính';
  return {
    label: match ? `${match.name} ${match.match[1]} · ${device}` : device,
    raw: userAgent
  };
}

function presentAuditLog(log) {
  const action = cleanAction(log.action);
  const baseAction = stripFailureSuffix(action);
  const definition = ACTION_DEFINITIONS[action] || ACTION_DEFINITIONS[baseAction];
  const result = deriveResult(action, log.result);
  const category = deriveCategory(action, log.category);
  const metadata = toSafeMetadata(log.metadata || {});
  const tone = result === 'failure' || result === 'denied'
    ? 'danger'
    : definition?.[2] || 'normal';
  return {
    ...log,
    action,
    actionLabel: definition?.[0] || fallbackActionLabel(action),
    label: definition?.[0] || fallbackActionLabel(action),
    category,
    categoryLabel: CATEGORY_LABELS[category] || CATEGORY_LABELS.system,
    result,
    resultLabel: RESULT_LABELS[result] || result,
    tone,
    adminName: log.adminDisplayName || log.adminEmail || 'Quản trị viên không xác định',
    targetType: log.targetType || 'admin',
    targetTypeLabel: TARGET_TYPE_LABELS[log.targetType] || 'Đối tượng',
    targetUrl: targetUrl(log.targetType, log.targetId),
    metadata,
    changes: buildChanges(metadata),
    summary: actionSummary(metadata, result),
    userAgentInfo: parseUserAgent(log.userAgent)
  };
}

module.exports = {
  ACTION_DEFINITIONS,
  CATEGORY_LABELS,
  RESULT_LABELS,
  TARGET_TYPE_LABELS,
  cleanAction,
  deriveCategory,
  deriveResult,
  presentAuditLog,
  targetUrl,
  toSafeMetadata,
  __test: {
    buildChanges,
    parseUserAgent,
    stripFailureSuffix
  }
};
