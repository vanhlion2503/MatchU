const fs = require("fs/promises");
const os = require("os");
const path = require("path");

const {
  FileState,
  GoogleGenAI,
  Type,
  createPartFromUri,
} = require("@google/genai");
const { onObjectFinalized } = require("firebase-functions/v2/storage");

const { admin, db } = require("../shared/firebase");
const { GEMINI_API_KEY } = require("../shared/secrets");
const { REPUTATION_MAX_SCORE } = require("../../reputation/taskConfig");
const {
  clamp,
  getCurrentReputationScore,
  toMillis,
} = require("../../reputation/types");

const DEFAULT_GEMINI_MODELS = Object.freeze([
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash",
  "gemini-2.0-flash-lite",
  "gemini-2.0-flash",
]);
const GEMINI_MODEL = DEFAULT_GEMINI_MODELS[0];
const MAX_VIDEO_BYTES = 150 * 1024 * 1024;
const GEMINI_FILE_WAIT_MS = 3 * 60 * 1000;
const GEMINI_FILE_POLL_MS = 3000;
const PROCESSING_LOCK_MS = 15 * 60 * 1000;
const VIOLATION_LOOKBACK_MS = 24 * 60 * 60 * 1000;
const POLICY_VERSION = "video_moderation_v1";
const DEFAULT_STORAGE_BUCKET =
  process.env.POST_VIDEO_UPLOAD_BUCKET || "matchu-5bd75.firebasestorage.app";
const STORAGE_PATH_RE = /^user_uploads\/([^/]+)\/videos\/([^/]+)\/source\.mp4$/;
const SAFE_ID_RE = /^[A-Za-z0-9_-]{1,160}$/;
const USERS_COLLECTION = db.collection("users");

const FINAL_STATUSES = new Set(["approved", "rejected", "review_required"]);
const DECISIONS = new Set(["approved", "rejected", "review_required"]);
const RISK_LEVELS = new Set(["none", "low", "medium", "high"]);
const VIOLATION_CATEGORIES = new Set([
  "sexual_content",
  "violence_gore",
  "weapon_threat",
  "hate_harassment",
  "bullying_abuse",
  "self_harm",
  "illegal_drugs",
  "scam_fraud",
  "privacy_doxxing",
  "child_safety",
  "spam_low_quality",
  "misinformation_dangerous",
]);
const PRIMARY_CATEGORIES = new Set(["none", ...VIOLATION_CATEGORIES]);

const VIDEO_MODERATION_SYSTEM_PROMPT = `Bạn là hệ thống kiểm duyệt video cho một ứng dụng mạng xã hội tiếng Việt.

Nhiệm vụ của bạn là phân tích toàn bộ video dựa trên:
- hình ảnh từng cảnh,
- hành động của người trong video,
- âm thanh/lời nói,
- chữ xuất hiện trong video,
- caption nếu được cung cấp,
- bối cảnh tổng thể.

Bạn phải đánh giá nội dung theo chính sách an toàn của ứng dụng. Không suy diễn quá mức. Nếu không chắc chắn, hãy chọn review_required thay vì rejected.

Các nhóm vi phạm cần kiểm tra:
- sexual_content
- violence_gore
- weapon_threat
- hate_harassment
- bullying_abuse
- self_harm
- illegal_drugs
- scam_fraud
- privacy_doxxing
- child_safety
- spam_low_quality
- misinformation_dangerous

Nguyên tắc:
1. Phân biệt rõ nội dung vi phạm thật với nội dung giáo dục, tin tức, tài liệu, y tế, thể thao hoặc nghệ thuật.
2. Không reject video chỉ vì có da thịt, đồ bơi, tập gym, nhảy múa, biểu diễn nghệ thuật hoặc cảnh y tế hợp pháp nếu không có yếu tố tình dục hóa/quấy rối/bạo lực nghiêm trọng.
3. Với nội dung bạo lực, hãy xem xét mức độ máu me, mục đích kích động, tính thật/giả, và bối cảnh tin tức/tài liệu.
4. Với trẻ vị thành niên, áp dụng mức bảo vệ cao nhất. Nếu có dấu hiệu khai thác hoặc tình dục hóa trẻ em, decision phải là rejected, category là child_safety, severity 5.
5. Với self_harm, nếu video hướng dẫn, khuyến khích hoặc cổ vũ tự gây hại, decision phải là rejected hoặc review_required tùy độ rõ ràng.
6. Với privacy_doxxing, nếu lộ giấy tờ, địa chỉ, số điện thoại hoặc thông tin cá nhân của người khác, cần flag.
7. Không mô tả chi tiết phản cảm hoặc nhạy cảm quá mức. Chỉ tóm tắt an toàn, đủ để hệ thống hiểu lý do.
8. Luôn trả về JSON hợp lệ, không markdown, không giải thích ngoài JSON.

Schema JSON bắt buộc:

{
  "decision": "approved | rejected | review_required",
  "confidence": 0.0,
  "overallSeverity": 0,
  "safeSummary": "Tóm tắt ngắn gọn, an toàn về nội dung video",
  "primaryViolationCategory": "none | sexual_content | violence_gore | weapon_threat | hate_harassment | bullying_abuse | self_harm | illegal_drugs | scam_fraud | privacy_doxxing | child_safety | spam_low_quality | misinformation_dangerous",
  "violations": [
    {
      "category": "sexual_content | violence_gore | weapon_threat | hate_harassment | bullying_abuse | self_harm | illegal_drugs | scam_fraud | privacy_doxxing | child_safety | spam_low_quality | misinformation_dangerous",
      "severity": 0,
      "confidence": 0.0,
      "timestamps": ["MM:SS"],
      "evidence": "Mô tả ngắn, an toàn, không quá chi tiết",
      "recommendedAction": "allow | warn | reject | human_review"
    }
  ],
  "visualFindings": [
    {
      "timestamp": "MM:SS",
      "description": "Mô tả hình ảnh an toàn",
      "risk": "none | low | medium | high"
    }
  ],
  "audioFindings": [
    {
      "timestamp": "MM:SS",
      "description": "Mô tả lời nói/âm thanh nếu có",
      "risk": "none | low | medium | high"
    }
  ],
  "textOverlayFindings": [
    {
      "timestamp": "MM:SS",
      "detectedText": "text nếu đọc được",
      "risk": "none | low | medium | high"
    }
  ],
  "needsHumanReview": false,
  "humanReviewReason": null,
  "reputationPenalty": {
    "shouldPenalize": false,
    "suggestedPoints": 0,
    "reason": "Lý do ngắn gọn"
  },
  "userMessageVi": "Thông báo ngắn bằng tiếng Việt để hiển thị cho người dùng nếu bị từ chối hoặc cần xem xét",
  "policyVersion": "video_moderation_v1"
}`;

const VIDEO_MODERATION_DECISION_GUIDANCE = `Additional decision guidance:
- The post caption is provided as context. It may already have passed text moderation before this video check.
- Other attached images, if any, are moderated separately before upload. Do not require human review only because a post has both video, text, and images.
- Return approved when the video and caption context show no clear policy risk, even if the content is ordinary, short, low-context, or visually simple.
- Use review_required only when there is a concrete uncertainty, medium/high risk signal, unclear possible violation, or explicit need for human review.
- Confidence means confidence in your decision. For clearly safe ordinary content, use 0.85 to 1.0, not 0.0.`;

const VIDEO_MODERATION_RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    decision: {
      type: Type.STRING,
      enum: ["approved", "rejected", "review_required"],
    },
    confidence: { type: Type.NUMBER },
    overallSeverity: { type: Type.INTEGER },
    safeSummary: { type: Type.STRING },
    primaryViolationCategory: {
      type: Type.STRING,
      enum: Array.from(PRIMARY_CATEGORIES),
    },
    violations: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          category: {
            type: Type.STRING,
            enum: Array.from(VIOLATION_CATEGORIES),
          },
          severity: { type: Type.INTEGER },
          confidence: { type: Type.NUMBER },
          timestamps: { type: Type.ARRAY, items: { type: Type.STRING } },
          evidence: { type: Type.STRING },
          recommendedAction: {
            type: Type.STRING,
            enum: ["allow", "warn", "reject", "human_review"],
          },
        },
        required: [
          "category",
          "severity",
          "confidence",
          "timestamps",
          "evidence",
          "recommendedAction",
        ],
      },
    },
    visualFindings: {
      type: Type.ARRAY,
      items: findingSchema("description"),
    },
    audioFindings: {
      type: Type.ARRAY,
      items: findingSchema("description"),
    },
    textOverlayFindings: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          timestamp: { type: Type.STRING },
          detectedText: { type: Type.STRING },
          risk: { type: Type.STRING, enum: Array.from(RISK_LEVELS) },
        },
        required: ["timestamp", "detectedText", "risk"],
      },
    },
    needsHumanReview: { type: Type.BOOLEAN },
    humanReviewReason: { type: Type.STRING, nullable: true },
    reputationPenalty: {
      type: Type.OBJECT,
      properties: {
        shouldPenalize: { type: Type.BOOLEAN },
        suggestedPoints: { type: Type.INTEGER },
        reason: { type: Type.STRING },
      },
      required: ["shouldPenalize", "suggestedPoints", "reason"],
    },
    userMessageVi: { type: Type.STRING },
    policyVersion: { type: Type.STRING },
  },
  required: [
    "decision",
    "confidence",
    "overallSeverity",
    "safeSummary",
    "primaryViolationCategory",
    "violations",
    "visualFindings",
    "audioFindings",
    "textOverlayFindings",
    "needsHumanReview",
    "humanReviewReason",
    "reputationPenalty",
    "userMessageVi",
    "policyVersion",
  ],
};

function findingSchema(descriptionKey) {
  return {
    type: Type.OBJECT,
    properties: {
      timestamp: { type: Type.STRING },
      [descriptionKey]: { type: Type.STRING },
      risk: { type: Type.STRING, enum: Array.from(RISK_LEVELS) },
    },
    required: ["timestamp", descriptionKey, "risk"],
  };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function clampNumber(value, min, max, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

function clampInt(value, min, max, fallback) {
  return Math.trunc(clampNumber(value, min, max, fallback));
}

function safeText(value, maxLength = 500) {
  if (typeof value !== "string") return "";
  return value.replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function safeMap(value) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value
    : {};
}

function getGeminiModelCandidates() {
  const configured = String(process.env.GEMINI_VIDEO_MODERATION_MODELS || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  const models = configured.length > 0 ? configured : DEFAULT_GEMINI_MODELS;
  return Array.from(new Set(models));
}

function errorMessage(error) {
  return error?.message || String(error || "");
}

function parseGeminiErrorPayload(error) {
  const message = errorMessage(error);
  try {
    return JSON.parse(message);
  } catch (_) {
    return null;
  }
}

function isGeminiRateLimitError(error) {
  const payload = parseGeminiErrorPayload(error);
  const status = error?.status || error?.code || payload?.error?.code;
  const text = errorMessage(error).toLowerCase();
  return (
    status === 429 ||
    payload?.error?.status === "RESOURCE_EXHAUSTED" ||
    text.includes("resource_exhausted") ||
    text.includes("quota exceeded") ||
    text.includes("rate limit")
  );
}

function isDailyGeminiQuotaError(error) {
  const text = errorMessage(error).toLowerCase();
  return (
    text.includes("requestsperday") ||
    text.includes("requests per day") ||
    text.includes("_rpd") ||
    text.includes("perday")
  );
}

function retryDelayMsFromGeminiError(error) {
  const payload = parseGeminiErrorPayload(error);
  const details = Array.isArray(payload?.error?.details)
    ? payload.error.details
    : [];
  const retryInfo = details.find((item) => item?.retryDelay);
  const match = /^(\d+(?:\.\d+)?)s$/i.exec(String(retryInfo?.retryDelay || ""));
  if (!match) return 0;
  return Math.ceil(Number(match[1]) * 1000);
}

function stripJsonFence(text) {
  return String(text || "")
    .trim()
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/i, "")
    .trim();
}

function parseStoragePath(name) {
  const match = STORAGE_PATH_RE.exec(String(name || ""));
  if (!match) return null;

  const uid = match[1].trim();
  const postId = match[2].trim();
  if (!SAFE_ID_RE.test(uid) || !SAFE_ID_RE.test(postId)) return null;

  return { uid, postId };
}

function normalizeRisk(value) {
  const normalized = safeText(value, 20).toLowerCase();
  return RISK_LEVELS.has(normalized) ? normalized : "none";
}

function normalizeRecommendedAction(value) {
  const normalized = safeText(value, 30).toLowerCase();
  if (["allow", "warn", "reject", "human_review"].includes(normalized)) {
    return normalized;
  }
  return "human_review";
}

function normalizeViolation(value) {
  const raw = safeMap(value);
  const category = safeText(raw.category, 80).toLowerCase();
  if (!VIOLATION_CATEGORIES.has(category)) return null;

  return {
    category,
    severity: clampInt(raw.severity, 0, 5, 0),
    confidence: clampNumber(raw.confidence, 0, 1, 0),
    timestamps: Array.isArray(raw.timestamps)
      ? raw.timestamps.map((item) => safeText(item, 16)).filter(Boolean).slice(0, 8)
      : [],
    evidence: safeText(raw.evidence, 300),
    recommendedAction: normalizeRecommendedAction(raw.recommendedAction),
  };
}

function normalizeFinding(value, descriptionKey) {
  const raw = safeMap(value);
  return {
    timestamp: safeText(raw.timestamp, 16),
    [descriptionKey]: safeText(raw[descriptionKey], 300),
    risk: normalizeRisk(raw.risk),
  };
}

function normalizeTextOverlayFinding(value) {
  const raw = safeMap(value);
  return {
    timestamp: safeText(raw.timestamp, 16),
    detectedText: safeText(raw.detectedText, 300),
    risk: normalizeRisk(raw.risk),
  };
}

function normalizeDecision(value) {
  const decision = safeText(value, 40).toLowerCase();
  return DECISIONS.has(decision) ? decision : "review_required";
}

function hasChildSafetyBlock(primaryCategory, violations) {
  return (
    primaryCategory === "child_safety" ||
    violations.some((item) => item.category === "child_safety")
  );
}

function hasElevatedFindingRisk(findings) {
  if (!Array.isArray(findings)) return false;
  return findings.some((item) => {
    const risk = normalizeRisk(item?.risk);
    return risk === "medium" || risk === "high";
  });
}

function hasMeaningfulModerationRisk(result) {
  return (
    result.overallSeverity >= 2 ||
    result.violations.some(
      (item) =>
        item.severity >= 2 ||
        item.recommendedAction === "reject" ||
        item.recommendedAction === "human_review"
    ) ||
    hasElevatedFindingRisk(result.visualFindings) ||
    hasElevatedFindingRisk(result.audioFindings) ||
    hasElevatedFindingRisk(result.textOverlayFindings)
  );
}

function sanitizeChildSafetyResult(result) {
  return {
    ...result,
    decision: "rejected",
    overallSeverity: 5,
    primaryViolationCategory: "child_safety",
    safeSummary:
      "Video bị chặn vì phát hiện rủi ro nghiêm trọng liên quan đến an toàn trẻ vị thành niên.",
    violations: [
      {
        category: "child_safety",
        severity: 5,
        confidence: Math.max(result.confidence, 0.8),
        timestamps: [],
        evidence: "Nội dung bị chặn vì lý do an toàn trẻ vị thành niên.",
        recommendedAction: "reject",
      },
    ],
    visualFindings: [],
    audioFindings: [],
    textOverlayFindings: [],
    needsHumanReview: false,
    humanReviewReason: null,
    userMessageVi:
      "Video vi phạm tiêu chuẩn an toàn nên bài viết đã bị từ chối.",
  };
}

function enforceDecisionRules(result) {
  let normalized = { ...result };
  const childSafetyBlock = hasChildSafetyBlock(
    normalized.primaryViolationCategory,
    normalized.violations
  );

  if (childSafetyBlock) {
    normalized = sanitizeChildSafetyResult(normalized);
  } else if (
    normalized.decision === "review_required" &&
    !hasMeaningfulModerationRisk(normalized)
  ) {
    normalized.decision = "approved";
    normalized.confidence = Math.max(normalized.confidence, 0.7);
    normalized.needsHumanReview = false;
    normalized.humanReviewReason = null;
  } else if (normalized.decision === "approved") {
    if (!hasMeaningfulModerationRisk(normalized)) {
      normalized.confidence = Math.max(normalized.confidence, 0.7);
      normalized.needsHumanReview = false;
      normalized.humanReviewReason = null;
    }
    const hasSafeApprovedResult =
      !hasMeaningfulModerationRisk(normalized) &&
      normalized.needsHumanReview !== true &&
      !normalized.humanReviewReason;
    if (hasSafeApprovedResult && normalized.confidence < 0.7) {
      normalized.confidence = 0.7;
    }
    if (!hasSafeApprovedResult && hasMeaningfulModerationRisk(normalized)) {
      normalized.overallSeverity = Math.max(normalized.overallSeverity, 2);
    }
    const hasMeaningfulRisk =
      normalized.overallSeverity >= 2 ||
      normalized.violations.some((item) => item.severity >= 2);
    if (normalized.confidence < 0.7 || hasMeaningfulRisk) {
      normalized.decision = "review_required";
      normalized.needsHumanReview = true;
      normalized.humanReviewReason =
        normalized.humanReviewReason ||
        "Gemini không đủ tự tin để tự động duyệt video.";
    }
  } else if (normalized.decision === "rejected") {
    if (normalized.overallSeverity < 4 || normalized.confidence < 0.75) {
      normalized.decision = "review_required";
      normalized.needsHumanReview = true;
      normalized.humanReviewReason =
        normalized.humanReviewReason ||
        "Có dấu hiệu rủi ro nhưng chưa đủ chắc chắn để từ chối tự động.";
    }
  } else {
    normalized.needsHumanReview = true;
  }

  const canPenalize =
    normalized.decision === "rejected" &&
    normalized.confidence >= 0.75 &&
    normalized.overallSeverity >= 4;
  const rawPenalty = safeMap(result.reputationPenalty);
  normalized.reputationPenalty = {
    shouldPenalize: canPenalize && rawPenalty.shouldPenalize !== false,
    suggestedPoints: clampInt(rawPenalty.suggestedPoints, 0, 10, 0),
    reason: safeText(rawPenalty.reason, 240),
  };

  if (normalized.decision === "approved") {
    normalized.userMessageVi = "";
  } else if (!normalized.userMessageVi) {
    normalized.userMessageVi =
      normalized.decision === "rejected"
        ? "Video vi phạm tiêu chuẩn cộng đồng nên bài viết đã bị từ chối."
        : "Video cần được xem xét thủ công trước khi hiển thị.";
  }

  return normalized;
}

function normalizeModerationResult(raw) {
  const safeRaw = safeMap(raw);
  const violations = Array.isArray(safeRaw.violations)
    ? safeRaw.violations.map(normalizeViolation).filter(Boolean).slice(0, 12)
    : [];
  const rawPrimary = safeText(safeRaw.primaryViolationCategory, 80).toLowerCase();
  const primaryViolationCategory = PRIMARY_CATEGORIES.has(rawPrimary)
    ? rawPrimary
    : violations[0]?.category || "none";

  const normalized = {
    decision: normalizeDecision(safeRaw.decision),
    confidence: clampNumber(safeRaw.confidence, 0, 1, 0),
    overallSeverity: clampInt(safeRaw.overallSeverity, 0, 5, 0),
    safeSummary: safeText(safeRaw.safeSummary, 500),
    primaryViolationCategory,
    violations,
    visualFindings: Array.isArray(safeRaw.visualFindings)
      ? safeRaw.visualFindings
          .map((item) => normalizeFinding(item, "description"))
          .slice(0, 20)
      : [],
    audioFindings: Array.isArray(safeRaw.audioFindings)
      ? safeRaw.audioFindings
          .map((item) => normalizeFinding(item, "description"))
          .slice(0, 20)
      : [],
    textOverlayFindings: Array.isArray(safeRaw.textOverlayFindings)
      ? safeRaw.textOverlayFindings.map(normalizeTextOverlayFinding).slice(0, 20)
      : [],
    needsHumanReview: safeRaw.needsHumanReview === true,
    humanReviewReason: safeText(safeRaw.humanReviewReason, 300) || null,
    reputationPenalty: safeMap(safeRaw.reputationPenalty),
    userMessageVi: safeText(safeRaw.userMessageVi, 300),
    geminiModel: safeText(safeRaw.geminiModel, 80) || null,
    policyVersion: POLICY_VERSION,
  };

  if (!normalized.safeSummary) {
    normalized.safeSummary =
      normalized.decision === "approved"
        ? "Không phát hiện vi phạm rõ ràng trong video."
        : "Video cần được hệ thống xem xét thêm.";
  }

  return enforceDecisionRules(normalized);
}

function parseGeminiResult(text) {
  try {
    return normalizeModerationResult(JSON.parse(stripJsonFence(text)));
  } catch (error) {
    console.error("Video moderation JSON parse failed:", {
      error: error?.message || String(error),
      text: String(text || "").slice(0, 500),
    });
    return buildReviewRequiredResult(
      "Không thể đọc kết quả kiểm duyệt tự động. Cần quản trị viên xem xét."
    );
  }
}

function buildReviewRequiredResult(reason) {
  return {
    decision: "review_required",
    confidence: 0,
    overallSeverity: 0,
    safeSummary: reason,
    primaryViolationCategory: "none",
    violations: [],
    visualFindings: [],
    audioFindings: [],
    textOverlayFindings: [],
    needsHumanReview: true,
    humanReviewReason: reason,
    reputationPenalty: {
      shouldPenalize: false,
      suggestedPoints: 0,
      reason: "",
    },
    userMessageVi: "Video cần được xem xét thủ công trước khi hiển thị.",
    policyVersion: POLICY_VERSION,
  };
}

function buildRejectedWithoutPenaltyResult(message) {
  return {
    decision: "rejected",
    confidence: 1,
    overallSeverity: 0,
    safeSummary: message,
    primaryViolationCategory: "none",
    violations: [],
    visualFindings: [],
    audioFindings: [],
    textOverlayFindings: [],
    needsHumanReview: false,
    humanReviewReason: null,
    reputationPenalty: {
      shouldPenalize: false,
      suggestedPoints: 0,
      reason: "",
    },
    userMessageVi: message,
    policyVersion: POLICY_VERSION,
  };
}

function requestedVisibilityOf(postData) {
  const requested = safeText(postData?.requestedVisibility, 30).toLowerCase();
  if (["public", "followers", "private"].includes(requested)) {
    return requested;
  }

  const current = safeText(postData?.visibility, 30).toLowerCase();
  if (["public", "followers", "private"].includes(current)) {
    return current;
  }

  return "public";
}

async function claimModerationRun({ object, uid, postId }) {
  const postRef = db.collection("posts").doc(postId);
  const generation = String(object.generation || "");
  const now = Date.now();
  let claimed = false;
  let postData = null;

  await db.runTransaction(async (tx) => {
    const postSnap = await tx.get(postRef);
    if (!postSnap.exists) return;

    const data = postSnap.data() || {};
    if (data.deletedAt != null) return;
    if (safeText(data.authorId, 180) !== uid) return;

    const videoModeration = safeMap(data.videoModeration);
    const currentStatus = safeText(data.moderationStatus, 40).toLowerCase();
    const processedGeneration = String(videoModeration.storageGeneration || "");
    if (FINAL_STATUSES.has(currentStatus) && processedGeneration === generation) {
      return;
    }

    const processingGeneration = String(
      videoModeration.processingGeneration || ""
    );
    const processingStartedAtMs = toMillis(videoModeration.processingStartedAt);
    if (
      processingGeneration === generation &&
      processingStartedAtMs != null &&
      now - processingStartedAtMs < PROCESSING_LOCK_MS
    ) {
      return;
    }

    postData = data;
    claimed = true;
    tx.set(
      postRef,
      {
        moderationStatus: "pending_moderation",
        moderationSource: "gemini_video",
        moderationMessageVi: null,
        moderationPolicyVersion: POLICY_VERSION,
        visibility: "private",
        isPublic: false,
        requestedVisibility: requestedVisibilityOf(data),
        videoStoragePath: object.name,
        videoModeration: {
          ...videoModeration,
          status: "processing",
          storageBucket: object.bucket || null,
          storagePath: object.name,
          storageGeneration: generation,
          processingGeneration: generation,
          contentType: object.contentType || null,
          sizeBytes: Number(object.size || 0),
          processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  return { claimed, postRef, postData };
}

function calculatePenaltyPoints(result, priorViolationCount) {
  const suggested = clampInt(result.reputationPenalty?.suggestedPoints, 0, 10, 0);
  const base =
    suggested > 0 ? suggested : result.overallSeverity >= 5 ? 7 : 5;
  const multiplier =
    priorViolationCount >= 4
      ? 3
      : priorViolationCount === 3
        ? 2
        : priorViolationCount === 2
          ? 1.5
          : 1;
  return clamp(Math.ceil(base * multiplier), 1, 15);
}

function videoViolationDocId(postId) {
  return `video_${postId.replace(/[^A-Za-z0-9_-]/g, "_")}`;
}

async function applyFinalModerationResult({ object, uid, postId, result }) {
  const postRef = db.collection("posts").doc(postId);
  const generation = String(object.generation || "");
  let applied = false;

  await db.runTransaction(async (tx) => {
    const postSnap = await tx.get(postRef);
    if (!postSnap.exists) return;

    const postData = postSnap.data() || {};
    if (safeText(postData.authorId, 180) !== uid) return;

    const previousVideoModeration = safeMap(postData.videoModeration);
    const currentGeneration = String(
      previousVideoModeration.storageGeneration ||
        previousVideoModeration.processingGeneration ||
        ""
    );
    if (currentGeneration && currentGeneration !== generation) {
      return;
    }

    let reputationPenalty = {
      ...result.reputationPenalty,
      applied: false,
      appliedPoints: 0,
      reputationBefore: null,
      reputationAfter: null,
      alreadyProcessed: false,
    };

    if (result.reputationPenalty.shouldPenalize === true) {
      const userRef = USERS_COLLECTION.doc(uid);
      const violationsRef = userRef.collection("postModerationViolations");
      const violationRef = violationsRef.doc(videoViolationDocId(postId));
      const cutoffMs = Date.now() - VIOLATION_LOOKBACK_MS;
      const [userSnap, violationSnap, recentViolationsSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(violationRef),
        tx.get(violationsRef.where("createdAtMillis", ">=", cutoffMs).limit(5)),
      ]);

      if (violationSnap.exists) {
        reputationPenalty = {
          ...reputationPenalty,
          alreadyProcessed: true,
        };
      } else if (userSnap.exists) {
        const userData = userSnap.data() || {};
        const reputationBefore = getCurrentReputationScore(userData);
        const appliedPoints = calculatePenaltyPoints(
          result,
          recentViolationsSnap.size
        );
        const reputationAfter = clamp(
          reputationBefore - appliedPoints,
          0,
          REPUTATION_MAX_SCORE
        );

        tx.set(
          userRef,
          {
            reputationScore: reputationAfter,
            reputation: reputationAfter,
            lastPostViolationAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        tx.set(violationRef, {
          uid,
          postId,
          contentType: "video",
          source: "gemini_video",
          policyVersion: POLICY_VERSION,
          reason: result.safeSummary,
          category: result.primaryViolationCategory,
          severity: result.overallSeverity,
          confidence: result.confidence,
          penalty: appliedPoints,
          reputationBefore,
          reputationAfter,
          storagePath: object.name,
          storageGeneration: generation,
          createdAtMillis: Date.now(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        reputationPenalty = {
          ...reputationPenalty,
          applied: appliedPoints > 0,
          appliedPoints,
          reputationBefore,
          reputationAfter,
        };
      }
    }

    const finalVisibility =
      result.decision === "approved" ? requestedVisibilityOf(postData) : "private";
    const videoModeration = {
      status: result.decision,
      decision: result.decision,
      confidence: result.confidence,
      overallSeverity: result.overallSeverity,
      safeSummary: result.safeSummary,
      primaryViolationCategory: result.primaryViolationCategory,
      violations: result.violations,
      visualFindings: result.visualFindings,
      audioFindings: result.audioFindings,
      textOverlayFindings: result.textOverlayFindings,
      needsHumanReview: result.needsHumanReview,
      humanReviewReason: result.humanReviewReason,
      reputationPenalty,
      userMessageVi: result.userMessageVi,
      geminiModel: result.geminiModel || null,
      policyVersion: POLICY_VERSION,
      storageBucket: object.bucket || null,
      storagePath: object.name,
      storageGeneration: generation,
      contentType: object.contentType || null,
      sizeBytes: Number(object.size || 0),
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(
      postRef,
      {
        moderationStatus: result.decision,
        moderationSource: "gemini_video",
        moderationMessageVi: result.userMessageVi || null,
        moderationPolicyVersion: POLICY_VERSION,
        visibility: finalVisibility,
        isPublic: finalVisibility === "public",
        videoStoragePath: object.name,
        videoModeration,
        videoModerationProcessedAt:
          admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    applied = true;
  });

  return applied;
}

async function waitForActiveGeminiFile(ai, fileName) {
  const deadline = Date.now() + GEMINI_FILE_WAIT_MS;
  let file = await ai.files.get({ name: fileName });

  while (Date.now() < deadline) {
    if (file.state === FileState.ACTIVE || file.state === "ACTIVE") {
      return file;
    }
    if (file.state === FileState.FAILED || file.state === "FAILED") {
      throw new Error(`Gemini file processing failed: ${file.status?.message || ""}`);
    }

    await sleep(GEMINI_FILE_POLL_MS);
    file = await ai.files.get({ name: fileName });
  }

  throw new Error("Timed out waiting for Gemini file to become ACTIVE.");
}

async function callGeminiVideoModerationModel({ ai, model, contents }) {
  const response = await ai.models.generateContent({
    model,
    contents,
    config: {
      temperature: 0,
      maxOutputTokens: 4096,
      responseMimeType: "application/json",
      responseSchema: VIDEO_MODERATION_RESPONSE_SCHEMA,
    },
  });
  const result = parseGeminiResult(response.text);
  result.geminiModel = model;
  return result;
}

async function generateVideoModerationResult({ ai, activeFile, object, caption }) {
  const contents = [
    createPartFromUri(
      activeFile.uri,
      activeFile.mimeType || object.contentType || "video/mp4"
    ),
    `${VIDEO_MODERATION_SYSTEM_PROMPT}

${VIDEO_MODERATION_DECISION_GUIDANCE}

Caption bài viết nếu có:
"""
${safeText(caption, 1000)}
"""`,
  ];
  const models = getGeminiModelCandidates();
  let lastError = null;

  for (const model of models) {
    try {
      return await callGeminiVideoModerationModel({ ai, model, contents });
    } catch (error) {
      lastError = error;
      if (!isGeminiRateLimitError(error)) {
        throw error;
      }

      const retryDelayMs = retryDelayMsFromGeminiError(error);
      const shouldRetrySameModel =
        retryDelayMs > 0 &&
        retryDelayMs <= 60000 &&
        !isDailyGeminiQuotaError(error);

      console.warn("Gemini video moderation model rate limited:", {
        model,
        retryDelayMs,
        fallbackAvailable: models.indexOf(model) < models.length - 1,
        error: errorMessage(error).slice(0, 600),
      });

      if (!shouldRetrySameModel) continue;

      await sleep(retryDelayMs);
      try {
        return await callGeminiVideoModerationModel({ ai, model, contents });
      } catch (retryError) {
        lastError = retryError;
        if (!isGeminiRateLimitError(retryError)) {
          throw retryError;
        }
        console.warn("Gemini video moderation retry was rate limited:", {
          model,
          error: errorMessage(retryError).slice(0, 600),
        });
      }
    }
  }

  throw lastError || new Error("All Gemini video moderation models failed.");
}

async function moderateVideoWithGemini({ object, localPath, caption }) {
  const apiKey = (GEMINI_API_KEY.value() || "").trim();
  if (!apiKey) {
    return buildReviewRequiredResult(
      "Gemini API key chưa được cấu hình nên cần xem xét thủ công."
    );
  }

  const ai = new GoogleGenAI({ apiKey });
  const uploadedFile = await ai.files.upload({
    file: localPath,
    config: {
      mimeType: object.contentType || "video/mp4",
      displayName: path.basename(localPath),
    },
  });
  const activeFile = await waitForActiveGeminiFile(ai, uploadedFile.name);

  try {
    return await generateVideoModerationResult({
      ai,
      activeFile,
      object,
      caption,
    });

    const response = await ai.models.generateContent({
      model: GEMINI_MODEL,
      contents: [
        createPartFromUri(
          activeFile.uri,
          activeFile.mimeType || object.contentType || "video/mp4"
        ),
        `${VIDEO_MODERATION_SYSTEM_PROMPT}

${VIDEO_MODERATION_DECISION_GUIDANCE}

Caption bài viết nếu có:
"""
${safeText(caption, 1000)}
"""`,
      ],
      config: {
        temperature: 0,
        maxOutputTokens: 4096,
        responseMimeType: "application/json",
        responseSchema: VIDEO_MODERATION_RESPONSE_SCHEMA,
      },
    });

    return parseGeminiResult(response.text);
  } finally {
    if (uploadedFile.name) {
      try {
        await ai.files.delete({ name: uploadedFile.name });
      } catch (error) {
        console.warn("Failed to delete Gemini uploaded video file:", {
          fileName: uploadedFile.name,
          error: error?.message || String(error),
        });
      }
    }
  }
}

const moderateUploadedPostVideo = onObjectFinalized(
  {
    bucket: DEFAULT_STORAGE_BUCKET,
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 540,
    memory: "1GiB",
    maxInstances: 2,
  },
  async (event) => {
    const object = event.data || {};
    const objectName = String(object.name || "");
    if (!objectName.startsWith("user_uploads/")) return;

    const parsedPath = parseStoragePath(objectName);
    if (!parsedPath) {
      console.warn("Ignored video moderation upload with invalid path:", {
        objectName,
      });
      return;
    }

    const { uid, postId } = parsedPath;
    const claim = await claimModerationRun({ object, uid, postId });
    if (!claim.claimed) return;

    const contentType = String(object.contentType || "").toLowerCase();
    const sizeBytes = Number(object.size || 0);

    if (!contentType.startsWith("video/")) {
      await applyFinalModerationResult({
        object,
        uid,
        postId,
        result: buildReviewRequiredResult(
          "Tệp tải lên không có định dạng video hợp lệ."
        ),
      });
      return;
    }

    if (!Number.isFinite(sizeBytes) || sizeBytes <= 0) {
      await applyFinalModerationResult({
        object,
        uid,
        postId,
        result: buildReviewRequiredResult(
          "Không đọc được dung lượng video. Cần xem xét thủ công."
        ),
      });
      return;
    }

    if (sizeBytes > MAX_VIDEO_BYTES) {
      await applyFinalModerationResult({
        object,
        uid,
        postId,
        result: buildRejectedWithoutPenaltyResult(
          "Video vượt quá giới hạn dung lượng cho phép nên bài viết đã bị từ chối."
        ),
      });
      return;
    }

    const bucket = admin.storage().bucket(object.bucket);
    const tempPath = path.join(
      os.tmpdir(),
      `post-video-${postId}-${object.generation || Date.now()}.mp4`
    );

    try {
      await bucket.file(objectName).download({ destination: tempPath });
      const result = await moderateVideoWithGemini({
        object,
        localPath: tempPath,
        caption: claim.postData?.content || "",
      });

      await applyFinalModerationResult({ object, uid, postId, result });
    } catch (error) {
      console.error("Video moderation failed; routing to human review:", {
        uid,
        postId,
        objectName,
        error: error?.message || String(error),
      });
      await applyFinalModerationResult({
        object,
        uid,
        postId,
        result: buildReviewRequiredResult(
          "Không thể kiểm duyệt video tự động lúc này. Cần xem xét thủ công."
        ),
      });
    } finally {
      try {
        await fs.unlink(tempPath);
      } catch (_) {}
    }
  }
);

module.exports = {
  VIDEO_MODERATION_SYSTEM_PROMPT,
  moderateUploadedPostVideo,
};
