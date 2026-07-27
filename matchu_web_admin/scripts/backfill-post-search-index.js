const { admin, firestore } = require('../src/config/firebase-admin');
const { buildAdminPostSearchTerms } = require('../src/utils/post-search-index');

const BATCH_SIZE = 300;

async function run() {
  let cursor = null;
  let indexed = 0;

  while (true) {
    let query = firestore.collection('posts')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = firestore.batch();
    for (const document of snapshot.docs) {
      const post = document.data() || {};
      batch.set(firestore.collection('adminPostSearchIndex').doc(document.id), {
        postId: document.id,
        searchTerms: buildAdminPostSearchTerms(document.id, post),
        createdAt: post.createdAt || null,
        sourceUpdatedAt: post.updatedAt || post.createdAt || null,
        indexedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    await batch.commit();
    indexed += snapshot.size;
    cursor = snapshot.docs.at(-1);
    console.log(`Indexed ${indexed} posts.`);
    if (snapshot.size < BATCH_SIZE) break;
  }

  console.log(`Admin post search backfill completed: ${indexed} posts.`);
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
