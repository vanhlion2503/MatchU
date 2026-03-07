const fs = require("fs");
const path = require("path");

const DICT_PATH = path.join(__dirname, "..", "..", "assets", "vi_2words_clean.txt");
let WORD_SET = null;
let LOAD_ERROR = null;

function ensureDictionaryLoaded() {
  if (WORD_SET) return WORD_SET;
  if (LOAD_ERROR) {
    throw LOAD_ERROR;
  }

  try {
    const set = new Set();
    const content = fs.readFileSync(DICT_PATH, "utf8");
    content.split("\n").forEach((line) => {
      const word = line.trim().toLowerCase();
      if (word) set.add(word);
    });

    WORD_SET = set;
    console.log("Vietnamese dictionary loaded:", WORD_SET.size);
    return WORD_SET;
  } catch (error) {
    LOAD_ERROR = error;
    throw error;
  }
}

function normalizeWord(word) {
  return word
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

function isValidVietnameseWord(word) {
  if (!word || typeof word !== "string") return false;

  try {
    return ensureDictionaryLoaded().has(normalizeWord(word));
  } catch (error) {
    console.error("Vietnamese dictionary load failed:", {
      message: error?.message || String(error),
    });
    return false;
  }
}

module.exports = {
  normalizeWord,
  isValidVietnameseWord,
};
