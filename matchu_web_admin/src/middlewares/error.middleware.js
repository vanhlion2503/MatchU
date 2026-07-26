const { nodeEnv } = require('../config/env'); const logger = require('../utils/logger');
module.exports = (err, req, res, next) => {
  logger.error('Application error', err);
  const status = err.statusCode || 500;
  if (req.accepts(['html', 'json']) === 'json') {
    return res.status(status).json({
      success: false,
      message: status === 500 ? 'Hệ thống xảy ra lỗi. Vui lòng thử lại sau.' : err.message
    });
  }
  const errorView = status === 403 ? 'errors/403' : status === 404 ? 'errors/404' : 'errors/500';
  const title = status === 403
    ? 'Không có quyền truy cập'
    : status === 404
      ? 'Không tìm thấy trang'
      : 'Hệ thống xảy ra lỗi';
  return res.status(status).render(errorView, {
    layout: 'layouts/auth-layout',
    pageTitle: title,
    error: nodeEnv === 'development' ? err : null
  });
};
