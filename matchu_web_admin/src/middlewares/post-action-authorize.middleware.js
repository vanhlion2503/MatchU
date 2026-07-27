const { POST_ACTION_PERMISSIONS } = require('../config/constants');

module.exports = (req, res, next) => {
  const action = req.body?.action;
  const permissions = POST_ACTION_PERMISSIONS[action] || [];
  const allowed = req.admin?.role === 'super_admin'
    || permissions.some((permission) => req.admin?.permissions?.includes(permission));

  if (allowed) return next();
  return res.status(403).render('errors/403', {
    layout: 'layouts/auth-layout',
    pageTitle: 'Không có quyền truy cập'
  });
};
