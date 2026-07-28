const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __test: { buildPostEngagementText },
} = require("../src/triggers/socialNotifications");

test("builds a direct title for one like", () => {
  assert.deepEqual(
    buildPostEngagementText({
      likeCount: 1,
      commentCount: 0,
      lastActorName: "An",
    }),
    {
      title: "An \u0111\u00E3 th\u00EDch b\u00E0i vi\u1EBFt c\u1EE7a b\u1EA1n",
      body: "Nh\u1EA5n \u0111\u1EC3 xem b\u00E0i vi\u1EBFt.",
    }
  );
});

test("uses the latest comment preview for one comment", () => {
  const result = buildPostEngagementText({
    likeCount: 0,
    commentCount: 1,
    lastActorName: "Binh",
    lastCommentPreview: "B\u00E0i vi\u1EBFt hay qu\u00E1!",
  });

  assert.equal(
    result.title,
    "Binh \u0111\u00E3 b\u00ECnh lu\u1EADn b\u00E0i vi\u1EBFt c\u1EE7a b\u1EA1n"
  );
  assert.equal(result.body, "B\u00E0i vi\u1EBFt hay qu\u00E1!");
});

test("uses a reply title when the latest activity answers a comment", () => {
  const result = buildPostEngagementText({
    likeCount: 0,
    commentCount: 1,
    lastActorName: "Lan",
    lastEventType: "reply",
    lastCommentPreview: "Cảm ơn bạn!",
  });

  assert.equal(result.title, "Lan đã trả lời bình luận của bạn");
  assert.equal(result.body, "Cảm ơn bạn!");
});

test("summarizes a burst of likes and comments", () => {
  assert.deepEqual(
    buildPostEngagementText({ likeCount: 7, commentCount: 3 }),
    {
      title: "B\u00E0i vi\u1EBFt c\u1EE7a b\u1EA1n c\u00F3 10 t\u01B0\u01A1ng t\u00E1c m\u1EDBi",
      body: "7 l\u01B0\u1EE3t th\u00EDch v\u00E0 3 b\u00ECnh lu\u1EADn",
    }
  );
});
