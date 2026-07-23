const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../shared/firebase");

const RECENT_AUTH_WINDOW_SECONDS = 10 * 60;
const WRITE_BATCH_LIMIT = 400;

function requireRecentAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const authTime = Number(request.auth.token?.auth_time || 0);
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (!authTime || nowSeconds - authTime > RECENT_AUTH_WINDOW_SECONDS) {
    throw new HttpsError(
      "failed-precondition",
      "Recent authentication is required."
    );
  }
  return request.auth.uid;
}

async function commitUpdates(documents, dataForDocument) {
  for (let offset = 0; offset < documents.length; offset += WRITE_BATCH_LIMIT) {
    const batch = db.batch();
    const page = documents.slice(offset, offset + WRITE_BATCH_LIMIT);
    for (const document of page) {
      batch.set(document.ref, dataForDocument(document), { merge: true });
    }
    await batch.commit();
  }
}

async function markAllDevicesRevoked(uid) {
  const userRef = db.collection("users").doc(uid);
  const [devices, notificationDevices] = await Promise.all([
    userRef.collection("devices").get(),
    userRef.collection("notificationDevices").get(),
  ]);

  const now = admin.firestore.FieldValue.serverTimestamp();
  await commitUpdates(devices.docs, () => ({
    e2eeStatus: "revoked",
    revokedAt: now,
    e2eeUpdatedAt: now,
    lastActiveAt: now,
  }));
  await commitUpdates(notificationDevices.docs, () => ({
    status: "revoked",
    pushEnabled: false,
    notificationPermission: "denied",
    notificationUpdatedAt: now,
    lastActiveAt: now,
    fcmToken: admin.firestore.FieldValue.delete(),
    fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
  }));
}

const revokeAccountSessions = onCall(async (request) => {
  const uid = requireRecentAuth(request);
  await Promise.all([
    admin.auth().revokeRefreshTokens(uid),
    markAllDevicesRevoked(uid),
  ]);
  return { ok: true };
});

async function removeSocialReferences(uid) {
  const users = db.collection("users");
  const [followersSnap, followingSnap] = await Promise.all([
    users.where("followers", "array-contains", uid).get(),
    users.where("following", "array-contains", uid).get(),
  ]);
  const refs = new Map();
  for (const doc of followersSnap.docs) refs.set(doc.ref.path, doc);
  for (const doc of followingSnap.docs) refs.set(doc.ref.path, doc);

  await commitUpdates([...refs.values()], (doc) => {
    const data = doc.data() || {};
    const update = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (Array.isArray(data.followers) && data.followers.includes(uid)) {
      update.followers = admin.firestore.FieldValue.arrayRemove(uid);
    }
    if (Array.isArray(data.following) && data.following.includes(uid)) {
      update.following = admin.firestore.FieldValue.arrayRemove(uid);
    }
    return update;
  });
}

async function hidePublicContent(uid) {
  const [postsSnap, commentsSnap] = await Promise.all([
    db.collection("posts").where("authorId", "==", uid).get(),
    db.collectionGroup("comments").where("userId", "==", uid).get(),
  ]);
  const now = admin.firestore.FieldValue.serverTimestamp();

  await commitUpdates(postsSnap.docs, () => ({
    deletedAt: now,
    updatedAt: now,
    isPublic: false,
    visibility: "private",
  }));
  await commitUpdates(commentsSnap.docs, () => ({
    content: "",
    imageUrl: "",
    voiceUrl: "",
    deletedAt: now,
    deletedBy: uid,
    updatedAt: now,
  }));
}

async function deleteOwnedStorage(uid) {
  try {
    const bucket = admin.storage().bucket();
    await Promise.all([
      bucket.deleteFiles({ prefix: `avatars/${uid}/` }),
      bucket.deleteFiles({ prefix: `posts/${uid}/` }),
      bucket.deleteFiles({ prefix: `user_uploads/${uid}/` }),
    ]);
  } catch (error) {
    // Storage cleanup is best-effort. The Firestore/Auth deletion must still
    // finish so a missing legacy file cannot trap the account in deletion.
    console.warn("Account storage cleanup failed", { uid, error });
  }
}

async function deleteDocuments(documents) {
  for (let offset = 0; offset < documents.length; offset += WRITE_BATCH_LIMIT) {
    const batch = db.batch();
    for (const document of documents.slice(
      offset,
      offset + WRITE_BATCH_LIMIT
    )) {
      batch.delete(document.ref);
    }
    await batch.commit();
  }
}

async function deleteBiometricData(uid) {
  const enrollmentRef = db.collection("faceEnrollments").doc(uid);
  const collections = [
    "faceReauthSessions",
    "faceLivenessChallenges",
    "faceLivenessRateLimits",
    "faceTemplateUpdateAuthorizations",
  ];
  const snapshots = await Promise.all(
    collections.map((name) =>
      db.collection(name).where("uid", "==", uid).get()
    )
  );
  await enrollmentRef.delete();
  await deleteDocuments(snapshots.flatMap((snapshot) => snapshot.docs));
}

async function removePrivateUserData(uid) {
  const userRef = db.collection("users").doc(uid);
  await db.recursiveDelete(userRef);
  await userRef.set({
    uid,
    email: "",
    phonenumber: "",
    fullname: "Tài khoản đã xóa",
    nickname: `deleted_${uid.slice(0, 12)}`,
    avatarUrl: null,
    bio: "",
    birthday: null,
    gender: null,
    interests: [],
    location: { lat: null, lng: null },
    followers: [],
    following: [],
    activeStatus: "offline",
    accountStatus: "deleted",
    role: "user",
    isProfileCompleted: false,
    isFaceVerified: false,
    totalPosts: 0,
    totalLikes: 0,
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

const deleteAccount = onCall(
  { timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    const uid = requireRecentAuth(request);
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile was not found.");
    }

    await userRef.set(
      {
        accountStatus: "deleting",
        activeStatus: "offline",
        deletionRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await Promise.all([
      markAllDevicesRevoked(uid),
      removeSocialReferences(uid),
      hidePublicContent(uid),
      deleteOwnedStorage(uid),
      deleteBiometricData(uid),
    ]);

    await admin.auth().revokeRefreshTokens(uid);
    await admin.auth().deleteUser(uid);

    try {
      await removePrivateUserData(uid);
    } catch (error) {
      console.error("Private account data cleanup failed", { uid, error });
      // Ensure PII is overwritten even if recursive deletion encountered a
      // legacy malformed subcollection.
      await userRef.set(
        {
          email: "",
          phonenumber: "",
          fullname: "Tài khoản đã xóa",
          avatarUrl: null,
          bio: "",
          birthday: null,
          gender: null,
          interests: [],
          activeStatus: "offline",
          accountStatus: "deleted",
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    try {
      await admin.database().ref(`status/${uid}`).remove();
    } catch (error) {
      console.warn("Realtime presence cleanup failed", { uid, error });
    }

    return { ok: true };
  }
);

module.exports = {
  revokeAccountSessions,
  deleteAccount,
  __test: {
    requireRecentAuth,
  },
};
