const { auth } = require('../config/firebase-admin');
const { sessionCookieName } = require('../config/env');
const { getActiveAdmin } = require('../services/admin.service');
function wantsJson(req) { return req.xhr || req.is('application/json') || req.get('accept')?.includes('application/json'); }
function deny(req, res, status, message) { if (wantsJson(req)) return res.status(status).json({ success: false, message }); return res.redirect('/login'); }
module.exports = async (req, res, next) => {
  const cookie = req.cookies[sessionCookieName];
  if (!cookie) return deny(req, res, 401, 'Vui lòng đăng nhập để tiếp tục.');
  try { const decoded = await auth.verifySessionCookie(cookie, true); const currentAdmin = await getActiveAdmin(decoded.uid); if (!currentAdmin) { res.clearCookie(sessionCookieName, { path: '/' }); return deny(req, res, 403, 'Tài khoản không có quyền quản trị.'); } req.admin = currentAdmin; res.locals.currentAdmin = currentAdmin; return next(); }
  catch (error) { res.clearCookie(sessionCookieName, { path: '/' }); return deny(req, res, 401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'); }
};
