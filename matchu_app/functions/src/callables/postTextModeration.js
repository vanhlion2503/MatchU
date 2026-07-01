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
const MAX_POST_CONTENT_LENGTH = 300;
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

  const spacedKeywords = Array.isArray(keywordMatcher.spaced)
    ? keywordMatcher.spaced
    : [];
  for (const keyword of spacedKeywords) {
    if (typeof keyword !== "string" || !keyword) continue;
    if (spacedText.includes(keyword)) return true;
  }

  const compactKeywords = Array.isArray(keywordMatcher.compact)
    ? keywordMatcher.compact
    : [];
  for (const keyword of compactKeywords) {
    if (typeof keyword !== "string" || !keyword) continue;
    if (compactText.includes(keyword)) return true;
  }

  return false;
}

function fallbackRuleCheck(content) {
  const normalizedText = normalizeText(content);
  const ruleText = normalizeRuleCheckText(content);

  if (!normalizedText) {
    return { isViolation: false, reason: null, source: "fallback_rule" };
  }

  if (containsKeyword(ruleText, DANGEROUS_KEYWORD_MATCHERS.sexual)) {
    return {
      isViolation: true,
      reason: "Nội dung khiêu dâm, tình dục: phát hiện từ khóa nhạy cảm",
      source: "fallback_rule",
    };
  }

  if (containsKeyword(ruleText, DANGEROUS_KEYWORD_MATCHERS.hate_or_threat)) {
    return {
      isViolation: true,
      reason: "Đe dọa, bạo lực hoặc xúc phạm ác ý: phát hiện từ khóa nguy hiểm",
      source: "fallback_rule",
    };
  }

  if (containsKeyword(ruleText, DANGEROUS_KEYWORD_MATCHERS.grooming)) {
    return {
      isViolation: true,
      reason: "Nội dung không an toàn: phát hiện từ khóa nguy hiểm",
      source: "fallback_rule",
    };
  }

  if (LINK_PATTERN.test(normalizedText) || PHONE_PATTERN.test(normalizedText)) {
    return {
      isViolation: true,
      reason: "Thông tin sai lệch nghiêm trọng, lừa đảo: phát hiện liên kết hoặc số điện thoại",
      source: "fallback_rule",
    };
  }

  return { isViolation: false, reason: null, source: "fallback_rule" };
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

  if (!isViolation) {
    return { isViolation: false, reason: null };
  }

  return {
    isViolation: true,
    reason: reason || "Nội dung vi phạm tiêu chuẩn cộng đồng.",
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
  return `Bạn là một hệ thống kiểm duyệt nội dung mạng xã hội thông minh và thấu hiểu ngữ cảnh cho người dùng Việt Nam.
Hãy phân tích nội dung sau và đánh giá xem có thực sự vi phạm tiêu chuẩn cộng đồng không.

Nội dung cần kiểm tra:
"""
${content}
"""

Các tiêu chí vi phạm:
1. Ngôn từ thù ghét, phân biệt chủng tộc, giới tính, tôn giáo, phân biệt vùng miền
2. Đe dọa, bạo lực, kích động bạo lực có chủ đích
3. Nội dung khiêu dâm, tình dục
4. Quấy rối, bắt nạt, xúc phạm cá nhân có chủ đích tấn công ác ý
5. Tự gây hại, khuyến khích tự tử hoặc tự làm đau bản thân
6. Thông tin sai lệch nghiêm trọng, lừa đảo

QUY TẮC QUAN TRỌNG VỀ NGỮ CẢNH:
- Phải phân biệt lời chửi rủa/tấn công ác ý thật sự với lời nói đùa, slang, teencode thông thường của bạn bè.
- Chỉ đánh dấu vi phạm khi nội dung thể hiện ý định vi phạm rõ ràng theo các tiêu chí trên.
- Không đánh dấu vi phạm chỉ vì có từ lóng nhẹ nếu ngữ cảnh không tấn công, không khiêu dâm, không đe dọa.

Quy tắc trả kết quả:
- Chỉ trả về JSON hợp lệ, không markdown.
- Schema: {"isViolation": boolean, "reason": string|null}
- Nếu không vi phạm: {"isViolation": false, "reason": null}
- Nếu vi phạm: reason phải là tên tiêu chí vi phạm + trích dẫn CHÍNH XÁC từ/cụm từ vi phạm trong nội dung.
- Nếu cùng 1 tiêu chí có nhiều từ vi phạm: gộp các từ lại, phân cách bằng dấu phẩy.
- Nếu vi phạm nhiều tiêu chí khác nhau: phân cách bằng dấu "; ".
- Ví dụ reason: "Quấy rối, xúc phạm cá nhân: \\"đồ ngu\\", \\"đồ ăn hại\\"; Đe dọa, bạo lực: \\"tao giết mày\\"".`;
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
    timeoutSeconds: 10,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const content =
      typeof request.data?.content === "string" ? request.data.content : "";
    const normalizedContent = content.trim();

    if (normalizedContent.length > MAX_POST_CONTENT_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        "Post content is too long."
      );
    }

    if (shouldFastApprove(normalizedContent)) {
      return { isViolation: false, reason: null };
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
            },
            required: ["isViolation", "reason"],
            propertyOrdering: ["isViolation", "reason"],
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

      if (isGeminiQuotaOrBillingError(error)) {
        return getFallbackResult({
          cacheKey,
          content: normalizedContent,
          request,
          error,
          logLevel: "warn",
        });
      }

      return getFallbackResult({
        cacheKey,
        content: normalizedContent,
        request,
        error,
        logLevel: "error",
      });
    }
  }
);

module.exports = {
  moderatePostText,
};
