const { getDashboardData } = require('../services/dashboard.service');
const { validateDashboardQuery, ALLOWED_RANGES } = require('../validators/dashboard.validator');
const AppError = require('../utils/app-error');

async function index(req, res) {
  const { error, value } = validateDashboardQuery(req.query);
  if (error) {
    throw new AppError(
      'Khoảng thời gian thống kê không hợp lệ.',
      400,
      'INVALID_DASHBOARD_RANGE'
    );
  }
  const dashboard = await getDashboardData({ rangeDays: value.range });
  const chartDataJson = JSON.stringify({ series: dashboard.series })
    .replaceAll('<', '\\u003c')
    .replaceAll('>', '\\u003e')
    .replaceAll('&', '\\u0026');

  return res.render('dashboard/index', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Trung tâm điều hành',
    dashboard,
    selectedRange: value.range,
    allowedRanges: ALLOWED_RANGES,
    chartDataJson,
    formatNumber: (number) => (
      number == null ? '—' : Number(number).toLocaleString('vi-VN')
    ),
    formatPercent: (number) => (
      number == null ? '—' : `${Number(number).toLocaleString('vi-VN', {
        maximumFractionDigits: 1
      })}%`
    ),
    formatDateTime: (date) => (
      date instanceof Date
        ? new Intl.DateTimeFormat('vi-VN', {
          dateStyle: 'short',
          timeStyle: 'short',
          timeZone: 'Asia/Bangkok'
        }).format(date)
        : '—'
    )
  });
}

module.exports = { index };
