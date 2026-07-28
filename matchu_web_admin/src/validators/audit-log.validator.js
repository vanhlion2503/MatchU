const Joi = require('joi');
const {
  CATEGORY_LABELS,
  RESULT_LABELS,
  TARGET_TYPE_LABELS
} = require('../utils/audit-log');

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

const querySchema = Joi.object({
  q: Joi.string().trim().max(120).allow('').default(''),
  adminId: Joi.string().trim().max(128).pattern(/^[A-Za-z0-9:_-]*$/).allow('').default(''),
  category: Joi.string().valid('', ...Object.keys(CATEGORY_LABELS)).default(''),
  result: Joi.string().valid('', ...Object.keys(RESULT_LABELS)).default(''),
  targetType: Joi.string().valid('', ...Object.keys(TARGET_TYPE_LABELS)).default(''),
  from: Joi.string().pattern(DATE_PATTERN).allow('').default(''),
  to: Joi.string().pattern(DATE_PATTERN).allow('').default(''),
  limit: Joi.number().integer().valid(25, 50, 100).default(25),
  cursor: Joi.string().trim().max(128).pattern(/^[A-Za-z0-9_-]*$/).allow('').default('')
}).unknown(false);

function bangkokBoundary(dateKey, endOfDay) {
  if (!dateKey) return null;
  const [year, month, day] = dateKey.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, -7));
  const localKey = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Bangkok',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(date);
  if (localKey !== dateKey || Number.isNaN(date.getTime())) return null;
  return endOfDay ? new Date(date.getTime() + (24 * 60 * 60 * 1000) - 1) : date;
}

function validateAuditLogQuery(query) {
  const result = querySchema.validate(query, {
    abortEarly: false,
    convert: true,
    stripUnknown: false
  });
  if (result.error) return result;
  const fromDate = bangkokBoundary(result.value.from, false);
  const toDate = bangkokBoundary(result.value.to, true);
  if ((result.value.from && !fromDate) || (result.value.to && !toDate)) {
    return { error: new Error('Ngày lọc không hợp lệ.'), value: result.value };
  }
  if (fromDate && toDate && fromDate > toDate) {
    return { error: new Error('Ngày bắt đầu phải trước ngày kết thúc.'), value: result.value };
  }
  return {
    error: null,
    value: {
      ...result.value,
      fromDate,
      toDate
    }
  };
}

module.exports = {
  validateAuditLogQuery,
  __test: { bangkokBoundary }
};
