const {
  listAdminProfiles,
  grantAdminAccess,
  updateAdminAccess,
  updateAdminStatus,
  canManageTarget
} = require('../services/admin-access.service');
const { writeAuditLog } = require('../services/audit-log.service');
const {
  validateListQuery,
  validateGrant,
  validateAccessUpdate,
  validateStatusUpdate
} = require('../validators/admin-access.validator');
const { ADMIN_ROLES, VALID_ADMIN_ROLES } = require('../config/constants');
const {
  ADMIN_STATUSES,
  ROLE_LABELS,
  ROLE_DESCRIPTIONS,
  PERMISSION_GROUPS,
  PROTECTED_ADMIN_PERMISSIONS,
  ROLE_PERMISSION_PRESETS
} = require('../config/admin-access');
const AppError = require('../utils/app-error');

function formatDate(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) return 'Chưa ghi nhận';
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Ho_Chi_Minh'
  }).format(value);
}

function redirectWithMessage(res, type, message) {
  return res.redirect(`/admins?${type}=${encodeURIComponent(String(message).slice(0, 300))}`);
}

function assignablePermissionGroups(currentAdmin) {
  if (currentAdmin.role === ADMIN_ROLES.SUPER_ADMIN) return PERMISSION_GROUPS;
  return PERMISSION_GROUPS
    .map((group) => ({
      ...group,
      permissions: group.permissions.filter((permission) =>
        !PROTECTED_ADMIN_PERMISSIONS.includes(permission.key)
        && currentAdmin.permissions?.includes(permission.key)
      )
    }))
    .filter((group) => group.permissions.length);
}

function assignableRoles(currentAdmin) {
  return currentAdmin.role === ADMIN_ROLES.SUPER_ADMIN
    ? VALID_ADMIN_ROLES
    : VALID_ADMIN_ROLES.filter((role) => role !== ADMIN_ROLES.SUPER_ADMIN);
}

function permissionLabelMap() {
  return Object.fromEntries(
    PERMISSION_GROUPS.flatMap((group) =>
      group.permissions.map((permission) => [permission.key, permission.label])
    )
  );
}

async function index(req, res) {
  const { error, value: filters } = validateListQuery({
    q: req.query.q,
    role: req.query.role,
    status: req.query.status
  });
  if (error) {
    throw new AppError(
      'Bộ lọc danh sách admin không hợp lệ.',
      400,
      'INVALID_ADMIN_FILTER'
    );
  }
  const { profiles, statistics } = await listAdminProfiles(filters);
  const permissionGroups = assignablePermissionGroups(req.admin);

  return res.render('admins/index', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Quản lý admin',
    profiles,
    statistics,
    filters,
    successMessage: String(req.query.success || '').slice(0, 300) || null,
    errorMessage: String(req.query.error || '').slice(0, 300) || null,
    roles: assignableRoles(req.admin),
    roleLabels: ROLE_LABELS,
    roleDescriptions: ROLE_DESCRIPTIONS,
    statusLabels: {
      [ADMIN_STATUSES.ACTIVE]: 'Đang hoạt động',
      [ADMIN_STATUSES.INACTIVE]: 'Đã vô hiệu hóa'
    },
    permissionGroups,
    permissionLabels: permissionLabelMap(),
    rolePresets: Object.fromEntries(
      Object.entries(ROLE_PERMISSION_PRESETS).map(([role, permissions]) => [
        role,
        permissions.filter((permission) =>
          permissionGroups.some((group) =>
            group.permissions.some((item) => item.key === permission)
          )
        )
      ])
    ),
    formatDate,
    canManageProfile: (profile) => canManageTarget(req.admin, profile)
  });
}

async function grant(req, res) {
  const { error, value } = validateGrant(req.body);
  if (error) {
    return redirectWithMessage(
      res,
      'error',
      error.message || 'Thông tin cấp quyền admin không hợp lệ.'
    );
  }
  try {
    const result = await grantAdminAccess(value, req.admin);
    await writeAuditLog({
      admin: req.admin,
      action: 'ADMIN_ACCESS_GRANTED',
      category: 'system',
      targetType: 'admin',
      targetId: result.uid,
      metadata: {
        email: result.email,
        authUserCreated: result.authUserCreated,
        before: result.before,
        after: result.after
      },
      req
    });
    return redirectWithMessage(
      res,
      'success',
      `Đã cấp quyền quản trị cho ${result.displayName}.`
    );
  } catch (caughtError) {
    await writeAuditLog({
      admin: req.admin,
      action: 'ADMIN_ACCESS_GRANT_FAILED',
      category: 'system',
      targetType: 'admin',
      targetId: String(value.identifier || value.email || '').slice(0, 128),
      result: 'failure',
      metadata: { errorCode: caughtError.code || 'UNKNOWN' },
      req
    });
    if (caughtError instanceof AppError) {
      return redirectWithMessage(res, 'error', caughtError.message);
    }
    throw caughtError;
  }
}

async function updateAccess(req, res) {
  const { error, value } = validateAccessUpdate(req.body);
  if (error) {
    return redirectWithMessage(
      res,
      'error',
      error.message || 'Thông tin phân quyền không hợp lệ.'
    );
  }
  try {
    const result = await updateAdminAccess(req.params.uid, value, req.admin);
    await writeAuditLog({
      admin: req.admin,
      action: 'ADMIN_ACCESS_UPDATED',
      category: 'system',
      targetType: 'admin',
      targetId: result.uid,
      metadata: {
        email: result.email,
        before: result.before,
        after: result.after
      },
      req
    });
    return redirectWithMessage(
      res,
      'success',
      `Đã cập nhật phân quyền của ${result.displayName}.`
    );
  } catch (caughtError) {
    await writeAuditLog({
      admin: req.admin,
      action: 'ADMIN_ACCESS_UPDATE_FAILED',
      category: 'system',
      targetType: 'admin',
      targetId: req.params.uid,
      result: 'failure',
      metadata: { errorCode: caughtError.code || 'UNKNOWN' },
      req
    });
    if (caughtError instanceof AppError) {
      return redirectWithMessage(res, 'error', caughtError.message);
    }
    throw caughtError;
  }
}

async function updateStatus(req, res) {
  const { error, value } = validateStatusUpdate(req.body);
  if (error) {
    return redirectWithMessage(
      res,
      'error',
      error.message || 'Thông tin trạng thái admin không hợp lệ.'
    );
  }
  try {
    const result = await updateAdminStatus(req.params.uid, value, req.admin);
    const activated = value.status === ADMIN_STATUSES.ACTIVE;
    await writeAuditLog({
      admin: req.admin,
      action: activated ? 'ADMIN_ACCESS_REACTIVATED' : 'ADMIN_ACCESS_DEACTIVATED',
      category: 'system',
      targetType: 'admin',
      targetId: result.uid,
      metadata: {
        email: result.email,
        reason: result.reason,
        before: result.before,
        after: result.after
      },
      req
    });
    return redirectWithMessage(
      res,
      'success',
      activated
        ? `Đã kích hoạt lại quyền quản trị của ${result.displayName}.`
        : `Đã vô hiệu hóa quyền quản trị của ${result.displayName}.`
    );
  } catch (caughtError) {
    await writeAuditLog({
      admin: req.admin,
      action: 'ADMIN_ACCESS_STATUS_FAILED',
      category: 'system',
      targetType: 'admin',
      targetId: req.params.uid,
      result: 'failure',
      metadata: { errorCode: caughtError.code || 'UNKNOWN' },
      req
    });
    if (caughtError instanceof AppError) {
      return redirectWithMessage(res, 'error', caughtError.message);
    }
    throw caughtError;
  }
}

module.exports = {
  index,
  grant,
  updateAccess,
  updateStatus
};
