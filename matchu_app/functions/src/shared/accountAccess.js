const { HttpsError } = require("firebase-functions/v2/https");

const { db } = require("./firebase");

const ACCOUNT_FEATURES = new Set([
  "posts",
  "comments",
  "chat",
  "matching",
  "calls",
]);

function asDate(value) {
  if (value instanceof Date) return value;
  if (value && typeof value.toDate === "function") return value.toDate();
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function evaluateAccountAccess(userData, feature, now = new Date()) {
  if (!ACCOUNT_FEATURES.has(feature)) {
    throw new TypeError(`Unsupported account feature: ${feature}`);
  }

  if (!userData) {
    return {
      allowed: false,
      reason: "account-unavailable",
      message: "User profile was not found.",
    };
  }

  const status = String(userData.accountStatus || "active")
    .trim()
    .toLowerCase();
  if (!status || status === "active") return { allowed: true };

  if (status === "deleting" || status === "deleted") {
    return {
      allowed: false,
      reason: "account-unavailable",
      message: "This account is no longer active.",
    };
  }
  if (status === "suspended") {
    return {
      allowed: false,
      reason: "account-suspended",
      message: "This account is suspended.",
    };
  }
  if (status === "banned") {
    return {
      allowed: false,
      reason: "account-banned",
      message: "This account is banned.",
    };
  }
  if (status !== "restricted") {
    return {
      allowed: false,
      reason: "account-status-invalid",
      message: "This account has an invalid status.",
    };
  }

  const restriction =
    userData.restriction && typeof userData.restriction === "object"
      ? userData.restriction
      : null;
  if (!restriction || !Array.isArray(restriction.features)) {
    return {
      allowed: false,
      reason: "account-restricted",
      message: "This account is restricted.",
    };
  }

  const expiresAt = asDate(restriction.expiresAt);
  if (expiresAt && expiresAt.getTime() <= now.getTime()) {
    return { allowed: true };
  }
  if (!restriction.features.includes(feature)) return { allowed: true };

  return {
    allowed: false,
    reason: "feature-restricted",
    message: `This account is restricted from using ${feature}.`,
    restrictionReason:
      typeof restriction.reason === "string" ? restriction.reason.trim() : "",
    expiresAt,
  };
}

async function assertAccountFeatureAllowed(uid, feature) {
  const snapshot = await db.collection("users").doc(uid).get();
  const decision = evaluateAccountAccess(
    snapshot.exists ? snapshot.data() : null,
    feature
  );
  if (decision.allowed) return;

  throw new HttpsError("permission-denied", decision.message, {
    reason: decision.reason,
    feature,
    restrictionReason: decision.restrictionReason || null,
    expiresAt: decision.expiresAt?.toISOString() || null,
  });
}

module.exports = {
  ACCOUNT_FEATURES,
  assertAccountFeatureAllowed,
  evaluateAccountAccess,
};
