const { createAdminSession } = require('../services/auth.service');
const { updateLastLogin } = require('../services/admin.service');
const { writeAuditLog } = require('../services/audit-log.service');
const { validateSession } = require('../validators/auth.validator');
const { sessionCookieName, firebase, nodeEnv } = require('../config/env');
const AppError = require('../utils/app-error');
const logger = require('../utils/logger');

function loginPage(req, res) { res.render('auth/login', { layout: 'layouts/auth-layout', pageTitle: 'Đăng nhập quản trị', firebaseConfig: { apiKey: firebase.webApiKey || '', authDomain: firebase.authDomain || '', projectId: firebase.projectId || '', appId: firebase.appId || '' } }); }
async function createSession(req, res) {
  const { error, value } = validateSession(req.body);
  if (error) return res.status(400).json({ success: false, message: 'Dữ liệu đăng nhập không hợp lệ.' });
  try {
    const { sessionCookie, expiresIn, currentAdmin } = await createAdminSession(value.idToken, value.rememberMe);
    res.cookie(sessionCookieName, sessionCookie, { httpOnly: true, secure: nodeEnv === 'production', sameSite: 'lax', maxAge: expiresIn, path: '/' });
    // Audit log and last-login metadata must not invalidate an already-created session.
    // They are operational metadata, not a condition for a valid Firebase login.
    await Promise.all([
      updateLastLogin(currentAdmin.uid).catch((error) => logger.error('Unable to update admin lastLoginAt', error)),
      writeAuditLog({ admin: currentAdmin, action: 'ADMIN_LOGIN', req })
    ]);
    return res.json({ success: true, redirectUrl: '/dashboard' });
  } catch (error) {
    if (error.code === 'ADMIN_ACCESS_DENIED') { await writeAuditLog({ action: 'ADMIN_LOGIN_DENIED', metadata: { reason: 'not_active_admin' }, req }); }
    if (error instanceof AppError) return res.status(error.statusCode).json({ success: false, message: error.message });
    // Never log idToken, cookie, or private key. Firebase error code is safe for server diagnostics.
    logger.error(`Admin session creation failed${error.code ? ` (${error.code})` : ''}`, error);
    return res.status(401).json({ success: false, message: 'Không thể xác thực thông tin đăng nhập.' });
  }
}
async function logout(req, res) { const currentAdmin = req.admin; res.clearCookie(sessionCookieName, { httpOnly: true, secure: nodeEnv === 'production', sameSite: 'lax', path: '/' }); if (currentAdmin) await writeAuditLog({ admin: currentAdmin, action: 'ADMIN_LOGOUT', req }); return res.redirect('/login'); }
module.exports = { loginPage, createSession, logout };
