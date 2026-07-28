const {
  listAuditLogs,
  getAuditStatistics,
  listAdminOptions
} = require('../services/audit-log.service');
const { validateAuditLogQuery } = require('../validators/audit-log.validator');
const {
  CATEGORY_LABELS,
  RESULT_LABELS,
  TARGET_TYPE_LABELS
} = require('../utils/audit-log');
const AppError = require('../utils/app-error');

const CATEGORY_ICONS = Object.freeze({
  auth: 'shield-lock',
  users: 'person',
  posts: 'file-post',
  reports: 'flag',
  notifications: 'bell',
  system: 'gear'
});

function queryString(filters, overrides = {}) {
  const values = { ...filters, ...overrides };
  const params = new URLSearchParams();
  for (const key of ['q', 'adminId', 'category', 'result', 'targetType', 'from', 'to', 'limit', 'cursor']) {
    if (values[key] !== '' && values[key] != null && !(key === 'limit' && values[key] === 25)) {
      params.set(key, String(values[key]));
    }
  }
  return params.toString();
}

function formatDateTime(date) {
  if (!(date instanceof Date)) return 'Không xác định';
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'short',
    timeStyle: 'medium',
    timeZone: 'Asia/Bangkok'
  }).format(date);
}

function formatIsoDate(date) {
  return date instanceof Date ? date.toISOString() : '';
}

function formatValue(value) {
  if (value == null || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'Có' : 'Không';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

function formatMetadata(metadata) {
  const entries = Object.entries(metadata || {}).filter(([key]) => !['before', 'after'].includes(key));
  if (!entries.length) return '';
  return JSON.stringify(Object.fromEntries(entries), null, 2);
}

async function index(req, res) {
  const { error, value: filters } = validateAuditLogQuery(req.query);
  if (error) {
    throw new AppError(
      error.message || 'Bộ lọc nhật ký quản trị không hợp lệ.',
      400,
      'INVALID_AUDIT_LOG_FILTER'
    );
  }

  const [page, statistics, adminOptions] = await Promise.all([
    listAuditLogs(filters),
    getAuditStatistics(),
    listAdminOptions()
  ]);
  const viewFilters = {
    q: filters.q,
    adminId: filters.adminId,
    category: filters.category,
    result: filters.result,
    targetType: filters.targetType,
    from: filters.from,
    to: filters.to,
    limit: filters.limit,
    cursor: filters.cursor
  };
  const activeFilterCount = ['q', 'adminId', 'category', 'result', 'targetType', 'from', 'to']
    .filter((key) => Boolean(viewFilters[key]))
    .length;

  return res.render('audit-logs/index', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Nhật ký quản trị',
    logs: page.logs,
    statistics,
    adminOptions,
    filters: viewFilters,
    activeFilterCount,
    categoryLabels: CATEGORY_LABELS,
    categoryIcons: CATEGORY_ICONS,
    resultLabels: RESULT_LABELS,
    targetTypeLabels: TARGET_TYPE_LABELS,
    formatDateTime,
    formatIsoDate,
    formatValue,
    formatMetadata,
    formatNumber: (value) => value == null ? '—' : Number(value).toLocaleString('vi-VN'),
    firstPageUrl: `/admin-logs${queryString(viewFilters, { cursor: '' }) ? `?${queryString(viewFilters, { cursor: '' })}` : ''}`,
    nextPageUrl: page.nextCursor
      ? `/admin-logs?${queryString(viewFilters, { cursor: page.nextCursor })}`
      : null,
    hasPreviousPage: Boolean(filters.cursor),
    scanned: page.scanned,
    scanLimitReached: page.scanLimitReached
  });
}

module.exports = { index };
