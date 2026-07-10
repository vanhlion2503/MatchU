const crypto = require("node:crypto");

const DEFAULT_EMBEDDING_MODEL =
  "Xenova/paraphrase-multilingual-mpnet-base-v2";
const EMBEDDING_MODEL =
  process.env.RECOMMENDATION_EMBEDDING_MODEL || DEFAULT_EMBEDDING_MODEL;
const EMBEDDING_DIMENSIONS = Number(
  process.env.RECOMMENDATION_EMBEDDING_DIMENSIONS || 768
);
if (
  !Number.isInteger(EMBEDDING_DIMENSIONS) ||
  EMBEDDING_DIMENSIONS <= 0 ||
  EMBEDDING_DIMENSIONS > 2048
) {
  throw new Error(
    "RECOMMENDATION_EMBEDDING_DIMENSIONS must be an integer from 1 to 2048."
  );
}

let extractorPromise = null;

function normalizeEmbeddingText({ content, tags }) {
  const normalizedContent =
    typeof content === "string" ? content.trim().replace(/\s+/g, " ") : "";
  const normalizedTags = Array.isArray(tags)
    ? tags
        .filter((tag) => typeof tag === "string")
        .map((tag) => tag.trim())
        .filter(Boolean)
        .join(" ")
    : "";

  return [normalizedContent, normalizedTags].filter(Boolean).join("\n# ");
}

function embeddingSignatureForText(text) {
  const normalizedText = typeof text === "string" ? text : "";
  return crypto.createHash("sha256").update(normalizedText).digest("hex");
}

function embeddingSignatureForPost(postData) {
  return embeddingSignatureForText(normalizeEmbeddingText({
    content: postData?.content,
    tags: postData?.tags,
  }));
}

async function loadExtractor() {
  if (!extractorPromise) {
    extractorPromise = (async () => {
      const { pipeline, env } = await import("@huggingface/transformers");
      env.allowLocalModels = false;
      env.allowRemoteModels = true;
      return pipeline("feature-extraction", EMBEDDING_MODEL);
    })();
  }

  return extractorPromise;
}

async function generateEmbeddingFromText(text) {
  const normalizedText =
    typeof text === "string" ? text.trim().replace(/\s+/g, " ") : "";
  if (!normalizedText) return [];

  const extractor = await loadExtractor();
  const output = await extractor(normalizedText, {
    pooling: "mean",
    normalize: true,
  });

  const vector = Array.from(output.data || [], Number);
  if (
    vector.length !== EMBEDDING_DIMENSIONS ||
    vector.some((value) => !Number.isFinite(value))
  ) {
    throw new Error(
      `Embedding model returned ${vector.length} dimensions; ` +
      `expected ${EMBEDDING_DIMENSIONS}.`
    );
  }
  return vector;
}

async function generatePostEmbedding(postData) {
  const text = normalizeEmbeddingText({
    content: postData?.content,
    tags: postData?.tags,
  });
  return generateEmbeddingFromText(text);
}

module.exports = {
  DEFAULT_EMBEDDING_MODEL,
  EMBEDDING_DIMENSIONS,
  EMBEDDING_MODEL,
  embeddingSignatureForPost,
  embeddingSignatureForText,
  generateEmbeddingFromText,
  generatePostEmbedding,
  normalizeEmbeddingText,
};
