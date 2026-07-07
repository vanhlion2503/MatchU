const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const { admin, db } = require("../shared/firebase");

function cleanString(value, maxLength = 160) {
  if (typeof value !== "string") return "";
  return value.trim().replace(/\s+/g, " ").slice(0, maxLength);
}

function toSafeUid(value) {
  return typeof value === "string" ? value.trim() : "";
}

function buildActorProfile(userId, data) {
  const fullname = cleanString(data?.fullname, 80);
  const nickname = cleanString(data?.nickname, 80);
  return {
    actorId: userId,
    actorName: fullname || nickname || "Người dùng MatchU",
    actorNickname: nickname,
    actorAvatarUrl: cleanString(data?.avatarUrl, 500),
    actorIsVerified: data?.isFaceVerified === true,
  };
}

async function loadActorProfile(userId) {
  if (!userId) {
    return buildActorProfile("", null);
  }

  const snap = await db.collection("users").doc(userId).get();
  return buildActorProfile(userId, snap.exists ? snap.data() : null);
}

function postPreview(postData) {
  const content = cleanString(postData?.content, 80);
  if (content) return content;

  const media = Array.isArray(postData?.media) ? postData.media : [];
  if (media.length > 0) return "bài viết có đính kèm nội dung đa phương tiện";
  return "bài viết của bạn";
}

function notificationRef(userId, notificationId) {
  return db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .doc(notificationId);
}

async function createNotification(userId, notificationId, payload) {
  if (!userId || !notificationId) return;

  await notificationRef(userId, notificationId).set(
    {
      ...payload,
      recipientId: userId,
      readAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

const createPostLikeNotification = onDocumentCreated(
  "posts/{postId}/likes/{userId}",
  async (event) => {
    const postId = cleanString(event.params.postId, 120);
    const actorId =
      toSafeUid(event.data?.data()?.userId) || toSafeUid(event.params.userId);
    if (!postId || !actorId) return;

    const postSnap = await db.collection("posts").doc(postId).get();
    if (!postSnap.exists) return;

    const post = postSnap.data() || {};
    const recipientId = toSafeUid(post.authorId);
    if (!recipientId || recipientId === actorId) return;

    const actor = await loadActorProfile(actorId);
    await createNotification(
      recipientId,
      `post_like_${postId}_${actorId}`,
      {
        type: "post_like",
        title: `${actor.actorName} đã thích bài viết của bạn`,
        body: `Bài viết: "${postPreview(post)}"`,
        postId,
        ...actor,
      }
    );
  }
);

const createPostCommentNotification = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const postId = cleanString(event.params.postId, 120);
    const commentId = cleanString(event.params.commentId, 120);
    const comment = event.data?.data() || {};
    const actorId = toSafeUid(comment.userId);
    if (!postId || !commentId || !actorId) return;

    const postSnap = await db.collection("posts").doc(postId).get();
    if (!postSnap.exists) return;

    const post = postSnap.data() || {};
    const recipientId = toSafeUid(post.authorId);
    if (!recipientId || recipientId === actorId) return;

    const actor = await loadActorProfile(actorId);
    const commentPreview =
      cleanString(comment.content, 120) ||
      (cleanString(comment.imageUrl, 10) ? "Đã bình luận bằng hình ảnh" : "") ||
      (cleanString(comment.voiceUrl, 10) ? "Đã bình luận bằng ghi âm" : "") ||
      "Đã bình luận bài viết của bạn";

    await createNotification(
      recipientId,
      `post_comment_${postId}_${commentId}`,
      {
        type: "post_comment",
        title: `${actor.actorName} đã bình luận bài viết của bạn`,
        body: commentPreview,
        postId,
        commentId,
        ...actor,
      }
    );
  }
);

const createModerationPenaltyNotification = onDocumentCreated(
  "users/{userId}/postModerationViolations/{violationId}",
  async (event) => {
    const userId = toSafeUid(event.params.userId);
    const violationId = cleanString(event.params.violationId, 120);
    const violation = event.data?.data() || {};
    if (!userId || !violationId) return;

    const penalty = Number(violation.penalty || 0);
    const reason = cleanString(violation.reason, 280);
    const reputationBefore = Number(violation.reputationBefore);
    const reputationAfter = Number(violation.reputationAfter);
    const bodyParts = [];

    if (reason) bodyParts.push(reason);
    if (Number.isFinite(penalty) && penalty > 0) {
      bodyParts.push(`Bạn bị trừ ${penalty} điểm uy tín.`);
    } else {
      bodyParts.push("Vi phạm đã được ghi nhận để theo dõi uy tín.");
    }

    await createNotification(
      userId,
      `moderation_penalty_${violationId}`,
      {
        type: "moderation_penalty",
        title: "Cảnh báo tiêu chuẩn cộng đồng",
        body: bodyParts.join(" "),
        reason: reason || null,
        severity: cleanString(violation.severity, 40) || null,
        penalty: Number.isFinite(penalty) ? penalty : 0,
        reputationBefore: Number.isFinite(reputationBefore)
          ? reputationBefore
          : null,
        reputationAfter: Number.isFinite(reputationAfter)
          ? reputationAfter
          : null,
      }
    );
  }
);

module.exports = {
  createPostLikeNotification,
  createPostCommentNotification,
  createModerationPenaltyNotification,
};
