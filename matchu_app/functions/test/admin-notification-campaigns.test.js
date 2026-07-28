const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __test: {
    buildCampaignMessage,
    compareVersions,
    inboxTypeForCategory,
    matchesDeviceRules,
    matchesUserRules,
    normalizeMetrics,
  },
} = require("../src/triggers/adminNotificationCampaigns");

test("builds a safe cross-platform admin campaign payload", () => {
  const result = buildCampaignMessage(
    {
      id: "campaign-1",
      category: "maintenance",
      title: "Bảo trì hệ thống",
      body: "MatchU sẽ bảo trì lúc 23:00.",
      action: { type: "app_route", value: "notifications" },
    },
    "token-1"
  );

  assert.equal(result.token, "token-1");
  assert.equal(result.data.type, "admin_campaign");
  assert.equal(result.data.campaignId, "campaign-1");
  assert.equal(result.android.notification.channelId, "system_announcements");
  assert.equal(result.apns.payload.aps.alert.title, "Bảo trì hệ thống");
});

test("compares application versions numerically", () => {
  assert.equal(compareVersions("1.10.0", "1.9.9"), 1);
  assert.equal(compareVersions("2.0.0+12", "2.0.0+3"), 1);
  assert.equal(compareVersions("1.0", "1.0.0"), 0);
});

test("matches user and device segment rules", () => {
  assert.equal(
    matchesUserRules(
      {
        accountStatus: "active",
        gender: "female",
        reputationScore: 90,
        isFaceVerified: true,
        interests: ["du lịch", "âm nhạc"],
      },
      {
        accountStatuses: ["active"],
        genders: ["female"],
        verification: "face_verified",
        minReputation: 80,
        interestTags: ["âm nhạc"],
      }
    ),
    true
  );
  assert.equal(
    matchesDeviceRules(
      { platform: "android", appVersion: "1.3.0" },
      { platforms: ["android"], minAppVersion: "1.2.0", maxAppVersion: "1.9.0" }
    ),
    true
  );
  assert.equal(
    matchesDeviceRules(
      { platform: "ios", appVersion: "1.3.0" },
      { platforms: ["android"] }
    ),
    false
  );
});

test("maps inbox categories and normalizes missing counters", () => {
  assert.equal(inboxTypeForCategory("policy_update"), "policy_update");
  assert.equal(inboxTypeForCategory("general"), "system_announcement");
  assert.deepEqual(normalizeMetrics({ acceptedDevices: 2 }), {
    eligibleUsers: 0,
    skippedUsers: 0,
    attemptedDevices: 0,
    acceptedDevices: 2,
    failedDevices: 0,
    inboxCreated: 0,
    invalidTokens: 0,
  });
});
