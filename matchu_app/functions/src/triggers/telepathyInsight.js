const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { GoogleGenAI } = require("@google/genai");

const { admin } = require("../shared/firebase");
const { GEMINI_API_KEY } = require("../shared/secrets");

const generateTelepathyAiInsight = onDocumentUpdated(
  {
    document: "tempChats/{roomId}",
    secrets: [GEMINI_API_KEY],
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
        "minigame.aiInsight.text": "Không đủ dữ liệu để phân tích.",
        "minigame.aiInsight.generatedAt":
          admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      const genAI = new GoogleGenAI({
        apiKey: GEMINI_API_KEY.value(),
      });

      const prompt = buildTelepathyPrompt(payload);

      const result = await genAI.models.generateContent({
        model: "gemini-3-flash-preview",
        contents: prompt,
      });

      const text = result.text ?? "Hai bạn có nhiều điểm thú vị để khám phá thêm.";

      await event.data.after.ref.update({
        "minigame.aiInsight.status": "done",
        "minigame.aiInsight.text": text,
        "minigame.aiInsight.generatedAt":
          admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("Gemini error:", error);

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

async function getSafeGeminiModel(genAI) {
  const model = genAI.getGenerativeModel({ model: "gemini-pro" });

  try {
    await model.generateContent("Ping");
    return model;
  } catch (error) {
    console.error("Gemini model test failed:", error);
    throw new Error("Gemini model is not usable");
  }
}

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

module.exports = {
  generateTelepathyAiInsight,
};
