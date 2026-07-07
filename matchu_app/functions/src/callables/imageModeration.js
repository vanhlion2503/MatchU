const vision = require("@google-cloud/vision");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../shared/firebase");
const { REPUTATION_MAX_SCORE } = require("../../reputation/taskConfig");
const {
  clamp,
  getCurrentReputationScore,
} = require("../../reputation/types");
const {
  MIN_REPUTATION_TO_POST,
  calculatePenalty,
} = require("./postTextModeration");

const client = new vision.ImageAnnotatorClient();

const MAX_IMAGE_BASE64_LENGTH = 9 * 1024 * 1024;
const MIN_REPUTATION_TO_MODERATE_POST_IMAGE = MIN_REPUTATION_TO_POST;
const VIOLATION_LOOKBACK_MS = 24 * 60 * 60 * 1000;
const USERS_COLLECTION = db.collection("users");
const MODERATION_CONTEXTS_WITH_PENALTY = new Set(["post", "comment"]);
const REJECT_LEVELS = new Set(["LIKELY", "VERY_LIKELY"]);
const CONTEXT_ALLOWED_LABELS = new Set([
  "beach",
  "pool",
  "swimming",
  "water",
  "sea",
  "ocean",
  "vacation",
  "coast",
  "sand",
  "resort",
  "outdoor",
]);

function normalizeLikelihood(value) {
  return typeof value === "string" && value.trim()
    ? value.trim().toUpperCase()
    : "UNKNOWN";
}

function isRejectedLikelihood(value) {
  return REJECT_LEVELS.has(normalizeLikelihood(value));
}

function normalizeLabel(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function hasAllowedRacyContext(labels) {
  if (!Array.isArray(labels)) return false;

  return labels.some((label) => {
    const normalized = normalizeLabel(label?.description || label?.name);
    if (!normalized) return false;
    if (CONTEXT_ALLOWED_LABELS.has(normalized)) return true;

    const words = normalized.split(" ");
    return words.some((word) => CONTEXT_ALLOWED_LABELS.has(word));
  });
}

function buildViolationResult(reason, severity, safeSearch, labels = []) {
  return {
    isViolation: true,
    reason,
    severity,
    safeSearch,
    labels,
    source: "google_cloud_vision",
  };
}

function buildAllowedResult(safeSearch, labels = []) {
  return {
    isViolation: false,
    reason: null,
    severity: null,
    penalty: 0,
    reputationBefore: null,
    reputationAfter: null,
    minReputationToPost: MIN_REPUTATION_TO_MODERATE_POST_IMAGE,
    safeSearch,
    labels,
    source: "google_cloud_vision",
  };
}

function shouldApplyPostPenalty(request) {
  return String(request.data?.context || "").trim().toLowerCase() === "post";
}

function moderationPenaltyContext(request) {
  const context = String(request.data?.context || "").trim().toLowerCase();
  return MODERATION_CONTEXTS_WITH_PENALTY.has(context) ? context : null;
}

async function assertCanPostImage(uid) {
  const userSnap = await USERS_COLLECTION.doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }

  const reputationScore = getCurrentReputationScore(userSnap.data() || {});
  if (reputationScore < MIN_REPUTATION_TO_MODERATE_POST_IMAGE) {
    throw new HttpsError(
      "failed-precondition",
      "Reputation score is too low to create posts.",
      {
        reputationScore,
        minReputationToPost: MIN_REPUTATION_TO_MODERATE_POST_IMAGE,
      }
    );
  }

  return reputationScore;
}

function summarizeSafeSearch(safeSearch) {
  const safe = safeSearch && typeof safeSearch === "object" ? safeSearch : {};
  return {
    adult: safe.adult || "UNKNOWN",
    violence: safe.violence || "UNKNOWN",
    racy: safe.racy || "UNKNOWN",
    spoof: safe.spoof || "UNKNOWN",
    medical: safe.medical || "UNKNOWN",
  };
}

async function applyPostImageViolationPenalty({ uid, moderationResult }) {
  const userRef = USERS_COLLECTION.doc(uid);
  const violationsRef = userRef.collection("postModerationViolations");
  const nowMs = Date.now();
  const cutoffMs = nowMs - VIOLATION_LOOKBACK_MS;
  const violationRef = violationsRef.doc();
  let penaltyResult = null;

  await db.runTransaction(async (tx) => {
    const [userSnap, recentViolationsSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(
        violationsRef
          .where("createdAtMillis", ">=", cutoffMs)
          .limit(3)
      ),
    ]);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    const reputationBefore = getCurrentReputationScore(userData);
    const penaltyMeta = calculatePenalty(
      moderationResult.severity,
      recentViolationsSnap.size
    );
    const reputationAfter = clamp(
      reputationBefore - penaltyMeta.penalty,
      0,
      REPUTATION_MAX_SCORE
    );

    tx.set(userRef, {
      reputationScore: reputationAfter,
      reputation: reputationAfter,
      postModerationViolationCount1d: penaltyMeta.violationNumber,
      postModerationViolationCount7d: penaltyMeta.violationNumber,
      lastPostViolationAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(violationRef, {
      uid,
      contentType: "image",
      reason: moderationResult.reason || null,
      severity: penaltyMeta.severity,
      basePenalty: penaltyMeta.basePenalty,
      multiplier: penaltyMeta.multiplier,
      penalty: penaltyMeta.penalty,
      violationNumber1d: penaltyMeta.violationNumber,
      violationNumber7d: penaltyMeta.violationNumber,
      reputationBefore,
      reputationAfter,
      safeSearch: summarizeSafeSearch(moderationResult.safeSearch),
      labels: Array.isArray(moderationResult.labels)
        ? moderationResult.labels.slice(0, 10)
        : [],
      createdAtMillis: nowMs,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    penaltyResult = {
      ...moderationResult,
      severity: penaltyMeta.severity,
      penalty: penaltyMeta.penalty,
      basePenalty: penaltyMeta.basePenalty,
      multiplier: penaltyMeta.multiplier,
      violationNumber1d: penaltyMeta.violationNumber,
      violationNumber7d: penaltyMeta.violationNumber,
      reputationBefore,
      reputationAfter,
      minReputationToPost: MIN_REPUTATION_TO_MODERATE_POST_IMAGE,
    };
  });

  return penaltyResult;
}

async function applyCommentImageViolationPenalty({ uid, moderationResult }) {
  const userRef = USERS_COLLECTION.doc(uid);
  const violationsRef = userRef.collection("commentModerationViolations");
  const nowMs = Date.now();
  const cutoffMs = nowMs - VIOLATION_LOOKBACK_MS;
  const violationRef = violationsRef.doc();
  let penaltyResult = null;

  await db.runTransaction(async (tx) => {
    const [userSnap, recentViolationsSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(
        violationsRef
          .where("createdAtMillis", ">=", cutoffMs)
          .limit(3)
      ),
    ]);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    const reputationBefore = getCurrentReputationScore(userData);
    const penaltyMeta = calculatePenalty(
      moderationResult.severity,
      recentViolationsSnap.size
    );
    const reputationAfter = clamp(
      reputationBefore - penaltyMeta.penalty,
      0,
      REPUTATION_MAX_SCORE
    );

    tx.set(userRef, {
      reputationScore: reputationAfter,
      reputation: reputationAfter,
      commentModerationViolationCount1d: penaltyMeta.violationNumber,
      commentModerationViolationCount7d: penaltyMeta.violationNumber,
      lastCommentViolationAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(violationRef, {
      uid,
      contentType: "image",
      reason: moderationResult.reason || null,
      severity: penaltyMeta.severity,
      basePenalty: penaltyMeta.basePenalty,
      multiplier: penaltyMeta.multiplier,
      penalty: penaltyMeta.penalty,
      violationNumber1d: penaltyMeta.violationNumber,
      violationNumber7d: penaltyMeta.violationNumber,
      reputationBefore,
      reputationAfter,
      safeSearch: summarizeSafeSearch(moderationResult.safeSearch),
      labels: Array.isArray(moderationResult.labels)
        ? moderationResult.labels.slice(0, 10)
        : [],
      createdAtMillis: nowMs,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    penaltyResult = {
      ...moderationResult,
      severity: penaltyMeta.severity,
      penalty: penaltyMeta.penalty,
      basePenalty: penaltyMeta.basePenalty,
      multiplier: penaltyMeta.multiplier,
      violationNumber1d: penaltyMeta.violationNumber,
      violationNumber7d: penaltyMeta.violationNumber,
      reputationBefore,
      reputationAfter,
    };
  });

  return penaltyResult;
}

function applyImageViolationPenalty({ uid, context, moderationResult }) {
  if (context === "post") {
    return applyPostImageViolationPenalty({ uid, moderationResult });
  }

  if (context === "comment") {
    return applyCommentImageViolationPenalty({ uid, moderationResult });
  }

  return moderationResult;
}

async function runSafeSearch(base64Image) {
  const [result] = await client.safeSearchDetection({
    image: { content: base64Image },
  });
  const annotation = result.safeSearchAnnotation || {};

  return {
    adult: normalizeLikelihood(annotation.adult),
    violence: normalizeLikelihood(annotation.violence),
    racy: normalizeLikelihood(annotation.racy),
    spoof: normalizeLikelihood(annotation.spoof),
    medical: normalizeLikelihood(annotation.medical),
  };
}

async function runLabelDetection(base64Image) {
  const [result] = await client.labelDetection({
    image: { content: base64Image },
  });
  return (result.labelAnnotations || []).map((label) => ({
    description: label.description || "",
    score: typeof label.score === "number" ? label.score : null,
  }));
}

const moderateImageContent = onCall(
  {
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const base64Image =
      typeof request.data?.base64Image === "string"
        ? request.data.base64Image.trim()
        : "";

    if (!base64Image) {
      throw new HttpsError("invalid-argument", "Image content is required.");
    }

    if (base64Image.length > MAX_IMAGE_BASE64_LENGTH) {
      throw new HttpsError("invalid-argument", "Image content is too large.");
    }

    const applyPostPenalty = shouldApplyPostPenalty(request);
    const penaltyContext = moderationPenaltyContext(request);
    if (applyPostPenalty) {
      await assertCanPostImage(request.auth.uid);
    }

    try {
      const safeSearch = await runSafeSearch(base64Image);
      let moderationResult = null;

      if (isRejectedLikelihood(safeSearch.adult)) {
        moderationResult = buildViolationResult(
          "Hình ảnh có nội dung người lớn không phù hợp.",
          "severe",
          safeSearch
        );
      } else if (isRejectedLikelihood(safeSearch.violence)) {
        moderationResult = buildViolationResult(
          "Hình ảnh có nội dung bạo lực không phù hợp.",
          "critical",
          safeSearch
        );
      } else if (safeSearch.racy !== "VERY_LIKELY") {
        return buildAllowedResult(safeSearch);
      }

      if (moderationResult) {
        if (!penaltyContext) return moderationResult;
        return applyImageViolationPenalty({
          uid: request.auth.uid,
          context: penaltyContext,
          moderationResult,
        });
      }

      const labels = await runLabelDetection(base64Image);
      if (hasAllowedRacyContext(labels)) {
        return buildAllowedResult(safeSearch, labels);
      }

      moderationResult = buildViolationResult(
        "Hình ảnh có nội dung khiêu gợi, không phù hợp với ngữ cảnh.",
        "moderate",
        safeSearch,
        labels
      );

      if (!penaltyContext) return moderationResult;
      return applyImageViolationPenalty({
        uid: request.auth.uid,
        context: penaltyContext,
        moderationResult,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      console.error("Image moderation failed:", {
        uid: request.auth.uid,
        error: error?.message || String(error),
      });
      throw new HttpsError(
        "unavailable",
        "Unable to moderate image right now."
      );
    }
  }
);

module.exports = {
  moderateImageContent,
};
