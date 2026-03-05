const MODERATION_THRESHOLD = 0.8;
const MODERATION_ENDPOINT =
  "https://ai-moderation-376071505252.asia-southeast1.run.app/moderate";
const AI_MODERATION_TIMEOUT_MS = 4000;
const AI_MODERATION_CACHE_TTL_MS = 5 * 60 * 1000;
const AI_MODERATION_CACHE_MAX_ENTRIES = 512;
const LINK_PATTERN = /(?:https?:\/\/|www\.)\S+/i;
const PHONE_PATTERN = /(?:\+?\d[\d .-]{8,}\d)/;
const EMOJI_ONLY_PATTERN = /^[\p{Extended_Pictographic}\u200d\ufe0f]+$/u;
const FAST_PATH_SAFE_PHRASES = new Set([
  "hi",
  "hello",
  "hey",
  "alo",
  "xin chào",
  "chào",
  "chào bạn",
  "rất vui được gặp bạn",
]);

const DANGEROUS_KEYWORDS = {
  sexual: [
    "lồn",
    "buồi",
    "cặc",
    "dương vật",
    "âm đạo",
    "địt",
    "đụ",
    "đéo",
    "làm tình",
    "chịch",
    "xxx",
    "sex",
    "sục",
    "bú",
    "liếm",
    "nứng",
    "thủ dâm",
    "l.ồ.n",
    "b.u.o.i",
    "c.a.c",
    "d.i.t",
    "đj.t",
    "đụ nhau",
  ],
  hate_or_threat: [
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
  grooming: [],
};

module.exports = {
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
};
