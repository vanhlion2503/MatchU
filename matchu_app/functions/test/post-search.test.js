const test = require("node:test");
const assert = require("node:assert/strict");

const {
  MATCH_TYPES,
  buildExactSearchTerms,
  buildSearchTerms,
  normalizeSearchText,
  normalizeSearchTextPreservingDiacritics,
  scorePostSearchMatch,
} = require("../src/search/postSearch");

test("normalization ignores Vietnamese accents, case and punctuation", () => {
  assert.equal(normalizeSearchText("  Cà Phê ĐẸP! "), "ca phe dep");
  assert.equal(
    normalizeSearchTextPreservingDiacritics("  Cà Phê ĐẸP! "),
    "cà phê đẹp"
  );
});

test("search scores follow the required precedence", () => {
  assert.deepEqual(
    scorePostSearchMatch({ content: "Học Flutter GetX", tags: [] }, "hoc flutter getx"),
    { matchType: MATCH_TYPES.exactSentence, score: 1, matchQuality: 1 }
  );
  assert.deepEqual(
    scorePostSearchMatch({ content: "Hôm nay học Flutter GetX nhé", tags: [] }, "flutter getx"),
    { matchType: MATCH_TYPES.keyPhrase, score: 0.85, matchQuality: 1 }
  );
  assert.deepEqual(
    scorePostSearchMatch({ content: "GetX giúp Flutter gọn hơn", tags: [] }, "flutter getx"),
    { matchType: MATCH_TYPES.allTerms, score: 0.7, matchQuality: 1 }
  );
  assert.deepEqual(
    scorePostSearchMatch({ content: "Flutter rất vui", tags: [] }, "flutter getx"),
    { matchType: MATCH_TYPES.partial, score: 0.4, matchQuality: 1 }
  );
  assert.deepEqual(
    scorePostSearchMatch({ content: "Một bài viết khác", tags: ["Flutter"] }, "flutter"),
    { matchType: MATCH_TYPES.hashtagOnly, score: 0.5, matchQuality: 1 }
  );
});

test("short query terms do not act as broad prefixes", () => {
  assert.equal(
    scorePostSearchMatch({ content: "Android rất thú vị", tags: [] }, "an"),
    null
  );
  assert.equal(
    scorePostSearchMatch({ content: "Kinh nghiệm du học", tags: [] }, "du lịch"),
    null
  );
});

test("short accented queries require the same Vietnamese diacritics", () => {
  assert.equal(
    scorePostSearchMatch({ content: "Ca sĩ biểu diễn", tags: [] }, "cá"),
    null
  );
  assert.deepEqual(
    scorePostSearchMatch({ content: "Cá cảnh rất đẹp", tags: [] }, "cá"),
    { matchType: MATCH_TYPES.keyPhrase, score: 0.85, matchQuality: 1 }
  );
  assert.equal(
    scorePostSearchMatch({ content: "Ca ngon trong tối nay", tags: [] }, "cá ngon"),
    null
  );
});

test("unaccented ambiguous short terms rank literal spelling first", () => {
  const literal = scorePostSearchMatch(
    { content: "Ca sĩ biểu diễn", tags: [] },
    "ca"
  );
  const foldedOnly = scorePostSearchMatch(
    { content: "Cà phê buổi sáng", tags: [] },
    "ca"
  );
  assert.equal(literal.matchQuality, 1);
  assert.equal(foldedOnly.matchQuality, 0.6);
});

test("search index separates exact terms from safe prefixes", () => {
  const terms = buildSearchTerms({ content: "Flutter", tags: ["GetX"] });
  const exactTerms = buildExactSearchTerms({
    content: "Flutter an",
    tags: ["GetX"],
  });
  assert.ok(!terms.includes("fl"));
  assert.ok(!terms.includes("flu"));
  assert.ok(terms.includes("flut"));
  assert.ok(terms.includes("flutter"));
  assert.ok(terms.includes("getx"));
  assert.ok(exactTerms.includes("an"));
  assert.ok(!exactTerms.includes("flut"));
});
