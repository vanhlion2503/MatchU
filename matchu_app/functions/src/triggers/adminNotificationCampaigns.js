const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");

const REGION = "asia-southeast1";
const CAMPAIGN_COLLECTION = "notificationCampaigns";
const JOB_COLLECTION = "notificationCampaignJobs";
const USER_PAGE_SIZE = 200;
const JOB_USER_LIMIT = 50;
const LEASE_MS = 5 * 60 * 1000;
const MAINTENANCE_LIMIT = 100;
const MAX_AUTOMATIC_ATTEMPTS = 5;
const ACTIVE_CAMPAIGN_STATUSES = new Set(["preparing", "sending"]);
const TERMINAL_CAMPAIGN_STATUSES = new Set([
  "completed",
  "partial_failed",
  "failed",
  "cancelled",
]);
const INVALID_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);
const TRANSIENT_MESSAGING_CODES = new Set([
  "messaging/internal-error",
  "messaging/server-unavailable",
  "messaging/unknown-error",
  "messaging/quota-exceeded",
]);

const scheduleAdminNotificationCampaigns = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Bangkok",
    region: REGION,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const due = await db
      .collection(CAMPAIGN_COLLECTION)
      .where("status", "==", "scheduled")
      .where("delivery.scheduledAt", "<=", now)
      .limit(25)
      .get();
    if (due.empty) return;

    const batch = db.batch();
    due.docs.forEach((doc) => {
      batch.set(
        doc.ref,
        {
          status: "queued",
          queuedAt: admin.firestore.FieldValue.serverTimestamp(),
          preparationPending: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
    await batch.commit();
  }
);

const prepareAdminNotificationCampaign = onDocumentWritten(
  {
    document: `${CAMPAIGN_COLLECTION}/{campaignId}`,
    region: REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (event) => {
    const after = event.data.after;
    if (!after?.exists) return;
    const data = after.data() || {};
    if (
      !(
        data.status === "queued" ||
        (data.status === "preparing" && data.preparationPending === true)
      )
    ) {
      return;
    }

    const claim = await claimPreparationPage(after.ref);
    if (!claim) return;

    try {
      const page = await resolveAudiencePage(claim);
      const committed = await commitAudiencePage(after.ref, claim, page);
      if (committed && page.isLastPage) await maybeFinalizeCampaign(after.ref);
    } catch (error) {
      await releasePreparationClaim(after.ref, claim, error);
      throw error;
    }
  }
);

async function claimPreparationPage(campaignRef) {
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(campaignRef);
    if (!snap.exists) return null;
    const data = snap.data() || {};
    const canClaim =
      data.status === "queued" ||
      (data.status === "preparing" && data.preparationPending === true);
    if (!canClaim) return null;

    const pageNumber = toInt(data.nextPageNumber);
    const preparationAttempt = toInt(data.preparationAttempt) + 1;
    transaction.set(
      campaignRef,
      {
        status: "preparing",
        preparationPending: false,
        preparationAttempt,
        preparationLeaseExpiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + LEASE_MS
        ),
        startedAt:
          data.startedAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return {
      id: campaignRef.id,
      ...data,
      pageNumber,
      cursor: cleanString(data.audienceCursor, 256),
      preparationAttempt,
    };
  });
}

async function resolveAudiencePage(campaign) {
  const audience = campaign.audience || {};
  if (audience.type === "single_user") {
    const uid = cleanString(audience.targetUserId, 128);
    const userSnap = uid
      ? await db.collection("users").doc(uid).get()
      : null;
    return {
      userIds: userSnap?.exists ? [uid] : [],
      cursor: "",
      scannedCount: userSnap?.exists ? 1 : 0,
      isLastPage: true,
    };
  }

  let query = db
    .collection("users")
    .orderBy(admin.firestore.FieldPath.documentId())
    .limit(USER_PAGE_SIZE);
  if (campaign.cursor) query = query.startAfter(campaign.cursor);
  const snap = await query.get();
  const rules = audience.type === "segment" ? audience.rules || {} : {};
  const userIds = snap.docs
    .filter((doc) => audience.type !== "segment" || matchesUserRules(doc.data() || {}, rules))
    .map((doc) => doc.id);
  return {
    userIds,
    cursor: snap.empty ? "" : snap.docs[snap.docs.length - 1].id,
    scannedCount: snap.size,
    isLastPage: snap.size < USER_PAGE_SIZE,
  };
}

async function commitAudiencePage(campaignRef, campaign, page) {
  const jobs = chunk(page.userIds, JOB_USER_LIMIT);
  return db.runTransaction(async (transaction) => {
    const currentSnap = await transaction.get(campaignRef);
    const current = currentSnap.data() || {};
    if (
      !currentSnap.exists ||
      current.status !== "preparing" ||
      toInt(current.preparationAttempt) !== campaign.preparationAttempt ||
      current.preparationPending === true
    ) {
      return false;
    }
    jobs.forEach((userIds, offset) => {
      const jobId = `${campaign.id}_${String(campaign.pageNumber).padStart(6, "0")}_${offset}`;
      transaction.set(db.collection(JOB_COLLECTION).doc(jobId), {
        campaignId: campaign.id,
        userIds,
        status: "pending",
        attempt: 0,
        hasReported: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    transaction.update(campaignRef, {
      audienceCursor: page.cursor || admin.firestore.FieldValue.delete(),
      scannedUsers: admin.firestore.FieldValue.increment(page.scannedCount),
      totalJobs: admin.firestore.FieldValue.increment(jobs.length),
      "metrics.targetUsers": admin.firestore.FieldValue.increment(page.userIds.length),
      nextPageNumber: campaign.pageNumber + 1,
      preparationAttempt: 0,
      preparationPending: !page.isLastPage,
      preparationLeaseExpiresAt: admin.firestore.FieldValue.delete(),
      materializationComplete: page.isLastPage,
      status: page.isLastPage ? "sending" : "preparing",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });
}

async function releasePreparationClaim(campaignRef, claim, error) {
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(campaignRef);
    if (!snap.exists) return;
    const data = snap.data() || {};
    if (data.status !== "preparing" || data.preparationPending === true) return;
    const exhausted = claim.preparationAttempt >= MAX_AUTOMATIC_ATTEMPTS;
    transaction.set(
      campaignRef,
      {
        status: exhausted ? "failed" : "preparing",
        preparationPending: !exhausted,
        preparationLeaseExpiresAt: admin.firestore.FieldValue.delete(),
        lastError: cleanString(error?.code || error?.message, 200) || "preparation_failed",
        ...(exhausted
          ? { completedAt: admin.firestore.FieldValue.serverTimestamp() }
          : {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

const dispatchAdminNotificationJob = onDocumentWritten(
  {
    document: `${JOB_COLLECTION}/{jobId}`,
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (event) => {
    const after = event.data.after;
    if (!after?.exists || after.data()?.status !== "pending") return;
    const claim = await claimJob(after.ref);
    if (!claim) return;

    const campaignRef = db.collection(CAMPAIGN_COLLECTION).doc(claim.campaignId);
    const campaignSnap = await campaignRef.get();
    if (!campaignSnap.exists) {
      await markJobCancelled(after.ref, "campaign_not_found");
      return;
    }
    const campaign = { id: campaignSnap.id, ...(campaignSnap.data() || {}) };
    if (!ACTIVE_CAMPAIGN_STATUSES.has(campaign.status)) {
      await markJobCancelled(after.ref, `campaign_${campaign.status || "inactive"}`);
      return;
    }

    try {
      const result = await processNotificationJob(claim, campaign);
      await finalizeJob(after.ref, campaignRef, claim, result);
      await maybeFinalizeCampaign(campaignRef);
    } catch (error) {
      if (claim.attempt >= MAX_AUTOMATIC_ATTEMPTS) {
        await permanentlyFailJob(after.ref, campaignRef, claim, error);
        await maybeFinalizeCampaign(campaignRef);
      } else {
        await releaseJobClaim(after.ref, claim, error);
      }
      throw error;
    }
  }
);

async function claimJob(jobRef) {
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(jobRef);
    if (!snap.exists) return null;
    const data = snap.data() || {};
    if (data.status !== "pending") return null;
    transaction.set(
      jobRef,
      {
        status: "sending",
        attempt: toInt(data.attempt) + 1,
        leaseExpiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + LEASE_MS),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return {
      id: jobRef.id,
      ...data,
      attempt: toInt(data.attempt) + 1,
      aggregateMetrics: normalizeMetrics(data.aggregateMetrics),
      retryTargets: Array.isArray(data.retryTargets) ? data.retryTargets : [],
    };
  });
}

async function processNotificationJob(job, campaign) {
  if (job.retryTargets.length > 0) {
    return processRetryTargets(job, campaign);
  }

  const metrics = normalizeMetrics(job.aggregateMetrics);
  const outbound = [];
  const channels = new Set(Array.isArray(campaign.channels) ? campaign.channels : []);

  for (const userId of job.userIds || []) {
    const userRef = db.collection("users").doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      metrics.skippedUsers += 1;
      continue;
    }

    const rules = campaign.audience?.rules || {};
    const hasDeviceSegment = hasDeviceRules(rules);
    const devices = channels.has("push") || hasDeviceSegment
      ? await loadUserDevices(userRef)
      : [];
    const segmentDevices = devices.filter((device) =>
      matchesDeviceRules(device.data, rules)
    );
    const pushDevices = segmentDevices.filter((device) =>
      isDeliverableDevice(device.data)
    );
    const matchesDeviceSegment = !hasDeviceSegment || segmentDevices.length > 0;
    const hasDeliveryTarget =
      channels.has("inbox") || (channels.has("push") && pushDevices.length > 0);
    const isEligible = matchesDeviceSegment && hasDeliveryTarget;
    if (!isEligible) {
      metrics.skippedUsers += 1;
      continue;
    }
    metrics.eligibleUsers += 1;

    if (channels.has("inbox")) {
      const created = await writeCampaignInbox(userRef, campaign);
      if (created) metrics.inboxCreated += 1;
    }
    if (channels.has("push")) {
      pushDevices.forEach((device) => {
        outbound.push({
          userId,
          deviceId: device.id,
          collection: device.collection,
          docRef: device.ref,
          token: device.token,
          message: buildCampaignMessage(campaign, device.token),
        });
      });
    }
  }

  const delivery = await sendOutbound(outbound);
  metrics.attemptedDevices += outbound.length;
  metrics.acceptedDevices += delivery.accepted;
  metrics.failedDevices += delivery.failed;
  metrics.invalidTokens += delivery.invalid;
  await cleanupInvalidTokens(delivery.invalidEntries);
  return { metrics, retryTargets: delivery.retryTargets };
}

async function processRetryTargets(job, campaign) {
  const metrics = normalizeMetrics(job.aggregateMetrics);
  const outbound = [];
  for (const target of job.retryTargets) {
    const ref = db
      .collection("users")
      .doc(cleanString(target.userId, 128))
      .collection(
        target.collection === "devices" ? "devices" : "notificationDevices"
      )
      .doc(cleanString(target.deviceId, 128));
    const snap = await ref.get();
    const data = snap.data() || {};
    if (!snap.exists || !isDeliverableDevice(data)) continue;
    const token = cleanString(data.fcmToken, 4096);
    if (!token) continue;
    outbound.push({
      userId: target.userId,
      deviceId: target.deviceId,
      collection:
        target.collection === "devices" ? "devices" : "notificationDevices",
      docRef: ref,
      token,
      message: buildCampaignMessage(campaign, token),
    });
  }

  const previousRetryCount = job.retryTargets.length;
  metrics.failedDevices = Math.max(0, metrics.failedDevices - previousRetryCount);
  const delivery = await sendOutbound(outbound);
  const disappearedCount = previousRetryCount - outbound.length;
  metrics.attemptedDevices += outbound.length;
  metrics.acceptedDevices += delivery.accepted;
  metrics.failedDevices += delivery.failed;
  metrics.invalidTokens += delivery.invalid + disappearedCount;
  await cleanupInvalidTokens(delivery.invalidEntries);
  return { metrics, retryTargets: delivery.retryTargets };
}

async function loadUserDevices(userRef) {
  let snap = await userRef.collection("notificationDevices").get();
  if (snap.empty) snap = await userRef.collection("devices").get();
  return snap.docs
    .map((doc) => {
      const data = doc.data() || {};
      return {
        id: doc.id,
        ref: doc.ref,
        collection: doc.ref.parent.id,
        data,
        token: cleanString(data.fcmToken, 4096),
      };
    })
    .filter((item) => !["revoked", "stale"].includes(
      cleanString(item.data.status || item.data.e2eeStatus, 40)
    ));
}

function isDeliverableDevice(device) {
  const status = cleanString(device.status || device.e2eeStatus, 40);
  return (
    !["inactive", "revoked", "stale"].includes(status) &&
    device.pushEnabled === true &&
    cleanString(device.fcmToken, 4096).length > 0
  );
}

async function writeCampaignInbox(userRef, campaign) {
  const ref = userRef.collection("notifications").doc(`campaign_${campaign.id}`);
  const snap = await ref.get();
  if (snap.exists) return false;
  await ref.set({
    recipientId: userRef.id,
    campaignId: campaign.id,
    type: inboxTypeForCategory(campaign.category),
    category: cleanString(campaign.category, 40),
    title: cleanString(campaign.title, 120),
    body: cleanString(campaign.body, 500),
    actionType: cleanString(campaign.action?.type, 40) || "inbox",
    actionValue: cleanString(campaign.action?.value, 500),
    readAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return true;
}

function inboxTypeForCategory(category) {
  return {
    maintenance: "maintenance",
    app_update: "app_update",
    policy_update: "policy_update",
  }[category] || "system_announcement";
}

function buildCampaignMessage(campaign, token) {
  const title = cleanString(campaign.title, 120);
  const body = cleanString(campaign.body, 500);
  const category = cleanString(campaign.category, 40) || "general";
  const campaignId = cleanString(campaign.id, 128);
  const data = {
    type: "admin_campaign",
    campaignId,
    category,
    title,
    body,
    actionType: cleanString(campaign.action?.type, 40) || "inbox",
    actionValue: cleanString(campaign.action?.value, 500),
    deliveryMode: "push",
  };
  return {
    token,
    notification: { title, body },
    data,
    android: {
      priority: category === "general" ? "normal" : "high",
      collapseKey: `campaign_${campaignId}`,
      notification: {
        channelId: "system_announcements",
        tag: `campaign_${campaignId}`,
        sound: "default",
      },
    },
    apns: {
      headers: {
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-collapse-id": `campaign_${campaignId}`.slice(0, 64),
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: "default",
          "thread-id": `campaign_${campaignId}`,
        },
      },
    },
  };
}

async function sendOutbound(outbound) {
  const settled = [];
  for (const entries of chunk(outbound, 100)) {
    const results = await Promise.allSettled(
      entries.map((entry) => admin.messaging().send(entry.message))
    );
    results.forEach((result, index) => settled.push({ result, entry: entries[index] }));
  }

  const retryTargets = [];
  const invalidEntries = [];
  let accepted = 0;
  let failed = 0;
  let invalid = 0;
  settled.forEach(({ result, entry }) => {
    if (result.status === "fulfilled") {
      accepted += 1;
      return;
    }
    failed += 1;
    const code = messagingErrorCode(result.reason);
    if (INVALID_TOKEN_CODES.has(code)) {
      invalid += 1;
      invalidEntries.push(entry);
    } else if (TRANSIENT_MESSAGING_CODES.has(code)) {
      retryTargets.push({
        userId: entry.userId,
        deviceId: entry.deviceId,
        collection: entry.collection,
      });
    }
  });
  return { accepted, failed, invalid, retryTargets, invalidEntries };
}

async function cleanupInvalidTokens(entries) {
  if (entries.length === 0) return;
  for (const group of chunk(entries, 400)) {
    const batch = db.batch();
    group.forEach((entry) => {
      batch.set(
        entry.docRef,
        {
          fcmToken: admin.firestore.FieldValue.delete(),
          fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
          pushEnabled: false,
          notificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
    await batch.commit();
  }
}

async function finalizeJob(jobRef, campaignRef, claim, result) {
  await db.runTransaction(async (transaction) => {
    const [jobSnap, campaignSnap] = await Promise.all([
      transaction.get(jobRef),
      transaction.get(campaignRef),
    ]);
    if (!jobSnap.exists || !campaignSnap.exists) return;
    const job = jobSnap.data() || {};
    if (job.status !== "sending" || toInt(job.attempt) !== claim.attempt) return;

    const previousMetrics = normalizeMetrics(job.aggregateMetrics);
    const nextMetrics = normalizeMetrics(result.metrics);
    const nextStatus = result.retryTargets.length > 0 ? "failed" : "completed";
    const previouslyReported = job.hasReported === true;
    const previousFailed = job.reportedStatus === "failed" ? 1 : 0;
    const nextFailed = nextStatus === "failed" ? 1 : 0;
    const metricUpdate = {};
    Object.keys(nextMetrics).forEach((key) => {
      const delta = nextMetrics[key] - previousMetrics[key];
      if (delta !== 0) {
        metricUpdate[`metrics.${key}`] = admin.firestore.FieldValue.increment(delta);
      }
    });

    transaction.set(
      jobRef,
      {
        status: nextStatus,
        aggregateMetrics: nextMetrics,
        retryTargets: result.retryTargets,
        hasReported: true,
        reportedStatus: nextStatus,
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    transaction.update(
      campaignRef,
      {
        ...metricUpdate,
        completedJobs: admin.firestore.FieldValue.increment(previouslyReported ? 0 : 1),
        failedJobs: admin.firestore.FieldValue.increment(nextFailed - previousFailed),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    );
  });
}

async function maybeFinalizeCampaign(campaignRef) {
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(campaignRef);
    if (!snap.exists) return;
    const data = snap.data() || {};
    if (
      TERMINAL_CAMPAIGN_STATUSES.has(data.status) ||
      data.materializationComplete !== true ||
      toInt(data.completedJobs) < toInt(data.totalJobs)
    ) {
      return;
    }
    const metrics = normalizeMetrics(data.metrics);
    let status = "completed";
    if (metrics.failedDevices > 0 || toInt(data.failedJobs) > 0) {
      status =
        metrics.acceptedDevices === 0 && metrics.inboxCreated === 0
          ? "failed"
          : "partial_failed";
    }
    transaction.set(
      campaignRef,
      {
        status,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

async function releaseJobClaim(jobRef, claim, error) {
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(jobRef);
    if (!snap.exists) return;
    const data = snap.data() || {};
    if (data.status !== "sending" || toInt(data.attempt) !== claim.attempt) return;
    transaction.set(
      jobRef,
      {
        status: "pending",
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
        lastError: cleanString(error?.code || error?.message, 200) || "job_failed",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

async function permanentlyFailJob(jobRef, campaignRef, claim, error) {
  await db.runTransaction(async (transaction) => {
    const [jobSnap, campaignSnap] = await Promise.all([
      transaction.get(jobRef),
      transaction.get(campaignRef),
    ]);
    if (!jobSnap.exists || !campaignSnap.exists) return;
    const job = jobSnap.data() || {};
    if (job.status !== "sending" || toInt(job.attempt) !== claim.attempt) return;
    const previouslyReported = job.hasReported === true;
    const previousFailed = job.reportedStatus === "failed" ? 1 : 0;
    transaction.set(
      jobRef,
      {
        status: "failed",
        hasReported: true,
        reportedStatus: "failed",
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
        lastError: cleanString(error?.code || error?.message, 200) || "job_failed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    transaction.update(campaignRef, {
      completedJobs: admin.firestore.FieldValue.increment(previouslyReported ? 0 : 1),
      failedJobs: admin.firestore.FieldValue.increment(1 - previousFailed),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function markJobCancelled(jobRef, reason) {
  await jobRef.set(
    {
      status: "cancelled",
      cancelReason: reason,
      leaseExpiresAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

const maintainAdminNotificationCampaigns = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Asia/Bangkok",
    region: REGION,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const [expiredJobs, expiredCampaigns] = await Promise.all([
      db
        .collection(JOB_COLLECTION)
        .where("status", "==", "sending")
        .where("leaseExpiresAt", "<=", now)
        .limit(MAINTENANCE_LIMIT)
        .get(),
      db
        .collection(CAMPAIGN_COLLECTION)
        .where("status", "==", "preparing")
        .where("preparationLeaseExpiresAt", "<=", now)
        .limit(MAINTENANCE_LIMIT)
        .get(),
    ]);
    const batch = db.batch();
    expiredJobs.docs.forEach((doc) => {
      batch.set(
        doc.ref,
        {
          status: "pending",
          leaseExpiresAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
    expiredCampaigns.docs.forEach((doc) => {
      batch.set(
        doc.ref,
        {
          preparationPending: true,
          preparationLeaseExpiresAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
    if (!expiredJobs.empty || !expiredCampaigns.empty) await batch.commit();
  }
);

function matchesUserRules(user, rules) {
  const accountStatuses = stringArray(rules.accountStatuses);
  if (
    accountStatuses.length > 0 &&
    !accountStatuses.includes(cleanString(user.accountStatus, 40) || "active")
  ) return false;

  const genders = stringArray(rules.genders);
  if (genders.length > 0 && !genders.includes(cleanString(user.gender, 40))) {
    return false;
  }

  if (rules.verification === "face_verified" && user.isFaceVerified !== true) return false;
  if (rules.verification === "face_unverified" && user.isFaceVerified === true) return false;
  if (rules.verification === "profile_completed" && user.isProfileCompleted !== true) return false;
  if (rules.verification === "profile_incomplete" && user.isProfileCompleted === true) return false;

  const reputation = toInt(user.reputationScore, 100);
  if (rules.minReputation != null && reputation < toInt(rules.minReputation)) return false;
  if (rules.maxReputation != null && reputation > toInt(rules.maxReputation)) return false;

  const age = ageFromBirthday(user.birthday);
  if (rules.minAge != null && (age == null || age < toInt(rules.minAge))) return false;
  if (rules.maxAge != null && (age == null || age > toInt(rules.maxAge))) return false;

  if (rules.activityDays != null) {
    const lastActiveMs = timestampToMillis(user.lastActiveAt);
    const cutoff = Date.now() - toInt(rules.activityDays) * 24 * 60 * 60 * 1000;
    if (!lastActiveMs || lastActiveMs < cutoff) return false;
  }

  const interestTags = stringArray(rules.interestTags).map((item) => item.toLowerCase());
  if (interestTags.length > 0) {
    const interests = stringArray(user.interests).map((item) => item.toLowerCase());
    if (!interestTags.some((tag) => interests.includes(tag))) return false;
  }
  return true;
}

function matchesDeviceRules(device, rules) {
  const platforms = stringArray(rules.platforms);
  if (platforms.length > 0 && !platforms.includes(cleanString(device.platform, 40))) {
    return false;
  }
  const version = cleanString(device.appVersion, 40);
  if (rules.minAppVersion && (!version || compareVersions(version, rules.minAppVersion) < 0)) {
    return false;
  }
  if (rules.maxAppVersion && (!version || compareVersions(version, rules.maxAppVersion) > 0)) {
    return false;
  }
  return true;
}

function hasDeviceRules(rules) {
  return (
    stringArray(rules.platforms).length > 0 ||
    cleanString(rules.minAppVersion, 40).length > 0 ||
    cleanString(rules.maxAppVersion, 40).length > 0
  );
}

function compareVersions(left, right) {
  const a = String(left || "").split(/[.+-]/).map((part) => Number.parseInt(part, 10) || 0);
  const b = String(right || "").split(/[.+-]/).map((part) => Number.parseInt(part, 10) || 0);
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index += 1) {
    const delta = (a[index] || 0) - (b[index] || 0);
    if (delta !== 0) return delta < 0 ? -1 : 1;
  }
  return 0;
}

function ageFromBirthday(value) {
  const millis = timestampToMillis(value);
  if (!millis) return null;
  const birthday = new Date(millis);
  const now = new Date();
  let age = now.getUTCFullYear() - birthday.getUTCFullYear();
  const monthDelta = now.getUTCMonth() - birthday.getUTCMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getUTCDate() < birthday.getUTCDate())) age -= 1;
  return age >= 0 ? age : null;
}

function normalizeMetrics(value) {
  const source = value || {};
  return {
    eligibleUsers: toInt(source.eligibleUsers),
    skippedUsers: toInt(source.skippedUsers),
    attemptedDevices: toInt(source.attemptedDevices),
    acceptedDevices: toInt(source.acceptedDevices),
    failedDevices: toInt(source.failedDevices),
    inboxCreated: toInt(source.inboxCreated),
    invalidTokens: toInt(source.invalidTokens),
  };
}

function messagingErrorCode(error) {
  return cleanString(error?.errorInfo?.code || error?.code, 120);
}

function stringArray(value) {
  return Array.isArray(value)
    ? value.map((item) => cleanString(item, 80)).filter(Boolean)
    : [];
}

function cleanString(value, maxLength = 160) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function toInt(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.trunc(number) : fallback;
}

function timestampToMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 0 : date.getTime();
}

function chunk(items, size) {
  const groups = [];
  for (let index = 0; index < items.length; index += size) {
    groups.push(items.slice(index, index + size));
  }
  return groups;
}

module.exports = {
  scheduleAdminNotificationCampaigns,
  prepareAdminNotificationCampaign,
  dispatchAdminNotificationJob,
  maintainAdminNotificationCampaigns,
  __test: {
    buildCampaignMessage,
    compareVersions,
    inboxTypeForCategory,
    hasDeviceRules,
    matchesDeviceRules,
    matchesUserRules,
    normalizeMetrics,
  },
};
