const { setGlobalOptions } = require("firebase-functions");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenAI } = require("@google/genai");
const admin = require("firebase-admin");
const axios = require("axios");
setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();
const fs = require("fs");
const path = require("path");

// ===== LOAD VIETNAMESE DICTIONARY =====
const DICT_PATH = path.join(__dirname, "assets", "vi_2words_clean.txt");
const WORD_SET = new Set();

(function loadDictionary() {
  const content = fs.readFileSync(DICT_PATH, "utf8");
  content.split("\n").forEach((line) => {
    const word = line.trim().toLowerCase();
    if (word) WORD_SET.add(word);
  });

  console.log("✅ Vietnamese dictionary loaded:", WORD_SET.size);
})();

function normalizeWord(word) {
  return word
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

function isValidVietnameseWord(word) {
  if (!word || typeof word !== "string") return false;
  return WORD_SET.has(normalizeWord(word));
}


const db = admin.firestore();
const MODERATION_THRESHOLD = 0.8;
const MODERATION_ENDPOINT =
  "https://ai-moderation-376071505252.asia-southeast1.run.app/moderate";
const LINK_PATTERN = /(?:https?:\/\/|www\.)\S+/i;
const PHONE_PATTERN = /(?:\+?\d[\d .-]{8,}\d)/;

const DANGEROUS_KEYWORDS = {
  sexual: [
    // bộ phận sinh dục (rõ ràng)
    "lồn",
    "buồi",
    "cặc",
    "dương vật",
    "âm đạo",
    "địt",
    "đụ",
    "đéo",

    // hành vi tình dục trực tiếp
    "làm tình",
    "chịch",
    "xxx",
    "sex",

    // khiêu dâm nặng
    "sục",
    "bú",
    "liếm",
    "nứng",
    "thủ dâm",

    // lách luật phổ biến
    "l.ồ.n",
    "b.u.o.i",
    "c.a.c",
    "d.i.t",
    "đj.t",
    "đụ nhau"
  ],

  hate_or_threat: [
    // đe dọa giết / gây thương tích
    "giết",
    "chém",
    "đâm",
    "đốt nhà",
    "đập chết",
    "xử mày",
    "cho mày chết",
    "đồ súc sinh",
    "mày liệu hồn",
    "ra đường coi chừng",
  ],

  grooming: [
    // gợi ý dụ dỗ / tiếp cận trẻ vị thành niên
  ],
};


const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.migrateTempChatMessages = onDocumentCreated(
  "chatRooms/{roomId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const roomData = snap.data();

    // ❌ Không phải room migrate
    if (!roomData.fromTempRoom) return;

    // 🔒 Chống chạy lại
    if (roomData.migrated === true) return;

    const tempRoomId = roomData.fromTempRoom;

    const tempMessagesSnap = await db
      .collection("tempChats")
      .doc(tempRoomId)
      .collection("messages")
      .orderBy("createdAt")
      .get();

    // Không có tin nhắn
    if (tempMessagesSnap.empty) {
      await snap.ref.update({ migrated: true });
      return;
    }

    let batch = db.batch();
    let count = 0;

    for (const doc of tempMessagesSnap.docs) {
      const data = doc.data();

      if (data.type === "system" || data.code) {
        continue;
      }

      const newMsgRef = snap.ref.collection("messages").doc();

      batch.set(newMsgRef, {
        ...data,
        createdAt: data.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
      });

      count++;

      // Commit tránh quá 500 ops
      if (count >= 450) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }

    // ✅ Đánh dấu migrate xong
    await snap.ref.update({
      migrated: true,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

exports.cleanupViewedImageMessage = onDocumentUpdated(
  "chatRooms/{roomId}/messages/{messageId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!before || !after) return;
    if (before.type !== "image") return;
    if (before.viewOnce !== true) return;
    if (after.type === "deleted" || after.imageDeleted === true) return;

    const beforeViewed = before.viewedBy || {};
    const afterViewed = after.viewedBy || {};

    const newViewers = Object.keys(afterViewed).filter(
      (uid) => !beforeViewed[uid]
    );
    if (newViewers.length === 0) return;

    const viewerUid = newViewers.find(
      (uid) => uid && uid !== before.senderId
    );
    if (!viewerUid) return;

    const imagePath = after.imagePath;

    if (imagePath && typeof imagePath === "string") {
      try {
        await admin.storage().bucket().file(imagePath).delete();
      } catch (e) {
        // ignore missing files or transient failures
      }
    }

    await event.data.after.ref.update({
      type: "deleted",
      text: "Ảnh đã bị xóa",
      imagePath: admin.firestore.FieldValue.delete(),
      imageDeleted: true,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedBy: viewerUid,
    });

    try {
      const roomRef = db.collection("chatRooms").doc(event.params.roomId);
      const roomSnap = await roomRef.get();
      if (!roomSnap.exists) return;

      const roomData = roomSnap.data();
      const lastAt = roomData.lastMessageAt;
      const createdAt = after.createdAt;

      if (
        lastAt &&
        createdAt &&
        lastAt.toMillis &&
        createdAt.toMillis &&
        lastAt.toMillis() === createdAt.toMillis()
      ) {
        await roomRef.update({
          lastMessage: "Ảnh đã bị xóa",
          lastMessageType: "deleted",
          lastMessageCipher: admin.firestore.FieldValue.delete(),
          lastMessageIv: admin.firestore.FieldValue.delete(),
          lastMessageKeyId: 0,
          lastSenderId: after.senderId || viewerUid,
        });
      }
    } catch (_) {}
  }
);

exports.generateTelepathyAiInsight = onDocumentUpdated(
  {
    document: "tempChats/{roomId}",
    secrets: [GEMINI_API_KEY], // 🔥 BẮT BUỘC
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after?.minigame?.aiInsight) return;

    const ai = after.minigame.aiInsight;
    if (ai.status !== "pending") return;
    if (ai.generatedAt) return;

    const beforeAi = before?.minigame?.aiInsight;
    if (beforeAi?.status === "pending" && !beforeAi?.generatedAt) return;

    const payload = ai.payload;
    if (!payload?.questions?.length) {
      await event.data.after.ref.update({
        "minigame.aiInsight.status": "error",
        "minigame.aiInsight.text":
          "Không đủ dữ liệu để phân tích.",
        "minigame.aiInsight.generatedAt":
          admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      const ai = new GoogleGenAI({
        apiKey: GEMINI_API_KEY.value(),
      });

      const prompt = buildTelepathyPrompt(payload);

      const result = await ai.models.generateContent({
        model: "gemini-3-flash-preview",
        contents: prompt,
      });

      const text =
        result.text ??
        "Hai bạn có nhiều điểm thú vị để khám phá thêm.";

      await event.data.after.ref.update({
        "minigame.aiInsight.status": "done",
        "minigame.aiInsight.text": text,
        "minigame.aiInsight.generatedAt":
          admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error("Gemini error:", e);

      await event.data.after.ref.update({
        "minigame.aiInsight.status": "error",
        "minigame.aiInsight.text":
          "AI đang suy nghĩ hơi lâu, hãy tiếp tục trò chuyện nhé 😉",
        "minigame.aiInsight.generatedAt":
          admin.firestore.FieldValue.serverTimestamp(),
      });
    }

  }
);

// =========================
// 🔐 SAFE GEMINI MODEL (Node SDK compatible)
// =========================
async function getSafeGeminiModel(genAI) {
  const model = genAI.getGenerativeModel({ model: "gemini-pro" });

  try {
    // 🔎 test nhẹ, không tốn nhiều quota
    await model.generateContent("Ping");

    return model;
  } catch (e) {
    console.error("Gemini model test failed:", e);
    throw new Error("Gemini model is not usable");
  }
}

/* =========================
   ✍️ PROMPT BUILDER
========================= */
function buildTelepathyPrompt(payload) {
  const { score, level, questions } = payload;

  const qaBlock = questions
    .map(
      (q, i) => `
Câu ${i + 1}:
- Tình huống: ${q.question}
- Người A chọn: ${q.me}
- Người B chọn: ${q.other}
- Trùng nhau: ${q.same ? "Có" : "Không"}
- Chủ đề: ${q.category}
`
    )
    .join("\n");

  return `
BẠN LÀ AI PHÂN TÍCH ĐỘ TƯƠNG THÍCH TRONG ỨNG DỤNG HẸN HÒ.

NHIỆM VỤ:
Viết một đoạn nhận xét ngắn giúp hai người:
- Cảm thấy thoải mái
- Có động lực tiếp tục trò chuyện
- Không gây áp lực hay phán xét

NGỮ CẢNH:
Hai người vừa chơi minigame “Thần giao cách cảm”.
Mục tiêu của đoạn này là tạo CẦU NỐI cho cuộc trò chuyện tiếp theo.

THÔNG TIN PHÂN TÍCH:
- Điểm tương thích: ${score}%
- Mức độ tương thích: ${level}

DỮ LIỆU CÂU HỎI:
${qaBlock}

YÊU CẦU VIẾT:
- Ngôn ngữ: Tiếng Việt
- Giọng điệu: Tích cực, tinh tế, thân thiện
- Độ dài: 3–5 câu ngắn
- Nội dung BẮT BUỘC:
  1. Nhận xét chung về mức độ hợp nhau
  2. Nêu 1 điểm giống nhau nổi bật (nếu có)
  3. Nêu 1 khác biệt thú vị (nếu có)
  4. Gợi ý 1 hướng trò chuyện tiếp theo (dạng gợi mở, không hỏi trực tiếp)

KHÔNG ĐƯỢC:
- Không dùng emoji
- Không dùng từ ngữ phán xét
- Không so sánh tốt / xấu
- Không nhắc đến AI, mô hình, hay hệ thống

CHỈ TRẢ VỀ ĐOẠN VĂN HOÀN CHỈNH.
`;
}

exports.validateWordChainDictionary = onDocumentUpdated(
  "tempChats/{roomId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after) return;

    const game = after.minigames?.wordChain;
    if (!game) return;

    const pending = game.pendingWord;
    if (!pending) return;

    // ===== ANTI LOOP =====
    const prevPending = before?.minigames?.wordChain?.pendingWord;
    if (
      prevPending &&
      prevPending.word === pending.word &&
      prevPending.uid === pending.uid
    ) {
      return;
    }

    const rawWord = pending.word;
    const uid = pending.uid;
    const ref = event.data.after.ref;

    if (!rawWord || !uid) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
      });
      return;
    }

    const word = normalizeWord(rawWord);

    // ===== CHECK STATUS =====
    if (game.status !== "playing") {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "not_playing",
      });
      return;
    }

    // ===== CHECK TURN =====
    if (game.turnUid !== uid) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "not_your_turn",
      });
      return;
    }

    // ===== CHECK FORMAT (2 TIẾNG) =====
    const parts = word.split(" ");
    if (parts.length !== 2) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "format",
      });
      return;
    }

    // ===== CHECK USED WORD =====
    const usedWords = (game.usedWords || []).map(normalizeWord);
    if (usedWords.includes(word)) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "used_word",
      });
      return;
    }

    // ===== CHECK STRICT CHAIN =====
    const prevWord = game.currentWord || "";
    if (prevWord) {
      const prevLast = normalizeWord(prevWord).split(" ").pop();
      const first = parts[0];

      if (first !== prevLast) {
        await ref.update({
          "minigames.wordChain.pendingWord":
            admin.firestore.FieldValue.delete(),
          "minigames.wordChain.invalidReason": "chain_mismatch",
        });
        return;
      }
    }

    // ===== CHECK DICTIONARY =====
    if (!isValidVietnameseWord(word)) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "dictionary",
      });
      return;
    }

    // ===== COMMIT WORD (AUTHORITATIVE) =====
    const participants = after.participants || [];
    const nextUid = participants.find((id) => id !== uid);

    if (!nextUid) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
      });
      return;
    }

    await ref.update({
      "minigames.wordChain.currentWord": word,
      "minigames.wordChain.usedWords":
        admin.firestore.FieldValue.arrayUnion(word),
      "minigames.wordChain.turnUid": nextUid,
      "minigames.wordChain.remainingSeconds": 15,
      "minigames.wordChain.pendingWord":
        admin.firestore.FieldValue.delete(),
      "minigames.wordChain.invalidReason":
        admin.firestore.FieldValue.delete(),
      "minigames.wordChain.updatedAt":
        admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

// =========================
// CHAT MODERATION (tempChats)
// =========================
function isNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function normalizeModerationText(value) {
  if (typeof value !== "string") return "";
  return value.toLowerCase().trim().replace(/\s+/g, " ");
}

function containsKeyword(normalizedText, keywords) {
  if (typeof normalizedText !== "string" || !normalizedText) return false;
  if (!Array.isArray(keywords) || keywords.length === 0) return false;

  return keywords.some((keyword) => {
    return typeof keyword === "string" &&
      keyword.length > 0 &&
      normalizedText.includes(keyword);
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
  const response = await axios.post(
    MODERATION_ENDPOINT,
    { text },
    { timeout: 10000 }
  );

  return {
    label: normalizeAiLabel(response?.data?.label),
    score: parseAiScore(response?.data?.score),
  };
}

exports.ensureTempChatModerationFields = onDocumentCreated(
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

exports.ensureUserReputationDefault = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const userData = snap.data() || {};
    if (isNumber(userData.reputation)) return;

    await snap.ref.set({ reputation: 100 }, { merge: true });
  }
);

exports.moderateTempChatMessage = onDocumentCreated(
  "tempChats/{chatId}/messages/{msgId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const roomId = event.params.chatId;
    const messageId = event.params.msgId;
    const message = snap.data() || {};

    try {

    // System/event message is not user-generated chat content.
    if (message.type === "system" || message.systemCode || message.event) {
      return;
    }

    const senderId =
      typeof message.senderId === "string" ? message.senderId.trim() : "";
    const text = typeof message.text === "string" ? message.text : "";

    if (!senderId) return;

    // Ignore already-processed message in case of retry/duplicate trigger.
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
      await snap.ref.set(
        {
          status: "blocked",
          blockedBy: "rule",
          reason: ruleResult.reason,
          warning: true,
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

    // label normal OR score < 0.8 => approve, no punishment
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

    // score >= 0.8 + scam => warning only, no punishment
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

    // score >= 0.8 + non-scam harmful label => block + penalty policy
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

      const penalty = calculatePenalty(nextCount);

      if (penalty > 0) {
        const userData = userSnap.exists ? userSnap.data() : {};
        const currentReputation = isNumber(userData?.reputation)
          ? userData.reputation
          : 100;
        const nextReputation = Math.max(0, currentReputation - penalty);

        const userPatch = { reputation: nextReputation };

        // Keep legacy score field synced if it already exists in this project.
        if (isNumber(userData?.reputationScore)) {
          userPatch.reputationScore = Math.max(
            0,
            userData.reputationScore - penalty
          );
        }

        tx.set(userRef, userPatch, { merge: true });
      } else if (!userSnap.exists || !isNumber(userSnap.data()?.reputation)) {
        tx.set(userRef, { reputation: 100 }, { merge: true });
      }

      tx.set(
        snap.ref,
        {
          status: "blocked",
          blockedBy: "ai",
          reason: aiLabel,
          warning: true,
          aiScore,
        },
        { merge: true }
      );
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



