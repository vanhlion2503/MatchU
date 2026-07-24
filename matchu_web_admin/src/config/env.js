const dotenv = require('dotenv');
dotenv.config();

const requiredInDevelopment = ['FIREBASE_PROJECT_ID', 'FIREBASE_CLIENT_EMAIL', 'FIREBASE_PRIVATE_KEY'];
if (process.env.NODE_ENV !== 'production') {
  const missing = requiredInDevelopment.filter((key) => !process.env[key]);
  if (missing.length) console.warn(`Firebase Admin is not configured yet. Missing: ${missing.join(', ')}`);
}

module.exports = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT) || 3000,
  sessionCookieName: process.env.SESSION_COOKIE_NAME || 'matchu_admin_session',
  sessionExpiresInDays: Number(process.env.SESSION_EXPIRES_IN_DAYS) || 5,
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY,
    webApiKey: process.env.FIREBASE_WEB_API_KEY,
    authDomain: process.env.FIREBASE_AUTH_DOMAIN,
    appId: process.env.FIREBASE_APP_ID
  }
};
