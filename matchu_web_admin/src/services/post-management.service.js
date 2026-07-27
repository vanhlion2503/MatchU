const { firestore, admin } = require('../config/firebase-admin');
const { POST_MODERATION_ACTIONS } = require('../config/constants');
const {
  buildAdminPostSearchQueryTerms,
  normalizeSearchText
} = require('../utils/post-search-index');
const AppError = require('../utils/app-error');

const POSTS = 'posts';
const POST_REPORTS = 'postReports';
const MODERATION_CASES = 'moderationCases';
const LIST_SCAN_BATCH = 100;
const LIST_MAX_SCANNED = 3000;
const FIRESTORE_IN_LIMIT = 30;
const REPORT_DETAIL_LIMIT = 200;
const MODERATION_CANDIDATE_LIMIT = 2000;
const SEARCH_CANDIDATE_LIMIT = 1000;
const VALID_VISIBILITIES = new Set(['public', 'followers', 'private']);
const OPEN_CASE_STATUSES = new Set(['open', 'in_review']);

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
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

function toInteger(value, fallback = 0) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return Math.trunc(value);
}

function toNumber(value, fallback = 0) {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function normalizeVisibility(value, legacyIsPublic) {
  const normalized = cleanString(value).toLowerCase();
  if (VALID_VISIBILITIES.has(normalized)) return normalized;
  return legacyIsPublic === false ? 'private' : 'public';
}

function normalizeModerationStatus(value) {
  const normalized = cleanString(value).toLowerCase();
  if (normalized === 'pending' || normalized === 'processing') return 'pending_moderation';
  if (normalized === 'needs_review' || normalized === 'human_review') return 'review_required';
  if (['approved', 'rejected', 'review_required', 'pending_moderation'].includes(normalized)) {
    return normalized;
  }
  return 'approved';
}

function normalizeMedia(value) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item) => item && typeof item === 'object')
    .map((item) => {
      const rawType = cleanString(item.type).toLowerCase();
      const type = rawType === 'voice' || rawType === 'audio_m4a'
        ? 'audio'
        : ['image', 'video', 'audio'].includes(rawType) ? rawType : 'image';
      return {
        url: safeHttpsUrl(item.url),
        type,
        durationMs: Math.max(0, toInteger(item.durationMs)),
        storagePath: cleanString(item.storagePath),
        mimeType: cleanString(item.mimeType),
        thumbnailUrl: safeHttpsUrl(item.thumbnailUrl)
      };
    })
    .filter((item) => item.url || item.storagePath);
}

function normalizeAuthor(value, authorId) {
  const author = value && typeof value === 'object' ? value : {};
  return {
    id: cleanString(author.id) || authorId,
    name: cleanString(author.name),
    nickname: cleanString(author.nickname),
    avatar: safeHttpsUrl(author.avatar),
    isVerified: author.isVerified === true
  };
}

function normalizeStats(value) {
  const stats = value && typeof value === 'object' ? value : {};
  return {
    likeCount: Math.max(0, toInteger(stats.likeCount)),
    commentCount: Math.max(0, toInteger(stats.commentCount)),
    shareCount: Math.max(0, toInteger(stats.shareCount)),
    externalShareCount: Math.max(0, toInteger(stats.externalShareCount)),
    saveCount: Math.max(0, toInteger(stats.saveCount))
  };
}

function normalizePost(doc) {
  const data = doc.data() || {};
  const authorId = cleanString(data.authorId);
  const media = normalizeMedia(data.media);
  const videoModeration = data.videoModeration && typeof data.videoModeration === 'object'
    ? data.videoModeration
    : null;
  const adminModeration = data.adminModeration && typeof data.adminModeration === 'object'
    ? data.adminModeration
    : null;

  return {
    postId: doc.id,
    authorId,
    postType: ['post', 'quote', 'repost'].includes(cleanString(data.postType))
      ? cleanString(data.postType)
      : 'post',
    content: cleanString(data.content),
    media,
    mediaTypes: [...new Set(media.map((item) => item.type))],
    tags: Array.isArray(data.tags) ? data.tags.map(cleanString).filter(Boolean) : [],
    visibility: normalizeVisibility(data.visibility, data.isPublic),
    requestedVisibility: VALID_VISIBILITIES.has(cleanString(data.requestedVisibility))
      ? cleanString(data.requestedVisibility)
      : null,
    moderationStatus: normalizeModerationStatus(data.moderationStatus),
    moderationSource: cleanString(data.moderationSource),
    moderationMessageVi: cleanString(data.moderationMessageVi),
    moderationPolicyVersion: cleanString(data.moderationPolicyVersion),
    videoStoragePath: cleanString(data.videoStoragePath),
    videoModeration,
    adminModeration: adminModeration ? {
      action: cleanString(adminModeration.action),
      decision: cleanString(adminModeration.decision),
      reason: cleanString(adminModeration.reason),
      adminId: cleanString(adminModeration.adminId),
      adminEmail: cleanString(adminModeration.adminEmail),
      previousVisibility: cleanString(adminModeration.previousVisibility),
      previousModerationStatus: cleanString(adminModeration.previousModerationStatus),
      updatedAt: toDate(adminModeration.updatedAt)
    } : null,
    stats: normalizeStats(data.stats),
    trendScore: toNumber(data.trendScore),
    trendBucket: toInteger(data.trendBucket),
    recommendationStatus: cleanString(data.recommendationStatus) || 'unknown',
    recommendationErrorCode: cleanString(data.recommendationErrorCode),
    author: normalizeAuthor(data.author, authorId),
    referencePostId: cleanString(data.referencePostId),
    referencePost: data.referencePost && typeof data.referencePost === 'object'
      ? {
        postId: cleanString(data.referencePost.postId),
        authorId: cleanString(data.referencePost.authorId),
        content: cleanString(data.referencePost.content),
        media: normalizeMedia(data.referencePost.media),
        author: normalizeAuthor(data.referencePost.author, cleanString(data.referencePost.authorId)),
        deletedAt: toDate(data.referencePost.deletedAt)
      }
      : null,
    createdAt: toDate(data.createdAt),
    updatedAt: toDate(data.updatedAt),
    deletedAt: toDate(data.deletedAt),
    reportCount: 0,
    reportCategories: [],
    latestReportAt: null,
    reportState: 'none',
    moderationCase: null,
    priority: 'normal'
  };
}

function normalizeReport(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    fromUid: cleanString(data.fromUid),
    toUid: cleanString(data.toUid),
    postId: cleanString(data.postId),
    postType: cleanString(data.postType),
    postContentPreview: cleanString(data.postContentPreview),
    postMediaUrls: Array.isArray(data.postMediaUrls)
      ? data.postMediaUrls.map(safeHttpsUrl).filter(Boolean)
      : [],
    categoryKey: cleanString(data.categoryKey),
    categoryTitle: cleanString(data.categoryTitle),
    reasonKey: cleanString(data.reasonKey),
    reasonTitle: cleanString(data.reasonTitle),
    customReason: cleanString(data.customReason),
    description: cleanString(data.description),
    imageUrls: Array.isArray(data.imageUrls) ? data.imageUrls.map(safeHttpsUrl).filter(Boolean) : [],
    createdAt: toDate(data.createdAt),
    reporter: null
  };
}

function normalizeModerationCase(doc) {
  if (!doc?.exists) return null;
  const data = doc.data() || {};
  return {
    id: doc.id,
    postId: cleanString(data.postId) || doc.id,
    status: cleanString(data.status) || 'open',
    priority: cleanString(data.priority) || 'normal',
    reportCount: Math.max(0, toInteger(data.reportCount)),
    categories: Array.isArray(data.categories)
      ? data.categories.map(cleanString).filter(Boolean)
      : [],
    assignedAdminId: cleanString(data.assignedAdminId),
    assignedAdminEmail: cleanString(data.assignedAdminEmail),
    resolution: cleanString(data.resolution),
    resolutionReason: cleanString(data.resolutionReason),
    createdAt: toDate(data.createdAt),
    updatedAt: toDate(data.updatedAt),
    resolvedAt: toDate(data.resolvedAt)
  };
}

function normalizeCaseAction(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    action: cleanString(data.action),
    reason: cleanString(data.reason),
    adminId: cleanString(data.adminId),
    adminEmail: cleanString(data.adminEmail),
    before: data.before && typeof data.before === 'object' ? data.before : {},
    after: data.after && typeof data.after === 'object' ? data.after : {},
    createdAt: toDate(data.createdAt)
  };
}

function calculatePriority(post) {
  const severity = Math.max(
    toInteger(post.videoModeration?.overallSeverity),
    ...(Array.isArray(post.videoModeration?.violations)
      ? post.videoModeration.violations.map((item) => toInteger(item?.severity))
      : [0])
  );
  if (severity >= 4 || post.reportCount >= 10) return 'critical';
  if (post.moderationStatus === 'review_required' || post.reportCount >= 5) return 'high';
  if (post.moderationStatus === 'pending_moderation' || post.reportCount > 0) return 'medium';
  return 'normal';
}

function hasOpenReports(post) {
  if (post.reportCount <= 0) return false;
  if (!post.moderationCase || OPEN_CASE_STATUSES.has(post.moderationCase.status)) return true;
  if (post.reportCount > post.moderationCase.reportCount) return true;
  const latestReportAt = post.latestReportAt?.getTime() || 0;
  const resolvedAt = post.moderationCase.resolvedAt?.getTime()
    || post.moderationCase.updatedAt?.getTime()
    || 0;
  return latestReportAt > resolvedAt;
}

function matchesPostDocumentFilters(post, filters) {
  const query = normalizeSearchText(filters.q);
  if (query) {
    const searchable = [
      post.postId,
      post.authorId,
      post.author.name,
      post.author.nickname,
      post.content,
      ...post.tags
    ].join(' ');
    if (!normalizeSearchText(searchable).includes(query)) return false;
  }
  if (filters.type && post.postType !== filters.type) return false;
  if (filters.media === 'text' && post.media.length > 0) return false;
  if (filters.media && filters.media !== 'text' && !post.mediaTypes.includes(filters.media)) return false;
  if (filters.visibility && post.visibility !== filters.visibility) return false;
  if (filters.moderation && post.moderationStatus !== filters.moderation) return false;
  if (filters.lifecycle === 'active' && post.deletedAt) return false;
  if (filters.lifecycle === 'deleted' && !post.deletedAt) return false;
  return true;
}

function matchesPostFilters(post, filters) {
  if (!matchesPostDocumentFilters(post, filters)) return false;
  if (filters.report === 'reported' && post.reportCount <= 0) return false;
  if (filters.report === 'unreported' && post.reportCount > 0) return false;
  if (filters.report === 'open' && !hasOpenReports(post)) return false;
  if (filters.report === 'resolved' && (post.reportCount <= 0 || hasOpenReports(post))) return false;
  if (filters.priority && post.priority !== filters.priority) return false;

  if (filters.queue === 'reported' && !hasOpenReports(post)) return false;
  if (filters.queue === 'review_required' && post.moderationStatus !== 'review_required') return false;
  if (filters.queue === 'pending' && post.moderationStatus !== 'pending_moderation') return false;
  if (filters.queue === 'rejected' && post.moderationStatus !== 'rejected') return false;
  if (filters.queue === 'all'
    && !hasOpenReports(post)
    && !['review_required', 'pending_moderation'].includes(post.moderationStatus)) return false;
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

async function getPostStatistics() {
  const posts = firestore.collection(POSTS);
  const reports = firestore.collection(POST_REPORTS);
  const [total, approved, pending, reviewRequired, rejected, reportCount] = await Promise.all([
    countQuery(posts),
    countQuery(posts.where('moderationStatus', '==', 'approved')),
    countQuery(posts.where('moderationStatus', '==', 'pending_moderation')),
    countQuery(posts.where('moderationStatus', '==', 'review_required')),
    countQuery(posts.where('moderationStatus', '==', 'rejected')),
    countQuery(reports)
  ]);
  return { total, approved, pending, reviewRequired, rejected, reportCount };
}

async function loadReportMetadata(postIds) {
  const metadata = new Map(postIds.map((postId) => [postId, {
    count: 0,
    categories: new Set(),
    latestAt: null
  }]));

  for (let offset = 0; offset < postIds.length; offset += FIRESTORE_IN_LIMIT) {
    const chunk = postIds.slice(offset, offset + FIRESTORE_IN_LIMIT);
    if (!chunk.length) continue;
    const snapshot = await firestore.collection(POST_REPORTS).where('postId', 'in', chunk).get();
    for (const doc of snapshot.docs) {
      const report = normalizeReport(doc);
      const item = metadata.get(report.postId);
      if (!item) continue;
      item.count += 1;
      if (report.categoryKey) item.categories.add(report.categoryKey);
      if (report.createdAt && (!item.latestAt || report.createdAt > item.latestAt)) {
        item.latestAt = report.createdAt;
      }
    }
  }
  return metadata;
}

async function loadModerationCases(postIds) {
  if (!postIds.length) return new Map();
  const snapshots = await firestore.getAll(
    ...postIds.map((postId) => firestore.collection(MODERATION_CASES).doc(postId))
  );
  return new Map(snapshots.map((snapshot) => [
    snapshot.id,
    normalizeModerationCase(snapshot)
  ]));
}

async function hydrateOperationalMetadata(posts) {
  if (!posts.length) return posts;
  const postIds = posts.map((post) => post.postId);
  const [reports, cases] = await Promise.all([
    loadReportMetadata(postIds),
    loadModerationCases(postIds)
  ]);

  for (const post of posts) {
    const reportMeta = reports.get(post.postId);
    post.reportCount = reportMeta?.count || 0;
    post.reportCategories = reportMeta ? [...reportMeta.categories] : [];
    post.latestReportAt = reportMeta?.latestAt || null;
    post.moderationCase = cases.get(post.postId) || null;
    const reportsAreOpen = hasOpenReports(post);
    post.reportState = post.reportCount <= 0
      ? 'none'
      : reportsAreOpen ? 'open' : post.moderationCase?.status || 'resolved';
    post.priority = reportsAreOpen
      ? calculatePriority(post)
      : post.moderationCase?.priority || calculatePriority(post);
  }
  return posts;
}

async function resolveCursor(cursor) {
  if (!cursor) return null;
  const snapshot = await firestore.collection(POSTS).doc(cursor).get();
  if (!snapshot.exists) {
    throw new AppError('Con trỏ phân trang không còn hợp lệ.', 400, 'INVALID_POST_CURSOR');
  }
  return snapshot;
}

async function listExactPostIdMatch(filters) {
  const query = cleanString(filters.q);
  if (filters.cursor || !/^[A-Za-z0-9_-]{1,120}$/.test(query)) return null;
  const snapshot = await firestore.collection(POSTS).doc(query).get();
  if (!snapshot.exists) return null;
  const post = normalizePost(snapshot);
  if (!matchesPostDocumentFilters(post, filters)) {
    return { posts: [], nextCursor: null, scanned: 1, scanLimitReached: false };
  }
  await hydrateOperationalMetadata([post]);
  return {
    posts: matchesPostFilters(post, filters) ? [post] : [],
    nextCursor: null,
    scanned: 1,
    scanLimitReached: false
  };
}

async function listIndexedPosts(filters) {
  const searchTerms = buildAdminPostSearchQueryTerms(filters.q);
  if (!cleanString(filters.q) || searchTerms.length === 0) return null;

  let snapshot;
  try {
    snapshot = await firestore.collection('adminPostSearchIndex')
      .where('searchTerms', 'array-contains-any', searchTerms)
      .orderBy('createdAt', 'desc')
      .limit(SEARCH_CANDIDATE_LIMIT)
      .get();
  } catch (error) {
    const code = String(error?.code || '').toLowerCase();
    if (code === '9' || code.includes('failed-precondition')) return null;
    throw error;
  }
  if (snapshot.empty) return null;

  const documents = await loadPostDocuments(snapshot.docs.map((document) => document.id));
  const candidates = documents
    .map(normalizePost)
    .filter((post) => matchesPostDocumentFilters(post, filters))
    .sort((left, right) => (
      (right.createdAt?.getTime() || 0) - (left.createdAt?.getTime() || 0)
    ));

  const needsOperationalFiltering = Boolean(filters.report || filters.priority);
  let matching = candidates;
  if (needsOperationalFiltering) {
    await hydrateOperationalMetadata(matching);
    matching = matching.filter((post) => matchesPostFilters(post, filters));
  }

  let startIndex = 0;
  if (filters.cursor) {
    const cursorIndex = matching.findIndex((post) => post.postId === filters.cursor);
    if (cursorIndex >= 0) startIndex = cursorIndex + 1;
  }
  const posts = matching.slice(startIndex, startIndex + filters.limit);
  if (!needsOperationalFiltering) await hydrateOperationalMetadata(posts);
  const hasMore = startIndex + posts.length < matching.length;

  return {
    posts,
    nextCursor: hasMore ? posts.at(-1)?.postId || null : null,
    scanned: snapshot.size,
    scanLimitReached: snapshot.size >= SEARCH_CANDIDATE_LIMIT
  };
}

async function listPosts(filters) {
  const exactMatch = await listExactPostIdMatch(filters);
  if (exactMatch) return exactMatch;
  const indexedMatches = await listIndexedPosts(filters);
  if (indexedMatches) return indexedMatches;

  const posts = [];
  let scanned = 0;
  let reachedEnd = false;
  let cursorSnapshot = await resolveCursor(filters.cursor);
  let nextCursor = null;

  while (posts.length < filters.limit && scanned < LIST_MAX_SCANNED) {
    let query = firestore
      .collection(POSTS)
      .orderBy('createdAt', 'desc')
      .limit(LIST_SCAN_BATCH);
    if (cursorSnapshot) query = query.startAfter(cursorSnapshot);

    const snapshot = await query.get();
    if (snapshot.empty) {
      reachedEnd = true;
      break;
    }

    const normalized = snapshot.docs.map(normalizePost);
    const candidates = normalized.filter((post) => matchesPostDocumentFilters(post, filters));
    const hydrated = await hydrateOperationalMetadata(candidates);
    const hydratedById = new Map(hydrated.map((post) => [post.postId, post]));

    for (let index = 0; index < normalized.length; index += 1) {
      const post = hydratedById.get(normalized[index].postId);
      cursorSnapshot = snapshot.docs[index];
      nextCursor = snapshot.docs[index].id;
      scanned += 1;
      if (post && matchesPostFilters(post, filters)) posts.push(post);
      if (posts.length >= filters.limit || scanned >= LIST_MAX_SCANNED) break;
    }

    if (posts.length >= filters.limit || scanned >= LIST_MAX_SCANNED) break;
    if (snapshot.size < LIST_SCAN_BATCH) {
      reachedEnd = true;
      break;
    }
  }

  return {
    posts,
    nextCursor: !reachedEnd && posts.length === filters.limit ? nextCursor : null,
    scanned,
    scanLimitReached: scanned >= LIST_MAX_SCANNED
  };
}

async function loadPostDocuments(postIds) {
  const documents = [];
  for (let offset = 0; offset < postIds.length; offset += 200) {
    const chunk = postIds.slice(offset, offset + 200);
    if (!chunk.length) continue;
    const snapshots = await firestore.getAll(
      ...chunk.map((postId) => firestore.collection(POSTS).doc(postId))
    );
    documents.push(...snapshots.filter((snapshot) => snapshot.exists));
  }
  return documents;
}

async function listModerationPosts(filters) {
  const candidateDocuments = new Map();
  const queries = [];

  if (filters.queue === 'all' || filters.queue === 'reported') {
    queries.push(
      firestore.collection(POST_REPORTS)
        .orderBy('createdAt', 'desc')
        .limit(MODERATION_CANDIDATE_LIMIT)
        .get()
        .then(async (snapshot) => {
          const postIds = [...new Set(snapshot.docs
            .map((doc) => cleanString(doc.data()?.postId))
            .filter(Boolean))];
          const postDocuments = await loadPostDocuments(postIds);
          for (const document of postDocuments) candidateDocuments.set(document.id, document);
        })
    );
  }

  const statuses = filters.queue === 'all'
    ? ['review_required', 'pending_moderation']
    : filters.queue === 'review_required'
      ? ['review_required']
      : filters.queue === 'pending'
        ? ['pending_moderation']
        : filters.queue === 'rejected'
          ? ['rejected']
          : [];
  for (const status of statuses) {
    queries.push(
      firestore.collection(POSTS)
        .where('moderationStatus', '==', status)
        .limit(MODERATION_CANDIDATE_LIMIT)
        .get()
        .then((snapshot) => {
          for (const document of snapshot.docs) candidateDocuments.set(document.id, document);
        })
    );
  }

  await Promise.all(queries);
  const hydrated = await hydrateOperationalMetadata(
    [...candidateDocuments.values()].map(normalizePost)
  );
  const priorityRank = { critical: 4, high: 3, medium: 2, normal: 1 };
  const matching = hydrated
    .filter((post) => matchesPostFilters(post, filters))
    .sort((left, right) => {
      const priorityDelta = (priorityRank[right.priority] || 0) - (priorityRank[left.priority] || 0);
      if (priorityDelta !== 0) return priorityDelta;
      const leftTime = left.latestReportAt?.getTime() || left.createdAt?.getTime() || 0;
      const rightTime = right.latestReportAt?.getTime() || right.createdAt?.getTime() || 0;
      return rightTime - leftTime;
    });

  let startIndex = 0;
  if (filters.cursor) {
    const cursorIndex = matching.findIndex((post) => post.postId === filters.cursor);
    if (cursorIndex >= 0) startIndex = cursorIndex + 1;
  }
  const posts = matching.slice(startIndex, startIndex + filters.limit);
  const hasMore = startIndex + posts.length < matching.length;
  return {
    posts,
    nextCursor: hasMore ? posts.at(-1)?.postId || null : null,
    scanned: hydrated.length,
    scanLimitReached: candidateDocuments.size >= MODERATION_CANDIDATE_LIMIT
  };
}

async function getReporters(reports) {
  const userIds = [...new Set(reports.map((report) => report.fromUid).filter(Boolean))];
  if (!userIds.length) return new Map();
  const snapshots = await firestore.getAll(
    ...userIds.map((uid) => firestore.collection('users').doc(uid))
  );
  return new Map(snapshots.map((snapshot) => {
    const data = snapshot.data() || {};
    return [snapshot.id, {
      uid: snapshot.id,
      name: cleanString(data.fullname),
      nickname: cleanString(data.nickname),
      avatarUrl: safeHttpsUrl(data.avatarUrl),
      accountStatus: cleanString(data.accountStatus) || 'active'
    }];
  }));
}

async function getPostDetail(postId) {
  const postRef = firestore.collection(POSTS).doc(postId);
  const caseRef = firestore.collection(MODERATION_CASES).doc(postId);
  const [postSnapshot, reportSnapshot, caseSnapshot] = await Promise.all([
    postRef.get(),
    firestore.collection(POST_REPORTS).where('postId', '==', postId).get(),
    caseRef.get()
  ]);
  if (!postSnapshot.exists) {
    throw new AppError('Không tìm thấy bài viết.', 404, 'POST_NOT_FOUND');
  }

  const post = normalizePost(postSnapshot);
  const reports = reportSnapshot.docs
    .map(normalizeReport)
    .sort((left, right) => (right.createdAt?.getTime() || 0) - (left.createdAt?.getTime() || 0))
    .slice(0, REPORT_DETAIL_LIMIT);
  const reporterMap = await getReporters(reports);
  for (const report of reports) report.reporter = reporterMap.get(report.fromUid) || null;

  const [authorSnapshot, actionSnapshot, commentCount] = await Promise.all([
    post.authorId ? firestore.collection('users').doc(post.authorId).get() : null,
    caseRef.collection('actions').orderBy('createdAt', 'desc').limit(100).get(),
    countQuery(postRef.collection('comments'))
  ]);
  const authorData = authorSnapshot?.data() || {};
  const moderationCase = normalizeModerationCase(caseSnapshot);

  post.reportCount = reportSnapshot.size;
  post.reportCategories = [...new Set(reports.map((report) => report.categoryKey).filter(Boolean))];
  post.latestReportAt = reports[0]?.createdAt || null;
  post.moderationCase = moderationCase;
  const reportsAreOpen = hasOpenReports(post);
  post.reportState = post.reportCount <= 0
    ? 'none'
    : reportsAreOpen ? 'open' : moderationCase?.status || 'resolved';
  post.priority = reportsAreOpen
    ? calculatePriority(post)
    : moderationCase?.priority || calculatePriority(post);

  return {
    post,
    authorAccount: authorSnapshot?.exists ? {
      uid: authorSnapshot.id,
      fullname: cleanString(authorData.fullname),
      nickname: cleanString(authorData.nickname),
      avatarUrl: safeHttpsUrl(authorData.avatarUrl),
      accountStatus: cleanString(authorData.accountStatus) || 'active',
      reputationScore: Math.max(0, toInteger(authorData.reputationScore, 100)),
      totalReports: Math.max(0, toInteger(authorData.totalReports)),
      trustWarnings: Math.max(0, toInteger(authorData.trustWarnings))
    } : null,
    reports,
    moderationCase: moderationCase || (reports.length ? {
      id: postId,
      postId,
      status: 'open',
      priority: post.priority,
      reportCount: reports.length,
      categories: post.reportCategories,
      assignedAdminId: '',
      assignedAdminEmail: '',
      resolution: '',
      resolutionReason: '',
      createdAt: post.latestReportAt,
      updatedAt: null,
      resolvedAt: null
    } : null),
    caseActions: actionSnapshot.docs.map(normalizeCaseAction),
    commentCount
  };
}

function resolveRestoredVisibility(postData) {
  const adminModeration = postData.adminModeration && typeof postData.adminModeration === 'object'
    ? postData.adminModeration
    : {};
  const candidates = [
    adminModeration.previousVisibility,
    postData.requestedVisibility,
    postData.visibility
  ];
  return candidates.map((item) => cleanString(item)).find((item) => VALID_VISIBILITIES.has(item))
    || 'private';
}

function reportSummary(snapshot) {
  const reports = snapshot.docs.map(normalizeReport);
  return {
    count: reports.length,
    categories: [...new Set(reports.map((report) => report.categoryKey).filter(Boolean))],
    reportIds: reports.slice(0, 100).map((report) => report.id)
  };
}

async function deleteDocumentReferences(references) {
  const uniqueReferences = [...new Map(
    references.map((reference) => [reference.path, reference])
  ).values()];
  const batchSize = 400;
  for (let offset = 0; offset < uniqueReferences.length; offset += batchSize) {
    const batch = firestore.batch();
    for (const reference of uniqueReferences.slice(offset, offset + batchSize)) {
      batch.delete(reference);
    }
    await batch.commit();
  }
  return uniqueReferences.length;
}

async function loadPermanentDeleteReferences(postId) {
  const queries = [
    firestore.collection(POST_REPORTS).where('postId', '==', postId),
    firestore.collection('postShareEvents').where('postId', '==', postId),
    firestore.collectionGroup('savedPosts').where('postId', '==', postId),
    firestore.collectionGroup('hiddenPosts').where('postId', '==', postId),
    firestore.collectionGroup('recommendationInteractions').where('postId', '==', postId),
    firestore.collectionGroup('feedImpressions').where('postId', '==', postId),
    firestore.collectionGroup('postShareRateLimits').where('postId', '==', postId)
  ];
  let snapshots;
  try {
    snapshots = await Promise.all(queries.map((query) => query.get()));
  } catch (error) {
    const code = String(error?.code || '').toLowerCase();
    if (code === '9' || code.includes('failed-precondition')) {
      throw new AppError(
        'Firestore index phục vụ xóa vĩnh viễn chưa sẵn sàng. Hãy deploy firestore:indexes và thử lại sau khi các index đã tạo xong.',
        503,
        'POST_DELETE_INDEX_NOT_READY'
      );
    }
    throw error;
  }
  return [
    ...snapshots.flatMap((snapshot) => snapshot.docs.map((document) => document.ref)),
    firestore.collection('adminPostSearchIndex').doc(postId)
  ];
}

async function executePermanentPostDelete(postId, payload) {
  if (cleanString(payload.confirmation) !== postId) {
    throw new AppError(
      'Mã xác nhận không khớp với bài viết.',
      400,
      'POST_DELETE_CONFIRMATION_MISMATCH'
    );
  }

  const postRef = firestore.collection(POSTS).doc(postId);
  const caseRef = firestore.collection(MODERATION_CASES).doc(postId);
  const postSnapshot = await postRef.get();
  if (!postSnapshot.exists) {
    throw new AppError('Không tìm thấy bài viết.', 404, 'POST_NOT_FOUND');
  }
  const postData = postSnapshot.data() || {};
  if (postData.deletedAt == null) {
    throw new AppError(
      'Chỉ có thể xóa vĩnh viễn bài viết đã được xóa mềm.',
      409,
      'POST_NOT_SOFT_DELETED'
    );
  }

  const references = await loadPermanentDeleteReferences(postId);
  const relatedDocumentCount = await deleteDocumentReferences(references);
  await firestore.recursiveDelete(caseRef);
  await firestore.recursiveDelete(postRef);

  return {
    actionId: null,
    caseId: caseRef.id,
    before: {
      moderationStatus: normalizeModerationStatus(postData.moderationStatus),
      visibility: normalizeVisibility(postData.visibility, postData.isPublic),
      deletedAt: toDate(postData.deletedAt)
    },
    after: { permanentlyDeleted: true },
    reportCount: references.filter((reference) => (
      reference.parent.id === POST_REPORTS
    )).length,
    deletionCounts: {
      relatedDocuments: relatedDocumentCount
    }
  };
}

async function executePostModerationAction(postId, payload, currentAdmin) {
  if (payload.action === POST_MODERATION_ACTIONS.DELETE_PERMANENTLY) {
    return executePermanentPostDelete(postId, payload);
  }

  const reportsSnapshot = await firestore
    .collection(POST_REPORTS)
    .where('postId', '==', postId)
    .get();
  const reports = reportSummary(reportsSnapshot);
  const postRef = firestore.collection(POSTS).doc(postId);
  const caseRef = firestore.collection(MODERATION_CASES).doc(postId);
  const actionRef = caseRef.collection('actions').doc();
  let result;

  await firestore.runTransaction(async (transaction) => {
    const [postSnapshot, caseSnapshot] = await Promise.all([
      transaction.get(postRef),
      transaction.get(caseRef)
    ]);
    if (!postSnapshot.exists) {
      throw new AppError('Không tìm thấy bài viết.', 404, 'POST_NOT_FOUND');
    }

    const postData = postSnapshot.data() || {};
    if (postData.deletedAt != null) {
      throw new AppError('Không thể kiểm duyệt bài viết đã bị xóa.', 409, 'POST_DELETED');
    }

    const before = {
      moderationStatus: normalizeModerationStatus(postData.moderationStatus),
      visibility: normalizeVisibility(postData.visibility, postData.isPublic),
      moderationSource: cleanString(postData.moderationSource)
    };
    const previousVisibility = resolveRestoredVisibility(postData);
    const update = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderationSource: 'admin_manual',
      adminModeration: {
        action: payload.action,
        decision: payload.action,
        reason: payload.reason,
        adminId: currentAdmin.uid,
        adminEmail: currentAdmin.email,
        previousVisibility,
        previousModerationStatus: before.moderationStatus,
        videoStorageGeneration: String(
          postData.videoModeration?.storageGeneration
            || postData.videoModeration?.processingGeneration
            || ''
        ) || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }
    };
    let caseStatus = 'resolved';
    let resolution = payload.action;

    if ([
      POST_MODERATION_ACTIONS.APPROVE,
      POST_MODERATION_ACTIONS.DISMISS,
      POST_MODERATION_ACTIONS.RESTORE
    ].includes(payload.action)) {
      update.moderationStatus = 'approved';
      update.moderationMessageVi = null;
      update.visibility = previousVisibility;
      update.isPublic = previousVisibility === 'public';
      if (payload.action === POST_MODERATION_ACTIONS.DISMISS) {
        caseStatus = 'dismissed';
        resolution = 'reports_dismissed';
      }
    } else if (payload.action === POST_MODERATION_ACTIONS.REJECT) {
      update.moderationStatus = 'rejected';
      update.moderationMessageVi = payload.reason;
      update.visibility = 'private';
      update.isPublic = false;
    } else if (payload.action === POST_MODERATION_ACTIONS.REVIEW) {
      update.moderationStatus = 'review_required';
      update.moderationMessageVi = payload.reason;
      update.visibility = 'private';
      update.isPublic = false;
      caseStatus = 'in_review';
      resolution = '';
    } else {
      throw new AppError('Hành động kiểm duyệt không được hỗ trợ.', 400, 'UNSUPPORTED_POST_ACTION');
    }

    const after = {
      moderationStatus: update.moderationStatus,
      visibility: update.visibility,
      moderationSource: update.moderationSource
    };
    const priority = calculatePriority({
      moderationStatus: update.moderationStatus,
      reportCount: reports.count,
      videoModeration: postData.videoModeration
    });
    const now = admin.firestore.FieldValue.serverTimestamp();
    const caseUpdate = {
      postId,
      authorId: cleanString(postData.authorId),
      status: caseStatus,
      priority,
      reportCount: reports.count,
      reportIds: reports.reportIds,
      categories: reports.categories,
      assignedAdminId: currentAdmin.uid,
      assignedAdminEmail: currentAdmin.email,
      resolution,
      resolutionReason: payload.reason,
      updatedAt: now,
      resolvedAt: caseStatus === 'in_review' ? null : now,
      source: reports.count > 0 ? 'community_reports' : 'content_moderation'
    };
    if (!caseSnapshot.exists) caseUpdate.createdAt = now;

    transaction.update(postRef, update);
    transaction.set(caseRef, caseUpdate, { merge: true });
    transaction.set(actionRef, {
      action: payload.action,
      reason: payload.reason,
      adminId: currentAdmin.uid,
      adminEmail: currentAdmin.email,
      before,
      after,
      reportCount: reports.count,
      createdAt: now
    });

    const authorId = cleanString(postData.authorId);
    if (payload.action === POST_MODERATION_ACTIONS.REJECT && authorId) {
      transaction.set(
        firestore.collection('users').doc(authorId).collection('notifications')
          .doc(`admin_post_moderation_${actionRef.id}`),
        {
          recipientId: authorId,
          type: 'moderation_penalty',
          title: 'Bài viết đã bị gỡ',
          body: payload.reason,
          reason: payload.reason,
          severity: 'admin_rejected',
          penalty: 0,
          postId,
          readAt: null,
          createdAt: now
        }
      );
    }

    result = {
      actionId: actionRef.id,
      caseId: caseRef.id,
      before,
      after,
      reportCount: reports.count
    };
  });

  return result;
}

module.exports = {
  getPostStatistics,
  listPosts,
  listModerationPosts,
  getPostDetail,
  executePostModerationAction,
  __test: {
    cleanString,
    safeHttpsUrl,
    toInteger,
    normalizePost,
    normalizeReport,
    normalizeModerationStatus,
    calculatePriority,
    matchesPostFilters,
    matchesPostDocumentFilters,
    resolveRestoredVisibility
  }
};
