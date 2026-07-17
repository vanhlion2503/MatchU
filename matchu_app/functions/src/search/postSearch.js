const MAX_INDEX_TERMS = 450;
// Prefixes shorter than four characters create too many false positives for
// Vietnamese words such as "an", "ca" and "du".
const MIN_PREFIX_LENGTH = 4;
const MAX_PREFIX_LENGTH = 18;
const MIN_PARTIAL_WEIGHT_COVERAGE = 0.35;

const PARTIAL_STOP_WORDS = new Set([
  "va",
  "la",
  "cua",
  "cho",
  "voi",
  "mot",
  "nhung",
  "cac",
  "thi",
  "ma",
  "a",
  "the",
  "and",
  "or",
  "to",
  "of",
  "in",
  "on",
  "for",
  "with",
  "is",
  "are",
]);

const MATCH_TYPES = Object.freeze({
  exactSentence: "exact_sentence",
  keyPhrase: "key_phrase",
  allTerms: "all_terms",
  hashtagOnly: "hashtag_only",
  partial: "partial",
});

const MATCH_SCORES = Object.freeze({
  [MATCH_TYPES.exactSentence]: 1.0,
  [MATCH_TYPES.keyPhrase]: 0.85,
  [MATCH_TYPES.allTerms]: 0.7,
  [MATCH_TYPES.hashtagOnly]: 0.5,
  [MATCH_TYPES.partial]: 0.4,
});

function normalizeSearchTextPreservingDiacritics(value) {
  return String(value || "")
    .normalize("NFC")
    .toLowerCase()
    .replace(/#/g, " ")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function normalizeSearchText(value) {
  return normalizeSearchTextPreservingDiacritics(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d");
}

function tokenize(value) {
  const normalized = normalizeSearchText(value);
  return normalized ? normalized.split(" ") : [];
}

function tokenizePreservingDiacritics(value) {
  const normalized = normalizeSearchTextPreservingDiacritics(value);
  return normalized ? normalized.split(" ") : [];
}

function uniqueTokens(values) {
  return Array.from(new Set(values));
}

function buildExactSearchTerms(post) {
  return uniqueTokens([
    ...tokenize(post?.content),
    ...(Array.isArray(post?.tags) ? post.tags.flatMap(tokenize) : []),
  ]);
}

function buildSearchTerms(post) {
  const tokens = buildExactSearchTerms(post);
  const terms = new Set();

  for (const token of tokens) {
    terms.add(token);
    const prefixEnd = Math.min(token.length, MAX_PREFIX_LENGTH);
    for (let length = MIN_PREFIX_LENGTH; length <= prefixEnd; length += 1) {
      terms.add(token.slice(0, length));
      if (terms.size >= MAX_INDEX_TERMS) return Array.from(terms);
    }
  }
  return Array.from(terms);
}

function isTermMatch(queryTerm, contentTerm) {
  if (queryTerm === contentTerm) return true;
  if (queryTerm.length < MIN_PREFIX_LENGTH) return false;
  if (!contentTerm.startsWith(queryTerm)) return false;
  return queryTerm.length / contentTerm.length >= 0.5;
}

function meaningfulPartialTerms(queryTerms) {
  const meaningful = queryTerms.filter((term) => !PARTIAL_STOP_WORDS.has(term));
  return meaningful.length ? meaningful : queryTerms;
}

function matchedTerms(queryTerms, targetTerms) {
  return queryTerms.filter((queryTerm) =>
    targetTerms.some((targetTerm) => isTermMatch(queryTerm, targetTerm))
  );
}

function hasEnoughPartialCoverage(queryTerms, matches) {
  if (!queryTerms.length || !matches.length) return false;
  const minimumMatchCount = queryTerms.length <= 2
    ? 1
    : Math.ceil(queryTerms.length / 2);
  if (matches.length < minimumMatchCount) return false;

  const totalWeight = queryTerms.reduce((sum, term) => sum + term.length, 0);
  const matchedWeight = matches.reduce((sum, term) => sum + term.length, 0);
  return totalWeight > 0 &&
    matchedWeight / totalWeight >= MIN_PARTIAL_WEIGHT_COVERAGE;
}

function diacriticSensitiveShortTerms(rawQuery) {
  const accentTerms = tokenizePreservingDiacritics(rawQuery);
  const foldedTerms = tokenize(rawQuery);
  return accentTerms.filter((term, index) =>
    foldedTerms[index]?.length <= 3 && term !== foldedTerms[index]
  );
}

function hasDiacriticSensitiveMatch(post, rawQuery) {
  const queryTerms = uniqueTokens(diacriticSensitiveShortTerms(rawQuery));
  if (!queryTerms.length) return true;
  const contentTerms = uniqueTokens(tokenizePreservingDiacritics(post?.content));
  const hashtagTerms = uniqueTokens(
    Array.isArray(post?.tags)
      ? post.tags.flatMap(tokenizePreservingDiacritics)
      : []
  );
  return queryTerms.every((term) =>
    contentTerms.includes(term) || hashtagTerms.includes(term)
  );
}

function shortQueryMatchQuality(post, rawQuery) {
  const foldedTerms = tokenize(rawQuery);
  if (foldedTerms.length !== 1 || foldedTerms[0].length > 3) return 1;

  const accentQuery = tokenizePreservingDiacritics(rawQuery)[0] || "";
  const accentTargets = [
    ...tokenizePreservingDiacritics(post?.content),
    ...(Array.isArray(post?.tags)
      ? post.tags.flatMap(tokenizePreservingDiacritics)
      : []),
  ];
  return accentTargets.includes(accentQuery) ? 1 : 0.6;
}

function scorePostSearchMatch(post, rawQuery) {
  const query = normalizeSearchText(rawQuery);
  if (!query) return null;

  const queryTerms = uniqueTokens(tokenize(query));
  const content = normalizeSearchText(post?.content);
  const contentTerms = uniqueTokens(tokenize(content));
  const hashtagTerms = uniqueTokens(
    Array.isArray(post?.tags) ? post.tags.flatMap(tokenize) : []
  );

  if (
    !hasDiacriticSensitiveMatch(post, rawQuery)
  ) {
    return null;
  }

  let matchType = null;
  if (content && content === query) {
    matchType = MATCH_TYPES.exactSentence;
  } else if (content && (` ${content} `).includes(` ${query} `)) {
    matchType = MATCH_TYPES.keyPhrase;
  } else if (
    queryTerms.length > 0 &&
    queryTerms.every((term) => contentTerms.includes(term))
  ) {
    matchType = MATCH_TYPES.allTerms;
  } else {
    const partialTerms = meaningfulPartialTerms(queryTerms);
    const contentMatches = matchedTerms(partialTerms, contentTerms);
    const hashtagMatches = matchedTerms(partialTerms, hashtagTerms);

    if (hasEnoughPartialCoverage(partialTerms, contentMatches)) {
      matchType = MATCH_TYPES.partial;
    } else if (hasEnoughPartialCoverage(partialTerms, hashtagMatches)) {
      matchType = MATCH_TYPES.hashtagOnly;
    }
  }

  if (!matchType) return null;
  return {
    matchType,
    score: MATCH_SCORES[matchType],
    matchQuality: shortQueryMatchQuality(post, rawQuery),
  };
}

module.exports = {
  MATCH_SCORES,
  MATCH_TYPES,
  buildExactSearchTerms,
  buildSearchTerms,
  normalizeSearchText,
  normalizeSearchTextPreservingDiacritics,
  scorePostSearchMatch,
  tokenize,
  tokenizePreservingDiacritics,
};
