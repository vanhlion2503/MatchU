const fs = require("fs");
const path = require("path");

const DICT_PATH = path.join(__dirname, "..", "..", "assets", "vi_2words_clean.txt");
const WORD_SET = new Set();

(function loadDictionary() {
  const content = fs.readFileSync(DICT_PATH, "utf8");
  content.split("\n").forEach((line) => {
    const word = line.trim().toLowerCase();
    if (word) WORD_SET.add(word);
  });

  console.log("Vietnamese dictionary loaded:", WORD_SET.size);
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

module.exports = {
  normalizeWord,
  isValidVietnameseWord,
};
