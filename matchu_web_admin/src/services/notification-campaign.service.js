const { firestore, admin } = require('../config/firebase-admin');
const {
  NOTIFICATION_AUDIENCES,
  NOTIFICATION_STATUSES
} = require('../config/constants');
const AppError = require('../utils/app-error');

const CAMPAIGNS = 'notificationCampaigns';
const JOBS = 'notificationCampaignJobs';
const EDITABLE_STATUSES = new Set([
  NOTIFICATION_STATUSES.DRAFT,
  NOTIFICATION_STATUSES.SCHEDULED
]);
const CANCELLABLE_STATUSES = new Set([
  NOTIFICATION_STATUSES.SCHEDULED,
  NOTIFICATION_STATUSES.QUEUED,
  NOTIFICATION_STATUSES.PREPARING,
  NOTIFICATION_STATUSES.SENDING
]);
const ESTIMATE_PAGE_SIZE = 200;
const ESTIMATE_SCAN_LIMIT = 5000;

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function toInteger(value, fallback = 0) {
  if (Number.isFinite(Number(value))) return Math.trunc(Number(value));
  return fallback;
}

function optionalInteger(value) {
  return value === '' || value == null ? null : toInteger(value);
}

function parseScheduledAt(value) {
  const normalized = cleanString(value);
  if (!normalized) return null;
  const withSeconds = /T\d{2}:\d{2}:\d{2}/.test(normalized)
    ? normalized
    : `${normalized}:00`;
  const withZone = /(?:Z|[+-]\d{2}:\d{2})$/.test(withSeconds)
    ? withSeconds
    : `${withSeconds}+07:00`;
  const date = new Date(withZone);
  if (Number.isNaN(date.getTime())) {
    throw new AppError('Thời gian hẹn gửi không hợp lệ.', 400, 'INVALID_SCHEDULE');
  }
  return date;
}

function buildAudience(payload) {
  return {
    type: payload.audienceType,
    targetUserId: payload.audienceType === NOTIFICATION_AUDIENCES.SINGLE_USER
      ? cleanString(payload.targetUserId)
      : '',
    rules: payload.audienceType === NOTIFICATION_AUDIENCES.SEGMENT ? {
      accountStatuses: payload.accountStatuses,
      genders: payload.genders,
      platforms: payload.platforms,
      verification: payload.verification,
      activityDays: optionalInteger(payload.activityDays),
      minAge: optionalInteger(payload.minAge),
      maxAge: optionalInteger(payload.maxAge),
      minReputation: optionalInteger(payload.minReputation),
      maxReputation: optionalInteger(payload.maxReputation),
      minAppVersion: cleanString(payload.minAppVersion),
      maxAppVersion: cleanString(payload.maxAppVersion),
      interestTags: payload.interestTags
    } : {}
  };
}

function buildChannels(payload) {
  return [
    ...(payload.channelPush ? ['push'] : []),
    ...(payload.channelInbox ? ['inbox'] : [])
  ];
}

function campaignStatus(payload, scheduledAt) {
  if (payload.intent === 'save_draft') return NOTIFICATION_STATUSES.DRAFT;
  return payload.sendMode === 'scheduled' && scheduledAt
    ? NOTIFICATION_STATUSES.SCHEDULED
    : NOTIFICATION_STATUSES.QUEUED;
}

function assertPublishTime(payload, scheduledAt) {
  if (payload.intent !== 'publish' || payload.sendMode !== 'scheduled') return;
  if (!scheduledAt || scheduledAt.getTime() < Date.now() + 30 * 1000) {
    throw new AppError(
      'Thời gian hẹn gửi phải cách thời điểm hiện tại ít nhất 30 giây.',
      400,
      'SCHEDULE_TOO_SOON'
    );
  }
}

function buildCampaignData(payload, currentAdmin) {
  const scheduledAt = parseScheduledAt(payload.scheduledAtLocal);
  assertPublishTime(payload, scheduledAt);
  const status = campaignStatus(payload, scheduledAt);
  return {
    category: payload.category,
    title: cleanString(payload.title),
    body: cleanString(payload.body),
    audience: buildAudience(payload),
    channels: buildChannels(payload),
    delivery: {
      sendMode: payload.sendMode,
      scheduledAt: scheduledAt
        ? admin.firestore.Timestamp.fromDate(scheduledAt)
        : null,
      timeZone: payload.timeZone
    },
    action: {
      type: payload.actionType,
      value: cleanString(payload.actionValue)
    },
    status,
    updatedBy: currentAdmin.uid,
    updatedByEmail: currentAdmin.email || '',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(status === NOTIFICATION_STATUSES.QUEUED
      ? {
          queuedAt: admin.firestore.FieldValue.serverTimestamp(),
          preparationPending: true
        }
      : { preparationPending: false })
  };
}

function normalizeCampaign(doc) {
  const data = doc.data() || {};
  const metrics = data.metrics || {};
  return {
    id: doc.id,
    ...data,
    audience: data.audience || { type: 'all', targetUserId: '', rules: {} },
    channels: Array.isArray(data.channels) ? data.channels : [],
    delivery: {
      ...(data.delivery || {}),
      scheduledAt: toDate(data.delivery?.scheduledAt)
    },
    action: data.action || { type: 'inbox', value: '' },
    metrics: {
      targetUsers: toInteger(metrics.targetUsers),
      eligibleUsers: toInteger(metrics.eligibleUsers),
      skippedUsers: toInteger(metrics.skippedUsers),
      attemptedDevices: toInteger(metrics.attemptedDevices),
      acceptedDevices: toInteger(metrics.acceptedDevices),
      failedDevices: toInteger(metrics.failedDevices),
      inboxCreated: toInteger(metrics.inboxCreated),
      invalidTokens: toInteger(metrics.invalidTokens)
    },
    revision: toInteger(data.revision),
    createdAt: toDate(data.createdAt),
    updatedAt: toDate(data.updatedAt),
    queuedAt: toDate(data.queuedAt),
    startedAt: toDate(data.startedAt),
    completedAt: toDate(data.completedAt),
    cancelledAt: toDate(data.cancelledAt)
  };
}

async function countStatus(status) {
  try {
    const snap = await firestore.collection(CAMPAIGNS).where('status', '==', status).count().get();
    return snap.data().count;
  } catch (_) {
    const snap = await firestore.collection(CAMPAIGNS).where('status', '==', status).get();
    return snap.size;
  }
}

async function getCampaignStatistics() {
  const [draft, scheduled, active, completed, failed] = await Promise.all([
    countStatus(NOTIFICATION_STATUSES.DRAFT),
    countStatus(NOTIFICATION_STATUSES.SCHEDULED),
    Promise.all([
      countStatus(NOTIFICATION_STATUSES.QUEUED),
      countStatus(NOTIFICATION_STATUSES.PREPARING),
      countStatus(NOTIFICATION_STATUSES.SENDING)
    ]).then((counts) => counts.reduce((sum, count) => sum + count, 0)),
    countStatus(NOTIFICATION_STATUSES.COMPLETED),
    Promise.all([
      countStatus(NOTIFICATION_STATUSES.PARTIAL_FAILED),
      countStatus(NOTIFICATION_STATUSES.FAILED)
    ]).then((counts) => counts.reduce((sum, count) => sum + count, 0))
  ]);
  return { draft, scheduled, active, completed, failed };
}

async function listCampaigns(filters) {
  const query = firestore.collection(CAMPAIGNS).orderBy('createdAt', 'desc').limit(200);
  const snapshot = await query.get();
  return snapshot.docs
    .map(normalizeCampaign)
    .filter((item) => !filters.status || item.status === filters.status)
    .filter((item) => !filters.category || item.category === filters.category)
    .filter((item) => !filters.audienceType || item.audience.type === filters.audienceType)
    .slice(0, filters.limit);
}

async function ensurePublishTarget(payload) {
  if (
    payload.intent !== 'publish'
    || payload.audienceType !== NOTIFICATION_AUDIENCES.SINGLE_USER
  ) return;
  const snapshot = await firestore.collection('users').doc(payload.targetUserId).get();
  if (!snapshot.exists) {
    throw new AppError('Không tìm thấy người dùng nhận thông báo.', 404, 'TARGET_USER_NOT_FOUND');
  }
}

async function createCampaign(payload, currentAdmin) {
  await ensurePublishTarget(payload);
  const ref = firestore.collection(CAMPAIGNS).doc();
  const data = buildCampaignData(payload, currentAdmin);
  await ref.set({
    ...data,
    metrics: {
      targetUsers: 0,
      eligibleUsers: 0,
      skippedUsers: 0,
      attemptedDevices: 0,
      acceptedDevices: 0,
      failedDevices: 0,
      inboxCreated: 0,
      invalidTokens: 0
    },
    totalJobs: 0,
    completedJobs: 0,
    failedJobs: 0,
    revision: 1,
    createdBy: currentAdmin.uid,
    createdByEmail: currentAdmin.email || '',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  return ref.id;
}

async function getCampaign(id) {
  const snapshot = await firestore.collection(CAMPAIGNS).doc(id).get();
  if (!snapshot.exists) {
    throw new AppError('Không tìm thấy chiến dịch thông báo.', 404, 'CAMPAIGN_NOT_FOUND');
  }
  return normalizeCampaign(snapshot);
}

async function updateCampaign(id, payload, currentAdmin) {
  await ensurePublishTarget(payload);
  const ref = firestore.collection(CAMPAIGNS).doc(id);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      throw new AppError('Không tìm thấy chiến dịch thông báo.', 404, 'CAMPAIGN_NOT_FOUND');
    }
    const current = snapshot.data() || {};
    if (!EDITABLE_STATUSES.has(current.status)) {
      throw new AppError('Chiến dịch đã bắt đầu xử lý và không thể chỉnh sửa.', 409, 'CAMPAIGN_LOCKED');
    }
    if (toInteger(current.revision) !== toInteger(payload.revision)) {
      throw new AppError('Chiến dịch vừa được cập nhật ở phiên khác. Vui lòng tải lại.', 409, 'REVISION_CONFLICT');
    }
    transaction.set(ref, {
      ...buildCampaignData(payload, currentAdmin),
      revision: toInteger(current.revision) + 1
    }, { merge: true });
  });
}

async function cancelCampaign(id, currentAdmin) {
  const ref = firestore.collection(CAMPAIGNS).doc(id);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new AppError('Không tìm thấy chiến dịch.', 404);
    const current = snapshot.data() || {};
    if (!CANCELLABLE_STATUSES.has(current.status)) {
      throw new AppError('Trạng thái chiến dịch không cho phép hủy.', 409, 'CAMPAIGN_NOT_CANCELLABLE');
    }
    transaction.set(ref, {
      status: NOTIFICATION_STATUSES.CANCELLED,
      preparationPending: false,
      cancelledBy: currentAdmin.uid,
      cancelledByEmail: currentAdmin.email || '',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      revision: toInteger(current.revision) + 1
    }, { merge: true });
  });
}

async function retryFailedJobs(id, currentAdmin) {
  const campaignRef = firestore.collection(CAMPAIGNS).doc(id);
  const campaign = await getCampaign(id);
  if (![NOTIFICATION_STATUSES.PARTIAL_FAILED, NOTIFICATION_STATUSES.FAILED].includes(campaign.status)) {
    throw new AppError('Chiến dịch không có lô gửi lỗi để thử lại.', 409, 'NO_FAILED_JOBS');
  }
  const failedJobs = await firestore.collection(JOBS)
    .where('campaignId', '==', id)
    .where('status', '==', 'failed')
    .limit(400)
    .get();
  if (failedJobs.empty) {
    throw new AppError('Không tìm thấy lô gửi lỗi để thử lại.', 409, 'NO_FAILED_JOBS');
  }
  const batch = firestore.batch();
  failedJobs.docs.forEach((doc) => {
    batch.set(doc.ref, {
      status: 'pending',
      retryRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
      leaseExpiresAt: admin.firestore.FieldValue.delete()
    }, { merge: true });
  });
  batch.set(campaignRef, {
    status: NOTIFICATION_STATUSES.SENDING,
    retryRequestedBy: currentAdmin.uid,
    retryRequestedByEmail: currentAdmin.email || '',
    retryRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
  await batch.commit();
  return failedJobs.size;
}

function campaignToForm(campaign) {
  const rules = campaign.audience.rules || {};
  const scheduledAt = campaign.delivery.scheduledAt;
  const localScheduledAt = scheduledAt
    ? new Date(scheduledAt.getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 16)
    : '';
  return {
    revision: campaign.revision,
    category: campaign.category,
    title: campaign.title || '',
    body: campaign.body || '',
    audienceType: campaign.audience.type,
    targetUserId: campaign.audience.targetUserId || '',
    accountStatuses: rules.accountStatuses || [],
    genders: rules.genders || [],
    platforms: rules.platforms || [],
    verification: rules.verification || '',
    activityDays: rules.activityDays ?? '',
    minAge: rules.minAge ?? '',
    maxAge: rules.maxAge ?? '',
    minReputation: rules.minReputation ?? '',
    maxReputation: rules.maxReputation ?? '',
    minAppVersion: rules.minAppVersion || '',
    maxAppVersion: rules.maxAppVersion || '',
    interestTags: (rules.interestTags || []).join(', '),
    channelPush: campaign.channels.includes('push'),
    channelInbox: campaign.channels.includes('inbox'),
    sendMode: campaign.delivery.sendMode || 'immediate',
    scheduledAtLocal: localScheduledAt,
    actionType: campaign.action.type || 'inbox',
    actionValue: campaign.action.value || ''
  };
}

function compareVersions(left, right) {
  const leftParts = String(left || '').split(/[.+-]/).map((item) => Number.parseInt(item, 10) || 0);
  const rightParts = String(right || '').split(/[.+-]/).map((item) => Number.parseInt(item, 10) || 0);
  const size = Math.max(leftParts.length, rightParts.length);
  for (let index = 0; index < size; index += 1) {
    const delta = (leftParts[index] || 0) - (rightParts[index] || 0);
    if (delta !== 0) return delta < 0 ? -1 : 1;
  }
  return 0;
}

function matchesEstimatedUser(data, rules) {
  if (rules.accountStatuses?.length) {
    if (!rules.accountStatuses.includes(cleanString(data.accountStatus) || 'active')) return false;
  }
  if (rules.genders?.length && !rules.genders.includes(cleanString(data.gender))) return false;
  if (rules.verification === 'face_verified' && data.isFaceVerified !== true) return false;
  if (rules.verification === 'face_unverified' && data.isFaceVerified === true) return false;
  if (rules.verification === 'profile_completed' && data.isProfileCompleted !== true) return false;
  if (rules.verification === 'profile_incomplete' && data.isProfileCompleted === true) return false;

  const reputation = toInteger(data.reputationScore, 100);
  if (rules.minReputation != null && reputation < rules.minReputation) return false;
  if (rules.maxReputation != null && reputation > rules.maxReputation) return false;

  const birthday = toDate(data.birthday);
  if (rules.minAge != null || rules.maxAge != null) {
    if (!birthday) return false;
    const now = new Date();
    let age = now.getUTCFullYear() - birthday.getUTCFullYear();
    const monthDelta = now.getUTCMonth() - birthday.getUTCMonth();
    if (monthDelta < 0 || (monthDelta === 0 && now.getUTCDate() < birthday.getUTCDate())) age -= 1;
    if (rules.minAge != null && age < rules.minAge) return false;
    if (rules.maxAge != null && age > rules.maxAge) return false;
  }
  if (rules.activityDays != null) {
    const lastActiveAt = toDate(data.lastActiveAt);
    if (!lastActiveAt || lastActiveAt.getTime() < Date.now() - rules.activityDays * 86400000) {
      return false;
    }
  }
  if (rules.interestTags?.length) {
    const interests = Array.isArray(data.interests)
      ? data.interests.map((item) => cleanString(item).toLocaleLowerCase('vi'))
      : [];
    if (!rules.interestTags.some((tag) => interests.includes(tag.toLocaleLowerCase('vi')))) {
      return false;
    }
  }
  return true;
}

function hasEstimatedDeviceRules(rules) {
  return Boolean(rules.platforms?.length || rules.minAppVersion || rules.maxAppVersion);
}

function matchesEstimatedDevice(data, rules) {
  if (rules.platforms?.length && !rules.platforms.includes(cleanString(data.platform))) return false;
  const version = cleanString(data.appVersion);
  if (rules.minAppVersion && (!version || compareVersions(version, rules.minAppVersion) < 0)) {
    return false;
  }
  if (rules.maxAppVersion && (!version || compareVersions(version, rules.maxAppVersion) > 0)) {
    return false;
  }
  const status = cleanString(data.status || data.e2eeStatus);
  return !['revoked', 'stale'].includes(status);
}

async function matchesEstimatedUserDevices(userRef, rules) {
  if (!hasEstimatedDeviceRules(rules)) return true;
  let snapshot = await userRef.collection('notificationDevices').get();
  if (snapshot.empty) snapshot = await userRef.collection('devices').get();
  return snapshot.docs.some((doc) => matchesEstimatedDevice(doc.data() || {}, rules));
}

async function estimateAudience(payload) {
  const audience = buildAudience(payload);
  if (audience.type === NOTIFICATION_AUDIENCES.SINGLE_USER) {
    const snapshot = await firestore.collection('users').doc(audience.targetUserId).get();
    return {
      estimatedUsers: snapshot.exists ? 1 : 0,
      scannedUsers: snapshot.exists ? 1 : 0,
      truncated: false
    };
  }
  if (audience.type === NOTIFICATION_AUDIENCES.ALL) {
    try {
      const snapshot = await firestore.collection('users').count().get();
      return {
        estimatedUsers: snapshot.data().count,
        scannedUsers: snapshot.data().count,
        truncated: false
      };
    } catch (_) {
      const snapshot = await firestore.collection('users').get();
      return { estimatedUsers: snapshot.size, scannedUsers: snapshot.size, truncated: false };
    }
  }

  let cursor = '';
  let scannedUsers = 0;
  let estimatedUsers = 0;
  let reachedEnd = false;
  while (scannedUsers < ESTIMATE_SCAN_LIMIT) {
    let query = firestore.collection('users')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(ESTIMATE_PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) {
      reachedEnd = true;
      break;
    }
    const remaining = ESTIMATE_SCAN_LIMIT - scannedUsers;
    const pageDocs = snapshot.docs.slice(0, remaining);
    scannedUsers += pageDocs.length;
    cursor = pageDocs[pageDocs.length - 1]?.id || cursor;
    const candidates = pageDocs.filter((doc) =>
      matchesEstimatedUser(doc.data() || {}, audience.rules)
    );
    const deviceMatches = await Promise.all(
      candidates.map((doc) => matchesEstimatedUserDevices(doc.ref, audience.rules))
    );
    estimatedUsers += deviceMatches.filter(Boolean).length;
    if (snapshot.size < ESTIMATE_PAGE_SIZE) {
      reachedEnd = true;
      break;
    }
  }
  return { estimatedUsers, scannedUsers, truncated: !reachedEnd };
}

module.exports = {
  getCampaignStatistics,
  listCampaigns,
  createCampaign,
  getCampaign,
  updateCampaign,
  cancelCampaign,
  retryFailedJobs,
  campaignToForm,
  estimateAudience,
  __test: {
    buildAudience,
    buildChannels,
    parseScheduledAt,
    normalizeCampaign,
    compareVersions,
    matchesEstimatedUser,
    matchesEstimatedDevice
  }
};
