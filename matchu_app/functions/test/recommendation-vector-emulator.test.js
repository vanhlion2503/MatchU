"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const { admin, db } = require("../src/shared/firebase");
const {
  ensurePostEmbedding,
  isPostEmbeddingCurrent,
} = require("../src/recommendation/core");
const {
  EMBEDDING_DIMENSIONS,
  EMBEDDING_MODEL,
  embeddingSignatureForPost,
} = require("../src/recommendation/embedding");
const {
  loadTrendingCandidateIds,
  loadVectorCandidateMatches,
  recommendationIndexRef,
  syncRecommendationIndexMetadata,
} = require("../src/recommendation/retrieval");

const emulatorTest = process.env.FIRESTORE_EMULATOR_HOST ? test : test.skip;

emulatorTest("embedding index supports KNN and popularity retrieval", async () => {
  const postId = `vector_emulator_${Date.now()}`;
  const vector = Array(EMBEDDING_DIMENSIONS).fill(0);
  vector[0] = 1;
  const post = {
    postId,
    authorId: "vector-test-author",
    postType: "post",
    content: "Flutter Firebase vector retrieval",
    tags: ["flutter", "firebase"],
    contentVector: vector,
    contentEmbeddingModel: EMBEDDING_MODEL,
    contentVectorDimensions: EMBEDDING_DIMENSIONS,
    visibility: "public",
    moderationStatus: "approved",
    stats: { likeCount: 8, commentCount: 2, shareCount: 1 },
    trendScore: 0,
    trendBucket: 0,
    referencePost: null,
    createdAt: admin.firestore.Timestamp.now(),
    deletedAt: null,
  };
  post.contentEmbeddingSignature = embeddingSignatureForPost(post);

  const postRef = db.collection("posts").doc(postId);
  const indexRef = recommendationIndexRef(postId);
  try {
    await postRef.set(post);
    await ensurePostEmbedding(postId, post);

    const [postSnap, indexSnap] = await Promise.all([
      postRef.get(),
      indexRef.get(),
    ]);
    assert.equal(isPostEmbeddingCurrent(postSnap.data()), true);
    assert.equal(indexSnap.exists, true);
    assert.equal(indexSnap.get("embeddingModel"), EMBEDDING_MODEL);
    assert.equal(indexSnap.get("embedding").toArray().length, EMBEDDING_DIMENSIONS);

    const matches = await loadVectorCandidateMatches(vector, { limit: 10 });
    assert.ok(matches.some((item) => item.postId === postId));
    const trendingIds = await loadTrendingCandidateIds(Date.now(), 10);
    assert.ok(trendingIds.includes(postId));
    const backfillPage = await db.collection("posts")
      .where("visibility", "==", "public")
      .where("moderationStatus", "==", "approved")
      .orderBy("createdAt", "desc")
      .orderBy(admin.firestore.FieldPath.documentId(), "desc")
      .limit(10)
      .get();
    assert.ok(backfillPage.docs.some((doc) => doc.id === postId));

    await syncRecommendationIndexMetadata(
      postId,
      { ...post, deletedAt: admin.firestore.Timestamp.now() },
      false,
      { eventVersionMillis: Date.now() + 1 }
    );
    const tombstone = await indexRef.get();
    assert.equal(tombstone.get("eligible"), false);
    assert.equal(tombstone.get("embedding"), undefined);
  } finally {
    await Promise.all([postRef.delete(), indexRef.delete()]);
  }
});

emulatorTest("media-only posts keep discovery metadata without a vector", async () => {
  const postId = `vector_empty_${Date.now()}`;
  const post = {
    postId,
    authorId: "vector-test-author",
    postType: "post",
    content: "",
    tags: [],
    visibility: "public",
    moderationStatus: "approved",
    stats: {},
    createdAt: admin.firestore.Timestamp.now(),
    deletedAt: null,
  };
  const postRef = db.collection("posts").doc(postId);
  const indexRef = recommendationIndexRef(postId);
  try {
    await postRef.set(post);
    await ensurePostEmbedding(postId, post);
    const [postSnap, indexSnap] = await Promise.all([
      postRef.get(),
      indexRef.get(),
    ]);
    assert.equal(isPostEmbeddingCurrent(postSnap.data()), true);
    assert.equal(indexSnap.exists, true);
    assert.equal(indexSnap.get("embedding"), undefined);
    assert.equal(indexSnap.get("eligible"), true);
  } finally {
    await Promise.all([postRef.delete(), indexRef.delete()]);
  }
});
