const { setGlobalOptions } = require("firebase-functions");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenAI } = require("@google/genai");
const admin = require("firebase-admin");
setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();
const db = admin.firestore();

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
    const after = event.data.after.data();
    if (!after?.minigame?.aiInsight) return;

    const ai = after.minigame.aiInsight;
    if (ai.status !== "pending") return;
    if (ai.generatedAt) return;

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

