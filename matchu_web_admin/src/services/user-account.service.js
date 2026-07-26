const { firestore, auth, admin } = require('../config/firebase-admin');
const { firebase } = require('../config/env');
const {
  USER_ACCOUNT_STATUSES,
  USER_ACTIONS
} = require('../config/constants');
const AppError = require('../utils/app-error');

const USERS = 'users';
const LIST_SCAN_BATCH = 100;
const LIST_MAX_SCANNED = 5000;
const DEVICE_BATCH_LIMIT = 400;

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function toInteger(value, fallback = 0) {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.trunc(value)
    : fallback;
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string') return new Date(value);
  return null;
}

function serializeDate(value) {
  const date = toDate(value);
  return date && !Number.isNaN(date.getTime()) ? date : null;
}

function normalizeAccountMeasure(value) {
  if (!value || typeof value !== 'object') return null;
  return {
    ...value,
    reason: cleanString(value.reason),
    reportId: cleanString(value.reportId),
    appliedBy: cleanString(value.appliedBy),
    features: Array.isArray(value.features) ? value.features.map(cleanString).filter(Boolean) : [],
    appliedAt: serializeDate(value.appliedAt),
    expiresAt: serializeDate(value.expiresAt)
  };
}

function normalizeUser(doc) {
  const data = doc.data() || {};
  return {
    uid: doc.id,
    fullname: cleanString(data.fullname),
    nickname: cleanString(data.nickname),
    email: cleanString(data.email),
    phonenumber: cleanString(data.phonenumber),
    avatarUrl: cleanString(data.avatarUrl),
    gender: cleanString(data.gender),
    birthday: serializeDate(data.birthday),
    bio: cleanString(data.bio),
    interests: Array.isArray(data.interests) ? data.interests.map(cleanString).filter(Boolean) : [],
    gem: Math.max(0, toInteger(data.gem)),
    reputationScore: Math.max(0, toInteger(data.reputationScore, 100)),
    trustWarnings: Math.max(0, toInteger(data.trustWarnings)),
    totalReports: Math.max(0, toInteger(data.totalReports)),
    avgChatRating: Number(data.avgChatRating || 0),
    totalChatRatings: Math.max(0, toInteger(data.totalChatRatings)),
    followersCount: Array.isArray(data.followers) ? data.followers.length : 0,
    followingCount: Array.isArray(data.following) ? data.following.length : 0,
    followingListVisibility: cleanString(data.followingListVisibility) || 'everyone',
    isPrivateAccount: data.isPrivateAccount === true,
    rank: Math.max(1, toInteger(data.rank, 1)),
    experience: Math.max(0, toInteger(data.experience)),
    totalPosts: Math.max(0, toInteger(data.totalPosts)),
    totalLikes: Math.max(0, toInteger(data.totalLikes)),
    activeStatus: cleanString(data.activeStatus) || 'offline',
    accountStatus: cleanString(data.accountStatus) || USER_ACCOUNT_STATUSES.ACTIVE,
    role: cleanString(data.role) || 'user',
    isProfileCompleted: data.isProfileCompleted === true,
    isFaceVerified: data.isFaceVerified === true,
    lastActiveAt: serializeDate(data.lastActiveAt),
    createdAt: serializeDate(data.createdAt),
    updatedAt: serializeDate(data.updatedAt),
    restriction: normalizeAccountMeasure(data.restriction),
    suspension: normalizeAccountMeasure(data.suspension),
    ban: normalizeAccountMeasure(data.ban),
    raw: data
  };
}

function matchesFilters(user, filters) {
  const query = cleanString(filters.q).toLocaleLowerCase('vi');
  if (query) {
    const searchable = [
      user.uid,
      user.fullname,
      user.nickname,
      user.email,
      user.phonenumber
    ].join(' ').toLocaleLowerCase('vi');
    if (!searchable.includes(query)) return false;
  }
  if (filters.status && user.accountStatus !== filters.status) return false;
  if (filters.verification === 'face_verified' && !user.isFaceVerified) return false;
  if (filters.verification === 'face_unverified' && user.isFaceVerified) return false;
  if (filters.verification === 'profile_completed' && !user.isProfileCompleted) return false;
  if (filters.verification === 'profile_incomplete' && user.isProfileCompleted) return false;
  if (filters.activity === 'online' && user.activeStatus !== 'online') return false;
  if (filters.activity === 'offline' && user.activeStatus === 'online') return false;
  if (filters.risk === 'reported' && user.totalReports <= 0) return false;
  if (filters.risk === 'warned' && user.trustWarnings <= 0) return false;
  if (filters.risk === 'low_reputation' && user.reputationScore >= 50) return false;
  return true;
}

async function countQuery(query) {
  try {
    const snapshot = await query.count().get();
    return snapshot.data().count;
  } catch (_) {
    const snapshot = await query.get();
    return snapshot.size;
  }
}

async function getUserStatistics() {
  const users = firestore.collection(USERS);
  const [total, active, restricted, suspended, banned, verified] = await Promise.all([
    countQuery(users),
    countQuery(users.where('accountStatus', '==', 'active')),
    countQuery(users.where('accountStatus', '==', 'restricted')),
    countQuery(users.where('accountStatus', '==', 'suspended')),
    countQuery(users.where('accountStatus', '==', 'banned')),
    countQuery(users.where('isFaceVerified', '==', true))
  ]);
  return { total, active, restricted, suspended, banned, verified };
}

async function listUsers(filters) {
  const pageSize = filters.limit;
  let query = firestore
    .collection(USERS)
    .orderBy(admin.firestore.FieldPath.documentId())
    .limit(LIST_SCAN_BATCH);
  if (filters.cursor) query = query.startAfter(filters.cursor);

  const users = [];
  let scanned = 0;
  let cursor = filters.cursor || '';
  let reachedEnd = false;

  while (users.length < pageSize && scanned < LIST_MAX_SCANNED) {
    const snapshot = await query.get();
    if (snapshot.empty) {
      reachedEnd = true;
      break;
    }

    for (const doc of snapshot.docs) {
      cursor = doc.id;
      scanned += 1;
      const user = normalizeUser(doc);
      if (matchesFilters(user, filters)) users.push(user);
      if (users.length >= pageSize || scanned >= LIST_MAX_SCANNED) break;
    }

    if (users.length >= pageSize || scanned >= LIST_MAX_SCANNED) break;
    if (snapshot.size < LIST_SCAN_BATCH) {
      reachedEnd = true;
      break;
    }
    query = firestore
      .collection(USERS)
      .orderBy(admin.firestore.FieldPath.documentId())
      .startAfter(cursor)
      .limit(LIST_SCAN_BATCH);
  }

  return {
    users,
    nextCursor: !reachedEnd && users.length === pageSize ? cursor : null,
    scanned,
    scanLimitReached: scanned >= LIST_MAX_SCANNED
  };
}

async function safeGetAuthUser(uid) {
  try {
    return await auth.getUser(uid);
  } catch (error) {
    if (error.code === 'auth/user-not-found') return null;
    throw error;
  }
}

async function getCollectionCount(path, whereField, value) {
  let query = firestore.collection(path);
  if (whereField) query = query.where(whereField, '==', value);
  return countQuery(query);
}

async function getRecentSubcollection(userRef, collectionName, limit = 20) {
  const collection = userRef.collection(collectionName);
  let snapshot;
  try {
    snapshot = await collection.orderBy('createdAt', 'desc').limit(limit).get();
  } catch (error) {
    if (Number(error.code) !== 9) throw error;
    snapshot = await collection.limit(limit).get();
  }
  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    createdAt: serializeDate(doc.data()?.createdAt),
    updatedAt: serializeDate(doc.data()?.updatedAt),
    expiresAt: serializeDate(doc.data()?.expiresAt)
  })).sort((left, right) => (right.createdAt?.getTime() || 0) - (left.createdAt?.getTime() || 0));
}

async function getUserDetail(uid) {
  const userRef = firestore.collection(USERS).doc(uid);
  const userSnapshot = await userRef.get();
  if (!userSnapshot.exists) {
    throw new AppError('Không tìm thấy tài khoản người dùng.', 404, 'USER_NOT_FOUND');
  }

  const [
    authUser,
    deviceSnapshot,
    postCount,
    postReportCount,
    profileReportCount,
    matchingReportCount,
    moderationViolations,
    penaltyLogs,
    adminActions
  ] = await Promise.all([
    safeGetAuthUser(uid),
    userRef.collection('devices').limit(100).get(),
    getCollectionCount('posts', 'authorId', uid),
    getCollectionCount('postReports', 'toUid', uid),
    getCollectionCount('userProfileReports', 'toUid', uid),
    getCollectionCount('userMatchingReports', 'toUid', uid),
    getRecentSubcollection(userRef, 'postModerationViolations'),
    getRecentSubcollection(userRef, 'reputationPenaltyLogs'),
    getRecentSubcollection(userRef, 'adminActions', 50)
  ]);

  const user = normalizeUser(userSnapshot);
  const devices = deviceSnapshot.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      id: doc.id,
      platform: cleanString(data.platform) || 'unknown',
      status: cleanString(data.e2eeStatus) || 'active',
      createdAt: serializeDate(data.createdAt),
      lastActiveAt: serializeDate(data.lastActiveAt)
    };
  }).sort((left, right) => (right.lastActiveAt?.getTime() || 0) - (left.lastActiveAt?.getTime() || 0));

  return {
    user,
    auth: authUser ? {
      uid: authUser.uid,
      email: authUser.email || user.email,
      emailVerified: authUser.emailVerified,
      phoneNumber: authUser.phoneNumber || user.phonenumber,
      disabled: authUser.disabled,
      providers: authUser.providerData.map((provider) => provider.providerId),
      creationTime: serializeDate(authUser.metadata.creationTime),
      lastSignInTime: serializeDate(authUser.metadata.lastSignInTime),
      tokensValidAfterTime: serializeDate(authUser.tokensValidAfterTime),
      mfaFactors: authUser.multiFactor?.enrolledFactors?.map((factor) => ({
        uid: factor.uid,
        factorId: factor.factorId,
        phoneNumber: factor.phoneNumber || '',
        enrollmentTime: serializeDate(factor.enrollmentTime)
      })) || []
    } : null,
    devices,
    counts: {
      posts: postCount,
      reports: postReportCount + profileReportCount + matchingReportCount,
      postReports: postReportCount,
      profileReports: profileReportCount,
      matchingReports: matchingReportCount,
      confirmedViolations: moderationViolations.length
    },
    moderationViolations,
    penaltyLogs,
    adminActions
  };
}

function actionNotification(action, reason) {
  const messages = {
    [USER_ACTIONS.WARN]: ['Cảnh báo từ MatchU', reason],
    [USER_ACTIONS.RESTRICT]: ['Tài khoản bị hạn chế', reason],
    [USER_ACTIONS.SUSPEND]: ['Tài khoản tạm khóa', reason],
    [USER_ACTIONS.BAN]: ['Tài khoản đã bị cấm', reason],
    [USER_ACTIONS.RESTORE]: ['Tài khoản đã được khôi phục', 'Các hạn chế quản trị đã được gỡ bỏ.']
  };
  return messages[action] || null;
}

async function writeUserNotification(userRef, actionId, action, reason) {
  const message = actionNotification(action, reason);
  if (!message) return;
  await userRef.collection('notifications').doc(`admin_action_${actionId}`).set({
    recipientId: userRef.id,
    type: 'moderation_penalty',
    title: message[0],
    body: message[1],
    reason: reason || '',
    severity: action,
    readAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function markDevicesRevoked(userRef) {
  const [devices, notificationDevices] = await Promise.all([
    userRef.collection('devices').get(),
    userRef.collection('notificationDevices').get()
  ]);
  const documents = [
    ...devices.docs.map((doc) => ({ type: 'device', ref: doc.ref })),
    ...notificationDevices.docs.map((doc) => ({ type: 'notification', ref: doc.ref }))
  ];

  for (let offset = 0; offset < documents.length; offset += DEVICE_BATCH_LIMIT) {
    const batch = firestore.batch();
    for (const item of documents.slice(offset, offset + DEVICE_BATCH_LIMIT)) {
      const common = {
        status: 'revoked',
        lastActiveAt: admin.firestore.FieldValue.serverTimestamp()
      };
      if (item.type === 'device') {
        batch.set(item.ref, {
          ...common,
          e2eeStatus: 'revoked',
          revokedAt: admin.firestore.FieldValue.serverTimestamp(),
          e2eeUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      } else {
        batch.set(item.ref, {
          ...common,
          pushEnabled: false,
          notificationPermission: 'denied',
          notificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          fcmToken: admin.firestore.FieldValue.delete(),
          fcmTokenUpdatedAt: admin.firestore.FieldValue.delete()
        }, { merge: true });
      }
    }
    await batch.commit();
  }
}

async function updateAccountStatus(userRef, action, payload, currentAdmin) {
  const now = admin.firestore.Timestamp.now();
  const expiresAt = payload.durationDays
    ? admin.firestore.Timestamp.fromMillis(now.toMillis() + payload.durationDays * 86400000)
    : null;
  const common = {
    reason: payload.reason,
    reportId: payload.reportId || null,
    appliedBy: currentAdmin.uid,
    appliedAt: admin.firestore.FieldValue.serverTimestamp()
  };
  const update = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };

  if (action === USER_ACTIONS.WARN) {
    update.trustWarnings = admin.firestore.FieldValue.increment(1);
    update.lastAdminWarning = common;
  } else if (action === USER_ACTIONS.RESTRICT) {
    update.accountStatus = USER_ACCOUNT_STATUSES.RESTRICTED;
    update.restriction = { ...common, features: payload.features, expiresAt };
  } else if (action === USER_ACTIONS.SUSPEND) {
    update.accountStatus = USER_ACCOUNT_STATUSES.SUSPENDED;
    update.activeStatus = 'offline';
    update.suspension = { ...common, expiresAt };
  } else if (action === USER_ACTIONS.BAN) {
    update.accountStatus = USER_ACCOUNT_STATUSES.BANNED;
    update.activeStatus = 'offline';
    update.ban = common;
  } else if (action === USER_ACTIONS.RESTORE) {
    update.accountStatus = USER_ACCOUNT_STATUSES.ACTIVE;
    update.restriction = admin.firestore.FieldValue.delete();
    update.suspension = admin.firestore.FieldValue.delete();
    update.ban = admin.firestore.FieldValue.delete();
    update.restoredAt = admin.firestore.FieldValue.serverTimestamp();
    update.restoredBy = currentAdmin.uid;
  }
  await userRef.set(update, { merge: true });
}

async function adjustBalance(userRef, action, payload, currentAdmin) {
  const field = action === USER_ACTIONS.ADJUST_GEM ? 'gem' : 'reputationScore';
  const ledgerCollection = action === USER_ACTIONS.ADJUST_GEM
    ? 'gemTransactions'
    : 'reputationAdminTransactions';
  let before = 0;
  let after = 0;

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    if (!snapshot.exists) throw new AppError('Không tìm thấy tài khoản người dùng.', 404);
    before = Math.max(0, toInteger(snapshot.data()?.[field]));
    after = before + payload.amount;
    if (after < 0) {
      throw new AppError(`Giá trị ${field} sau điều chỉnh không được âm.`, 400, 'NEGATIVE_BALANCE');
    }
    const ledgerRef = firestore.collection(ledgerCollection).doc();
    transaction.update(userRef, {
      [field]: after,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    transaction.set(ledgerRef, {
      uid: userRef.id,
      type: 'admin_adjustment',
      amount: payload.amount,
      before,
      after,
      reason: payload.reason,
      reportId: payload.reportId || null,
      adminId: currentAdmin.uid,
      adminEmail: currentAdmin.email,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  return { field, before, after };
}

async function sendPasswordResetEmail(uid) {
  const authUser = await safeGetAuthUser(uid);
  if (!authUser?.email) {
    throw new AppError('Tài khoản không có email để đặt lại mật khẩu.', 400, 'EMAIL_NOT_FOUND');
  }
  if (!firebase.webApiKey) {
    throw new AppError(
      'Chưa cấu hình Firebase Web API Key để gửi email đặt lại mật khẩu.',
      503,
      'FIREBASE_WEB_API_KEY_MISSING'
    );
  }
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(firebase.webApiKey)}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ requestType: 'PASSWORD_RESET', email: authUser.email })
    }
  );
  if (!response.ok) {
    throw new AppError('Không thể gửi email đặt lại mật khẩu.', 502, 'PASSWORD_RESET_FAILED');
  }
  return { email: authUser.email };
}

async function executeUserAction(uid, payload, currentAdmin) {
  const userRef = firestore.collection(USERS).doc(uid);
  const beforeSnapshot = await userRef.get();
  if (!beforeSnapshot.exists) {
    throw new AppError('Không tìm thấy tài khoản người dùng.', 404, 'USER_NOT_FOUND');
  }
  const beforeUser = normalizeUser(beforeSnapshot);
  const actionRef = userRef.collection('adminActions').doc();
  let result = {};

  if ([
    USER_ACTIONS.WARN,
    USER_ACTIONS.RESTRICT,
    USER_ACTIONS.SUSPEND,
    USER_ACTIONS.BAN,
    USER_ACTIONS.RESTORE
  ].includes(payload.action)) {
    if (payload.action === USER_ACTIONS.BAN) {
      const authUser = await safeGetAuthUser(uid);
      if (authUser) {
        await auth.updateUser(uid, { disabled: true });
        await auth.revokeRefreshTokens(uid);
      }
      await markDevicesRevoked(userRef);
    }
    if (payload.action === USER_ACTIONS.SUSPEND) {
      const authUser = await safeGetAuthUser(uid);
      if (authUser) {
        // Temporary suspension must still allow credential verification so
        // mobile can securely read and display the suspension reason/expiry.
        // Authorization remains blocked by accountStatus in Rules/Functions.
        if (authUser.disabled) {
          await auth.updateUser(uid, { disabled: false });
        }
        await auth.revokeRefreshTokens(uid);
      }
      await markDevicesRevoked(userRef);
    }
    if (payload.action === USER_ACTIONS.RESTORE) {
      const authUser = await safeGetAuthUser(uid);
      if (authUser?.disabled) await auth.updateUser(uid, { disabled: false });
    }
    await updateAccountStatus(userRef, payload.action, payload, currentAdmin);
  } else if (payload.action === USER_ACTIONS.REVOKE_SESSIONS) {
    await auth.revokeRefreshTokens(uid);
    await markDevicesRevoked(userRef);
  } else if (payload.action === USER_ACTIONS.RESET_FACE_VERIFICATION) {
    const batch = firestore.batch();
    batch.delete(firestore.collection('faceEnrollments').doc(uid));
    batch.set(userRef, {
      isFaceVerified: false,
      faceVerifiedAt: admin.firestore.FieldValue.delete(),
      faceVerificationVersion: admin.firestore.FieldValue.delete(),
      faceVerificationResetAt: admin.firestore.FieldValue.serverTimestamp(),
      faceVerificationResetBy: currentAdmin.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    await batch.commit();
  } else if (payload.action === USER_ACTIONS.SEND_PASSWORD_RESET) {
    result = await sendPasswordResetEmail(uid);
  } else if ([
    USER_ACTIONS.ADJUST_GEM,
    USER_ACTIONS.ADJUST_REPUTATION
  ].includes(payload.action)) {
    result = await adjustBalance(userRef, payload.action, payload, currentAdmin);
  } else {
    throw new AppError('Hành động quản trị không được hỗ trợ.', 400, 'UNSUPPORTED_USER_ACTION');
  }

  const afterSnapshot = await userRef.get();
  const afterUser = normalizeUser(afterSnapshot);
  const actionData = {
    action: payload.action,
    reason: payload.reason || '',
    reportId: payload.reportId || null,
    features: payload.features || [],
    durationDays: payload.durationDays || null,
    amount: payload.amount || null,
    adminId: currentAdmin.uid,
    adminEmail: currentAdmin.email,
    before: {
      accountStatus: beforeUser.accountStatus,
      trustWarnings: beforeUser.trustWarnings,
      gem: beforeUser.gem,
      reputationScore: beforeUser.reputationScore,
      isFaceVerified: beforeUser.isFaceVerified
    },
    after: {
      accountStatus: afterUser.accountStatus,
      trustWarnings: afterUser.trustWarnings,
      gem: afterUser.gem,
      reputationScore: afterUser.reputationScore,
      isFaceVerified: afterUser.isFaceVerified
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };
  await Promise.all([
    actionRef.set(actionData),
    writeUserNotification(userRef, actionRef.id, payload.action, payload.reason)
  ]);

  return { actionId: actionRef.id, before: actionData.before, after: actionData.after, ...result };
}

module.exports = {
  listUsers,
  getUserStatistics,
  getUserDetail,
  executeUserAction,
  __test: { normalizeUser, matchesFilters, toInteger, cleanString }
};
