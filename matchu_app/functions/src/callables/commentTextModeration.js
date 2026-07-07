const { GoogleGenAI, Type } = require("@google/genai");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

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

const GEMINI_MODEL = "gemini-2.5-flash";
const MAX_COMMENT_LENGTH = 300;
const KEYWORD_MIN_LENGTH = 3;
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
    source,
  };
}

function fallbackRuleCheck(content) {
  const normalizedText = normalizeText(content);
  const ruleText = normalizeRuleCheckText(content);

  if (!normalizedText) return allowedResult("fallback_rule");

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
      "Bình luận có liên kết hoặc số điện thoại có nguy cơ spam/lừa đảo",
      "moderate"
    );
  }

  return allowedResult("fallback_rule");
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
1. Hate speech or discrimination.
2. Threats, violence, or incitement.
3. Sexual or pornographic content.
4. Harassment, bullying, or targeted personal insults.
5. Self-harm encouragement.
6. Fraud, impersonation, scam, illegal content, or unsafe contact solicitation.
7. Spam or repeated low-quality promotional content.

Comment-specific context rules:
- Comments are short, conversational, reactive, and may use slang, teasing, emojis, sarcasm, or fragments.
- Do not flag normal disagreement, mild teasing between friends, casual slang, compliments, short reactions, or low-context replies.
- Mark a violation only when harmful intent is clear from the comment itself.
- Be stricter for direct attacks at a person or group, sexual solicitation, threats, grooming, scams, or doxxing.
- Do not require the tone or structure of a full post.

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

    if (shouldFastApprove(normalizedContent)) {
      return allowedResult();
    }

    const cacheKey = normalizeText(normalizedContent);
    const cached = cacheKey ? getCachedResult(cacheKey) : null;
    if (cached) return cached;

    const apiKey = (GEMINI_API_KEY.value() || "").trim();
    if (!apiKey) {
      return getFallbackResult({
        cacheKey,
        content: normalizedContent,
        request,
        error: new Error("Gemini API key is not configured."),
        logLevel: "warn",
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

      return moderationResult;
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      return getFallbackResult({
        cacheKey,
        content: normalizedContent,
        request,
        error,
        logLevel: isGeminiQuotaOrBillingError(error) ? "warn" : "error",
      });
    }
  }
);

module.exports = {
  moderateCommentText,
};
