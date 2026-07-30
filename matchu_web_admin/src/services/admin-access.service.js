const { auth, firestore, admin } = require('../config/firebase-admin');
const { ADMIN_ROLES, VALID_ADMIN_ROLES } = require('../config/constants');
const {
  ADMIN_STATUSES,
  ALL_ADMIN_PERMISSIONS,
  PROTECTED_ADMIN_PERMISSIONS
} = require('../config/admin-access');
const AppError = require('../utils/app-error');
const logger = require('../utils/logger');

const COLLECTION = 'adminProfiles';

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function normalizePermissions(role, permissions) {
  if (role === ADMIN_ROLES.SUPER_ADMIN) return [];
  const allowlist = new Set(ALL_ADMIN_PERMISSIONS);
  return [...new Set(Array.isArray(permissions) ? permissions : [])]
    .filter((permission) => allowlist.has(permission))
    .sort();
}

function normalizeProfile(document) {
  const data = document.data() || {};
  const role = VALID_ADMIN_ROLES.includes(data.role) ? data.role : ADMIN_ROLES.ANALYST;
  return {
    uid: document.id,
    email: String(data.email || '').trim(),
    displayName: String(data.displayName || data.email || 'Admin').trim(),
    avatarUrl: data.avatarUrl || null,
    role,
    permissions: normalizePermissions(role, data.permissions),
    status: data.status === ADMIN_STATUSES.ACTIVE
      ? ADMIN_STATUSES.ACTIVE
      : ADMIN_STATUSES.INACTIVE,
    createdAt: toDate(data.createdAt),
    updatedAt: toDate(data.updatedAt),
    lastLoginAt: toDate(data.lastLoginAt),
    createdBy: data.createdBy || null,
    updatedBy: data.updatedBy || null,
    statusReason: String(data.statusReason || '').slice(0, 300)
  };
}

function normalizedSearchText(profile) {
  return [
    profile.uid,
    profile.email,
    profile.displayName,
    profile.role
  ].join(' ').toLocaleLowerCase('vi-VN');
}

function matchesFilters(profile, filters) {
  if (filters.q
    && !normalizedSearchText(profile).includes(filters.q.toLocaleLowerCase('vi-VN'))) {
    return false;
  }
  if (filters.role && profile.role !== filters.role) return false;
  if (filters.status && profile.status !== filters.status) return false;
  return true;
}

function compareProfiles(left, right) {
  if (left.status !== right.status) {
    return left.status === ADMIN_STATUSES.ACTIVE ? -1 : 1;
  }
  if (left.role !== right.role) {
    if (left.role === ADMIN_ROLES.SUPER_ADMIN) return -1;
    if (right.role === ADMIN_ROLES.SUPER_ADMIN) return 1;
  }
  const leftDate = left.lastLoginAt || left.updatedAt || left.createdAt;
  const rightDate = right.lastLoginAt || right.updatedAt || right.createdAt;
  if (leftDate && rightDate && leftDate.getTime() !== rightDate.getTime()) {
    return rightDate.getTime() - leftDate.getTime();
  }
  return left.displayName.localeCompare(right.displayName, 'vi');
}

function ensureManager(currentAdmin) {
  const allowed = currentAdmin?.role === ADMIN_ROLES.SUPER_ADMIN
    || currentAdmin?.permissions?.includes('admins.manage');
  if (!allowed) {
    throw new AppError(
      'Bạn không có quyền quản lý tài khoản admin.',
      403,
      'ADMIN_MANAGEMENT_FORBIDDEN'
    );
  }
}

function canManageTarget(currentAdmin, targetProfile) {
  if (!currentAdmin || !targetProfile || targetProfile.uid === currentAdmin.uid) return false;
  if (currentAdmin.role === ADMIN_ROLES.SUPER_ADMIN) return true;
  if (!currentAdmin.permissions?.includes('admins.manage')) return false;
  if (targetProfile.role === ADMIN_ROLES.SUPER_ADMIN) return false;
  return targetProfile.permissions.every((permission) =>
    !PROTECTED_ADMIN_PERMISSIONS.includes(permission)
    && currentAdmin.permissions.includes(permission)
  );
}

function ensureCanAssign(currentAdmin, role, permissions, targetProfile = null) {
  ensureManager(currentAdmin);
  if (targetProfile?.uid === currentAdmin.uid) {
    throw new AppError(
      'Bạn không thể thay đổi vai trò, quyền hoặc trạng thái của chính mình.',
      400,
      'ADMIN_SELF_UPDATE_FORBIDDEN'
    );
  }
  if (targetProfile && !canManageTarget(currentAdmin, targetProfile)) {
    throw new AppError(
      'Bạn không thể quản lý tài khoản có cấp quyền cao hơn phạm vi của mình.',
      403,
      'ADMIN_TARGET_OUT_OF_SCOPE'
    );
  }
  if (currentAdmin.role === ADMIN_ROLES.SUPER_ADMIN) return;
  if (targetProfile?.role === ADMIN_ROLES.SUPER_ADMIN || role === ADMIN_ROLES.SUPER_ADMIN) {
    throw new AppError(
      'Chỉ Super Admin mới có thể cấp hoặc thay đổi vai trò Super Admin.',
      403,
      'SUPER_ADMIN_ASSIGNMENT_FORBIDDEN'
    );
  }
  const protectedPermission = permissions.find((permission) =>
    PROTECTED_ADMIN_PERMISSIONS.includes(permission)
  );
  if (protectedPermission) {
    throw new AppError(
      'Chỉ Super Admin mới có thể cấp quyền quản lý admin.',
      403,
      'PROTECTED_PERMISSION_ASSIGNMENT'
    );
  }
  const unavailablePermission = permissions.find((permission) =>
    !currentAdmin.permissions?.includes(permission)
  );
  if (unavailablePermission) {
    throw new AppError(
      'Bạn chỉ có thể cấp các quyền mà tài khoản của bạn đang sở hữu.',
      403,
      'PERMISSION_ESCALATION_FORBIDDEN'
    );
  }
}

async function listAdminProfiles(filters) {
  const snapshot = await firestore.collection(COLLECTION).get();
  const allProfiles = snapshot.docs.map(normalizeProfile);
  const profiles = allProfiles.filter((profile) => matchesFilters(profile, filters));
  profiles.sort(compareProfiles);
  return {
    profiles,
    statistics: {
      total: allProfiles.length,
      active: allProfiles.filter((profile) => profile.status === ADMIN_STATUSES.ACTIVE).length,
      inactive: allProfiles.filter((profile) => profile.status === ADMIN_STATUSES.INACTIVE).length,
      superAdmins: allProfiles.filter((profile) =>
        profile.role === ADMIN_ROLES.SUPER_ADMIN
        && profile.status === ADMIN_STATUSES.ACTIVE
      ).length
    }
  };
}

async function resolveAuthUser(identifier) {
  try {
    const normalized = String(identifier || '').trim();
    return normalized.includes('@')
      ? await auth.getUserByEmail(normalized.toLowerCase())
      : await auth.getUser(normalized);
  } catch (error) {
    if (error?.code === 'auth/user-not-found' || error?.code === 'auth/invalid-uid') {
      throw new AppError(
        'Không tìm thấy tài khoản Firebase Authentication tương ứng.',
        404,
        'AUTH_USER_NOT_FOUND'
      );
    }
    throw error;
  }
}

function mapCreateUserError(error) {
  const definitions = {
    'auth/email-already-exists': [
      'Email này đã có tài khoản. Hãy chọn “Tài khoản có sẵn” để cấp quyền.',
      409,
      'AUTH_EMAIL_EXISTS'
    ],
    'auth/invalid-email': [
      'Địa chỉ email không hợp lệ.',
      400,
      'AUTH_EMAIL_INVALID'
    ],
    'auth/invalid-password': [
      'Mật khẩu không đáp ứng yêu cầu của Firebase Authentication.',
      400,
      'AUTH_PASSWORD_INVALID'
    ],
    'auth/password-does-not-meet-requirements': [
      'Mật khẩu không đáp ứng chính sách mật khẩu của Firebase project.',
      400,
      'AUTH_PASSWORD_POLICY_FAILED'
    ],
    'auth/operation-not-allowed': [
      'Firebase chưa bật phương thức đăng nhập Email/Password.',
      503,
      'AUTH_PASSWORD_PROVIDER_DISABLED'
    ],
    'auth/insufficient-permission': [
      'Firebase service account chưa có quyền tạo tài khoản Authentication.',
      503,
      'AUTH_CREATE_USER_FORBIDDEN'
    ]
  };
  const definition = definitions[error?.code];
  return definition
    ? new AppError(definition[0], definition[1], definition[2])
    : error;
}

async function provisionAuthUser(input) {
  if (input.mode !== 'create') {
    return {
      authUser: await resolveAuthUser(input.identifier),
      created: false
    };
  }
  try {
    const authUser = await auth.createUser({
      email: input.email,
      password: input.password,
      displayName: input.displayName,
      emailVerified: false,
      disabled: false
    });
    return { authUser, created: true };
  } catch (error) {
    throw mapCreateUserError(error);
  }
}

async function rollbackCreatedAuthUser(uid) {
  try {
    await auth.deleteUser(uid);
    return true;
  } catch (error) {
    logger.error(`Unable to roll back newly created Firebase Auth user ${uid}`, error);
    return false;
  }
}

async function grantAdminAccess(input, currentAdmin) {
  const permissions = normalizePermissions(input.role, input.permissions);
  ensureCanAssign(currentAdmin, input.role, permissions);
  const { authUser, created } = await provisionAuthUser(input);
  if (authUser.disabled) {
    throw new AppError(
      'Tài khoản Firebase Authentication đang bị vô hiệu hóa.',
      409,
      'AUTH_USER_DISABLED'
    );
  }
  if (!authUser.email) {
    throw new AppError(
      'Tài khoản cần có email để đăng nhập trang quản trị.',
      400,
      'ADMIN_EMAIL_REQUIRED'
    );
  }

  const reference = firestore.collection(COLLECTION).doc(authUser.uid);
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  const profile = {
    uid: authUser.uid,
    email: authUser.email,
    displayName: authUser.displayName || authUser.email,
    avatarUrl: authUser.photoURL || null,
    role: input.role,
    permissions,
    status: ADMIN_STATUSES.ACTIVE,
    statusReason: '',
    authenticationSource: created ? 'admin_created_password' : 'existing_firebase_account',
    createdAt: timestamp,
    createdBy: currentAdmin.uid,
    updatedAt: timestamp,
    updatedBy: currentAdmin.uid
  };

  try {
    await firestore.runTransaction(async (transaction) => {
      const existing = await transaction.get(reference);
      if (existing.exists) {
        throw new AppError(
          'Tài khoản này đã có hồ sơ admin. Hãy cập nhật quyền trong danh sách.',
          409,
          'ADMIN_PROFILE_EXISTS'
        );
      }
      transaction.set(reference, profile);
    });
  } catch (error) {
    if (created && !await rollbackCreatedAuthUser(authUser.uid)) {
      throw new AppError(
        `Không thể hoàn tất phân quyền và không thể tự dọn tài khoản ${authUser.uid}. Vui lòng kiểm tra Firebase Authentication.`,
        500,
        'ADMIN_PROVISION_ROLLBACK_FAILED'
      );
    }
    throw error;
  }

  return {
    uid: authUser.uid,
    email: authUser.email,
    displayName: profile.displayName,
    authUserCreated: created,
    before: null,
    after: {
      role: profile.role,
      permissions: profile.permissions,
      status: profile.status
    }
  };
}

async function getActiveSuperAdminCount(transaction) {
  const query = firestore.collection(COLLECTION).where('role', '==', ADMIN_ROLES.SUPER_ADMIN);
  const snapshot = await transaction.get(query);
  return snapshot.docs.filter((document) => {
    const data = document.data() || {};
    return data.status === ADMIN_STATUSES.ACTIVE;
  }).length;
}

async function updateAdminAccess(uid, input, currentAdmin) {
  const reference = firestore.collection(COLLECTION).doc(uid);
  let result;

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) {
      throw new AppError('Không tìm thấy hồ sơ admin.', 404, 'ADMIN_PROFILE_NOT_FOUND');
    }
    const currentProfile = normalizeProfile(snapshot);
    const permissions = normalizePermissions(input.role, input.permissions);
    ensureCanAssign(currentAdmin, input.role, permissions, currentProfile);

    if (
      currentProfile.role === ADMIN_ROLES.SUPER_ADMIN
      && currentProfile.status === ADMIN_STATUSES.ACTIVE
      && input.role !== ADMIN_ROLES.SUPER_ADMIN
      && await getActiveSuperAdminCount(transaction) <= 1
    ) {
      throw new AppError(
        'Không thể hạ quyền Super Admin đang hoạt động cuối cùng.',
        409,
        'LAST_SUPER_ADMIN_REQUIRED'
      );
    }

    const after = {
      role: input.role,
      permissions,
      status: currentProfile.status
    };
    transaction.update(reference, {
      role: input.role,
      permissions,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: currentAdmin.uid
    });
    result = {
      uid,
      email: currentProfile.email,
      displayName: currentProfile.displayName,
      before: {
        role: currentProfile.role,
        permissions: currentProfile.permissions,
        status: currentProfile.status
      },
      after
    };
  });
  return result;
}

async function updateAdminStatus(uid, input, currentAdmin) {
  const reference = firestore.collection(COLLECTION).doc(uid);
  let result;

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) {
      throw new AppError('Không tìm thấy hồ sơ admin.', 404, 'ADMIN_PROFILE_NOT_FOUND');
    }
    const currentProfile = normalizeProfile(snapshot);
    ensureCanAssign(
      currentAdmin,
      currentProfile.role,
      currentProfile.permissions,
      currentProfile
    );

    if (
      currentProfile.role === ADMIN_ROLES.SUPER_ADMIN
      && currentProfile.status === ADMIN_STATUSES.ACTIVE
      && input.status === ADMIN_STATUSES.INACTIVE
      && await getActiveSuperAdminCount(transaction) <= 1
    ) {
      throw new AppError(
        'Không thể vô hiệu hóa Super Admin đang hoạt động cuối cùng.',
        409,
        'LAST_SUPER_ADMIN_REQUIRED'
      );
    }

    transaction.update(reference, {
      status: input.status,
      statusReason: input.status === ADMIN_STATUSES.INACTIVE ? input.reason : '',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: currentAdmin.uid
    });
    result = {
      uid,
      email: currentProfile.email,
      displayName: currentProfile.displayName,
      reason: input.reason,
      before: {
        role: currentProfile.role,
        permissions: currentProfile.permissions,
        status: currentProfile.status
      },
      after: {
        role: currentProfile.role,
        permissions: currentProfile.permissions,
        status: input.status
      }
    };
  });
  return result;
}

module.exports = {
  listAdminProfiles,
  grantAdminAccess,
  updateAdminAccess,
  updateAdminStatus,
  canManageTarget,
  __test: {
    canManageTarget,
    compareProfiles,
    ensureCanAssign,
    matchesFilters,
    normalizePermissions,
    normalizeProfile,
    mapCreateUserError,
    toDate
  }
};
