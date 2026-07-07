const {
  DANGEROUS_KEYWORDS,
  EMOJI_ONLY_PATTERN,
  FAST_PATH_SAFE_PHRASES,
  LINK_PATTERN,
  PHONE_PATTERN,
} = require("./moderationConstants");

const KEYWORD_MIN_LENGTH = 3;

function normalizeModerationText(value) {
  if (typeof value !== "string") return "";
  return value.toLowerCase().trim().replace(/\s+/g, " ");
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
  const normalized = normalizeModerationText(value);
  if (!normalized) {
    return { spaced: "", compact: "" };
  }

  const leetNormalized = normalizeLeet(normalized);
  const withoutDiacritics = stripVietnameseDiacritics(leetNormalized);
  const withoutNoise = withoutDiacritics.replace(/[^a-z0-9\s]/g, " ");

  return {
    spaced: withoutNoise.replace(/\s+/g, " ").trim(),
    compact: withoutNoise.replace(/[^a-z0-9]/g, ""),
  };
}

function normalizeFastPathText(value) {
  const normalized = normalizeModerationText(value);
  if (!normalized) return "";
  return stripVietnameseDiacritics(normalized)
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function isEmojiOnly(value) {
  if (typeof value !== "string") return false;
  const compact = value.replace(/\s+/g, "");
  return compact.length > 0 && EMOJI_ONLY_PATTERN.test(compact);
}

function shouldFastApproveWithoutAi(content) {
  const normalized = normalizeModerationText(content);
  if (!normalized) return true;
  if (isEmojiOnly(normalized)) return true;

  const fastPathText = normalizeFastPathText(normalized);
  return fastPathText.length > 0 && FAST_PATH_SAFE_PHRASES.has(fastPathText);
}

function buildKeywordMatcher(keywords) {
  const spaced = new Set();
  const compact = new Set();

  if (!Array.isArray(keywords)) return { spaced: [], compact: [] };

  for (const keyword of keywords) {
    if (typeof keyword !== "string") continue;

    const normalizedKeyword = normalizeRuleCheckText(keyword);
    if (normalizedKeyword.spaced.length >= KEYWORD_MIN_LENGTH) {
      spaced.add(normalizedKeyword.spaced);
    }

    const hasMultipleWords = normalizedKeyword.spaced.includes(" ");
    const compactMinLength = hasMultipleWords ? KEYWORD_MIN_LENGTH : 4;
    if (normalizedKeyword.compact.length >= compactMinLength) {
      compact.add(normalizedKeyword.compact);
    }
  }

  return {
    spaced: Array.from(spaced),
    compact: Array.from(compact),
  };
}

function containsKeyword(textVariants, keywordMatcher) {
  if (!textVariants || !keywordMatcher) return null;

  const spacedText =
    typeof textVariants.spaced === "string" ? textVariants.spaced : "";
  const compactText =
    typeof textVariants.compact === "string" ? textVariants.compact : "";
  const paddedSpacedText = ` ${spacedText} `;

  for (const keyword of keywordMatcher.spaced || []) {
    if (typeof keyword !== "string" || !keyword) continue;
    if (paddedSpacedText.includes(` ${keyword} `)) {
      return keyword;
    }
  }

  for (const keyword of keywordMatcher.compact || []) {
    if (typeof keyword !== "string" || !keyword) continue;
    if (compactText.includes(keyword)) {
      return keyword;
    }
  }

  return null;
}

const KEYWORD_MATCHERS = Object.freeze({
  sexual: buildKeywordMatcher(DANGEROUS_KEYWORDS.sexual),
  profanity: buildKeywordMatcher(DANGEROUS_KEYWORDS.profanity),
  harassment: buildKeywordMatcher(DANGEROUS_KEYWORDS.harassment),
  regional_discrimination: buildKeywordMatcher(
    DANGEROUS_KEYWORDS.regional_discrimination
  ),
  hate_or_threat: buildKeywordMatcher(DANGEROUS_KEYWORDS.hate_or_threat),
  grooming: buildKeywordMatcher(DANGEROUS_KEYWORDS.grooming),
});

function violationResult(reason, severity, source = "fallback_rule") {
  return {
    isViolation: true,
    reason,
    severity,
    source,
  };
}

function buildTextRuleModerationResult(content, context = "post") {
  const normalizedText = normalizeModerationText(content);
  const ruleText = normalizeRuleCheckText(content);

  if (!normalizedText) {
    return {
      isViolation: false,
      reason: null,
      severity: null,
      source: "fallback_rule",
    };
  }

  const threatKeyword = containsKeyword(ruleText, KEYWORD_MATCHERS.hate_or_threat);
  if (threatKeyword) {
    return violationResult(
      `Đe dọa, bạo lực hoặc kích động gây hại: phát hiện cụm "${threatKeyword}".`,
      "critical"
    );
  }

  const groomingKeyword = containsKeyword(ruleText, KEYWORD_MATCHERS.grooming);
  if (groomingKeyword) {
    return violationResult(
      `Nội dung không an toàn với trẻ vị thành niên: phát hiện cụm "${groomingKeyword}".`,
      "critical"
    );
  }

  const regionalKeyword = containsKeyword(
    ruleText,
    KEYWORD_MATCHERS.regional_discrimination
  );
  if (regionalKeyword) {
    return violationResult(
      `Phân biệt vùng miền hoặc công kích nhóm người: phát hiện cụm "${regionalKeyword}".`,
      "severe"
    );
  }

  const harassmentKeyword = containsKeyword(
    ruleText,
    KEYWORD_MATCHERS.harassment
  );
  if (harassmentKeyword) {
    return violationResult(
      `Quấy rối, bắt nạt hoặc công kích cá nhân: phát hiện cụm "${harassmentKeyword}".`,
      "severe"
    );
  }

  const profanityKeyword = containsKeyword(ruleText, KEYWORD_MATCHERS.profanity);
  if (profanityKeyword) {
    return violationResult(
      `Chửi bới hoặc xúc phạm độc hại: phát hiện cụm "${profanityKeyword}".`,
      context === "comment" ? "moderate" : "severe"
    );
  }

  const sexualKeyword = containsKeyword(ruleText, KEYWORD_MATCHERS.sexual);
  if (sexualKeyword) {
    return violationResult(
      `Nội dung khiêu dâm hoặc tình dục: phát hiện cụm "${sexualKeyword}".`,
      "severe"
    );
  }

  if (LINK_PATTERN.test(normalizedText) || PHONE_PATTERN.test(normalizedText)) {
    return violationResult(
      context === "comment"
        ? "Bình luận có liên kết hoặc số điện thoại có nguy cơ spam/lừa đảo."
        : "Thông tin sai lệch nghiêm trọng hoặc lừa đảo: phát hiện liên kết/số điện thoại.",
      context === "comment" ? "moderate" : "severe"
    );
  }

  return {
    isViolation: false,
    reason: null,
    severity: null,
    source: "fallback_rule",
  };
}

module.exports = {
  buildTextRuleModerationResult,
  normalizeModerationText,
  shouldFastApproveWithoutAi,
};
