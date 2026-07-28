const crypto = require('crypto');
const { firestore, admin } = require('../config/firebase-admin');
const { REPORT_CASE_ACTIONS } = require('../config/constants');
const AppError = require('../utils/app-error');

const REPORT_CASES = 'reportCases';
const LIST_BATCH_SIZE = 100;
const LIST_MAX_SCANNED = 1000;
const DETAIL_REPORT_LIMIT = 200;

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function cleanStringArray(value, limit = 30) {
  if (!Array.isArray(value)) return [];
  return value.map(cleanString).filter(Boolean).slice(0, limit);
}

function safeHttpsUrl(value) {
  const normalized = cleanString(value);
  if (!normalized) return '';
  try {
    const parsed = new URL(normalized);
    return parsed.protocol === 'https:' ? parsed.toString() : '';
  } catch (_) {
    return '';
  }
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  return null;
}

function toInteger(value, fallback = 0) {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.trunc(value)
    : fallback;
}

function buildReportCaseId(type, targetId, contextId = '') {
  const identity = `${cleanString(type)}:${cleanString(targetId)}:${cleanString(contextId)}`;
  return `${cleanString(type) || 'report'}_${crypto
    .createHash('sha256')
    .update(identity)
    .digest('hex')
    .slice(0, 40)}`;
}

function normalizeCase(document) {
  const data = document.data() || {};
  return {
    caseId: document.id,
    type: cleanString(data.type),
    targetId: cleanString(data.targetId),
    contextId: cleanString(data.contextId),
    reportedUid: cleanString(data.reportedUid),
    postId: cleanString(data.postId),
    roomId: cleanString(data.roomId),
    status: cleanString(data.status) || 'open',
    priority: cleanString(data.priority) || 'normal',
    reportCount: Math.max(0, toInteger(data.reportCount)),
    categoryKeys: cleanStringArray(data.categoryKeys),
    caseSources: cleanStringArray(data.caseSources, 10),
    contentModerationRequired: data.contentModerationRequired === true,
    moderationStatus: cleanString(data.moderationStatus),
    moderationSource: cleanString(data.moderationSource),
    moderationSummary: cleanString(data.moderationSummary),
    moderationReason: cleanString(data.moderationReason),
    latestReasonKey: cleanString(data.latestReasonKey),
    latestReportAt: toDate(data.latestReportAt),
    assignedAdminId: cleanString(data.assignedAdminId),
    assignedAdminEmail: cleanString(data.assignedAdminEmail),
    resolution: cleanString(data.resolution),
    resolutionReason: cleanString(data.resolutionReason),
    createdAt: toDate(data.createdAt),
    updatedAt: toDate(data.updatedAt),
    resolvedAt: toDate(data.resolvedAt),
    reportedUser: null,
    post: null
  };
}

function normalizeReport(document) {
  const data = document.data() || {};
  return {
    id: cleanString(data.id) || document.id,
    projectionId: document.id,
    source: cleanString(data.source),
    type: cleanString(data.type),
    reporterUid: cleanString(data.reporterUid),
    reportedUid: cleanString(data.reportedUid),
    postId: cleanString(data.postId),
    roomId: cleanString(data.roomId),
    categoryKey: cleanString(data.categoryKey),
    categoryTitle: cleanString(data.categoryTitle),
    reasonKey: cleanString(data.reasonKey),
    reasonTitle: cleanString(data.reasonTitle),
    customReason: cleanString(data.customReason),
    description: cleanString(data.description),
    imageUrls: Array.isArray(data.imageUrls)
      ? data.imageUrls.map(safeHttpsUrl).filter(Boolean)
      : [],
    postType: cleanString(data.postType),
    postContentPreview: cleanString(data.postContentPreview),
    postMediaUrls: Array.isArray(data.postMediaUrls)
      ? data.postMediaUrls.map(safeHttpsUrl).filter(Boolean)
      : [],
    originalPath: cleanString(data.originalPath),
    createdAt: toDate(data.createdAt),
    reporter: null
  };
}

function normalizeAction(document) {
  const data = document.data() || {};
  return {
    id: document.id,
    action: cleanString(data.action),
    reason: cleanString(data.reason),
    resolution: cleanString(data.resolution),
    adminId: cleanString(data.adminId),
    adminEmail: cleanString(data.adminEmail),
    beforeStatus: cleanString(data.beforeStatus),
    afterStatus: cleanString(data.afterStatus),
    createdAt: toDate(data.createdAt)
  };
}

function normalizeUser(document) {
  if (!document?.exists) return null;
  const data = document.data() || {};
  return {
    uid: document.id,
    fullname: cleanString(data.fullname),
    nickname: cleanString(data.nickname),
    avatarUrl: safeHttpsUrl(data.avatarUrl),
    accountStatus: cleanString(data.accountStatus) || 'active',
    totalReports: Math.max(0, toInteger(data.totalReports)),
    reputationScore: Math.max(0, toInteger(data.reputationScore, 100))
  };
}

function normalizePost(document) {
  if (!document?.exists) return null;
  const data = document.data() || {};
  const author = data.author && typeof data.author === 'object' ? data.author : {};
  const media = Array.isArray(data.media) ? data.media : [];
  return {
    postId: document.id,
    authorId: cleanString(data.authorId),
    content: cleanString(data.content),
    postType: cleanString(data.postType) || 'post',
    visibility: cleanString(data.visibility) || (data.isPublic === false ? 'private' : 'public'),
    moderationStatus: cleanString(data.moderationStatus) || 'approved',
    moderationSource: cleanString(data.moderationSource),
    videoModeration: data.videoModeration && typeof data.videoModeration === 'object'
      ? {
        decision: cleanString(data.videoModeration.decision),
        confidence: Number(data.videoModeration.confidence) || 0,
        overallSeverity: Math.max(0, toInteger(data.videoModeration.overallSeverity)),
        primaryViolationCategory: cleanString(data.videoModeration.primaryViolationCategory),
        safeSummary: cleanString(data.videoModeration.safeSummary),
        humanReviewReason: cleanString(data.videoModeration.humanReviewReason)
      }
      : null,
    deletedAt: toDate(data.deletedAt),
    author: {
      name: cleanString(author.name),
      nickname: cleanString(author.nickname)
    },
    mediaUrl: media.map((item) => safeHttpsUrl(item?.url)).find(Boolean) || ''
  };
}

function matchesFilters(reportCase, filters, currentAdmin) {
  if (filters.source === 'community' && !reportCase.caseSources.includes('community_reports')) {
    return false;
  }
  if (filters.source === 'content_moderation' && !reportCase.contentModerationRequired) {
    return false;
  }
  if (filters.priority && reportCase.priority !== filters.priority) return false;
  if (filters.assignee === 'me' && reportCase.assignedAdminId !== currentAdmin.uid) return false;
  if (filters.assignee === 'unassigned' && reportCase.assignedAdminId) return false;
  if (!filters.q) return true;
  const query = filters.q.toLocaleLowerCase('vi-VN');
  return [
    reportCase.caseId,
    reportCase.targetId,
    reportCase.reportedUid,
    reportCase.postId,
    reportCase.roomId,
    reportCase.assignedAdminEmail,
    reportCase.latestReasonKey,
    reportCase.moderationStatus,
    reportCase.moderationSource,
    reportCase.moderationSummary,
    ...reportCase.categoryKeys
  ].join(' ').toLocaleLowerCase('vi-VN').includes(query);
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

async function getReportStatistics() {
  const cases = firestore.collection(REPORT_CASES);
  const [total, open, inReview, resolved, dismissed] = await Promise.all([
    countQuery(cases),
    countQuery(cases.where('status', '==', 'open')),
    countQuery(cases.where('status', '==', 'in_review')),
    countQuery(cases.where('status', '==', 'resolved')),
    countQuery(cases.where('status', '==', 'dismissed'))
  ]);
  return { total, open, inReview, resolved, dismissed };
}

async function getPendingReportCount() {
  return countQuery(
    firestore.collection(REPORT_CASES).where('status', '==', 'open')
  );
}

function baseListQuery(filters) {
  let query = firestore.collection(REPORT_CASES);
  if (filters.type) query = query.where('type', '==', filters.type);
  if (filters.status) query = query.where('status', '==', filters.status);
  return query.orderBy('latestReportAt', 'desc');
}

async function resolveCursor(cursor) {
  if (!cursor) return null;
  const snapshot = await firestore.collection(REPORT_CASES).doc(cursor).get();
  if (!snapshot.exists) {
    throw new AppError('Con trỏ phân trang báo cáo không còn hợp lệ.', 400, 'INVALID_REPORT_CURSOR');
  }
  return snapshot;
}

async function hydrateCases(cases) {
  if (!cases.length) return cases;
  const userIds = [...new Set(cases.map((item) => item.reportedUid).filter(Boolean))];
  const postIds = [...new Set(cases.map((item) => item.postId).filter(Boolean))];
  const [userSnapshots, postSnapshots] = await Promise.all([
    userIds.length
      ? firestore.getAll(...userIds.map((uid) => firestore.collection('users').doc(uid)))
      : [],
    postIds.length
      ? firestore.getAll(...postIds.map((postId) => firestore.collection('posts').doc(postId)))
      : []
  ]);
  const users = new Map(userSnapshots.map((item) => [item.id, normalizeUser(item)]));
  const posts = new Map(postSnapshots.map((item) => [item.id, normalizePost(item)]));
  for (const reportCase of cases) {
    reportCase.reportedUser = users.get(reportCase.reportedUid) || null;
    reportCase.post = posts.get(reportCase.postId) || null;
  }
  return cases;
}

async function listReportCases(filters, currentAdmin) {
  const cases = [];
  let scanned = 0;
  let reachedEnd = false;
  let cursorSnapshot = await resolveCursor(filters.cursor);
  let nextCursor = null;

  while (cases.length < filters.limit && scanned < LIST_MAX_SCANNED) {
    let query = baseListQuery(filters).limit(LIST_BATCH_SIZE);
    if (cursorSnapshot) query = query.startAfter(cursorSnapshot);
    const snapshot = await query.get();
    if (snapshot.empty) {
      reachedEnd = true;
      break;
    }

    for (const document of snapshot.docs) {
      cursorSnapshot = document;
      nextCursor = document.id;
      scanned += 1;
      const reportCase = normalizeCase(document);
      if (matchesFilters(reportCase, filters, currentAdmin)) cases.push(reportCase);
      if (cases.length >= filters.limit || scanned >= LIST_MAX_SCANNED) break;
    }
    if (cases.length >= filters.limit || scanned >= LIST_MAX_SCANNED) break;
    if (snapshot.size < LIST_BATCH_SIZE) {
      reachedEnd = true;
      break;
    }
  }

  await hydrateCases(cases);
  return {
    cases,
    nextCursor: !reachedEnd && cases.length === filters.limit ? nextCursor : null,
    scanned,
    scanLimitReached: scanned >= LIST_MAX_SCANNED
  };
}

async function loadReporters(reports) {
  const ids = [...new Set(reports.map((item) => item.reporterUid).filter(Boolean))];
  if (!ids.length) return;
  const snapshots = await firestore.getAll(
    ...ids.map((uid) => firestore.collection('users').doc(uid))
  );
  const users = new Map(snapshots.map((item) => [item.id, normalizeUser(item)]));
  for (const report of reports) report.reporter = users.get(report.reporterUid) || null;
}

async function getMatchingContext(roomId) {
  if (!roomId) return null;
  const [tempChat, chatRoom] = await Promise.all([
    firestore.collection('tempChats').doc(roomId).get(),
    firestore.collection('chatRooms').doc(roomId).get()
  ]);
  const snapshot = tempChat.exists ? tempChat : chatRoom.exists ? chatRoom : null;
  if (!snapshot) return null;
  const data = snapshot.data() || {};
  return {
    roomId: snapshot.id,
    collection: snapshot.ref.parent.id,
    status: cleanString(data.status),
    participants: cleanStringArray(data.participants || data.members, 10),
    createdAt: toDate(data.createdAt),
    endedAt: toDate(data.endedAt)
  };
}

async function getReportCaseDetail(caseId) {
  const caseRef = firestore.collection(REPORT_CASES).doc(caseId);
  const [caseSnapshot, reportSnapshot, actionSnapshot] = await Promise.all([
    caseRef.get(),
    caseRef.collection('reports').orderBy('createdAt', 'desc').limit(DETAIL_REPORT_LIMIT).get(),
    caseRef.collection('actions').orderBy('createdAt', 'desc').limit(100).get()
  ]);
  if (!caseSnapshot.exists) {
    throw new AppError('Không tìm thấy hồ sơ báo cáo.', 404, 'REPORT_CASE_NOT_FOUND');
  }

  const reportCase = normalizeCase(caseSnapshot);
  await hydrateCases([reportCase]);
  const reports = reportSnapshot.docs.map(normalizeReport);
  await loadReporters(reports);
  const matchingContext = reportCase.type === 'matching'
    ? await getMatchingContext(reportCase.roomId)
    : null;

  return {
    reportCase,
    reports,
    actions: actionSnapshot.docs.map(normalizeAction),
    matchingContext
  };
}

function actionOutcome(action, payload, currentStatus) {
  if (action === REPORT_CASE_ACTIONS.ASSIGN_TO_ME) {
    return { status: currentStatus, resolution: '' };
  }
  if (action === REPORT_CASE_ACTIONS.START_REVIEW) {
    return { status: 'in_review', resolution: '' };
  }
  if (action === REPORT_CASE_ACTIONS.RESOLVE) {
    return { status: 'resolved', resolution: payload.resolution };
  }
  if (action === REPORT_CASE_ACTIONS.DISMISS) {
    return { status: 'dismissed', resolution: 'not_violation' };
  }
  if (action === REPORT_CASE_ACTIONS.REOPEN) {
    return { status: 'open', resolution: '' };
  }
  throw new AppError('Hành động báo cáo không được hỗ trợ.', 400, 'UNSUPPORTED_REPORT_ACTION');
}

async function executeReportAction(caseId, payload, currentAdmin) {
  const caseRef = firestore.collection(REPORT_CASES).doc(caseId);
  const actionRef = caseRef.collection('actions').doc();
  let result;

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(caseRef);
    if (!snapshot.exists) {
      throw new AppError('Không tìm thấy hồ sơ báo cáo.', 404, 'REPORT_CASE_NOT_FOUND');
    }
    const data = snapshot.data() || {};
    const beforeStatus = cleanString(data.status) || 'open';
    const outcome = actionOutcome(payload.action, payload, beforeStatus);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const update = {
      status: outcome.status,
      updatedAt: now
    };

    if ([REPORT_CASE_ACTIONS.ASSIGN_TO_ME, REPORT_CASE_ACTIONS.START_REVIEW].includes(payload.action)) {
      update.assignedAdminId = currentAdmin.uid;
      update.assignedAdminEmail = currentAdmin.email;
    }
    if ([REPORT_CASE_ACTIONS.RESOLVE, REPORT_CASE_ACTIONS.DISMISS].includes(payload.action)) {
      update.resolution = outcome.resolution;
      update.resolutionReason = payload.reason;
      update.resolvedAt = now;
      update.assignedAdminId = currentAdmin.uid;
      update.assignedAdminEmail = currentAdmin.email;
    }
    if (payload.action === REPORT_CASE_ACTIONS.REOPEN) {
      update.resolution = null;
      update.resolutionReason = null;
      update.resolvedAt = null;
      update.assignedAdminId = currentAdmin.uid;
      update.assignedAdminEmail = currentAdmin.email;
    }

    transaction.update(caseRef, update);
    transaction.set(actionRef, {
      action: payload.action,
      reason: payload.reason || '',
      resolution: outcome.resolution || '',
      adminId: currentAdmin.uid,
      adminEmail: currentAdmin.email,
      beforeStatus,
      afterStatus: outcome.status,
      createdAt: now
    });
    result = {
      actionId: actionRef.id,
      beforeStatus,
      afterStatus: outcome.status,
      resolution: outcome.resolution
    };
  });

  return result;
}

async function recordTargetModerationOutcome({
  type,
  targetId,
  contextId = '',
  action,
  reason,
  currentAdmin
}) {
  const caseId = buildReportCaseId(type, targetId, contextId);
  const caseRef = firestore.collection(REPORT_CASES).doc(caseId);
  const snapshot = await caseRef.get();
  if (!snapshot.exists) return null;

  const dismissed = action === 'dismiss';
  const inReview = action === 'review';
  const payload = {
    action: dismissed
      ? REPORT_CASE_ACTIONS.DISMISS
      : inReview ? REPORT_CASE_ACTIONS.START_REVIEW : REPORT_CASE_ACTIONS.RESOLVE,
    reason,
    resolution: dismissed
      ? ''
      : action === 'reject' || action === 'delete_permanently'
        ? 'content_removed'
        : 'action_taken'
  };
  return executeReportAction(caseId, payload, currentAdmin);
}

async function recordUserModerationOutcome({
  caseId,
  userId,
  action,
  reason,
  currentAdmin
}) {
  const caseRef = firestore.collection(REPORT_CASES).doc(caseId);
  const snapshot = await caseRef.get();
  if (!snapshot.exists) return null;
  const data = snapshot.data() || {};
  if (cleanString(data.reportedUid) !== cleanString(userId)) {
    throw new AppError(
      'Hồ sơ báo cáo không thuộc tài khoản đang được xử lý.',
      409,
      'REPORT_CASE_TARGET_MISMATCH'
    );
  }
  return executeReportAction(caseId, {
    action: REPORT_CASE_ACTIONS.RESOLVE,
    reason: reason || `Đã thực hiện thao tác ${action} trên tài khoản.`,
    resolution: ['warn', 'restrict', 'suspend', 'ban'].includes(action)
      ? 'account_penalized'
      : 'action_taken'
  }, currentAdmin);
}

module.exports = {
  getPendingReportCount,
  getReportStatistics,
  listReportCases,
  getReportCaseDetail,
  executeReportAction,
  recordTargetModerationOutcome,
  recordUserModerationOutcome,
  __test: {
    buildReportCaseId,
    normalizeCase,
    normalizeReport,
    matchesFilters,
    actionOutcome,
    safeHttpsUrl
  }
};
