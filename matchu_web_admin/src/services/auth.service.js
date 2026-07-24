const { auth } = require('../config/firebase-admin');
const { sessionExpiresInDays } = require('../config/env');
const { getActiveAdmin } = require('./admin.service');
const AppError = require('../utils/app-error');
async function createAdminSession(idToken, rememberMe) {
  const decodedToken = await auth.verifyIdToken(idToken);
  const currentAdmin = await getActiveAdmin(decodedToken.uid);
  if (!currentAdmin) throw new AppError('Tài khoản không có quyền quản trị hoặc đã bị vô hiệu hóa.', 403, 'ADMIN_ACCESS_DENIED');
  const expiresIn = (rememberMe ? sessionExpiresInDays : 1) * 24 * 60 * 60 * 1000;
  const sessionCookie = await auth.createSessionCookie(idToken, { expiresIn });
  return { sessionCookie, expiresIn, currentAdmin };
}
module.exports = { createAdminSession };
