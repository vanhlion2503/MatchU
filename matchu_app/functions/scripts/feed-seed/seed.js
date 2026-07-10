"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const admin = require("firebase-admin");
const { CONTENT_BY_TOPIC, TOPIC_GROUPS, TOPICS } = require("./content");

const PROTECTED_PROJECT_IDS = new Set(["matchu-5bd75"]);
const BATCH_COLLECTION = "_seedBatches";
const MAX_BATCH_DATA_WRITES = 220;
const COMMENT_TEXTS = Object.freeze([
  "Mình cũng từng thử cách này và thấy khá hiệu quả.",
  "Góc nhìn hay quá, cảm ơn bạn đã chia sẻ!",
  "Mình đang quan tâm chủ đề này, bạn kể thêm được không?",
  "Đọc xong có thêm động lực để bắt đầu luôn. ✨",
  "Ý này hợp lý, nhất là phần duy trì đều đặn.",
  "Mình chọn phương án thứ hai vì dễ áp dụng hơn.",
  "Lưu lại để cuối tuần thử nhé.",
  "Có ai đã áp dụng lâu hơn một tháng chưa?",
]);

function parseBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === "") return fallback;
  if (typeof value === "boolean") return value;
  return ["1", "true", "yes", "on"].includes(String(value).toLowerCase());
}

function parseInteger(
  value,
  fallback,
  name,
  { min = 0, max = Number.MAX_SAFE_INTEGER } = {},
) {
  if (value === undefined || value === null || value === "") return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new Error(`${name} must be an integer from ${min} to ${max}.`);
  }
  return parsed;
}

function splitCsv(value) {
  if (!value) return [];
  return String(value)
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function normalizeTopic(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function resolveTopics(value) {
  const requested = splitCsv(value);
  if (requested.length === 0 || requested.includes("all")) return [...TOPICS];
  const byNormalized = new Map(
    TOPICS.map((topic) => [normalizeTopic(topic), topic]),
  );
  const resolved = requested.map((topic) =>
    byNormalized.get(normalizeTopic(topic)),
  );
  const unknown = requested.filter((_, index) => !resolved[index]);
  if (unknown.length > 0) {
    throw new Error(
      `Unknown topics: ${unknown.join(", ")}. Supported: ${TOPICS.join(", ")}`,
    );
  }
  return [...new Set(resolved)];
}

function parseRatios(value) {
  const result = { text: 0.72, image: 0.23, video: 0.05 };
  if (value) {
    for (const pair of splitCsv(value)) {
      const [rawKey, rawValue] = pair.split("=");
      const key = String(rawKey || "")
        .trim()
        .toLowerCase();
      const numeric = Number(rawValue);
      if (
        !Object.hasOwn(result, key) ||
        !Number.isFinite(numeric) ||
        numeric < 0
      ) {
        throw new Error(
          `Invalid media ratio '${pair}'. Use text=0.7,image=0.25,video=0.05.`,
        );
      }
      result[key] = numeric;
    }
  }
  const total = result.text + result.image + result.video;
  if (total <= 0)
    throw new Error("At least one media ratio must be greater than zero.");
  return Object.fromEntries(
    Object.entries(result).map(([key, ratio]) => [key, ratio / total]),
  );
}

function loadMediaConfig(filePath) {
  if (!filePath)
    return { imageUrls: [], videoUrls: [], videoThumbnailUrls: [] };
  const absolutePath = path.resolve(filePath);
  const raw = JSON.parse(fs.readFileSync(absolutePath, "utf8"));
  const validUrls = (value, key) => {
    if (!Array.isArray(value))
      throw new Error(`${key} in media config must be an array.`);
    return value
      .map((item) => String(item).trim())
      .filter((url) => {
        try {
          const parsed = new URL(url);
          return parsed.protocol === "https:";
        } catch (_) {
          return false;
        }
      });
  };
  return {
    imageUrls: validUrls(raw.imageUrls || [], "imageUrls"),
    videoUrls: validUrls(raw.videoUrls || [], "videoUrls"),
    videoThumbnailUrls: validUrls(
      raw.videoThumbnailUrls || [],
      "videoThumbnailUrls",
    ),
  };
}

async function validateConfiguredMediaUrls(mediaConfig) {
  const urls = [
    ...mediaConfig.imageUrls,
    ...mediaConfig.videoUrls,
    ...mediaConfig.videoThumbnailUrls,
  ];
  for (const url of [...new Set(urls)]) {
    let response;
    try {
      response = await fetch(url, {
        method: "HEAD",
        redirect: "follow",
        signal: AbortSignal.timeout(10000),
      });
      if (!response.ok) {
        response = await fetch(url, {
          method: "GET",
          headers: { Range: "bytes=0-0" },
          redirect: "follow",
          signal: AbortSignal.timeout(10000),
        });
      }
    } catch (error) {
      throw new Error(
        `Media URL is unreachable and will not be seeded: ${url} (${error?.message || String(error)})`,
      );
    } finally {
      await response?.body?.cancel();
    }
    if (!response?.ok) {
      throw new Error(
        `Media URL returned HTTP ${response?.status || "unknown"} and will not be seeded: ${url}`,
      );
    }
  }
}

function sanitizeId(value) {
  return String(value || "")
    .trim()
    .replace(/[^A-Za-z0-9_-]/g, "_")
    .slice(0, 70);
}

function hashNumber(value) {
  return Number.parseInt(
    crypto.createHash("sha256").update(String(value)).digest("hex").slice(0, 8),
    16,
  );
}

function manifestId(documentPath) {
  return crypto.createHash("sha256").update(documentPath).digest("hex");
}

function topicGroupIndex(topic) {
  const index = TOPIC_GROUPS.findIndex((group) => group.includes(topic));
  return index < 0 ? 0 : index;
}

function validateOptions(options) {
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{2,69}$/.test(options.seedBatchId)) {
    throw new Error(
      "SEED_BATCH_ID must be 3-70 characters: letters, digits, '_' or '-'.",
    );
  }
  if (
    options.count < options.authorCount * 3 ||
    options.count > options.authorCount * 15
  ) {
    throw new Error(
      "Post count must keep every author in the requested 3-15 posts range.",
    );
  }
  if (options.count < options.topics.length * 3) {
    throw new Error(
      "Post count must allow all three hand-written variants for every selected topic. Increase --count or select fewer topics.",
    );
  }
  if (!["emulator", "development", "production"].includes(options.target)) {
    throw new Error("--target must be emulator, development, or production.");
  }
  if (!["existing", "mixed", "seed"].includes(options.authorSource)) {
    throw new Error("--author-source must be existing, mixed, or seed.");
  }
}

function assertSafety(options) {
  if (process.env.ALLOW_FIRESTORE_SEED !== "true") {
    throw new Error(
      "Refusing to continue: set ALLOW_FIRESTORE_SEED=true explicitly.",
    );
  }
  if (!options.projectId)
    throw new Error("FIREBASE_PROJECT_ID (or --project-id) is required.");
  if (options.target === "emulator") {
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      throw new Error(
        "Emulator target requires FIRESTORE_EMULATOR_HOST (for example 127.0.0.1:8080).",
      );
    }
    return;
  }
  if (options.target === "production") {
    if (process.env.SEED_ENVIRONMENT !== "production") {
      throw new Error("Production writes require SEED_ENVIRONMENT=production.");
    }
    if (process.env.ALLOW_PRODUCTION_FIRESTORE_SEED !== "true") {
      throw new Error(
        "Production writes require ALLOW_PRODUCTION_FIRESTORE_SEED=true.",
      );
    }
    if (process.env.CONFIRM_FIREBASE_PROJECT_ID !== options.projectId) {
      throw new Error(
        "CONFIRM_FIREBASE_PROJECT_ID must exactly match FIREBASE_PROJECT_ID.",
      );
    }
    if (process.env.CONFIRM_PUBLIC_FEED_SEED !== "true") {
      throw new Error(
        "Production writes require CONFIRM_PUBLIC_FEED_SEED=true.",
      );
    }
    if (!PROTECTED_PROJECT_IDS.has(options.projectId)) {
      throw new Error(
        `Project '${options.projectId}' is not an explicitly registered production project.`,
      );
    }
    if (options.authorSource !== "seed" || !options.createSeedUsers) {
      throw new Error(
        "Production writes require --author-source seed and --create-seed-users.",
      );
    }
    if (
      options.includeModerationTestData ||
      options.includeReports ||
      options.includeRestrictions
    ) {
      throw new Error(
        "Production mode forbids moderation-test, report, and restriction seed data.",
      );
    }
    if (process.env.FIRESTORE_EMULATOR_HOST) {
      throw new Error(
        "Unset FIRESTORE_EMULATOR_HOST before targeting production.",
      );
    }
    return;
  }
  if (process.env.SEED_ENVIRONMENT !== "development") {
    throw new Error("Development writes require SEED_ENVIRONMENT=development.");
  }
  if (PROTECTED_PROJECT_IDS.has(options.projectId)) {
    throw new Error(
      `Project '${options.projectId}' is production-protected by this repository and cannot be seeded.`,
    );
  }
  if (
    !options.dryRun &&
    !options.deleteBatch &&
    options.authorSource !== "seed"
  ) {
    throw new Error(
      "Development writes require --author-source seed so Cloud Function side effects cannot mutate existing users.",
    );
  }
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "Unset FIRESTORE_EMULATOR_HOST before targeting a development project.",
    );
  }
}

function initializeFirestore(options) {
  if (admin.apps.length === 0) {
    const appOptions = { projectId: options.projectId };
    if (options.target === "development" || options.target === "production")
      appOptions.credential = admin.credential.applicationDefault();
    admin.initializeApp(appOptions);
  }
  const db = admin.firestore();
  db.settings({ ignoreUndefinedProperties: true });
  return db;
}

function userSnapshot(doc) {
  const data = doc.data() || {};
  const nickname = String(data.nickname || "").trim();
  const fullname = String(data.fullname || "").trim();
  return {
    id: doc.id,
    name: fullname || nickname || "Người dùng",
    nickname,
    avatar: String(data.avatarUrl || "").trim(),
    isVerified: data.isFaceVerified === true,
    isSeedData: data.isSeedData === true,
    interests: Array.isArray(data.interests)
      ? data.interests.map((item) => String(item))
      : [],
    data,
  };
}

function buildSeedUser(options, index, role = "author") {
  const id = `seed_${sanitizeId(options.seedBatchId)}_${role}_${String(index + 1).padStart(2, "0")}`;
  const group = TOPIC_GROUPS[index % TOPIC_GROUPS.length];
  const now = admin.firestore.Timestamp.now();
  const nickname = `${role === "actor" ? "persona" : "tacgia"}${index + 1}`;
  return {
    id,
    snapshot: {
      id,
      name:
        role === "actor"
          ? `Persona đề xuất ${index + 1}`
          : `Tác giả mẫu ${index + 1}`,
      nickname,
      avatar: "",
      isVerified: false,
      isSeedData: true,
      interests: group,
    },
    data: {
      uid: id,
      email: "",
      fullname:
        role === "actor"
          ? `Persona đề xuất ${index + 1}`
          : `Tác giả mẫu ${index + 1}`,
      nickname,
      phonenumber: "",
      bio: "Tài khoản Firestore chỉ dùng cho dữ liệu kiểm thử feed.",
      avatarUrl: "",
      interests: group,
      interestVector: [],
      interestWeight: 0,
      effectiveCount: 0,
      nearlyEnabled: false,
      reputationScore: 100,
      reputationTodayClaimed: 0,
      reputationTodayCap: 10,
      trustWarnings: 0,
      totalReports: 0,
      avgChatRating: 5,
      totalChatRatings: 0,
      followers: [],
      following: [],
      rank: 1,
      experience: 0,
      dailyExp: 0,
      totalPosts: 0,
      totalLikes: 0,
      activeStatus: "offline",
      accountStatus: "active",
      role: "user",
      isProfileCompleted: true,
      isFaceVerified: false,
      createdAt: now,
      updatedAt: now,
      isSeedData: true,
      seedBatchId: options.seedBatchId,
      seedRole: role,
    },
  };
}

async function loadAuthorsAndActors(db, options) {
  const usersSnap = await db
    .collection("users")
    .limit(Math.max(options.authorCount * 5, 50))
    .get();
  const existing = usersSnap.docs
    .map(userSnapshot)
    .filter((user) => user.data.accountStatus !== "disabled")
    .sort((a, b) => a.id.localeCompare(b.id));
  const existingSeed = existing.filter(
    (user) => user.isSeedData && user.data.seedBatchId === options.seedBatchId,
  );
  const existingAuthorSeed = existingSeed.filter(
    (user) => user.data.seedRole === "author",
  );
  const existingActorSeed = existingSeed.filter(
    (user) => user.data.seedRole === "actor",
  );
  const pendingDocs = [];
  let authors = [];

  if (options.authorSource === "seed") {
    authors = existingAuthorSeed.slice(0, options.authorCount);
  } else if (options.authorSource === "mixed") {
    const realTake = Math.ceil(options.authorCount / 2);
    authors = [
      ...existing.filter((user) => !user.isSeedData).slice(0, realTake),
      ...existingAuthorSeed,
    ].slice(0, options.authorCount);
  } else {
    authors = existing.slice(0, options.authorCount);
  }

  if (authors.length < options.authorCount) {
    if (!options.createSeedUsers) {
      throw new Error(
        `Only ${authors.length}/${options.authorCount} eligible authors found. Add --create-seed-users or change --author-source.`,
      );
    }
    const usedIds = new Set(authors.map((author) => author.id));
    for (let index = 0; authors.length < options.authorCount; index += 1) {
      const seedUser = buildSeedUser(options, index, "author");
      if (usedIds.has(seedUser.id)) continue;
      authors.push(seedUser.snapshot);
      pendingDocs.push({
        collection: "users",
        id: seedUser.id,
        data: seedUser.data,
        kind: "seedUser",
      });
      usedIds.add(seedUser.id);
    }
  }

  const actors = [];
  if (options.includeInteractions) {
    for (const existingActor of existingActorSeed) {
      if (actors.length >= options.interactionActorCount) break;
      actors.push(existingActor);
    }
    if (options.createSeedUsers) {
      for (
        let index = 0;
        actors.length < options.interactionActorCount;
        index += 1
      ) {
        const seedUser = buildSeedUser(options, index, "actor");
        if (actors.some((item) => item.id === seedUser.id)) continue;
        actors.push(seedUser.snapshot);
        pendingDocs.push({
          collection: "users",
          id: seedUser.id,
          data: seedUser.data,
          kind: "seedUser",
        });
      }
    } else {
      for (const author of authors.filter((item) => item.isSeedData)) {
        if (actors.length >= options.interactionActorCount) break;
        if (!actors.some((item) => item.id === author.id)) actors.push(author);
      }
      if (actors.length < options.interactionActorCount) {
        throw new Error(
          "Interaction seeding only uses seed-marked users. Add --create-seed-users.",
        );
      }
    }
  }

  return { authors, actors, pendingDocs };
}

function chooseCreatedAt(options, index, nowMillis) {
  const day = 86400000;
  const minute = 60000;
  const bucket = index % 5;
  let offset;
  if (bucket === 0) offset = (3 + (index % 43)) * minute;
  else if (bucket === 1) offset = (1 + (index % 20)) * 60 * minute;
  else if (bucket === 2)
    offset = (1 + (index % 7)) * day + (index % 12) * 60 * minute;
  else if (bucket === 3)
    offset = (8 + (index % 23)) * day + (index % 10) * 60 * minute;
  else
    offset =
      (31 +
        (hashNumber(`${options.seedBatchId}:${index}`) %
          Math.max(1, options.maxAgeDays - 30))) *
      day;
  return admin.firestore.Timestamp.fromMillis(nowMillis - offset);
}

function chooseMediaType(ratios, index) {
  const point = (hashNumber(`media:${index}`) % 10000) / 10000;
  if (point < ratios.text) return "text";
  if (point < ratios.text + ratios.image) return "image";
  return "video";
}

function buildMedia(mediaType, mediaConfig, index) {
  if (mediaType === "image" && mediaConfig.imageUrls.length > 0) {
    const count =
      index % 5 === 0 ? Math.min(3, mediaConfig.imageUrls.length) : 1;
    return Array.from({ length: count }, (_, position) => ({
      url: mediaConfig.imageUrls[
        (index + position) % mediaConfig.imageUrls.length
      ],
      type: "image",
      mimeType: "image/jpeg",
    }));
  }
  if (mediaType === "video" && mediaConfig.videoUrls.length > 0) {
    const thumbnailUrl =
      mediaConfig.videoThumbnailUrls.length > 0
        ? mediaConfig.videoThumbnailUrls[
            index % mediaConfig.videoThumbnailUrls.length
          ]
        : undefined;
    return [
      {
        url: mediaConfig.videoUrls[index % mediaConfig.videoUrls.length],
        type: "video",
        mimeType: "video/mp4",
        ...(thumbnailUrl ? { thumbnailUrl } : {}),
      },
    ];
  }
  return [];
}

function moderationFor(options, index, requestedVisibility) {
  if (!options.includeModerationTestData || index % 19 > 3) {
    return {
      status: "approved",
      visibility: requestedVisibility,
      requestedVisibility: null,
      deletedAt: null,
    };
  }
  if (index % 19 === 0) {
    return {
      status: "rejected",
      visibility: "private",
      requestedVisibility,
      deletedAt: null,
    };
  }
  if (index % 19 === 1) {
    return {
      status: "review_required",
      visibility: "private",
      requestedVisibility,
      deletedAt: null,
    };
  }
  if (index % 19 === 2) {
    return {
      status: "pending_moderation",
      visibility: "private",
      requestedVisibility,
      deletedAt: null,
    };
  }
  return {
    status: "approved",
    visibility: requestedVisibility,
    requestedVisibility: null,
    deletedAt: admin.firestore.Timestamp.fromMillis(Date.now() - 3600000),
  };
}

function referenceSnapshot(post) {
  return {
    postId: post.id,
    authorId: post.data.authorId,
    postType: post.data.postType,
    content: post.data.content,
    media: post.data.media,
    tags: post.data.tags,
    contentVector: post.data.contentVector || [],
    visibility: post.data.visibility,
    isPublic: post.data.isPublic,
    author: post.data.author,
    createdAt: post.data.createdAt,
    deletedAt: post.data.deletedAt,
  };
}

function buildPosts(options, authors, mediaConfig) {
  const nowMillis = Date.now();
  const posts = [];

  for (let index = 0; index < options.count; index += 1) {
    const topic = options.topics[index % options.topics.length];
    const groupIndex = topicGroupIndex(topic);
    const author = authors[index % authors.length];
    const variants = CONTENT_BY_TOPIC[topic];
    const variantIndex =
      Math.floor(index / options.topics.length) % variants.length;
    let content = variants[variantIndex];
    const id = `seed_${sanitizeId(options.seedBatchId)}_post_${String(index + 1).padStart(4, "0")}`;
    let postType = "post";
    let referencePost = null;
    const shareCandidates = posts.filter(
      (post) =>
        post.data.visibility === "public" &&
        post.data.moderationStatus === "approved" &&
        !post.data.deletedAt &&
        post.data.authorId !== author.id,
    );
    const mayCreateShare = index >= options.topics.length * 3;
    if (
      options.includeShares &&
      mayCreateShare &&
      author.isSeedData &&
      shareCandidates.length > 0 &&
      index % 17 === 0
    ) {
      postType = "quote";
      referencePost = shareCandidates[(index * 7) % shareCandidates.length];
      content =
        `Mình chia sẻ lại góc nhìn này vì thấy rất đáng để cùng thảo luận. ${content}`.slice(
          0,
          300,
        );
    } else if (
      options.includeShares &&
      mayCreateShare &&
      author.isSeedData &&
      shareCandidates.length > 0 &&
      index % 29 === 0
    ) {
      postType = "repost";
      referencePost = shareCandidates[(index * 5) % shareCandidates.length];
      content = "";
    }
    const visibilityRoll = index % 20;
    const requestedVisibility =
      visibilityRoll === 0
        ? "private"
        : visibilityRoll <= 2
          ? "followers"
          : "public";
    const moderation = moderationFor(options, index, requestedVisibility);
    const mediaType =
      postType === "repost" ? "text" : chooseMediaType(options.ratios, index);
    const media =
      postType === "repost" ? [] : buildMedia(mediaType, mediaConfig, index);
    if (postType === "post" && media.length > 0 && index % 7 === 0) {
      content = "";
    }
    const createdAt = chooseCreatedAt(options, index, nowMillis);
    const updatedAt = createdAt;
    posts.push({
      id,
      author,
      topic,
      popularity: [
        "none",
        "low",
        "medium",
        "popular",
        "comment-heavy",
        "save-heavy",
      ][index % 6],
      referencePost,
      data: {
        postId: id,
        authorId: author.id,
        postType,
        content,
        media,
        tags:
          index % 4 === 0
            ? [topic, TOPIC_GROUPS[groupIndex][0]].filter(
                (item, pos, list) => list.indexOf(item) === pos,
              )
            : [topic],
        contentVector: [],
        visibility: moderation.visibility,
        isPublic: moderation.visibility === "public",
        requestedVisibility: moderation.requestedVisibility,
        moderationStatus: moderation.status,
        moderationSource:
          options.includeModerationTestData && moderation.status !== "approved"
            ? "seed_test"
            : null,
        moderationMessageVi:
          options.includeModerationTestData && moderation.status !== "approved"
            ? "Dữ liệu kiểm thử bộ lọc; không hiển thị công khai."
            : null,
        moderationPolicyVersion:
          options.includeModerationTestData && moderation.status !== "approved"
            ? "seed_test_v1"
            : null,
        videoStoragePath: null,
        videoModeration: null,
        stats: { likeCount: 0, commentCount: 0, shareCount: 0, saveCount: 0 },
        trendScore: index % 11 === 0 ? 12 : index % 5,
        trendBucket: index % 4,
        author: {
          id: author.id,
          name: author.name,
          nickname: author.nickname,
          avatar: author.avatar,
          isVerified: author.isVerified,
        },
        referencePostId: referencePost?.id || null,
        referencePost: referencePost ? referenceSnapshot(referencePost) : null,
        createdAt,
        updatedAt,
        deletedAt: moderation.deletedAt,
        isSeedData: true,
        seedBatchId: options.seedBatchId,
        seedTopic: topic,
        seedPopularityProfile: [
          "none",
          "low",
          "medium",
          "popular",
          "comment-heavy",
          "save-heavy",
        ][index % 6],
      },
    });
  }

  for (const sharedPost of posts.filter((post) => post.referencePost)) {
    sharedPost.referencePost.data.stats.shareCount += 1;
  }
  return posts;
}

function desiredCounts(profile, actorCount) {
  const unique = Math.max(0, actorCount - 1);
  switch (profile) {
    case "low":
      return { likes: Math.min(1, unique), comments: 0, saves: 0 };
    case "medium":
      return {
        likes: Math.min(3, unique),
        comments: 2,
        saves: Math.min(1, unique),
      };
    case "popular":
      return {
        likes: Math.min(10, unique),
        comments: Math.min(7, actorCount * 2),
        saves: Math.min(5, unique),
      };
    case "comment-heavy":
      return {
        likes: Math.min(2, unique),
        comments: Math.min(10, actorCount * 2),
        saves: Math.min(1, unique),
      };
    case "save-heavy":
      return {
        likes: Math.min(2, unique),
        comments: 1,
        saves: Math.min(9, unique),
      };
    default:
      return { likes: 0, comments: 0, saves: 0 };
  }
}

function buildInteractions(options, posts, actors) {
  if (!options.includeInteractions || actors.length === 0) return [];
  const docs = [];
  // Actor zero is a deliberate cold-start persona with following data but no history.
  const activeActors = actors.slice(1);
  if (activeActors.length === 0) return docs;

  for (let postIndex = 0; postIndex < posts.length; postIndex += 1) {
    const post = posts[postIndex];
    if (post.data.deletedAt || post.data.moderationStatus !== "approved")
      continue;
    const counts = desiredCounts(post.popularity, activeActors.length + 1);
    const allEligibleActors = activeActors.filter(
      (actor) => actor.id !== post.data.authorId,
    );
    const preferredActors = allEligibleActors.filter((actor) =>
      (actor.interests || []).includes(post.topic),
    );
    const eligibleActors = [
      ...preferredActors,
      ...allEligibleActors.filter(
        (actor) =>
          !preferredActors.some((preferred) => preferred.id === actor.id),
      ),
    ];
    if (eligibleActors.length === 0) continue;

    const actualLikeCount = Math.min(counts.likes, eligibleActors.length);
    for (let index = 0; index < actualLikeCount; index += 1) {
      const actor = eligibleActors[(postIndex + index) % eligibleActors.length];
      docs.push({
        collection: `posts/${post.id}/likes`,
        id: actor.id,
        kind: "like",
        data: {
          userId: actor.id,
          createdAt: post.data.createdAt,
          isSeedData: true,
          seedBatchId: options.seedBatchId,
        },
      });
    }
    post.data.stats.likeCount = actualLikeCount;

    let firstCommentId = null;
    let replyCount = 0;
    for (let index = 0; index < counts.comments; index += 1) {
      const actor =
        eligibleActors[(postIndex + index + 1) % eligibleActors.length];
      const commentId = `seed_${sanitizeId(options.seedBatchId)}_comment_${String(postIndex + 1).padStart(4, "0")}_${String(index + 1).padStart(2, "0")}`;
      const isReply = index > 0 && index % 4 === 0 && firstCommentId;
      if (!firstCommentId) firstCommentId = commentId;
      if (isReply) replyCount += 1;
      docs.push({
        collection: `posts/${post.id}/comments`,
        id: commentId,
        kind: "comment",
        data: {
          commentId,
          userId: actor.id,
          content: COMMENT_TEXTS[(postIndex + index) % COMMENT_TEXTS.length],
          imageUrl: "",
          voiceUrl: "",
          voiceDurationMs: null,
          parentId: isReply ? firstCommentId : null,
          likeCount: 0,
          replyCount: 0,
          createdAt: admin.firestore.Timestamp.fromMillis(
            post.data.createdAt.toMillis() + (index + 1) * 90000,
          ),
          updatedAt: null,
          deletedAt: null,
          deletedBy: null,
          isEdited: false,
          isSeedData: true,
          seedBatchId: options.seedBatchId,
        },
      });
    }
    if (firstCommentId && replyCount > 0) {
      const first = docs.find((doc) => doc.id === firstCommentId);
      if (first) first.data.replyCount = replyCount;
    }
    post.data.stats.commentCount = counts.comments;

    const actualSaveCount = Math.min(counts.saves, eligibleActors.length);
    for (let index = 0; index < actualSaveCount; index += 1) {
      const actor =
        eligibleActors[(postIndex + index + 2) % eligibleActors.length];
      docs.push({
        collection: `users/${actor.id}/savedPosts`,
        id: post.id,
        kind: "savedPost",
        data: {
          postId: post.id,
          userId: actor.id,
          savedAt: post.data.createdAt,
          updatedAt: post.data.createdAt,
          isSeedData: true,
          seedBatchId: options.seedBatchId,
        },
      });
    }
    post.data.stats.saveCount = actualSaveCount;

    if (options.includeReports && postIndex % 31 === 0) {
      const actor = eligibleActors[postIndex % eligibleActors.length];
      const reportId = `seed_${sanitizeId(options.seedBatchId)}_report_${String(postIndex + 1).padStart(4, "0")}`;
      docs.push({
        collection: "postReports",
        id: reportId,
        kind: "postReport",
        data: {
          fromUid: actor.id,
          toUid: post.data.authorId,
          postId: post.id,
          postType: post.data.postType,
          postAuthorName: post.data.author.name,
          postAuthorNickname: post.data.author.nickname,
          postContentPreview: post.data.content.slice(0, 160),
          postMediaUrls: post.data.media.map((item) => item.url),
          categoryKey: "other",
          categoryTitle: "Khác",
          reasonKey: "community_guideline_violation",
          reasonTitle: "Vi phạm quy định cộng đồng",
          customReason: "",
          description: "Dữ liệu báo cáo an toàn dùng để kiểm thử.",
          imageUrls: [],
          source: "post",
          createdAt: post.data.createdAt,
          isSeedData: true,
          seedBatchId: options.seedBatchId,
        },
      });
    }
  }

  if (options.includeRestrictions && actors.length > 1 && posts.length > 0) {
    const actor = actors[1];
    const target = posts.find((post) => post.data.authorId !== actor.id);
    if (target) {
      docs.push({
        collection: `users/${actor.id}/hiddenPostAuthors`,
        id: target.data.authorId,
        kind: "hiddenPostAuthor",
        data: {
          userId: actor.id,
          authorId: target.data.authorId,
          displayName: target.data.author.name,
          nickname: target.data.author.nickname,
          avatarUrl: target.data.author.avatar,
          sourcePostId: target.id,
          hiddenAt: target.data.createdAt,
          updatedAt: target.data.createdAt,
        },
      });
    }
  }
  return docs;
}

async function generateRealEmbeddings(options, posts) {
  if (!options.generateEmbeddings) return;
  const {
    EMBEDDING_DIMENSIONS,
    EMBEDDING_MODEL,
    embeddingSignatureForPost,
    generatePostEmbedding,
  } = require("../../src/recommendation/embedding");
  const eligible = posts.filter(
    (post) =>
      post.data.visibility === "public" &&
      post.data.moderationStatus === "approved" &&
      !post.data.deletedAt &&
      post.data.postType !== "repost",
  );
  console.info(
    `[feed-seed] generating ${eligible.length} real embeddings with ${EMBEDDING_MODEL}`,
  );
  for (let index = 0; index < eligible.length; index += 1) {
    const post = eligible[index];
    let lastError;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        const vector = await generatePostEmbedding(post.data);
        if (!Array.isArray(vector) || vector.length === 0) {
          throw new Error("Embedding service returned an empty vector.");
        }
        post.data.contentVector = vector;
        post.data.contentEmbeddingModel = EMBEDDING_MODEL;
        post.data.contentEmbeddingSignature =
          embeddingSignatureForPost(post.data);
        post.data.contentVectorDimensions = EMBEDDING_DIMENSIONS;
        post.data.contentVectorUpdatedAt = admin.firestore.Timestamp.now();
        lastError = null;
        break;
      } catch (error) {
        lastError = error;
        console.error(
          `[feed-seed] embedding attempt ${attempt}/3 failed for ${post.id}:`,
          error?.message || String(error),
        );
      }
    }
    if (lastError) throw lastError;
    if ((index + 1) % 10 === 0 || index + 1 === eligible.length) {
      console.info(
        `[feed-seed] embedded ${index + 1}/${eligible.length} posts`,
      );
    }
  }
}

function attachSeedPersonaFollowing(pendingDocs, actors, authors, posts) {
  for (let index = 0; index < actors.length; index += 1) {
    const pending = pendingDocs.find((item) => item.id === actors[index].id);
    if (!pending) continue;
    // Cold start has following but no interaction vector; other personas follow a topic cluster.
    const interests = new Set(actors[index].interests || []);
    pending.data.following = authors
      .filter((author) =>
        posts.some(
          (post) =>
            post.data.authorId === author.id && interests.has(post.topic),
        ),
      )
      .map((author) => author.id)
      .slice(0, 6);
  }
}

function attachSeedUserAggregates(pendingDocs, posts, interactions) {
  for (const pending of pendingDocs.filter(
    (item) => item.kind === "seedUser",
  )) {
    pending.data.totalPosts = posts.filter(
      (post) => post.data.authorId === pending.id,
    ).length;
    pending.data.totalLikes = posts
      .filter((post) => post.data.authorId === pending.id)
      .reduce((sum, post) => sum + Number(post.data.stats.likeCount || 0), 0);
    pending.data.totalReports = interactions.filter(
      (item) => item.kind === "postReport" && item.data.toUid === pending.id,
    ).length;
  }
}

function asDocumentSpecs(db, options, pendingDocs, posts, interactions) {
  const specs = [];
  for (const doc of pendingDocs)
    specs.push({ ...doc, ref: db.collection(doc.collection).doc(doc.id) });
  for (const post of posts)
    specs.push({
      collection: "posts",
      id: post.id,
      data: post.data,
      kind: "post",
      ref: db.collection("posts").doc(post.id),
    });
  for (const doc of interactions)
    specs.push({ ...doc, ref: db.collection(doc.collection).doc(doc.id) });
  return specs.map((spec) => ({
    ...spec,
    path: spec.ref.path,
    seedBatchId: options.seedBatchId,
  }));
}

async function inspectExisting(db, options, specs) {
  const create = [];
  let skipped = 0;
  const existingManifest = await db
    .collection(BATCH_COLLECTION)
    .doc(options.seedBatchId)
    .collection("documents")
    .get();
  const manifestedPaths = new Set(
    existingManifest.docs
      .map((doc) => String(doc.data()?.path || ""))
      .filter(Boolean),
  );
  for (let offset = 0; offset < specs.length; offset += 250) {
    const chunk = specs.slice(offset, offset + 250);
    const snapshots = await db.getAll(...chunk.map((spec) => spec.ref));
    snapshots.forEach((snapshot, index) => {
      const spec = chunk[index];
      if (!snapshot.exists) {
        create.push(spec);
        return;
      }
      const data = snapshot.data() || {};
      if (
        (data.isSeedData === true &&
          data.seedBatchId === options.seedBatchId) ||
        (spec.kind === "hiddenPostAuthor" && manifestedPaths.has(spec.path))
      ) {
        skipped += 1;
        return;
      }
      throw new Error(
        `Refusing to overwrite existing non-batch document: ${spec.path}`,
      );
    });
  }
  return { create, skipped };
}

async function commitSpecs(db, options, specs) {
  const batchRef = db.collection(BATCH_COLLECTION).doc(options.seedBatchId);
  const summary = await inspectExisting(db, options, specs);
  if (options.dryRun)
    return {
      created: 0,
      skipped: summary.skipped,
      planned: summary.create.length,
    };

  let created = 0;
  for (
    let offset = 0;
    offset < summary.create.length;
    offset += MAX_BATCH_DATA_WRITES
  ) {
    const chunk = summary.create.slice(offset, offset + MAX_BATCH_DATA_WRITES);
    const batch = db.batch();
    for (const spec of chunk) {
      batch.create(spec.ref, spec.data);
      const manifestRef = batchRef
        .collection("documents")
        .doc(manifestId(spec.path));
      batch.create(manifestRef, {
        path: spec.path,
        kind: spec.kind,
        seedBatchId: options.seedBatchId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    created += chunk.length;
    console.info(
      `[feed-seed] committed ${created}/${summary.create.length} documents`,
    );
  }
  await batchRef.set(
    {
      seedBatchId: options.seedBatchId,
      isSeedData: true,
      projectId: options.projectId,
      target: options.target,
      status: "complete",
      documentCount: specs.length,
      createdDocumentCount: created,
      skippedDocumentCount: summary.skipped,
      options: {
        count: options.count,
        authorCount: options.authorCount,
        topics: options.topics,
        includeInteractions: options.includeInteractions,
        includeModerationTestData: options.includeModerationTestData,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { created, skipped: summary.skipped, planned: summary.create.length };
}

async function deleteSeedBatch(db, options) {
  const batchRef = db.collection(BATCH_COLLECTION).doc(options.seedBatchId);
  const manifest = await batchRef.collection("documents").get();
  if (manifest.empty) {
    throw new Error(
      `No manifest found for seed batch '${options.seedBatchId}'. Nothing was deleted.`,
    );
  }
  const entries = manifest.docs
    .map((doc) => ({ manifestRef: doc.ref, ...(doc.data() || {}) }))
    .filter((entry) => typeof entry.path === "string" && entry.path)
    .sort((a, b) => b.path.split("/").length - a.path.split("/").length);
  const seedUserPaths = new Set(
    entries
      .filter((entry) => entry.kind === "seedUser")
      .map((entry) => entry.path),
  );
  const verified = [];
  let missing = 0;
  for (let offset = 0; offset < entries.length; offset += 250) {
    const chunk = entries.slice(offset, offset + 250);
    const refs = chunk.map((entry) => db.doc(entry.path));
    const snapshots = await db.getAll(...refs);
    snapshots.forEach((snapshot, index) => {
      const entry = chunk[index];
      if (!snapshot.exists) {
        missing += 1;
        verified.push({ ...entry, targetRef: snapshot.ref, exists: false });
        return;
      }
      const data = snapshot.data() || {};
      const parentUserPath =
        entry.kind === "hiddenPostAuthor"
          ? entry.path.split("/").slice(0, 2).join("/")
          : "";
      const isManifestOnlySchema =
        entry.kind === "hiddenPostAuthor" && seedUserPaths.has(parentUserPath);
      if (
        !isManifestOnlySchema &&
        (data.isSeedData !== true || data.seedBatchId !== options.seedBatchId)
      ) {
        throw new Error(
          `Rollback stopped: marker mismatch at ${snapshot.ref.path}.`,
        );
      }
      verified.push({ ...entry, targetRef: snapshot.ref, exists: true });
    });
  }
  if (options.dryRun)
    return {
      deleted: 0,
      planned: verified.filter((entry) => entry.exists).length,
      missing,
    };

  // Firestore parent deletes do not remove subcollections. Recursively deleting
  // only verified seed-user roots also removes trigger-created recommendation,
  // notification and reputation documents that are not part of the manifest.
  let recursivelyDeletedSeedUsers = 0;
  for (const entry of verified.filter(
    (item) => item.exists && item.kind === "seedUser",
  )) {
    await db.recursiveDelete(entry.targetRef);
    entry.exists = false;
    recursivelyDeletedSeedUsers += 1;
  }

  let deleted = 0;
  for (
    let offset = 0;
    offset < verified.length;
    offset += MAX_BATCH_DATA_WRITES
  ) {
    const chunk = verified.slice(offset, offset + MAX_BATCH_DATA_WRITES);
    const batch = db.batch();
    for (const entry of chunk) {
      if (entry.exists) batch.delete(entry.targetRef);
      batch.delete(entry.manifestRef);
    }
    await batch.commit();
    deleted += chunk.filter((entry) => entry.exists).length;
  }
  await batchRef.delete();
  return {
    deleted: deleted + recursivelyDeletedSeedUsers,
    planned: verified.length,
    missing,
    recursivelyDeletedSeedUsers,
  };
}

async function backfillRecommendationHistory(db, options) {
  const postsSnap = await db
    .collection("posts")
    .where("seedBatchId", "==", options.seedBatchId)
    .get();
  const usersSnap = await db
    .collection("users")
    .where("seedBatchId", "==", options.seedBatchId)
    .get();
  if (postsSnap.empty || usersSnap.empty) {
    throw new Error(
      `Seed posts/users not found for batch '${options.seedBatchId}'.`,
    );
  }

  const seedUserIds = new Set(usersSnap.docs.map((doc) => doc.id));
  const postById = new Map(postsSnap.docs.map((doc) => [doc.id, doc.data()]));
  const eventsByUser = new Map();
  const addEvent = (event) => {
    if (!seedUserIds.has(event.uid)) return;
    event.eventId = String(event.eventId)
      .trim()
      .replace(/[^A-Za-z0-9_-]/g, "_")
      .slice(0, 140);
    if (!eventsByUser.has(event.uid)) eventsByUser.set(event.uid, []);
    eventsByUser.get(event.uid).push(event);
  };

  for (const postDoc of postsSnap.docs) {
    const post = postDoc.data();
    const isEligible =
      post.visibility === "public" &&
      post.moderationStatus === "approved" &&
      !post.deletedAt &&
      post.postType !== "repost";
    if (isEligible) {
      const [likesSnap, commentsSnap] = await Promise.all([
        postDoc.ref.collection("likes").get(),
        postDoc.ref.collection("comments").get(),
      ]);
      for (const likeDoc of likesSnap.docs) {
        const like = likeDoc.data();
        const uid = String(like.userId || likeDoc.id).trim();
        addEvent({
          uid,
          postId: postDoc.id,
          action: "like",
          eventId: `like_${postDoc.id}_${uid}`,
          occurredAt: like.createdAt,
        });
      }
      for (const commentDoc of commentsSnap.docs) {
        const comment = commentDoc.data();
        const uid = String(comment.userId || "").trim();
        addEvent({
          uid,
          postId: postDoc.id,
          action: "comment",
          eventId: `comment_${postDoc.id}_${commentDoc.id}`,
          occurredAt: comment.createdAt,
        });
      }
    }

    const referencePostId = String(post.referencePostId || "").trim();
    if (
      referencePostId &&
      (post.postType === "quote" || post.postType === "repost") &&
      postById.has(referencePostId)
    ) {
      addEvent({
        uid: String(post.authorId || "").trim(),
        postId: referencePostId,
        action: "share",
        eventId: `${post.postType}_${postDoc.id}_${referencePostId}`,
        occurredAt: post.createdAt,
      });
    }
  }

  const existingIdsByUser = new Map();
  await Promise.all(
    [...eventsByUser.keys()].map(async (uid) => {
      const snap = await db
        .collection("users")
        .doc(uid)
        .collection("recommendationInteractions")
        .get();
      existingIdsByUser.set(uid, new Set(snap.docs.map((doc) => doc.id)));
    }),
  );

  const missingByUser = new Map();
  for (const [uid, events] of eventsByUser.entries()) {
    const existingIds = existingIdsByUser.get(uid) || new Set();
    missingByUser.set(
      uid,
      events.filter((event) => !existingIds.has(event.eventId)),
    );
  }
  const planned = [...missingByUser.values()].reduce(
    (sum, events) => sum + events.length,
    0,
  );
  if (options.dryRun) {
    return {
      expected: [...eventsByUser.values()].reduce(
        (sum, events) => sum + events.length,
        0,
      ),
      existing: [...existingIdsByUser.values()].reduce(
        (sum, ids) => sum + ids.size,
        0,
      ),
      planned,
      created: 0,
    };
  }

  const {
    recordRecommendationInteraction,
  } = require("../../src/recommendation/core");
  let created = 0;
  await Promise.all(
    [...missingByUser.entries()].map(async ([uid, events]) => {
      for (const event of events) {
        await recordRecommendationInteraction(event);
        created += 1;
      }
      console.info(
        `[feed-seed] recommendation backfill ${uid}: ${events.length} events`,
      );
    }),
  );
  return {
    expected: [...eventsByUser.values()].reduce(
      (sum, events) => sum + events.length,
      0,
    ),
    existing: [...existingIdsByUser.values()].reduce(
      (sum, ids) => sum + ids.size,
      0,
    ),
    planned,
    created,
  };
}

function preview(options, authors, actors, posts, interactions, specs, result) {
  const typeCounts = posts.reduce((acc, post) => {
    acc[post.data.postType] = (acc[post.data.postType] || 0) + 1;
    return acc;
  }, {});
  const mediaCounts = posts.reduce((acc, post) => {
    const type = post.data.media[0]?.type || "text";
    acc[type] = (acc[type] || 0) + 1;
    return acc;
  }, {});
  return {
    mode: options.dryRun ? "dry-run" : "write",
    projectId: options.projectId,
    target: options.target,
    seedBatchId: options.seedBatchId,
    authors: authors.length,
    seedAuthors: authors.filter((author) => author.isSeedData).length,
    interactionActors: actors.length,
    posts: posts.length,
    topics: options.topics,
    postTypes: typeCounts,
    mediaTypes: mediaCounts,
    interactions: interactions.reduce((acc, item) => {
      acc[item.kind] = (acc[item.kind] || 0) + 1;
      return acc;
    }, {}),
    totalDocuments: specs.length,
    databaseResult: result,
    samplePost: posts[0]?.data || null,
  };
}

async function runSeed(db, options) {
  const mediaConfig = loadMediaConfig(options.mediaConfigPath);
  await validateConfiguredMediaUrls(mediaConfig);
  if (
    (options.ratios.image > 0 && mediaConfig.imageUrls.length === 0) ||
    (options.ratios.video > 0 && mediaConfig.videoUrls.length === 0)
  ) {
    console.warn(
      "[feed-seed] Missing configured media URLs; those selections safely fall back to text-only posts.",
    );
  }
  const { authors, actors, pendingDocs } = await loadAuthorsAndActors(
    db,
    options,
  );
  const posts = buildPosts(options, authors, mediaConfig);
  attachSeedPersonaFollowing(pendingDocs, actors, authors, posts);
  await generateRealEmbeddings(options, posts);
  const interactions = buildInteractions(options, posts, actors);
  attachSeedUserAggregates(pendingDocs, posts, interactions);
  const specs = asDocumentSpecs(db, options, pendingDocs, posts, interactions);
  const result = await commitSpecs(db, options, specs);
  return preview(options, authors, actors, posts, interactions, specs, result);
}

module.exports = {
  BATCH_COLLECTION,
  TOPICS,
  assertSafety,
  backfillRecommendationHistory,
  buildInteractions,
  buildPosts,
  buildSeedUser,
  deleteSeedBatch,
  initializeFirestore,
  parseBoolean,
  parseInteger,
  parseRatios,
  resolveTopics,
  runSeed,
  validateOptions,
};
