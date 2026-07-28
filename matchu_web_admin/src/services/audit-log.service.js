const { firestore, admin } = require('../config/firebase-admin');
const logger = require('../utils/logger');
const {
  cleanAction,
  deriveCategory,
  deriveResult,
  presentAuditLog,
  toSafeMetadata
} = require('../utils/audit-log');

const COLLECTION = 'adminAuditLogs';
const QUERY_BATCH_SIZE = 100;
const QUERY_SCAN_LIMIT = 1000;
const OVERVIEW_LIMIT = 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function normalizeDocument(document) {
  const data = document.data() || {};
  return presentAuditLog({
    id: document.id,
    adminId: data.adminId || '',
    adminEmail: data.adminEmail || '',
    adminDisplayName: data.adminDisplayName || '',
    adminRole: data.adminRole || '',
    action: data.action || '',
    category: data.category || '',
    result: data.result || '',
    targetType: data.targetType || 'admin',
    targetId: data.targetId || '',
    metadata: data.metadata || {},
    ipAddress: data.ipAddress || '',
    userAgent: data.userAgent || '',
    requestId: data.requestId || '',
    eventVersion: Number(data.eventVersion) || 1,
    createdAt: toDate(data.createdAt)
  });
}

function normalizedSearchText(log) {
  return [
    log.id,
    log.action,
    log.actionLabel,
    log.adminId,
    log.adminEmail,
    log.adminDisplayName,
    log.targetId,
    log.ipAddress,
    log.requestId
  ].join(' ').toLocaleLowerCase('vi-VN');
}

function matchesFilters(log, filters) {
  if (filters.q && !normalizedSearchText(log).includes(filters.q.toLocaleLowerCase('vi-VN'))) {
    return false;
  }
  if (filters.adminId && log.adminId !== filters.adminId) return false;
  if (filters.category && log.category !== filters.category) return false;
  if (filters.result && log.result !== filters.result) return false;
  if (filters.targetType && log.targetType !== filters.targetType) return false;
  return true;
}

async function resolveCursor(cursor) {
  if (!cursor) return null;
  const snapshot = await firestore.collection(COLLECTION).doc(cursor).get();
  return snapshot.exists ? snapshot : null;
}

function buildBaseQuery(filters) {
  let query = firestore.collection(COLLECTION);
  if (filters.fromDate) query = query.where('createdAt', '>=', filters.fromDate);
  if (filters.toDate) query = query.where('createdAt', '<=', filters.toDate);
  return query.orderBy('createdAt', 'desc');
}

async function listAuditLogs(filters) {
  const logs = [];
  let query = buildBaseQuery(filters);
  let cursorSnapshot = await resolveCursor(filters.cursor);
  let scanned = 0;
  let reachedEnd = false;
  let nextCursor = null;
  let foundFollowingMatch = false;

  while (scanned < QUERY_SCAN_LIMIT && !reachedEnd && !foundFollowingMatch) {
    const requestedLimit = Math.min(QUERY_BATCH_SIZE, QUERY_SCAN_LIMIT - scanned);
    let pageQuery = query.limit(requestedLimit);
    if (cursorSnapshot) pageQuery = pageQuery.startAfter(cursorSnapshot);
    const snapshot = await pageQuery.get();
    if (snapshot.empty) {
      reachedEnd = true;
      break;
    }

    for (const document of snapshot.docs) {
      cursorSnapshot = document;
      scanned += 1;
      const log = normalizeDocument(document);
      if (!matchesFilters(log, filters)) continue;
      if (logs.length < filters.limit) {
        logs.push(log);
        nextCursor = document.id;
      } else {
        foundFollowingMatch = true;
        break;
      }
    }
    if (snapshot.size < requestedLimit) {
      reachedEnd = true;
    }
  }

  const scanLimitReached = scanned >= QUERY_SCAN_LIMIT && !reachedEnd && !foundFollowingMatch;
  const hasNextPage = foundFollowingMatch || scanLimitReached;
  if (scanLimitReached && logs.length < filters.limit) nextCursor = cursorSnapshot?.id || null;
  return {
    logs,
    nextCursor: hasNextPage ? nextCursor : null,
    hasNextPage,
    scanned,
    scanLimitReached
  };
}

async function safeTotalCount() {
  try {
    const snapshot = await firestore.collection(COLLECTION).count().get();
    return Number(snapshot.data().count) || 0;
  } catch (error) {
    logger.error('Unable to count admin audit logs', error);
    return null;
  }
}

async function getAuditStatistics(now = new Date()) {
  const since = new Date(now.getTime() - DAY_MS);
  const [total, recentResult] = await Promise.all([
    safeTotalCount(),
    firestore.collection(COLLECTION)
      .where('createdAt', '>=', since)
      .orderBy('createdAt', 'desc')
      .limit(OVERVIEW_LIMIT)
      .get()
      .then((snapshot) => snapshot.docs.map(normalizeDocument))
      .catch((error) => {
        logger.error('Unable to load recent audit overview', error);
        return [];
      })
  ]);
  const adminIds = new Set(recentResult.map((item) => item.adminId).filter(Boolean));
  return {
    total,
    last24Hours: recentResult.length,
    failures24Hours: recentResult.filter((item) => item.result === 'failure').length,
    denied24Hours: recentResult.filter((item) => item.result === 'denied').length,
    activeAdmins24Hours: adminIds.size,
    recentTruncated: recentResult.length >= OVERVIEW_LIMIT
  };
}

async function listAdminOptions() {
  const snapshot = await firestore.collection('adminProfiles').get();
  return snapshot.docs
    .map((document) => {
      const data = document.data() || {};
      return {
        uid: document.id,
        displayName: data.displayName || data.email || document.id,
        email: data.email || '',
        status: data.status || 'unknown'
      };
    })
    .sort((left, right) => left.displayName.localeCompare(right.displayName, 'vi'));
}

async function writeAuditLog({
  admin: currentAdmin,
  action,
  targetType = 'admin',
  targetId,
  metadata = {},
  result,
  category,
  req
}) {
  try {
    const normalizedAction = cleanAction(action);
    await firestore.collection(COLLECTION).add({
      adminId: currentAdmin?.uid || null,
      adminEmail: currentAdmin?.email || null,
      adminDisplayName: currentAdmin?.displayName || null,
      adminRole: currentAdmin?.role || null,
      action: normalizedAction,
      category: deriveCategory(normalizedAction, category),
      result: deriveResult(normalizedAction, result),
      targetType,
      targetId: targetId || currentAdmin?.uid || null,
      metadata: toSafeMetadata(metadata),
      ipAddress: req?.ip || '',
      userAgent: req?.get?.('user-agent') || '',
      requestId: req?.id || '',
      eventVersion: 2,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    return true;
  } catch (error) {
    logger.error('Unable to write admin audit log', error);
    return false;
  }
}

module.exports = {
  writeAuditLog,
  listAuditLogs,
  getAuditStatistics,
  listAdminOptions,
  __test: {
    matchesFilters,
    normalizeDocument,
    toDate
  }
};
