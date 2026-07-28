const ADMIN_ROLES = Object.freeze({
  SUPER_ADMIN: 'super_admin', MODERATOR: 'moderator', SUPPORT: 'support', ANALYST: 'analyst'
});
const VALID_ADMIN_ROLES = Object.values(ADMIN_ROLES);
const USER_ACCOUNT_STATUSES = Object.freeze({
  ACTIVE: 'active',
  RESTRICTED: 'restricted',
  SUSPENDED: 'suspended',
  BANNED: 'banned',
  DELETING: 'deleting',
  DELETED: 'deleted'
});
const USER_ACTIONS = Object.freeze({
  WARN: 'warn',
  RESTRICT: 'restrict',
  SUSPEND: 'suspend',
  BAN: 'ban',
  RESTORE: 'restore',
  REVOKE_SESSIONS: 'revoke_sessions',
  RESET_FACE_VERIFICATION: 'reset_face_verification',
  SEND_PASSWORD_RESET: 'send_password_reset',
  ADJUST_GEM: 'adjust_gem',
  ADJUST_REPUTATION: 'adjust_reputation'
});
const USER_ACTION_PERMISSIONS = Object.freeze({
  [USER_ACTIONS.WARN]: 'users.warn',
  [USER_ACTIONS.RESTRICT]: 'users.restrict',
  [USER_ACTIONS.SUSPEND]: 'users.suspend',
  [USER_ACTIONS.BAN]: 'users.ban',
  [USER_ACTIONS.RESTORE]: 'users.restore',
  [USER_ACTIONS.REVOKE_SESSIONS]: 'users.sessions.revoke',
  [USER_ACTIONS.RESET_FACE_VERIFICATION]: 'users.verification.manage',
  [USER_ACTIONS.SEND_PASSWORD_RESET]: 'users.security.manage',
  [USER_ACTIONS.ADJUST_GEM]: 'users.gems.adjust',
  [USER_ACTIONS.ADJUST_REPUTATION]: 'users.reputation.adjust'
});
const POST_MODERATION_ACTIONS = Object.freeze({
  APPROVE: 'approve',
  REJECT: 'reject',
  REVIEW: 'review',
  DISMISS: 'dismiss',
  RESTORE: 'restore',
  DELETE_PERMANENTLY: 'delete_permanently'
});
const POST_ACTION_PERMISSIONS = Object.freeze({
  [POST_MODERATION_ACTIONS.APPROVE]: ['posts.moderate'],
  [POST_MODERATION_ACTIONS.REJECT]: ['posts.moderate'],
  [POST_MODERATION_ACTIONS.REVIEW]: ['posts.moderate'],
  [POST_MODERATION_ACTIONS.DISMISS]: ['posts.moderate'],
  [POST_MODERATION_ACTIONS.RESTORE]: ['posts.restore', 'posts.moderate'],
  [POST_MODERATION_ACTIONS.DELETE_PERMANENTLY]: ['posts.delete']
});
const REPORT_CASE_ACTIONS = Object.freeze({
  ASSIGN_TO_ME: 'assign_to_me',
  START_REVIEW: 'start_review',
  RESOLVE: 'resolve',
  DISMISS: 'dismiss',
  REOPEN: 'reopen'
});
const REPORT_ACTION_PERMISSIONS = Object.freeze({
  [REPORT_CASE_ACTIONS.ASSIGN_TO_ME]: ['reports.manage'],
  [REPORT_CASE_ACTIONS.START_REVIEW]: ['reports.manage'],
  [REPORT_CASE_ACTIONS.RESOLVE]: ['reports.resolve'],
  [REPORT_CASE_ACTIONS.DISMISS]: ['reports.resolve'],
  [REPORT_CASE_ACTIONS.REOPEN]: ['reports.resolve']
});
const APP_VERSION = '1.0.0';
module.exports = {
  ADMIN_ROLES,
  VALID_ADMIN_ROLES,
  USER_ACCOUNT_STATUSES,
  USER_ACTIONS,
  USER_ACTION_PERMISSIONS,
  POST_MODERATION_ACTIONS,
  POST_ACTION_PERMISSIONS,
  REPORT_CASE_ACTIONS,
  REPORT_ACTION_PERMISSIONS,
  APP_VERSION
};
