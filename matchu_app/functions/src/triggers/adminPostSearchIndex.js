const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { admin, db } = require("../shared/firebase");

const MAX_INDEX_TERMS = 450;
const NGRAM_LENGTH = 3;

function normalizeSearchText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function tokenize(value) {
  const normalized = normalizeSearchText(value);
  return normalized ? normalized.split(" ") : [];
}

function addTokenTerms(terms, token) {
  if (!token) return;
  terms.add(token);
  if (token.length < NGRAM_LENGTH) return;
  for (let index = 0; index <= token.length - NGRAM_LENGTH; index += 1) {
    terms.add(token.slice(index, index + NGRAM_LENGTH));
    if (terms.size >= MAX_INDEX_TERMS) return;
  }
}

function buildAdminPostSearchTerms(postId, post = {}) {
  const author = post.author && typeof post.author === "object" ? post.author : {};
  const values = [
    postId,
    post.authorId,
    author.id,
    author.name,
    author.nickname,
    post.content,
    ...(Array.isArray(post.tags) ? post.tags : []),
  ];
  const terms = new Set();
  for (const value of values) {
    for (const token of tokenize(value)) {
      addTokenTerms(terms, token);
      if (terms.size >= MAX_INDEX_TERMS) return [...terms];
    }
  }
  return [...terms];
}

const syncAdminPostSearchIndex = onDocumentWritten(
  {
    document: "posts/{postId}",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    const postId = String(event.params.postId || "").trim();
    if (!postId) return;
    const indexRef = db.collection("adminPostSearchIndex").doc(postId);
    if (!event.data?.after?.exists) {
      await indexRef.delete();
      return;
    }
    const post = event.data.after.data() || {};
    await indexRef.set({
      postId,
      searchTerms: buildAdminPostSearchTerms(postId, post),
      createdAt: post.createdAt || null,
      sourceUpdatedAt: post.updatedAt || post.createdAt || null,
      indexedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

module.exports = {
  syncAdminPostSearchIndex,
  _test: {
    buildAdminPostSearchTerms,
    normalizeSearchText,
  },
};
