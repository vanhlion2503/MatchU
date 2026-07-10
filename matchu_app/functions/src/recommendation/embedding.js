const EMBEDDING_MODEL =
  process.env.RECOMMENDATION_EMBEDDING_MODEL ||
  "Xenova/paraphrase-multilingual-mpnet-base-v2";

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

  return Array.from(output.data || [], Number);
}

async function generatePostEmbedding(postData) {
  const text = normalizeEmbeddingText({
    content: postData?.content,
    tags: postData?.tags,
  });
  return generateEmbeddingFromText(text);
}

module.exports = {
  EMBEDDING_MODEL,
  generateEmbeddingFromText,
  generatePostEmbedding,
  normalizeEmbeddingText,
};
