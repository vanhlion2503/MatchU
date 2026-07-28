require("../src/shared/firebase");

const { db } = require("../src/shared/firebase");
const { upsertReportCase } = require("../src/triggers/reportCases");

const SOURCES = ["postReports", "userProfileReports", "userMatchingReports"];
const PAGE_SIZE = 200;

async function backfillSource(source) {
  let processed = 0;
  let cursor = null;

  do {
    let query = db.collection(source)
      .orderBy("__name__")
      .limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const document of snapshot.docs) {
      await upsertReportCase(source, document.id, document.data() || {});
      processed += 1;
    }
    cursor = snapshot.docs.at(-1);
    console.log(`[${source}] processed ${processed}`);
  } while (cursor);

  return processed;
}

async function main() {
  let total = 0;
  for (const source of SOURCES) total += await backfillSource(source);
  console.log(`Backfill completed: ${total} reports projected.`);
}

main().catch((error) => {
  console.error("Unable to backfill report cases:", error);
  process.exitCode = 1;
});
