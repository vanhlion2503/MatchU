const { auth } = require('../config/firebase-admin');
const { sessionCookieName } = require('../config/env');
const { getActiveAdmin } = require('../services/admin.service');
const { getPendingReportCount } = require('../services/report-management.service');
const { getPendingPostModerationCount } = require('../services/post-management.service');
function wantsJson(req) { return req.xhr || req.is('application/json') || req.get('accept')?.includes('application/json'); }
function deny(req, res, status, message) { if (wantsJson(req)) return res.status(status).json({ success: false, message }); return res.redirect('/login'); }
module.exports = async (req, res, next) => {
  const cookie = req.cookies[sessionCookieName];
  if (!cookie) return deny(req, res, 401, 'Vui lòng đăng nhập để tiếp tục.');
  try {
    const decoded = await auth.verifySessionCookie(cookie, true);
    const currentAdmin = await getActiveAdmin(decoded.uid);
    if (!currentAdmin) {
      res.clearCookie(sessionCookieName, { path: '/' });
      return deny(req, res, 403, 'Tài khoản không có quyền quản trị.');
    }
    req.admin = currentAdmin;
    res.locals.currentAdmin = currentAdmin;
  }
  catch (error) { res.clearCookie(sessionCookieName, { path: '/' }); return deny(req, res, 401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'); }

  const canReadReports = req.admin.role === 'super_admin'
    || req.admin.permissions?.includes('reports.read');
  const canReadPosts = req.admin.role === 'super_admin'
    || req.admin.permissions?.includes('posts.read');
  res.locals.pendingReportCount = 0;
  res.locals.pendingPostModerationCount = 0;
  if (req.method === 'GET') {
    const [reportsResult, postsResult] = await Promise.allSettled([
      canReadReports ? getPendingReportCount() : Promise.resolve(0),
      canReadPosts ? getPendingPostModerationCount() : Promise.resolve(0)
    ]);
    if (reportsResult.status === 'fulfilled') {
      res.locals.pendingReportCount = reportsResult.value;
    }
    if (postsResult.status === 'fulfilled') {
      res.locals.pendingPostModerationCount = postsResult.value;
    }
  }
  return next();
};
