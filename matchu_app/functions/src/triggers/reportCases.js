const crypto = require("crypto");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { admin, db } = require("../shared/firebase");

const REPORT_CASES = "reportCases";
const HIGH_RISK_CATEGORIES = new Set([
  "harassment",
  "inappropriate_content",
  "scam",
]);
const HIGH_RISK_MATCHING_REASONS = new Set(["phamcam", "quayroi"]);

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function cleanStringArray(value, limit = 20) {
  if (!Array.isArray(value)) return [];
  return value.map(cleanString).filter(Boolean).slice(0, limit);
}

function buildReportCaseId(type, targetId, contextId = "") {
  const identity = `${cleanString(type)}:${cleanString(targetId)}:${cleanString(contextId)}`;
  return `${cleanString(type) || "report"}_${crypto
    .createHash("sha256")
    .update(identity)
    .digest("hex")
    .slice(0, 40)}`;
}

function normalizeReport(source, reportId, data = {}) {
  const type = source === "postReports"
    ? "post"
    : source === "userProfileReports" ? "profile" : "matching";
  const reportedUid = cleanString(data.toUid);
  const postId = type === "post" ? cleanString(data.postId) : "";
  const roomId = type === "matching" ? cleanString(data.roomId) : "";
  const targetId = postId || reportedUid;
  const contextId = type === "matching" ? roomId : "";
  const reasonKey = cleanString(data.reasonKey) || cleanString(data.reason);
  const reasonTitle = cleanString(data.reasonTitle) || reasonKey;

  return {
    id: cleanString(reportId),
    source,
    type,
    targetId,
    contextId,
    reportedUid,
    reporterUid: cleanString(data.fromUid),
    postId,
    roomId,
    categoryKey: cleanString(data.categoryKey) || (type === "matching" ? reasonKey : ""),
    categoryTitle: cleanString(data.categoryTitle),
    reasonKey,
    reasonTitle,
    customReason: cleanString(data.customReason),
    description: cleanString(data.description),
    imageUrls: cleanStringArray(data.imageUrls, 3),
    postType: cleanString(data.postType),
    postContentPreview: cleanString(data.postContentPreview).slice(0, 1000),
    postMediaUrls: cleanStringArray(data.postMediaUrls, 10),
    createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
  };
}

function calculatePriority({ reportCount, categoryKey, reasonKey }) {
  if (reportCount >= 10) return "critical";
  if (
    reportCount >= 5
    || HIGH_RISK_CATEGORIES.has(categoryKey)
    || HIGH_RISK_MATCHING_REASONS.has(reasonKey)
  ) {
    return "high";
  }
  return reportCount > 0 ? "medium" : "normal";
}

function higherPriority(current, candidate) {
  const rank = { normal: 1, medium: 2, high: 3, critical: 4 };
  return (rank[current] || 0) >= (rank[candidate] || 0) ? current : candidate;
}

async function upsertReportCase(source, reportId, data) {
  const report = normalizeReport(source, reportId, data);
  if (!report.id || !report.targetId || !report.reportedUid || !report.reporterUid) {
    console.warn("Skipping malformed report projection", {
      source,
      reportId,
      targetId: report.targetId,
    });
    return null;
  }

  const caseId = buildReportCaseId(report.type, report.targetId, report.contextId);
  const caseRef = db.collection(REPORT_CASES).doc(caseId);
  const projectionRef = caseRef.collection("reports").doc(`${source}_${report.id}`);

  await db.runTransaction(async (transaction) => {
    const [caseSnapshot, projectionSnapshot] = await Promise.all([
      transaction.get(caseRef),
      transaction.get(projectionRef),
    ]);
    if (projectionSnapshot.exists) return;

    const existing = caseSnapshot.data() || {};
    const reportCount = Math.max(0, Number(existing.reportCount) || 0) + 1;
    const previousStatus = cleanString(existing.status);
    const shouldReopen = ["resolved", "dismissed"].includes(previousStatus);
    const categoryKeys = new Set(cleanStringArray(existing.categoryKeys, 30));
    if (report.categoryKey) categoryKeys.add(report.categoryKey);
    const now = admin.firestore.FieldValue.serverTimestamp();

    transaction.set(caseRef, {
      caseId,
      type: report.type,
      targetId: report.targetId,
      contextId: report.contextId || null,
      reportedUid: report.reportedUid,
      postId: report.postId || null,
      roomId: report.roomId || null,
      status: shouldReopen || !previousStatus ? "open" : previousStatus,
      priority: higherPriority(
        cleanString(existing.priority),
        calculatePriority({
          reportCount,
          categoryKey: report.categoryKey,
          reasonKey: report.reasonKey,
        }),
      ),
      reportCount,
      categoryKeys: [...categoryKeys].slice(0, 30),
      latestReportId: report.id,
      latestReportSource: source,
      latestReasonKey: report.reasonKey || null,
      latestReportAt: report.createdAt,
      assignedAdminId: shouldReopen ? null : existing.assignedAdminId || null,
      assignedAdminEmail: shouldReopen ? null : existing.assignedAdminEmail || null,
      resolution: shouldReopen ? null : existing.resolution || null,
      resolutionReason: shouldReopen ? null : existing.resolutionReason || null,
      resolvedAt: shouldReopen ? null : existing.resolvedAt || null,
      reopenedAt: shouldReopen ? now : existing.reopenedAt || null,
      createdAt: caseSnapshot.exists ? existing.createdAt || now : now,
      updatedAt: now,
    }, { merge: true });
    transaction.set(projectionRef, {
      ...report,
      caseId,
      originalPath: `${source}/${report.id}`,
      projectedAt: now,
    });
  });

  return caseId;
}

function createReportCaseTrigger(source) {
  return onDocumentCreated(
    {
      document: `${source}/{reportId}`,
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (event) => {
      await upsertReportCase(
        source,
        String(event.params.reportId || ""),
        event.data?.data() || {},
      );
    },
  );
}

const createPostReportCase = createReportCaseTrigger("postReports");
const createProfileReportCase = createReportCaseTrigger("userProfileReports");
const createMatchingReportCase = createReportCaseTrigger("userMatchingReports");

module.exports = {
  createPostReportCase,
  createProfileReportCase,
  createMatchingReportCase,
  upsertReportCase,
  _test: {
    buildReportCaseId,
    calculatePriority,
    higherPriority,
    normalizeReport,
  },
};
