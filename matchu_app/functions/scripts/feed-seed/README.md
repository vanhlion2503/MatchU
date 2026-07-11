# MatchU feed seed tool

This directory contains a development-only Firebase Admin CLI that creates a
purposeful Vietnamese feed dataset and can remove exactly one seed batch. It is
kept outside Flutter production code and never runs as a deployed Cloud
Function.

## Schema verified from the application

Posts live at `posts/{postId}`. The production create path writes:

| Field                       | Firestore type  | Purpose                                                                                                     |
| --------------------------- | --------------- | ----------------------------------------------------------------------------------------------------------- |
| `postId`, `authorId`        | string          | Identity and existing `users/{authorId}` reference                                                          |
| `postType`                  | string          | `post`, `quote`, or `repost`                                                                                |
| `content`                   | string          | Trimmed body, maximum 300 characters                                                                        |
| `media`                     | array of map    | `url`, `type`; optional `durationMs`, `storagePath`, `mimeType`, `thumbnailUrl`                             |
| `tags`                      | array of string | Content/topic signals used by embedding generation                                                          |
| `contentVector`             | array of number | Server-generated embedding; absent/empty before the pipeline completes                                      |
| `visibility`, `isPublic`    | string, bool    | `public`, `followers`, `private`; the legacy bool must agree                                                |
| `requestedVisibility`       | string/null     | Requested final visibility while a video is private and pending moderation                                  |
| `moderationStatus`          | string          | `pending_moderation`, `approved`, `rejected`, `review_required`                                             |
| moderation fields           | string/map/null | `moderationSource`, `moderationMessageVi`, `moderationPolicyVersion`, `videoStoragePath`, `videoModeration` |
| `stats`                     | map             | `likeCount`, `commentCount`, `shareCount`, `saveCount`                                                      |
| `trendScore`, `trendBucket` | number          | Popularity inputs used by ranking                                                                           |
| `author`                    | map             | Snapshot: `id`, `name`, `nickname`, `avatar`, `isVerified`                                                  |
| reference fields            | string/map/null | `referencePostId` and a `referencePost` snapshot for quote/repost                                           |
| timestamps                  | timestamp/null  | `createdAt`, `updatedAt`, `deletedAt`                                                                       |

Fields needed by the current create/read paths are `postId`, `authorId`,
`postType`, `content`, `media`, `tags`, matching visibility fields,
`moderationStatus`, `stats`, the trend fields, `author`, and timestamps. The
deserializers have defensive defaults, but omitting those fields produces an
incomplete document rather than a production-shaped one.

Interaction storage is:

- `posts/{postId}/likes/{userId}` with `userId`, `createdAt`.
- `posts/{postId}/comments/{commentId}` with content/media fields, `parentId`,
  `likeCount`, `replyCount`, timestamps and soft-delete fields.
- `posts/{postId}/comments/{commentId}/likes/{userId}` for comment likes.
- `users/{userId}/savedPosts/{postId}` with `postId`, `userId`, `savedAt`,
  `updatedAt`.
- Quote/repost post documents represent shares; there is no separate share
  collection.
- `postReports/{reportId}` stores post-report snapshots.
- `users/{userId}/hiddenPostAuthors/{authorId}` hides an author. Individual
  hidden post IDs are persisted in `users/{userId}/hiddenPosts/{postId}` and
  mirrored locally by `FeedController` for immediate/offline filtering.
- `users/{userId}/recommendationInteractions/{eventId}` is server-managed
  history populated by like/comment/save/share triggers. Inactive tombstones
  make removals idempotent when Firestore events are retried or reordered.
- `users/{userId}/recommendationCache/feed` stores a ten-minute ranked pool.
- `postRecommendationIndex/{postId}` is a server-only retrieval index. It holds
  a Firestore-native 768-dimensional vector plus daily popularity metadata;
  Flutter never downloads this large field.

Production media paths are `posts/{uid}/{postId}/image_{index}.jpg`,
`posts/{uid}/{postId}/voice_{index}.{extension}`, and
`user_uploads/{uid}/videos/{postId}/source.mp4` plus `thumbnail.jpg`. The seed
tool does not invent download URLs or upload unmoderated files. With no media
configuration, selected image/video posts safely become text-only.

### Current schema/ranking notes

- Feed exposure is aggregated at `users/{uid}/feedImpressions/{postId}`. A
  visible fraction of at least 60% for three seconds adds a light dwell signal
  (0.35); raw impressions alone do not train preference.
- `saveCount` is updated atomically with `savedPosts` and contributes to
  popularity using the same 1.3 weight as preference learning.
- Tags are canonical topic IDs. Known aliases are normalized before embedding;
  changing the normalized content signature causes a real re-embedding.
- Hide-post (1.0), hide-author (1.4), and report (2.0) build a separate negative
  vector. It penalizes similar candidates without corrupting positive interest.
- Candidate retrieval is hybrid: up to 160 global cosine-nearest posts, 120
  seven-day popularity candidates, 180 recent posts, and bounded public posts
  from followed authors are merged before ranking. Similarity must be `>= 0.7`.
  Ranking keeps a three-day content half-life with a `0.6` floor, a 140-post
  cached pool, and a ten-minute cache. Trending uses log-scaled engagement plus
  a freshness baseline. Interest-history rebuilds use a 30-day half-life.
- Cold start is trending/following only. At effective count `< 10`, the system
  explores; at `>= 10`, content similarity receives 70% of the score.
- The client hydrates recommended IDs in Firestore `whereIn` batches (up to 30
  IDs) and falls back to isolated reads if a stale or inaccessible ID makes a
  batch fail.
- Embeddings store their model, normalized-content SHA-256 signature and vector
  dimensions. Edits and model changes invalidate stale vectors. This tool
  either leaves vectors empty for the trigger or calls the configured model
  (`Xenova/paraphrase-multilingual-mpnet-base-v2`); it never synthesizes random
  vectors.
- Author data is denormalized. Later profile changes do not automatically
  update old post snapshots.
- `isPublic` and `visibility` duplicate the same state and must remain in sync.
- `trendScore` and `trendBucket` remain optional manual boosts. The retrieval
  index derives its normal popularity signal directly from live post counters.
- Post creation, likes and comments also activate notification and reputation
  triggers. Development-project writes therefore require seed-only authors;
  this prevents side effects on existing accounts.

### Vector index deployment and migration

- Deploy `firestore.indexes.json` before expecting KNN retrieval. Until the
  vector and popularity indexes are ready, recommendation automatically falls
  back to recent/following candidates instead of failing the feed.
- The configured model outputs 768 dimensions. If
  `RECOMMENDATION_EMBEDDING_MODEL` or
  `RECOMMENDATION_EMBEDDING_DIMENSIONS` changes, update the vector index
  dimension and redeploy indexes first.
- `backfillRecentPostEmbeddings` now walks the whole eligible post collection
  with a persistent cursor in `system/recommendationVectorBackfill`, 80 posts
  every 15 minutes. New and edited posts are indexed immediately by
  `embedPostContent`.

## Safety model

Every invocation requires all of:

```text
ALLOW_FIRESTORE_SEED=true
FIREBASE_PROJECT_ID=<explicit-project-id>
SEED_BATCH_ID=<unique-batch-id>
```

The default target is the Firestore Emulator and it refuses to run unless
`FIRESTORE_EMULATOR_HOST` is present. Development-project writes additionally
require `SEED_ENVIRONMENT=development`, Application Default Credentials, and
`--author-source seed`. Production is available only for the explicitly
registered project `matchu-5bd75`, with separate production/public-feed
confirmation variables, seed-only authors, and no moderation/report/restriction
test records.

Document IDs are deterministic for a batch. Rerunning the same batch skips its
existing documents; any ID collision without matching seed markers stops the
whole run. Each created document has `isSeedData: true` and `seedBatchId`, and
each path is recorded below `_seedBatches/{seedBatchId}/documents`. Writes are
split so each Firestore batch remains below 500 operations.

Rollback verifies both markers before deleting a path. Seed-user roots are
recursively deleted so server-triggered notification, reputation,
recommendation and cache subcollections do not become orphaned. Existing user
documents are never updated or deleted. Seed interactions use only seed-marked
personas; persona zero deliberately remains cold-start.

## Setup

From `matchu_app/functions`, install the already-declared dependencies:

```powershell
npm ci
```

Do not place a service-account JSON file in the repository. Emulator runs need
no credential. For a development project, use Application Default Credentials
from a trusted developer machine (for example `gcloud auth
application-default login`) or workload identity in CI.

For media, copy `media.example.json` outside the repository or to an ignored
local file, then add only working HTTPS/Firebase Storage download URLs. Images
and videos remain configurable data, not source constants. Before planning any
write, the CLI performs a HEAD request (with a one-byte GET fallback) and stops
if a configured URL is unreachable.

## Firestore Emulator

Start Firestore and Functions from `matchu_app` so embedding/recommendation,
notification, and reputation triggers can run:

```powershell
firebase emulators:start --only firestore,functions
```

In a second PowerShell window:

```powershell
$env:ALLOW_FIRESTORE_SEED = 'true'
$env:FIREBASE_PROJECT_ID = 'matchu-feed-local'
$env:SEED_BATCH_ID = 'feed-test-001'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'

npm --prefix functions run seed:feed:dry-run -- --target emulator --count 120 --authors 12 --author-source seed --create-seed-users --include-interactions --include-moderation-test-data
npm --prefix functions run seed:feed -- --target emulator --count 120 --authors 12 --author-source seed --create-seed-users --include-interactions --include-moderation-test-data
```

If Functions Emulator is not running, add `--generate-embeddings` to generate
real vectors inside the CLI. The first use downloads the configured model and
is intentionally slower. With Functions Emulator running, the existing
`embedPostContent` trigger fills vectors and like/comment/share triggers build
recommendation history.

## Development Firebase project

Use a dedicated non-production Firebase project. The current repository
project cannot be used.

```powershell
$env:ALLOW_FIRESTORE_SEED = 'true'
$env:SEED_ENVIRONMENT = 'development'
$env:FIREBASE_PROJECT_ID = 'matchu-development'
$env:SEED_BATCH_ID = 'feed-dev-001'
Remove-Item Env:FIRESTORE_EMULATOR_HOST -ErrorAction SilentlyContinue

npm --prefix functions run seed:feed:dry-run -- --target development --count 100 --authors 10 --author-source seed --create-seed-users --include-interactions
npm --prefix functions run seed:feed -- --target development --count 100 --authors 10 --author-source seed --create-seed-users --include-interactions
```

To select topics, time range and media distribution:

```powershell
npm --prefix functions run seed:feed -- --target development --count 90 --authors 9 --author-source seed --create-seed-users --topics flutter,firebase,ai,lập-trình --ratios text=0.65,image=0.25,video=0.10 --max-age-days 180 --media-config C:\secure-test-data\matchu-media.json
```

The post/author constraint is enforced: requested count must be between three
and fifteen posts per author. The script distributes timestamps across recent
minutes, today, seven days, thirty days and older data, and rotates no/low/
medium/popular/comment-heavy/save-heavy engagement profiles.

## Main production project (`matchu-5bd75`)

Use this only when seed posts are intentionally meant to appear in the real
feed. Production mode creates new seed-marked users and never selects an
existing account as author or interaction persona. It also refuses moderation
test data, fake reports, and hidden-author test records.

```powershell
$env:ALLOW_FIRESTORE_SEED = 'true'
$env:ALLOW_PRODUCTION_FIRESTORE_SEED = 'true'
$env:CONFIRM_PUBLIC_FEED_SEED = 'true'
$env:CONFIRM_FIREBASE_PROJECT_ID = 'matchu-5bd75'
$env:SEED_ENVIRONMENT = 'production'
$env:FIREBASE_PROJECT_ID = 'matchu-5bd75'
$env:SEED_BATCH_ID = 'prod-feed-20260710-001'
Remove-Item Env:FIRESTORE_EMULATOR_HOST -ErrorAction SilentlyContinue

npm --prefix functions run seed:feed:dry-run -- --target production --count 90 --authors 9 --author-source seed --create-seed-users --include-interactions --no-include-reports --no-include-restrictions --generate-embeddings
npm --prefix functions run seed:feed -- --target production --count 90 --authors 9 --author-source seed --create-seed-users --include-interactions --no-include-reports --no-include-restrictions --generate-embeddings
```

`--generate-embeddings` runs the existing model locally before the write. The
deployed embedding trigger then sees a matching real vector and avoids doing
the expensive inference again. Like/comment/share triggers still run and build
the seed personas' recommendation history.

If a large interaction batch causes Firestore transaction contention in the
deployed triggers, preview and repair only missing history events with the same
production confirmation variables:

```powershell
npm --prefix functions run seed:feed -- --target production --backfill-recommendation-history --dry-run --author-source seed --create-seed-users --no-include-reports --no-include-restrictions
npm --prefix functions run seed:feed -- --target production --backfill-recommendation-history --author-source seed --create-seed-users --no-include-reports --no-include-restrictions
```

The repair calls the existing `recordRecommendationInteraction` function,
skips existing event IDs, and processes each persona sequentially so it does
not create the original contention pattern.

## Delete or preview deletion

```powershell
npm --prefix functions run seed:feed:delete -- --target emulator --dry-run
npm --prefix functions run seed:feed:delete -- --target emulator
```

The environment variables, especially the exact `SEED_BATCH_ID`, must still be
set. Only paths from that batch manifest with matching markers are removed.

## Example seeded post

Timestamps below are Firestore `Timestamp` values in the database:

```json
{
  "postId": "seed_feed-test-001_post_0001",
  "authorId": "seed_feed-test-001_author_01",
  "postType": "post",
  "content": "Mình vừa thử học 25 phút rồi nghỉ 5 phút, bất ngờ là đỡ mất tập trung hẳn. Có bạn nào duy trì Pomodoro lâu dài không? 📚",
  "media": [],
  "tags": ["học-tập"],
  "contentVector": [],
  "visibility": "public",
  "isPublic": true,
  "moderationStatus": "approved",
  "stats": {
    "likeCount": 0,
    "commentCount": 0,
    "shareCount": 0,
    "saveCount": 0
  },
  "trendScore": 12,
  "trendBucket": 0,
  "author": {
    "id": "seed_feed-test-001_author_01",
    "name": "Tác giả mẫu 1",
    "nickname": "tacgia1",
    "avatar": "",
    "isVerified": false
  },
  "deletedAt": null,
  "isSeedData": true,
  "seedBatchId": "feed-test-001",
  "seedTopic": "học-tập",
  "seedPopularityProfile": "none"
}
```

## Recommendation/feed verification checklist

- General feed shows only public, approved, non-deleted, non-repost-only posts.
- Following feed includes followers-only posts only for persona `following`
  entries and paginates without duplicates.
- Cold-start persona returns trending/following results with no content score.
- Active personas gain real `recommendationInteractions`, `interestVector`,
  weight and effective count after triggers finish.
- Topic-personalized posts score above unrelated posts once embeddings exist.
- KNN retrieval finds relevant posts outside the latest-180 window and reports
  `retrievalMode: hybrid_vector`; disabling/missing indexes keeps fallback feed
  usable.
- New zero-engagement posts rank by freshness while recent popular posts rank
  by engagement; old popular posts demonstrate the seven-day cutoff.
- Quote/repost counters equal the actual reference documents.
- Like, comment and save counters equal their seeded documents; one user never
  likes or saves the same post twice.
- Comment reply counts match child comments.
- Pagination covers more than one page and never repeats an ID.
- Private, followers-only, rejected, review-required and soft-deleted test
  posts stay out of the public feed.
- Hidden-author persona excludes that author after cache invalidation.
- The same batch rerun reports skips instead of duplicates.
- Batch dry-delete count matches the manifest, and rollback leaves non-seed
  documents untouched.

## Files inspected for this implementation

- `lib/models/feed/post_model.dart`, `media_model.dart`, `stats_model.dart`,
  `post_comment_model.dart`, and `lib/models/user_model.dart`.
- `lib/services/feed/post_service.dart`, `post_comment_service.dart`,
  `post_restriction_service.dart`, `recommendation_service.dart`,
  `embedding_service.dart`, and moderation services.
- `lib/controllers/feed/feed_controller.dart`,
  `post_composer_controller.dart`, `post_creation_sync.dart`, and post detail/
  comment controllers.
- `lib/views/feed/feed_screen.dart`, `create_post_sheet.dart`, `post_item.dart`,
  media, privacy, action and repost widgets.
- `lib/models/post_report_model.dart`, `post_report_reason.dart`, and
  `lib/services/report/post_report_service.dart`.
- `functions/src/recommendation/core.js`, `embedding.js`, `retrieval.js`,
  `src/callables/recommendPosts.js`, and `src/triggers/recommendationEvents.js`.
- Post/comment/image/video moderation callables and triggers,
  `functions/reputation/types.js`, `triggers.js`, and `functions/index.js`.
- `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc`,
  and both Node package manifests.

## Firebase cost and security notes

- Admin SDK bypasses security rules. The CLI safety checks and protected project
  ID are therefore mandatory controls, not optional convenience.
- Each seeded document also creates one manifest document, so write count is
  roughly doubled. Likes/comments can additionally invoke Functions, create
  notifications/reputation records, run embedding inference and invalidate
  caches.
- KNN queries charge vector-index reads in addition to the post documents that
  are hydrated for ranking/display. Monitor both index-entry and document reads
  when tuning candidate limits.
- Eligible post writes maintain one server-only recommendation-index document;
  interaction counter changes also refresh its popularity metadata.
- Model generation can consume CPU, memory, network download and Functions
  runtime. Prefer the Emulator for repeated experiments.
- Firebase Storage costs occur only for URLs/files managed separately; this
  CLI does not upload media.
- Keep ADC and any media URL configuration outside source control. Never commit
  a service account or API key.
- Run dry-run first, use a unique batch ID, inspect the project ID in the safety
  log, and roll back obsolete batches promptly.
