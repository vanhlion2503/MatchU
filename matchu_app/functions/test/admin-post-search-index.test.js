const test = require("node:test");
const assert = require("node:assert/strict");
const {
  _test: { buildAdminPostSearchTerms, normalizeSearchText },
} = require("../src/triggers/adminPostSearchIndex");

test("normalizes Vietnamese admin post search text", () => {
  assert.equal(normalizeSearchText("  Nguyễn Đăng  "), "nguyen dang");
});

test("indexes post identity, author, content, tags and substring ngrams", () => {
  const terms = buildAdminPostSearchTerms("post-1", {
    authorId: "user-1",
    author: { name: "Nguyễn An", nickname: "an" },
    content: "Âm nhạc mùa hè",
    tags: ["giải trí"],
  });
  assert.ok(terms.includes("post"));
  assert.ok(terms.includes("user"));
  assert.ok(terms.includes("nhac"));
  assert.ok(terms.includes("mua"));
  assert.ok(terms.includes("guy"));
});
