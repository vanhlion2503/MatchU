function forbidden(req, res) { if (req.accepts(['html', 'json']) === 'json') return res.status(403).json({ success: false, message: 'Bạn không có quyền thực hiện thao tác này.' }); return res.status(403).render('errors/403', { layout: 'layouts/auth-layout', pageTitle: 'Không có quyền truy cập' }); }
function requireRole(...roles) { return (req, res, next) => req.admin?.role === 'super_admin' || roles.includes(req.admin?.role) ? next() : forbidden(req, res); }
function requirePermission(...permissions) { return (req, res, next) => req.admin?.role === 'super_admin' || permissions.every((permission) => req.admin?.permissions?.includes(permission)) ? next() : forbidden(req, res); }
module.exports = { requireRole, requirePermission };
