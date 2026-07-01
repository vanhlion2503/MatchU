const vision = require("@google-cloud/vision");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const client = new vision.ImageAnnotatorClient();

const MAX_IMAGE_BASE64_LENGTH = 9 * 1024 * 1024;
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

function buildViolationResult(reason, safeSearch, labels = []) {
  return {
    isViolation: true,
    reason,
    safeSearch,
    labels,
    source: "google_cloud_vision",
  };
}

function buildAllowedResult(safeSearch, labels = []) {
  return {
    isViolation: false,
    reason: null,
    safeSearch,
    labels,
    source: "google_cloud_vision",
  };
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
    timeoutSeconds: 20,
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

    try {
      const safeSearch = await runSafeSearch(base64Image);

      if (isRejectedLikelihood(safeSearch.adult)) {
        return buildViolationResult(
          "Hình ảnh có nội dung người lớn không phù hợp.",
          safeSearch
        );
      }

      if (isRejectedLikelihood(safeSearch.violence)) {
        return buildViolationResult(
          "Hình ảnh có nội dung bạo lực không phù hợp.",
          safeSearch
        );
      }

      if (safeSearch.racy !== "VERY_LIKELY") {
        return buildAllowedResult(safeSearch);
      }

      const labels = await runLabelDetection(base64Image);
      if (hasAllowedRacyContext(labels)) {
        return buildAllowedResult(safeSearch, labels);
      }

      return buildViolationResult(
        "Hình ảnh có nội dung khiêu gợi, không phù hợp với ngữ cảnh.",
        safeSearch,
        labels
      );
    } catch (error) {
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
