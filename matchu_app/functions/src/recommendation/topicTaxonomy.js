"use strict";

const TOPIC_ALIASES = Object.freeze({
  "flutter-dev": "flutter",
  flutterdev: "flutter",
  dart: "flutter",
  "firebase-dev": "firebase",
  "trí-tuệ-nhân-tạo": "ai",
  "tri-tue-nhan-tao": "ai",
  "artificial-intelligence": "ai",
  "lập-trình-flutter": "flutter",
  "lap-trinh-flutter": "flutter",
});

function normalizeTopicId(value) {
  if (typeof value !== "string") return "";
  const normalized = value
    .trim()
    .toLocaleLowerCase("vi")
    .replace(/^#+/, "")
    .replace(/[_\s]+/g, "-")
    .replace(/-+/g, "-");
  return TOPIC_ALIASES[normalized] || normalized;
}

function normalizeTopicIds(values) {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.map(normalizeTopicId).filter(Boolean))];
}

module.exports = { normalizeTopicId, normalizeTopicIds };
