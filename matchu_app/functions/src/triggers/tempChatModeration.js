const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const axios = require("axios");

const { admin, db } = require("../shared/firebase");
const {
  MODERATION_THRESHOLD,
  MODERATION_ENDPOINT,
  AI_MODERATION_TIMEOUT_MS,
  AI_MODERATION_CACHE_TTL_MS,
  AI_MODERATION_CACHE_MAX_ENTRIES,
  LINK_PATTERN,
  PHONE_PATTERN,
  EMOJI_ONLY_PATTERN,
  FAST_PATH_SAFE_PHRASES,
  DANGEROUS_KEYWORDS,
} = require("../shared/moderationConstants");

const AI_MODERATION_CACHE = new Map();

function isNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function normalizeModerationText(value) {
  if (typeof value !== "string") return "";
  return value.toLowerCase().trim().replace(/\s+/g, " ");
}

function normalizeFastPathText(value) {
  const normalized = normalizeModerationText(value);
  if (!normalized) return "";
  return normalized
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function isEmojiOnlyMessage(value) {
  if (typeof value !== "string") return false;
  const compact = value.replace(/\s+/g, "");
  if (!compact) return false;
  return EMOJI_ONLY_PATTERN.test(compact);
}

function shouldFastApproveWithoutAi(text) {
  const normalized = normalizeModerationText(text);
  if (!normalized) return true;
  if (isEmojiOnlyMessage(normalized)) return true;

  const fastPathText = normalizeFastPathText(normalized);
  if (!fastPathText) return false;
  return FAST_PATH_SAFE_PHRASES.has(fastPathText);
}

function getCachedAiModerationResult(key) {
  const cached = AI_MODERATION_CACHE.get(key);
  if (!cached) return null;

  if (cached.expiresAt <= Date.now()) {
    AI_MODERATION_CACHE.delete(key);
    return null;
  }

  return cached.result;
}

function setCachedAiModerationResult(key, result) {
  AI_MODERATION_CACHE.set(key, {
    result,
    expiresAt: Date.now() + AI_MODERATION_CACHE_TTL_MS,
  });

  if (AI_MODERATION_CACHE.size <= AI_MODERATION_CACHE_MAX_ENTRIES) return;

  const oldestKey = AI_MODERATION_CACHE.keys().next().value;
  if (oldestKey !== undefined) {
    AI_MODERATION_CACHE.delete(oldestKey);
  }
}

function containsKeyword(normalizedText, keywords) {
  if (typeof normalizedText !== "string" || !normalizedText) return false;
  if (!Array.isArray(keywords) || keywords.length === 0) return false;

  return keywords.some((keyword) => {
    return (
      typeof keyword === "string" &&
      keyword.length > 0 &&
      normalizedText.includes(keyword)
    );
  });
}

function normalizeParticipants(participants, userA, userB) {
  const normalized = [];

  if (Array.isArray(participants)) {
    for (const uid of participants) {
      if (typeof uid !== "string") continue;
      const trimmed = uid.trim();
      if (!trimmed || normalized.includes(trimmed)) continue;
      normalized.push(trimmed);
    }
  }

  for (const uid of [userA, userB]) {
    if (typeof uid !== "string") continue;
    const trimmed = uid.trim();
    if (!trimmed || normalized.includes(trimmed)) continue;
    normalized.push(trimmed);
  }

  return normalized;
}

function normalizeViolationCountMap(rawMap, participants) {
  const map = {};

  if (rawMap && typeof rawMap === "object" && !Array.isArray(rawMap)) {
    for (const [uid, value] of Object.entries(rawMap)) {
      if (typeof uid !== "string" || !uid.trim()) continue;
      const parsed = Number(value);
      map[uid] = Number.isFinite(parsed) && parsed >= 0 ? Math.floor(parsed) : 0;
    }
  }

  for (const uid of participants) {
    if (!isNumber(map[uid])) {
      map[uid] = 0;
    }
  }

  return map;
}

function normalizeAiLabel(label) {
  const raw = normalizeModerationText(label);

  if (
    raw === "normal" ||
    raw === "scam" ||
    raw === "sexual" ||
    raw === "grooming" ||
    raw === "hate_or_threat"
  ) {
    return raw;
  }

  if (raw === "hate" || raw === "insult" || raw === "threat") {
    return "hate_or_threat";
  }

  return "hate_or_threat";
}

function parseAiScore(score) {
  const parsed = Number(score);
  return Number.isFinite(parsed) ? parsed : 0;
}

function calculatePenalty(violationCount) {
  if (violationCount <= 1) return 0;
  if (violationCount === 2) return 2;
  return Math.pow(2, violationCount - 1);
}

function getCurrentReputationScore(userData) {
  const candidates = [];
  if (isNumber(userData?.reputation)) {
    candidates.push(userData.reputation);
  }
  if (isNumber(userData?.reputationScore)) {
    candidates.push(userData.reputationScore);
  }

  if (candidates.length === 0) return 100;
  return Math.min(...candidates);
}

async function applyViolationPenaltyAndBlock({
  snap,
  roomId,
  senderId,
  reason,
  blockedBy,
  aiScore,
}) {
  const roomRef = db.collection("tempChats").doc(roomId);
  const userRef = db.collection("users").doc(senderId);

  await db.runTransaction(async (tx) => {
    const [latestMsgSnap, roomSnap, userSnap] = await Promise.all([
      tx.get(snap.ref),
      tx.get(roomRef),
      tx.get(userRef),
    ]);

    if (!latestMsgSnap.exists) return;

    const latestMsg = latestMsgSnap.data() || {};
    if (
      typeof latestMsg.status === "string" &&
      latestMsg.status !== "pending"
    ) {
      return;
    }

    const roomData = roomSnap.exists ? roomSnap.data() : {};
    const participants = normalizeParticipants(
      roomData?.participants,
      roomData?.userA,
      roomData?.userB
    );
    const violationCount = normalizeViolationCountMap(
      roomData?.violationCount,
      participants
    );

    const previousCount = isNumber(violationCount[senderId])
      ? violationCount[senderId]
      : 0;
    const nextCount = previousCount + 1;
    violationCount[senderId] = nextCount;

    const roomPatch = { violationCount };
    if (participants.length > 0) {
      roomPatch.participants = participants;
    }
    tx.set(roomRef, roomPatch, { merge: true });

    const userData = userSnap.exists ? userSnap.data() : {};
    const currentReputation = getCurrentReputationScore(userData);
    const penalty = calculatePenalty(nextCount);
    const nextReputation = Math.max(0, currentReputation - penalty);

    tx.set(
      userRef,
      {
        reputation: nextReputation,
        reputationScore: nextReputation,
      },
      { merge: true }
    );

    tx.set(
      snap.ref,
      {
        status: "blocked",
        blockedBy,
        reason,
        warning: true,
        aiScore: isNumber(aiScore) ? aiScore : null,
      },
      { merge: true }
    );
  });
}

function ruleCheck(text) {
  const normalizedText = normalizeModerationText(text);

  if (!normalizedText) {
    return { isViolation: false, reason: null };
  }

  if (containsKeyword(normalizedText, DANGEROUS_KEYWORDS.sexual)) {
    return { isViolation: true, reason: "sexual" };
  }

  if (containsKeyword(normalizedText, DANGEROUS_KEYWORDS.hate_or_threat)) {
    return { isViolation: true, reason: "hate_or_threat" };
  }

  if (containsKeyword(normalizedText, DANGEROUS_KEYWORDS.grooming)) {
    return { isViolation: true, reason: "grooming" };
  }

  if (LINK_PATTERN.test(normalizedText) || PHONE_PATTERN.test(normalizedText)) {
    return { isViolation: true, reason: "scam" };
  }

  return { isViolation: false, reason: null };
}

async function callAiModeration(text) {
  const normalizedText = normalizeModerationText(text);
  if (normalizedText) {
    const cachedResult = getCachedAiModerationResult(normalizedText);
    if (cachedResult) return cachedResult;
  }

  const response = await axios.post(
    MODERATION_ENDPOINT,
    { text },
    { timeout: AI_MODERATION_TIMEOUT_MS }
  );

  const result = {
    label: normalizeAiLabel(response?.data?.label),
    score: parseAiScore(response?.data?.score),
  };

  if (normalizedText) {
    setCachedAiModerationResult(normalizedText, result);
  }

  return result;
}

const ensureTempChatModerationFields = onDocumentCreated(
  "tempChats/{chatId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const roomData = snap.data() || {};
    const participants = normalizeParticipants(
      roomData.participants,
      roomData.userA,
      roomData.userB
    );
    const violationCount = normalizeViolationCountMap(
      roomData.violationCount,
      participants
    );

    const patch = { violationCount };
    if (participants.length > 0) {
      patch.participants = participants;
    }

    await snap.ref.set(patch, { merge: true });
  }
);

const ensureUserReputationDefault = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const userData = snap.data() || {};
    const hasReputation = isNumber(userData.reputation);
    const hasReputationScore = isNumber(userData.reputationScore);
    if (hasReputation && hasReputationScore) return;

    const baseScore = getCurrentReputationScore(userData);
    await snap.ref.set(
      {
        reputation: baseScore,
        reputationScore: baseScore,
      },
      { merge: true }
    );
  }
);

const moderateTempChatMessage = onDocumentCreated(
  "tempChats/{chatId}/messages/{msgId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const roomId = event.params.chatId;
    const messageId = event.params.msgId;
    const message = snap.data() || {};

    try {
      if (message.type === "system" || message.systemCode || message.event) {
        return;
      }

      const senderId =
        typeof message.senderId === "string" ? message.senderId.trim() : "";
      const text = typeof message.text === "string" ? message.text : "";

      if (!senderId) return;

      if (typeof message.status === "string" && message.status !== "pending") {
        return;
      }

      if (!text.trim()) {
        await snap.ref.set(
          {
            status: "approved",
            blockedBy: null,
            reason: null,
            warning: false,
            aiScore: null,
          },
          { merge: true }
        );
        return;
      }

      const ruleResult = ruleCheck(text);
      if (ruleResult.isViolation) {
        await applyViolationPenaltyAndBlock({
          snap,
          roomId,
          senderId,
          reason: ruleResult.reason,
          blockedBy: "rule",
          aiScore: null,
        });
        return;
      }

      if (shouldFastApproveWithoutAi(text)) {
        await snap.ref.set(
          {
            status: "approved",
            blockedBy: null,
            reason: null,
            warning: false,
            aiScore: null,
          },
          { merge: true }
        );
        return;
      }

      let aiResult;
      try {
        aiResult = await callAiModeration(text);
      } catch (error) {
        console.error("AI moderation failed; fallback to approve:", {
          roomId,
          messageId,
          error: error?.message || String(error),
        });

        await snap.ref.set(
          {
            status: "approved",
            blockedBy: null,
            reason: null,
            warning: false,
            aiScore: null,
          },
          { merge: true }
        );
        return;
      }

      const aiLabel = aiResult.label;
      const aiScore = aiResult.score;

      if (aiLabel === "normal" || aiScore < MODERATION_THRESHOLD) {
        await snap.ref.set(
          {
            status: "approved",
            blockedBy: null,
            reason: null,
            warning: false,
            aiScore,
          },
          { merge: true }
        );
        return;
      }

      if (aiLabel === "scam") {
        await snap.ref.set(
          {
            status: "approved",
            blockedBy: null,
            reason: "scam",
            warning: true,
            aiScore,
          },
          { merge: true }
        );
        return;
      }

      await applyViolationPenaltyAndBlock({
        snap,
        roomId,
        senderId,
        reason: aiLabel,
        blockedBy: "ai",
        aiScore,
      });
    } catch (error) {
      console.error("Temp chat moderation crashed; fallback approve:", {
        roomId,
        messageId,
        error: error?.message || String(error),
      });

      try {
        const latestMsgSnap = await snap.ref.get();
        if (!latestMsgSnap.exists) return;

        const latestMsg = latestMsgSnap.data() || {};
        if (
          typeof latestMsg.status === "string" &&
          latestMsg.status !== "pending"
        ) {
          return;
        }

        await snap.ref.set(
          {
            status: "approved",
            blockedBy: null,
            reason: null,
            warning: false,
            aiScore: null,
          },
          { merge: true }
        );
      } catch (fallbackError) {
        console.error("Fallback approve failed:", {
          roomId,
          messageId,
          error: fallbackError?.message || String(fallbackError),
        });
      }
    }
  }
);

module.exports = {
  ensureTempChatModerationFields,
  ensureUserReputationDefault,
  moderateTempChatMessage,
};
