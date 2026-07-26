const test = require("node:test");
const assert = require("node:assert/strict");

const { __test } = require("../src/callables/tempChatSession");

test("normalizes supported gender aliases", () => {
  assert.equal(__test.normalizeGender("nam"), "male");
  assert.equal(__test.normalizeGender("Nữ"), "female");
  assert.equal(__test.normalizeGender("unknown"), "random");
});

test("matching preference must be mutual", () => {
  assert.equal(
    __test.isMutualMatch(
      { gender: "male", targetGender: "female" },
      { gender: "female", targetGender: "male" }
    ),
    true
  );
  assert.equal(
    __test.isMutualMatch(
      { gender: "male", targetGender: "female" },
      { gender: "female", targetGender: "female" }
    ),
    false
  );
});

test("matching mode must be mutual", () => {
  assert.equal(__test.normalizeMatchingMode("VIDEO"), "video");
  assert.equal(__test.normalizeMatchingMode("unknown"), "chat");
  assert.equal(
    __test.isMutualMatch(
      { gender: "male", targetGender: "random", matchingMode: "video" },
      { gender: "female", targetGender: "random", matchingMode: "chat" }
    ),
    false
  );
});

test("temp chat matching requires at least 80 reputation points", () => {
  assert.equal(
    __test.hasSufficientMatchingReputation({ reputationScore: 79 }, "chat"),
    false
  );
  assert.equal(
    __test.hasSufficientMatchingReputation({ reputationScore: 80 }, "chat"),
    true
  );
});

test("video matching requires at least 90 reputation points", () => {
  assert.equal(
    __test.hasSufficientMatchingReputation({ reputationScore: 89 }, "video"),
    false
  );
  assert.equal(
    __test.hasSufficientMatchingReputation({ reputationScore: 90 }, "video"),
    true
  );
});

test("video matching requires one gem while chat matching does not", () => {
  assert.equal(__test.gemBalanceFrom({ gem: 3 }), 3);
  assert.equal(__test.gemBalanceFrom({}), 15);
  assert.doesNotThrow(() =>
    __test.assertSufficientVideoGem({ gem: 0 }, "chat", "seeker")
  );
  assert.throws(
    () => __test.assertSufficientVideoGem({ gem: 0 }, "video", "seeker"),
    (error) => error.code === "resource-exhausted" &&
      error.details.reason === "insufficient-gem" &&
      error.details.requiredGem === 1 &&
      error.details.currentGem === 0
  );
});

test("video gem transaction ids are deterministic per room and user", () => {
  assert.equal(
    __test.videoMatchChargeId("room-a", "user-a"),
    "video_match_room-a_user-a"
  );
  assert.equal(
    __test.videoMatchRefundId("room-a", "user-a"),
    "video_match_refund_room-a_user-a"
  );
});

test("room extension is available only in the last minute", () => {
  const now = 1_000_000;
  const room = {
    status: "active",
    participants: ["user-a", "user-b"],
    extensionCount: 0,
    expiresAt: { toMillis: () => now + 60_000 },
  };

  assert.equal(
    __test.roomExtensionFailureReason(room, "user-a", now),
    null
  );
  assert.equal(
    __test.roomExtensionFailureReason({
      ...room,
      expiresAt: { toMillis: () => now + 60_001 },
    }, "user-a", now),
    "too-early"
  );
  assert.equal(
    __test.roomExtensionFailureReason({
      ...room,
      expiresAt: { toMillis: () => now },
    }, "user-a", now),
    "room-expired"
  );
});

test("room extension enforces participant and two-use limits", () => {
  const now = 1_000_000;
  const room = {
    status: "active",
    participants: ["user-a", "user-b"],
    extensionCount: 2,
    expiresAt: { toMillis: () => now + 30_000 },
  };

  assert.equal(
    __test.roomExtensionFailureReason(room, "user-c", now),
    "not-participant"
  );
  assert.equal(
    __test.roomExtensionFailureReason(room, "user-a", now),
    "extension-limit-reached"
  );
  assert.equal(
    __test.roomExtensionChargeId("room-a", 2),
    "room_extension_room-a_2"
  );
});

test("video face admission requires enrollment and a fresh device-bound proof", () => {
  const nowMillis = Date.parse("2026-07-23T00:00:00.000Z");
  const validInput = {
    userData: { isFaceVerified: true },
    enrollmentData: { isActive: true },
    proofData: {
      uid: "user-a",
      status: "valid",
      purpose: "video_matching",
      deviceId: "device-a",
      useCount: 1,
      maxUses: 3,
      expiresAt: { toMillis: () => nowMillis + 60_000 },
    },
    uid: "user-a",
    deviceId: "device-a",
    nowMillis,
  };

  assert.equal(__test.faceProofFailureReason(validInput), null);
  assert.equal(
    __test.faceProofFailureReason({
      ...validInput,
      userData: { isFaceVerified: false },
    }),
    "face-enrollment-required"
  );
  assert.equal(
    __test.faceProofFailureReason({
      ...validInput,
      proofData: { ...validInput.proofData, useCount: 3 },
    }),
    "face-reauth-required"
  );
  assert.equal(
    __test.faceProofFailureReason({
      ...validInput,
      deviceId: "another-device",
    }),
    "face-proof-device-mismatch"
  );
});

test("video face admission feature flag is secure by default", () => {
  assert.equal(
    __test.isVideoMatchingFaceVerificationEnabled(undefined),
    true
  );
  assert.equal(
    __test.isVideoMatchingFaceVerificationEnabled("true"),
    true
  );
  assert.equal(
    __test.isVideoMatchingFaceVerificationEnabled("false"),
    false
  );
});

test("legacy profiles without reputation retain the default score", () => {
  assert.equal(__test.reputationScoreFrom({}), 100);
  assert.equal(__test.hasSufficientMatchingReputation({}, "video"), true);
});

test("insufficient reputation returns machine-readable error details", () => {
  assert.throws(
    () => __test.assertMatchingReputation(
      { reputationScore: 70 },
      "video",
      "seeker"
    ),
    (error) => error.code === "failed-precondition" &&
      error.details.reason === "insufficient-reputation" &&
      error.details.requiredReputation === 90 &&
      error.details.currentReputation === 70
  );
});

test("verified users do not consume daily quota", () => {
  const patch = __test.quotaPatch(
    { isFaceVerified: true, dailyMatchingCount: 10 },
    new Date("2026-07-16T12:00:00.000Z")
  );
  assert.deepEqual(patch, {});
});

test("daily quota resets using the Bangkok calendar day", () => {
  const now = new Date("2026-07-16T18:30:00.000Z");
  assert.equal(__test.bangkokDateKey(now), "2026-07-17");
  assert.deepEqual(
    __test.quotaPatch(
      { dailyMatchingDate: "2026-07-16", dailyMatchingCount: 9 },
      now
    ),
    { dailyMatchingDate: "2026-07-17", dailyMatchingCount: 1 }
  );
});

test("daily quota rejects the eleventh unverified match", () => {
  const now = new Date("2026-07-16T12:00:00.000Z");
  assert.throws(
    () => __test.quotaPatch({
      dailyMatchingDate: __test.bangkokDateKey(now),
      dailyMatchingCount: 10,
    }, now),
    (error) => error.code === "resource-exhausted"
  );
});

test("only resumes an active temp room that contains the user", () => {
  assert.equal(
    __test.isActiveTempRoomForUser(
      { status: "active", participants: ["user-a", "user-b"] },
      "user-a"
    ),
    true
  );
  assert.equal(
    __test.isActiveTempRoomForUser(
      { status: "ended", participants: ["user-a", "user-b"] },
      "user-a"
    ),
    false
  );
  assert.equal(
    __test.isActiveTempRoomForUser(
      { status: "active", participants: ["user-b", "user-c"] },
      "user-a"
    ),
    false
  );
});

test("room expiration task ids are deterministic per expiration version", () => {
  const first = __test.roomExpirationTaskId("room-a", 1_000_000);
  assert.equal(first, __test.roomExpirationTaskId("room-a", 1_000_000));
  assert.notEqual(first, __test.roomExpirationTaskId("room-a", 1_300_000));
  assert.notEqual(first, __test.roomExpirationTaskId("room-b", 1_000_000));
  assert.match(first, /^room-expiry-[a-f0-9]{40}$/);
});

test("room expiration descriptors retain room identity for fallback recovery", () => {
  assert.deepEqual(
    __test.roomExpirationDescriptor(" room-a ", {
      expiresAt: { toMillis: () => 1_000_000 },
    }),
    { roomId: "room-a", expiresAtMillis: 1_000_000 }
  );
  assert.deepEqual(
    __test.roomExpirationDescriptor("room-a", {}),
    { roomId: "room-a", expiresAtMillis: null }
  );
  assert.equal(__test.roomExpirationDescriptor("", {}), null);
});

test("expiration task only ends the matching active room version when due", () => {
  const activeRoom = {
    status: "active",
    expiresAt: { toMillis: () => 1_000_000 },
  };

  assert.equal(
    __test.roomExpirationDecision(activeRoom, 1_000_000, 999_999),
    "not-due"
  );
  assert.equal(
    __test.roomExpirationDecision(activeRoom, 1_000_000, 1_000_000),
    "expire"
  );
  assert.equal(
    __test.roomExpirationDecision(activeRoom, 900_000, 1_000_000),
    "stale"
  );
  assert.equal(
    __test.roomExpirationDecision(
      { ...activeRoom, status: "ended" },
      1_000_000,
      1_000_000
    ),
    "already-ended"
  );
});
