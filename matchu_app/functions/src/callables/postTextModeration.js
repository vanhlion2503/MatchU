const { GoogleGenAI, Type } = require("@google/genai");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../shared/firebase");
const { GEMINI_API_KEY } = require("../shared/secrets");
const {
  AI_MODERATION_CACHE_MAX_ENTRIES,
  AI_MODERATION_CACHE_TTL_MS,
  DANGEROUS_KEYWORDS,
  EMOJI_ONLY_PATTERN,
  FAST_PATH_SAFE_PHRASES,
  LINK_PATTERN,
  PHONE_PATTERN,
} = require("../shared/moderationConstants");
const { REPUTATION_MAX_SCORE } = require("../../reputation/taskConfig");
const {
  clamp,
  getCurrentReputationScore,
} = require("../../reputation/types");

const GEMINI_MODEL = "gemini-2.5-flash";
const MAX_POST_CONTENT_LENGTH = 300;
const KEYWORD_MIN_LENGTH = 3;
const MIN_REPUTATION_TO_POST = 60;
const VIOLATION_LOOKBACK_MS = 24 * 60 * 60 * 1000;
const USERS_COLLECTION = db.collection("users");
const CACHE = new Map();

const VIOLATION_SEVERITIES = Object.freeze({
  minor: Object.freeze({ basePenalty: 1 }),
  moderate: Object.freeze({ basePenalty: 3 }),
  severe: Object.freeze({ basePenalty: 5 }),
  critical: Object.freeze({ basePenalty: 7 }),
});

function normalizeText(value) {
  if (typeof value !== "string") return "";
  return value.toLowerCase().trim().replace(/\s+/g, " ");
}

function normalizeFastPathText(value) {
  const normalized = normalizeText(value);
  if (!normalized) return "";
  return normalized
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeLeet(text) {
  if (typeof text !== "string") return "";
  return text
    .replace(/0/g, "o")
    .replace(/1/g, "i")
    .replace(/3/g, "e")
    .replace(/4/g, "a")
    .replace(/5/g, "s")
    .replace(/7/g, "t")
    .replace(/@/g, "a")
    .replace(/\$/g, "s")
    .replace(/!/g, "i")
    .replace(/j/g, "i");
}

function stripVietnameseDiacritics(text) {
  if (typeof text !== "string") return "";
  return text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "d");
}

function normalizeRuleCheckText(value) {
  const normalized = normalizeText(value);
  if (!normalized) {
    return { spaced: "", compact: "" };
  }

  const leetNormalized = normalizeLeet(normalized);
  const withoutDiacritics = stripVietnameseDiacritics(leetNormalized);
  const withoutNoise = withoutDiacritics.replace(
    /[^a-z0-9\u00c0-\u1ef9\s]/g,
    " "
  );
  const spaced = withoutNoise.replace(/\s+/g, " ").trim();
  const compact = withoutNoise.replace(/[^a-z0-9\u00c0-\u1ef9]/g, "");

  return { spaced, compact };
}

function isEmojiOnly(value) {
  const compact = value.replace(/\s+/g, "");
  return compact.length > 0 && EMOJI_ONLY_PATTERN.test(compact);
}

function shouldFastApprove(content) {
  const normalized = normalizeText(content);
  if (!normalized) return true;
  if (isEmojiOnly(normalized)) return true;

  const fastPathText = normalizeFastPathText(normalized);
  return fastPathText.length > 0 && FAST_PATH_SAFE_PHRASES.has(fastPathText);
}

function buildKeywordMatcher(keywords) {
  const spaced = new Set();
  const compact = new Set();

  if (!Array.isArray(keywords)) {
    return { spaced: [], compact: [] };
  }

  for (const keyword of keywords) {
    if (typeof keyword !== "string") continue;

    const normalizedKeyword = normalizeRuleCheckText(keyword);
    if (normalizedKeyword.spaced.length >= KEYWORD_MIN_LENGTH) {
      spaced.add(normalizedKeyword.spaced);
    }
    if (normalizedKeyword.compact.length >= KEYWORD_MIN_LENGTH) {
      compact.add(normalizedKeyword.compact);
    }
  }

  return {
    spaced: Array.from(spaced),
    compact: Array.from(compact),
  };
}

const DANGEROUS_KEYWORD_MATCHERS = {
  sexual: buildKeywordMatcher(DANGEROUS_KEYWORDS.sexual),
  hate_or_threat: buildKeywordMatcher(DANGEROUS_KEYWORDS.hate_or_threat),
  grooming: buildKeywordMatcher(DANGEROUS_KEYWORDS.grooming),
};

function containsKeyword(textVariants, keywordMatcher) {
  if (!textVariants || typeof textVariants !== "object") return false;
  if (!keywordMatcher || typeof keywordMatcher !== "object") return false;

  const spacedText =
    typeof textVariants.spaced === "string" ? textVariants.spaced : "";
  const compactText =
    typeof textVariants.compact === "string" ? textVariants.compact : "";

  for (const keyword of keywordMatcher.spaced || []) {
    if (typeof keyword === "string" && keyword && spacedText.includes(keyword)) {
      return true;
    }
  }

  for (const keyword of keywordMatcher.compact || []) {
    if (typeof keyword === "string" && keyword && compactText.includes(keyword)) {
      return true;
    }
  }

  return false;
}

function violationResult(reason, severity, source = "fallback_rule") {
  return {
    isViolation: true,
    reason,
    severity: normalizeViolationSeverity(severity),
    source,
  };
}

function fallbackRuleCheck(content) {
  const normalizedText = normalizeText(content);
  const ruleText = normalizeRuleCheckText(content);

  if (!normalizedText) {
    return { isViolation: false, reason: null, severity: null, source: "fallback_rule" };
  }

  if (containsKeyword(ruleText, DANGEROUS_KEYWORD_MATCHERS.sexual)) {
    return violationResult(
      "Nội dung khiêu dâm hoặc tình dục: phát hiện từ khóa nhạy cảm",
      "severe"
    );
  }

  if (containsKeyword(ruleText, DANGEROUS_KEYWORD_MATCHERS.hate_or_threat)) {
    return violationResult(
      "Đe dọa, bạo lực hoặc xúc phạm ác ý: phát hiện từ khóa nguy hiểm",
      "critical"
    );
  }

  if (containsKeyword(ruleText, DANGEROUS_KEYWORD_MATCHERS.grooming)) {
    return violationResult(
      "Nội dung không an toàn: phát hiện từ khóa nguy hiểm",
      "critical"
    );
  }

  if (LINK_PATTERN.test(normalizedText) || PHONE_PATTERN.test(normalizedText)) {
    return violationResult(
      "Thông tin sai lệch nghiêm trọng hoặc lừa đảo: phát hiện liên kết/số điện thoại",
      "severe"
    );
  }

  return { isViolation: false, reason: null, severity: null, source: "fallback_rule" };
}

function getCachedResult(key) {
  const cached = CACHE.get(key);
  if (!cached) return null;

  if (cached.expiresAt <= Date.now()) {
    CACHE.delete(key);
    return null;
  }

  return cached.result;
}

function setCachedResult(key, result) {
  CACHE.set(key, {
    result,
    expiresAt: Date.now() + AI_MODERATION_CACHE_TTL_MS,
  });

  if (CACHE.size <= AI_MODERATION_CACHE_MAX_ENTRIES) return;

  const oldestKey = CACHE.keys().next().value;
  if (oldestKey !== undefined) {
    CACHE.delete(oldestKey);
  }
}

function stripJsonFence(text) {
  return String(text || "")
    .trim()
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/i, "")
    .trim();
}

function normalizeViolationSeverity(value) {
  const severity =
    typeof value === "string" ? value.trim().toLowerCase() : "";
  if (VIOLATION_SEVERITIES[severity]) return severity;
  return "moderate";
}

function normalizeGeminiResult(raw) {
  const isViolation = raw?.isViolation === true || raw?.violation === true;
  const reason =
    typeof raw?.reason === "string" ? raw.reason.trim().slice(0, 500) : "";

  if (!isViolation) {
    return { isViolation: false, reason: null, severity: null };
  }

  return {
    isViolation: true,
    reason: reason || "Noi dung bai viet vi pham tieu chuan cong dong.",
    severity: normalizeViolationSeverity(raw?.severity),
  };
}

function parseGeminiResult(text) {
  try {
    return normalizeGeminiResult(JSON.parse(stripJsonFence(text)));
  } catch (error) {
    console.error("Post moderation JSON parse failed:", {
      error: error?.message || String(error),
      text: String(text || "").slice(0, 500),
    });
    throw new Error("Unable to parse moderation response.");
  }
}

function isGeminiQuotaOrBillingError(error) {
  const rawMessage = error?.message || String(error);
  const status = error?.status || error?.code || error?.response?.status;
  return (
    status === 429 ||
    rawMessage.includes("RESOURCE_EXHAUSTED") ||
    rawMessage.includes("prepayment credits are depleted")
  );
}

function buildPrompt(content) {
  return `You are a Vietnamese social-feed moderation system.
Analyze the following post content and decide whether it clearly violates community standards.

Content:
"""
${content}
"""

Violation criteria:
1. Hate speech or discrimination.
2. Threats, violence, or incitement.
3. Sexual or pornographic content.
4. Harassment, bullying, or targeted personal insults.
5. Self-harm encouragement.
6. Serious misinformation, fraud, impersonation, scam, illegal content.
7. Spam, repeated low-quality content, or wrong category.

Context rules:
- Distinguish malicious attacks from jokes, slang, and casual friend banter.
- Mark violation only when the intent is clear.
- Do not mark mild slang as violation when there is no attack, sexual content, or threat.

Severity:
- minor: wrong category, light spam, low-quality content.
- moderate: insults, inflammatory content, repeated spam.
- severe: harassment, light scam, harmful content.
- critical: clear fraud, impersonation, threats, illegal content.

Return only valid JSON, no markdown.
Schema: {"isViolation": boolean, "reason": string|null, "severity": "minor"|"moderate"|"severe"|"critical"|null}
If not violation: {"isViolation": false, "reason": null, "severity": null}
If violation: reason must include the violated criterion and exact quoted offending word/phrase from the content.`;
}

function buildAllowedResult(reputationScore = null) {
  return {
    isViolation: false,
    reason: null,
    severity: null,
    penalty: 0,
    reputationBefore: reputationScore,
    reputationAfter: reputationScore,
    minReputationToPost: MIN_REPUTATION_TO_POST,
  };
}

function recurrenceMultiplier(violationNumber) {
  if (violationNumber <= 2) return 1;
  if (violationNumber === 3) return 1.5;
  if (violationNumber === 4) return 2;
  return 3;
}

function calculatePenalty(severity, priorViolationCount) {
  const normalizedSeverity = normalizeViolationSeverity(severity);
  const basePenalty = VIOLATION_SEVERITIES[normalizedSeverity].basePenalty;
  const violationNumber = Math.max(1, priorViolationCount + 1);
  const multiplier = recurrenceMultiplier(violationNumber);
  const penalty =
    violationNumber === 1 ? 0 : Math.ceil(basePenalty * multiplier);

  return {
    severity: normalizedSeverity,
    basePenalty,
    violationNumber,
    multiplier,
    penalty,
  };
}

async function assertCanPost(uid) {
  const userSnap = await USERS_COLLECTION.doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }

  const reputationScore = getCurrentReputationScore(userSnap.data() || {});
  if (reputationScore < MIN_REPUTATION_TO_POST) {
    throw new HttpsError(
      "failed-precondition",
      "Reputation score is too low to create posts.",
      {
        reputationScore,
        minReputationToPost: MIN_REPUTATION_TO_POST,
      }
    );
  }

  return reputationScore;
}

async function applyPostViolationPenalty({ uid, moderationResult, content }) {
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
      contentPreview: String(content || "").slice(0, 300),
      reason: moderationResult.reason || null,
      severity: penaltyMeta.severity,
      basePenalty: penaltyMeta.basePenalty,
      multiplier: penaltyMeta.multiplier,
      penalty: penaltyMeta.penalty,
      violationNumber1d: penaltyMeta.violationNumber,
      violationNumber7d: penaltyMeta.violationNumber,
      reputationBefore,
      reputationAfter,
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
      minReputationToPost: MIN_REPUTATION_TO_POST,
    };
  });

  return penaltyResult;
}

function getFallbackResult({ cacheKey, content, request, error, logLevel }) {
  const fallbackResult = fallbackRuleCheck(content);
  if (cacheKey) {
    setCachedResult(cacheKey, fallbackResult);
  }

  const payload = {
    uid: request.auth.uid,
    error: error?.message || String(error),
    fallbackResult,
  };

  if (logLevel === "warn") {
    console.warn(
      "Gemini unavailable; used fallback post moderation rules:",
      payload
    );
  } else {
    console.error(
      "Gemini post moderation failed; used fallback rules:",
      payload
    );
  }

  return fallbackResult;
}

const moderatePostText = onCall(
  {
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 15,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const uid = request.auth.uid;
    const content =
      typeof request.data?.content === "string" ? request.data.content : "";
    const normalizedContent = content.trim();

    if (normalizedContent.length > MAX_POST_CONTENT_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        "Post content is too long."
      );
    }

    const reputationScore = await assertCanPost(uid);

    if (shouldFastApprove(normalizedContent)) {
      return buildAllowedResult(reputationScore);
    }

    const cacheKey = normalizeText(normalizedContent);
    const cached = cacheKey ? getCachedResult(cacheKey) : null;
    if (cached) {
      if (!cached.isViolation) return buildAllowedResult(reputationScore);
      return applyPostViolationPenalty({
        uid,
        moderationResult: cached,
        content: normalizedContent,
      });
    }

    const apiKey = (GEMINI_API_KEY.value() || "").trim();
    if (!apiKey) {
      const fallbackResult = getFallbackResult({
        cacheKey,
        content: normalizedContent,
        request,
        error: new Error("Gemini API key is not configured."),
        logLevel: "warn",
      });
      if (!fallbackResult.isViolation) return buildAllowedResult(reputationScore);
      return applyPostViolationPenalty({
        uid,
        moderationResult: fallbackResult,
        content: normalizedContent,
      });
    }

    try {
      const ai = new GoogleGenAI({ apiKey });
      const response = await ai.models.generateContent({
        model: GEMINI_MODEL,
        contents: buildPrompt(normalizedContent),
        config: {
          temperature: 0,
          maxOutputTokens: 256,
          responseMimeType: "application/json",
          responseSchema: {
            type: Type.OBJECT,
            properties: {
              isViolation: { type: Type.BOOLEAN },
              reason: { type: Type.STRING, nullable: true },
              severity: {
                type: Type.STRING,
                nullable: true,
                enum: ["minor", "moderate", "severe", "critical"],
              },
            },
            required: ["isViolation", "reason", "severity"],
            propertyOrdering: ["isViolation", "reason", "severity"],
          },
        },
      });

      const moderationResult = parseGeminiResult(response.text);
      if (cacheKey) {
        setCachedResult(cacheKey, moderationResult);
      }

      if (!moderationResult.isViolation) {
        return buildAllowedResult(reputationScore);
      }

      return applyPostViolationPenalty({
        uid,
        moderationResult,
        content: normalizedContent,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      const fallbackResult = getFallbackResult({
        cacheKey,
        content: normalizedContent,
        request,
        error,
        logLevel: isGeminiQuotaOrBillingError(error) ? "warn" : "error",
      });
      if (!fallbackResult.isViolation) return buildAllowedResult(reputationScore);
      return applyPostViolationPenalty({
        uid,
        moderationResult: fallbackResult,
        content: normalizedContent,
      });
    }
  }
);

module.exports = {
  moderatePostText,
  MIN_REPUTATION_TO_POST,
  calculatePenalty,
};
