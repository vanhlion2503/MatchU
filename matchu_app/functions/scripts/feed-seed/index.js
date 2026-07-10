#!/usr/bin/env node
"use strict";

const {
  assertSafety,
  backfillRecommendationHistory,
  deleteSeedBatch,
  initializeFirestore,
  parseBoolean,
  parseInteger,
  parseRatios,
  resolveTopics,
  runSeed,
  validateOptions,
} = require("./seed");

const BOOLEAN_FLAGS = new Set([
  "dry-run",
  "delete-batch",
  "create-seed-users",
  "include-interactions",
  "include-moderation-test-data",
  "include-reports",
  "include-restrictions",
  "include-shares",
  "generate-embeddings",
  "backfill-recommendation-history",
]);

function parseArgv(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--help" || token === "-h") {
      values.help = true;
      continue;
    }
    if (!token.startsWith("--"))
      throw new Error(`Unexpected argument: ${token}`);
    const withoutPrefix = token.slice(2);
    if (withoutPrefix.startsWith("no-")) {
      const key = withoutPrefix.slice(3);
      if (!BOOLEAN_FLAGS.has(key))
        throw new Error(`Unknown boolean flag: ${token}`);
      values[key] = false;
      continue;
    }
    const equalsAt = withoutPrefix.indexOf("=");
    if (equalsAt >= 0) {
      values[withoutPrefix.slice(0, equalsAt)] = withoutPrefix.slice(
        equalsAt + 1,
      );
      continue;
    }
    if (BOOLEAN_FLAGS.has(withoutPrefix)) {
      values[withoutPrefix] = true;
      continue;
    }
    const next = argv[index + 1];
    if (!next || next.startsWith("--"))
      throw new Error(`Missing value for --${withoutPrefix}`);
    values[withoutPrefix] = next;
    index += 1;
  }
  return values;
}

function buildOptions(args) {
  const seedBatchId = args["batch-id"] || process.env.SEED_BATCH_ID || "";
  return {
    projectId: args["project-id"] || process.env.FIREBASE_PROJECT_ID || "",
    seedBatchId,
    target: args.target || "emulator",
    dryRun: parseBoolean(args["dry-run"]),
    deleteBatch: parseBoolean(args["delete-batch"]),
    backfillRecommendationHistory: parseBoolean(
      args["backfill-recommendation-history"],
    ),
    count: parseInteger(args.count, 120, "--count", { min: 3, max: 2000 }),
    authorCount: parseInteger(args.authors, 12, "--authors", {
      min: 1,
      max: 200,
    }),
    interactionActorCount: parseInteger(
      args["interaction-actors"],
      8,
      "--interaction-actors",
      { min: 2, max: 100 },
    ),
    maxAgeDays: parseInteger(args["max-age-days"], 120, "--max-age-days", {
      min: 32,
      max: 730,
    }),
    topics: resolveTopics(args.topics),
    ratios: parseRatios(args.ratios),
    mediaConfigPath: args["media-config"] || "",
    authorSource: args["author-source"] || "existing",
    createSeedUsers: parseBoolean(args["create-seed-users"]),
    includeInteractions: parseBoolean(args["include-interactions"]),
    includeModerationTestData: parseBoolean(
      args["include-moderation-test-data"],
    ),
    includeReports: parseBoolean(args["include-reports"], true),
    includeRestrictions: parseBoolean(args["include-restrictions"], true),
    includeShares: parseBoolean(args["include-shares"], true),
    generateEmbeddings: parseBoolean(args["generate-embeddings"]),
  };
}

function printHelp() {
  console.log(`MatchU feed seed tool

Required environment for every command:
  ALLOW_FIRESTORE_SEED=true
  FIREBASE_PROJECT_ID=<emulator-or-development-project>
  SEED_BATCH_ID=<unique-batch-id>

Write protection:
  --target emulator       Default; requires FIRESTORE_EMULATOR_HOST.
  --target development    Requires SEED_ENVIRONMENT=development and ADC.
  --target production     Requires ADC plus explicit production/public-feed
                          confirmation variables and seed-only users.

Main options:
  --count 120                       Number of posts (3-15 per author).
  --authors 12                      Number of authors.
  --topics all|flutter,firebase     Topic selection.
  --ratios text=.7,image=.25,video=.05
  --max-age-days 120
  --author-source existing|mixed|seed
  --create-seed-users               Create missing Firestore-only seed users.
  --include-interactions            Likes/comments/saves/reports/restrictions.
  --interaction-actors 8            Seed-marked personas; one remains cold-start.
  --include-moderation-test-data    Adds private/rejected/deleted filter cases.
  --media-config <json>             HTTPS image/video URLs; no URLs means text fallback.
  --generate-embeddings             Use the existing real embedding model with retry.
  --backfill-recommendation-history Repair missing trigger events sequentially per persona.
  --dry-run                         Read and preview only; perform no writes.
  --delete-batch                    Delete only documents listed in this batch manifest.
  --no-include-shares               Disable quote/repost documents.
  --no-include-reports              Disable report test documents.
  --no-include-restrictions         Disable hidden-author test documents.
`);
}

async function main() {
  const args = parseArgv(process.argv.slice(2));
  if (args.help) {
    printHelp();
    return;
  }
  const options = buildOptions(args);
  validateOptions(options);
  assertSafety(options);
  const db = initializeFirestore(options);

  console.info("[feed-seed] safety context:", {
    projectId: options.projectId,
    target: options.target,
    emulatorHost: process.env.FIRESTORE_EMULATOR_HOST || null,
    seedBatchId: options.seedBatchId,
    dryRun: options.dryRun,
    operation: options.deleteBatch ? "delete" : "seed",
  });

  if (options.deleteBatch) {
    const result = await deleteSeedBatch(db, options);
    console.log(
      JSON.stringify(
        { operation: "delete", seedBatchId: options.seedBatchId, ...result },
        null,
        2,
      ),
    );
    return;
  }
  if (options.backfillRecommendationHistory) {
    const result = await backfillRecommendationHistory(db, options);
    console.log(
      JSON.stringify(
        {
          operation: "backfill-recommendation-history",
          seedBatchId: options.seedBatchId,
          ...result,
        },
        null,
        2,
      ),
    );
    return;
  }
  const result = await runSeed(db, options);
  console.log(JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error(
    "[feed-seed] failed:",
    error?.stack || error?.message || String(error),
  );
  process.exitCode = 1;
});
