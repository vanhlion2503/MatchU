const ADMIN_ROLES = Object.freeze({
  SUPER_ADMIN: 'super_admin', MODERATOR: 'moderator', SUPPORT: 'support', ANALYST: 'analyst'
});
const VALID_ADMIN_ROLES = Object.values(ADMIN_ROLES);
const APP_VERSION = '1.0.0';
module.exports = { ADMIN_ROLES, VALID_ADMIN_ROLES, APP_VERSION };
