const { GoogleGenAI, Type } = require("@google/genai");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../shared/firebase");
const {
  assertAccountFeatureAllowed,
} = require("../shared/accountAccess");
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
const { calculatePenalty } = require("./postTextModeration");
const {
  buildTextRuleModerationResult,
} = require("../shared/textModerationRules");

const GEMINI_MODEL = "gemini-2.5-flash";
const MAX_COMMENT_LENGTH = 300;
const KEYWORD_MIN_LENGTH = 3;
const VIOLATION_LOOKBACK_MS = 24 * 60 * 60 * 1000;
const USERS_COLLECTION = db.collection("users");
const CACHE = new Map();

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

  return {
    spaced: withoutNoise.replace(/\s+/g, " ").trim(),
    compact: withoutNoise.replace(/[^a-z0-9\u00c0-\u1ef9]/g, ""),
  };
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

function normalizeViolationSeverity(value) {
  const severity =
    typeof value === "string" ? value.trim().toLowerCase() : "";
  if (["minor", "moderate", "severe", "critical"].includes(severity)) {
    return severity;
  }
  return "moderate";
}

function violationResult(reason, severity, source = "fallback_rule") {
  return {
    isViolation: true,
    reason,
    severity: normalizeViolationSeverity(severity),
    source,
  };
}

function allowedResult(source = "comment_text_moderation") {
  return {
    isViolation: false,
    reason: null,
    severity: null,
    penalty: 0,
    reputationBefore: null,
    reputationAfter: null,
    source,
  };
}

function fallbackRuleCheck(content) {
  return buildTextRuleModerationResult(content, "comment");
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

function normalizeGeminiResult(raw) {
  const isViolation = raw?.isViolation === true || raw?.violation === true;
  const reason =
    typeof raw?.reason === "string" ? raw.reason.trim().slice(0, 500) : "";

  if (!isViolation) return allowedResult("gemini");

  return {
    isViolation: true,
    reason: reason || "Nội dung bình luận vi phạm tiêu chuẩn cộng đồng.",
    severity: normalizeViolationSeverity(raw?.severity),
    source: "gemini",
  };
}

function parseGeminiResult(text) {
  try {
    return normalizeGeminiResult(JSON.parse(stripJsonFence(text)));
  } catch (error) {
    console.error("Comment moderation JSON parse failed:", {
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
  return `You are a Vietnamese social-feed comment moderation system.
Analyze the following comment or reply and decide whether it clearly violates community standards.

Comment:
"""
${content}
"""

Violation criteria:
1. Hate speech or discrimination, including Vietnamese regional discrimination such as attacks on people from North/Central/South regions.
2. Threats, violence, or incitement.
3. Sexual or pornographic content.
4. Harassment, bullying, targeted personal insults, toxic profanity, or demeaning abuse.
5. Self-harm encouragement.
6. Fraud, impersonation, scam, illegal content, or unsafe contact solicitation.
7. Spam or repeated low-quality promotional content.

Comment-specific context rules:
- Comments are short, conversational, reactive, and may use slang, teasing, emojis, sarcasm, or fragments.
- Do not flag normal disagreement, mild teasing between friends, casual slang, compliments, short reactions, or low-context replies.
- Mark a violation only when harmful intent is clear from the comment itself.
- Be stricter for direct attacks at a person or group, sexual solicitation, threats, grooming, scams, or doxxing.
- Do not require the tone or structure of a full post.
- Treat obfuscated Vietnamese abuse, teencode, missing accents, and punctuation-separated insults as equivalent to the original phrase.
- Be strict with replies that insult a region, ethnicity, origin, family, appearance, intelligence, or social class.

Severity:
- minor: light spam or repeated low-quality promotion.
- moderate: targeted insults, harassment, inflammatory content, suspicious contact/link sharing.
- severe: sexual harassment, clear scam, harmful instructions.
- critical: threats, illegal content, grooming, severe hate, doxxing, self-harm encouragement.

Return only valid JSON, no markdown.
Schema: {"isViolation": boolean, "reason": string|null, "severity": "minor"|"moderate"|"severe"|"critical"|null}
If not violation: {"isViolation": false, "reason": null, "severity": null}
If violation: reason must include the violated criterion and exact quoted offending word/phrase from the comment.`;
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
      "Gemini unavailable; used fallback comment moderation rules:",
      payload
    );
  } else {
    console.error(
      "Gemini comment moderation failed; used fallback rules:",
      payload
    );
  }

  return fallbackResult;
}

async function applyCommentViolationPenalty({ uid, moderationResult, content }) {
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
      contentType: "text",
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
      source: moderationResult.source || null,
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

const moderateCommentText = onCall(
  {
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 15,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const content =
      typeof request.data?.content === "string" ? request.data.content : "";
    const normalizedContent = content.trim();

    if (normalizedContent.length > MAX_COMMENT_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        "Comment content is too long."
      );
    }

    const uid = request.auth.uid;
    await assertAccountFeatureAllowed(uid, "comments");

    if (shouldFastApprove(normalizedContent)) {
      return allowedResult();
    }

    const cacheKey = normalizeText(normalizedContent);

    // Rule-based moderation catches explicit abuse even when AI misses context.
    const ruleResult = fallbackRuleCheck(normalizedContent);
    if (ruleResult.isViolation) {
      if (cacheKey) setCachedResult(cacheKey, ruleResult);
      return applyCommentViolationPenalty({
        uid,
        moderationResult: ruleResult,
        content: normalizedContent,
      });
    }

    const cached = cacheKey ? getCachedResult(cacheKey) : null;
    if (cached) {
      if (!cached.isViolation) return cached;
      return applyCommentViolationPenalty({
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
      if (!fallbackResult.isViolation) return fallbackResult;
      return applyCommentViolationPenalty({
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

      if (!moderationResult.isViolation) return moderationResult;
      return applyCommentViolationPenalty({
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
      if (!fallbackResult.isViolation) return fallbackResult;
      return applyCommentViolationPenalty({
        uid,
        moderationResult: fallbackResult,
        content: normalizedContent,
      });
    }
  }
);

module.exports = {
  moderateCommentText,
};
