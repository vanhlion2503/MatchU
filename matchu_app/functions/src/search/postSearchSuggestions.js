const {
  normalizeSearchText,
  tokenize,
  tokenizePreservingDiacritics,
} = require("./postSearch");

const MAX_PHRASE_WORDS = 5;

function cleanDisplayText(value) {
  return String(value || "").trim().replace(/\s+/g, " ");
}

function buildPostSearchSuggestions(posts, rawQuery, limit = 8) {
  const query = cleanDisplayText(rawQuery);
  const normalizedQuery = normalizeSearchText(query);
  const queryTerms = tokenize(query);
  if (!normalizedQuery || !queryTerms.length) return [];

  const lastTerm = queryTerms[queryTerms.length - 1];
  const baseTerms = tokenizePreservingDiacritics(query).slice(0, -1);
  const candidates = new Map();

  function addCandidate(
    displayValue,
    { tag = false, word = false, phrase = false, popularity = 0 } = {}
  ) {
    const display = cleanDisplayText(displayValue);
    const normalized = normalizeSearchText(display);
    if (!display || normalized === normalizedQuery) return;
    if (!normalized.startsWith(normalizedQuery) && queryTerms.length === 1) return;

    const current = candidates.get(normalized) || {
      display,
      hits: 0,
      tagHits: 0,
      wordHits: 0,
      phraseHits: 0,
      popularity: 0,
    };
    current.hits += 1;
    if (tag) current.tagHits += 1;
    if (word) current.wordHits += 1;
    if (phrase) current.phraseHits += 1;
    current.popularity = Math.max(current.popularity, Number(popularity) || 0);
    candidates.set(normalized, current);
  }

  for (const item of posts) {
    const post = item?.data || item || {};
    const popularity = Number(item?.popularity ?? post.popularityScore) || 0;
    const tags = Array.isArray(post.tags) ? post.tags : [];

    for (const rawTag of tags) {
      const tag = cleanDisplayText(rawTag).replace(/^#+/, "");
      const normalizedTag = normalizeSearchText(tag);
      if (normalizedTag.startsWith(normalizedQuery)) {
        addCandidate(`#${tag}`, { tag: true, popularity });
      } else if (normalizedTag.startsWith(lastTerm)) {
        addCandidate([...baseTerms, `#${tag}`].join(" "), {
          tag: true,
          popularity,
        });
      }
    }

    const words = tokenizePreservingDiacritics(post.content);
    for (let start = 0; start < words.length; start += 1) {
      const normalizedWord = normalizeSearchText(words[start]);
      if (normalizedWord.startsWith(lastTerm)) {
        addCandidate([...baseTerms, words[start]].join(" "), {
          word: true,
          popularity,
        });
      }

      for (
        let count = 2;
        count <= MAX_PHRASE_WORDS && start + count <= words.length;
        count += 1
      ) {
        const phrase = words.slice(start, start + count).join(" ");
        if (normalizeSearchText(phrase).startsWith(normalizedQuery)) {
          addCandidate(phrase, { phrase: true, popularity });
        }
      }
    }
  }

  return Array.from(candidates.values())
    .sort((a, b) =>
      (b.tagHits - a.tagHits) ||
      (b.wordHits - a.wordHits) ||
      (b.phraseHits - a.phraseHits) ||
      (b.hits - a.hits) ||
      (a.display.length - b.display.length) ||
      (b.popularity - a.popularity) ||
      a.display.localeCompare(b.display, "vi")
    )
    .slice(0, Math.max(1, limit))
    .map((item) => item.display);
}

module.exports = { buildPostSearchSuggestions };
