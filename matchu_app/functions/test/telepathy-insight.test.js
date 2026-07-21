const test = require("node:test");
const assert = require("node:assert/strict");

const { __test } = require("../src/triggers/telepathyInsight");

test("Telepathy AI uses latency-bounded generation settings", () => {
  assert.equal(__test.TELEPATHY_AI_MODEL, "gemini-3-flash-preview");
  assert.deepEqual(__test.TELEPATHY_AI_CONFIG, {
    thinkingConfig: { thinkingLevel: "minimal" },
    maxOutputTokens: 256,
  });
});

test("Telepathy prompt keeps the existing insight contract", () => {
  const prompt = __test.buildTelepathyPrompt({
    score: 75,
    level: "high",
    questions: [
      {
        question: "Cuối tuần lý tưởng?",
        me: "Đi biển",
        other: "Đi biển",
        same: true,
        category: "hobby",
      },
    ],
  });

  assert.match(prompt, /Điểm tương thích: 75%/);
  assert.match(prompt, /Mức độ tương thích: high/);
  assert.match(prompt, /Cuối tuần lý tưởng\?/);
  assert.match(prompt, /Người A chọn: Đi biển/);
  assert.match(prompt, /Độ dài: 3–5 câu ngắn/);
  assert.match(prompt, /CHỈ TRẢ VỀ ĐOẠN VĂN HOÀN CHỈNH/);
});
