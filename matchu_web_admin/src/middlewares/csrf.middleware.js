const crypto = require('crypto');
const { nodeEnv } = require('../config/env');
const AppError = require('../utils/app-error');

const CSRF_COOKIE = 'matchu_admin_csrf';
const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

function tokensEqual(left, right) {
  if (typeof left !== 'string' || typeof right !== 'string') return false;
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length
    && crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function csrfProtection(req, res, next) {
  let token = req.cookies[CSRF_COOKIE];
  if (!token || !/^[a-f0-9]{64}$/.test(token)) {
    token = crypto.randomBytes(32).toString('hex');
    res.cookie(CSRF_COOKIE, token, {
      httpOnly: false,
      secure: nodeEnv === 'production',
      sameSite: 'strict',
      path: '/'
    });
  }
  res.locals.csrfToken = token;

  if (SAFE_METHODS.has(req.method)) return next();
  const submitted = req.body?._csrf || req.get('x-csrf-token');
  if (!tokensEqual(token, submitted)) {
    return next(new AppError(
      'Phiên biểu mẫu không hợp lệ hoặc đã hết hạn. Vui lòng tải lại trang.',
      403,
      'INVALID_CSRF_TOKEN'
    ));
  }
  return next();
}

module.exports = csrfProtection;
