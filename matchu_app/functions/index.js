require("./src/shared/firebase");

const { getTurnCredentials } = require("./src/callables/getTurnCredentials");
const {
  sendEncryptedChatMessage,
  publishWrappedRoomKeys,
} = require("./src/callables/chatMessages");
const {
  moderatePostText,
} = require("./src/callables/postTextModeration");
const {
  moderateCommentText,
} = require("./src/callables/commentTextModeration");
const {
  moderateImageContent,
} = require("./src/callables/imageModeration");
const {
  recommendPosts,
} = require("./src/callables/recommendPosts");
const { searchPosts } = require("./src/callables/searchPosts");
const {
  storeFaceRecoveryBackup,
  getFaceRecoveryBackupStatus,
  recoverBackupKeyWithFace,
  deleteFaceRecoveryBackup,
} = require("./src/callables/faceRecoveryBackup");
const {
  touchReputationDailyOnAppOpen,
  getReputationDailyState,
  claimReputationTask,
  getReputationHistory,
} = require("./reputation/callables");
const {
  migrateTempChatMessages,
  cleanupViewedImageMessage,
} = require("./src/triggers/chatRoomEvents");
const {
  queueChatMessageNotification,
  dispatchQueuedChatNotification,
} = require("./src/triggers/chatMessageNotifications");
const {
  createPostLikeNotification,
  createPostCommentNotification,
  createModerationPenaltyNotification,
} = require("./src/triggers/socialNotifications");
const {
  cleanupStaleUserDevices,
} = require("./src/triggers/deviceMaintenance");
const {
  generateTelepathyAiInsight,
} = require("./src/triggers/telepathyInsight");
const {
  validateWordChainDictionary,
} = require("./src/triggers/wordChainValidation");
const {
  moderateUploadedPostVideo,
} = require("./src/triggers/videoModeration");
const {
  backfillRecentPostEmbeddings,
  embedPostContent,
  invalidateRecommendationCacheOnBlockedBy,
  invalidateRecommendationCacheOnBlock,
  invalidateRecommendationCacheOnHiddenPost,
  invalidateRecommendationCacheOnRestrictions,
  removeInterestOnPostCommentDelete,
  removeInterestOnPostUnlike,
  removeInterestOnPostUnsave,
  rebuildStaleInterestVectors,
  retryFailedPostEmbeddings,
  updateInterestOnPostComment,
  updateInterestOnPostLike,
  updateInterestOnPostSave,
  updateInterestOnDwell,
  updateNegativeInterestOnHiddenPost,
  updateNegativeInterestOnHiddenAuthor,
  updateNegativeInterestOnPostReport,
  removeNegativeInterestOnUnhideAuthor,
  updateInterestOnQuoteOrRepost,
} = require("./src/triggers/recommendationEvents");
const {
  ensureTempChatModerationFields,
  ensureUserReputationDefault,
  moderateTempChatMessage,
} = require("./src/triggers/tempChatModeration");
const {
  startTempChatMatching,
  cancelTempChatMatching,
  convertTempChat,
  expireTempChatSessions,
  cleanupExpiredMatchingSessions,
  releaseEndedTempChatParticipants,
} = require("./src/callables/tempChatSession");
const {
  ensureUserReputationDailyDefaults,
  progressTempChat3Rooms3MinutesTask,
  progressMutualLikeLongChat5TimesTask,
  progressReceivedFiveStarRatingTask,
  progressQualifiedDailyPostTask,
  progressQuote3OtherPostsTask,
  progressLike5PostsComment5TimesOnPostLike,
  progressLike5PostsComment5TimesOnComment,
} = require("./reputation/triggers");

exports.getTurnCredentials = getTurnCredentials;
exports.sendEncryptedChatMessage = sendEncryptedChatMessage;
exports.publishWrappedRoomKeys = publishWrappedRoomKeys;
exports.moderatePostText = moderatePostText;
exports.moderateCommentText = moderateCommentText;
exports.moderateImageContent = moderateImageContent;
exports.recommendPosts = recommendPosts;
exports.searchPosts = searchPosts;
exports.storeFaceRecoveryBackup = storeFaceRecoveryBackup;
exports.getFaceRecoveryBackupStatus = getFaceRecoveryBackupStatus;
exports.recoverBackupKeyWithFace = recoverBackupKeyWithFace;
exports.deleteFaceRecoveryBackup = deleteFaceRecoveryBackup;
exports.touchReputationDailyOnAppOpen = touchReputationDailyOnAppOpen;
exports.getReputationDailyState = getReputationDailyState;
exports.claimReputationTask = claimReputationTask;
exports.getReputationHistory = getReputationHistory;
exports.queueChatMessageNotification = queueChatMessageNotification;
exports.dispatchQueuedChatNotification = dispatchQueuedChatNotification;
exports.createPostLikeNotification = createPostLikeNotification;
exports.createPostCommentNotification = createPostCommentNotification;
exports.createModerationPenaltyNotification =
  createModerationPenaltyNotification;
exports.cleanupStaleUserDevices = cleanupStaleUserDevices;
exports.migrateTempChatMessages = migrateTempChatMessages;
exports.cleanupViewedImageMessage = cleanupViewedImageMessage;
exports.generateTelepathyAiInsight = generateTelepathyAiInsight;
exports.validateWordChainDictionary = validateWordChainDictionary;
exports.moderateUploadedPostVideo = moderateUploadedPostVideo;
exports.embedPostContent = embedPostContent;
exports.backfillRecentPostEmbeddings = backfillRecentPostEmbeddings;
exports.updateInterestOnPostLike = updateInterestOnPostLike;
exports.removeInterestOnPostUnlike = removeInterestOnPostUnlike;
exports.updateInterestOnPostComment = updateInterestOnPostComment;
exports.removeInterestOnPostCommentDelete = removeInterestOnPostCommentDelete;
exports.updateInterestOnPostSave = updateInterestOnPostSave;
exports.updateInterestOnDwell = updateInterestOnDwell;
exports.updateNegativeInterestOnHiddenPost = updateNegativeInterestOnHiddenPost;
exports.updateNegativeInterestOnHiddenAuthor = updateNegativeInterestOnHiddenAuthor;
exports.updateNegativeInterestOnPostReport = updateNegativeInterestOnPostReport;
exports.removeNegativeInterestOnUnhideAuthor =
  removeNegativeInterestOnUnhideAuthor;
exports.removeInterestOnPostUnsave = removeInterestOnPostUnsave;
exports.updateInterestOnQuoteOrRepost = updateInterestOnQuoteOrRepost;
exports.rebuildStaleInterestVectors = rebuildStaleInterestVectors;
exports.retryFailedPostEmbeddings = retryFailedPostEmbeddings;
exports.invalidateRecommendationCacheOnRestrictions =
  invalidateRecommendationCacheOnRestrictions;
exports.invalidateRecommendationCacheOnBlock =
  invalidateRecommendationCacheOnBlock;
exports.invalidateRecommendationCacheOnHiddenPost =
  invalidateRecommendationCacheOnHiddenPost;
exports.invalidateRecommendationCacheOnBlockedBy =
  invalidateRecommendationCacheOnBlockedBy;
exports.ensureTempChatModerationFields = ensureTempChatModerationFields;
exports.ensureUserReputationDefault = ensureUserReputationDefault;
exports.ensureUserReputationDailyDefaults = ensureUserReputationDailyDefaults;
exports.progressTempChat3Rooms3MinutesTask = progressTempChat3Rooms3MinutesTask;
exports.progressMutualLikeLongChat5TimesTask =
  progressMutualLikeLongChat5TimesTask;
exports.progressReceivedFiveStarRatingTask = progressReceivedFiveStarRatingTask;
exports.progressQualifiedDailyPostTask = progressQualifiedDailyPostTask;
exports.progressQuote3OtherPostsTask = progressQuote3OtherPostsTask;
exports.progressLike5PostsComment5TimesOnPostLike =
  progressLike5PostsComment5TimesOnPostLike;
exports.progressLike5PostsComment5TimesOnComment =
  progressLike5PostsComment5TimesOnComment;
exports.moderateTempChatMessage = moderateTempChatMessage;
exports.startTempChatMatching = startTempChatMatching;
exports.cancelTempChatMatching = cancelTempChatMatching;
exports.convertTempChat = convertTempChat;
exports.expireTempChatSessions = expireTempChatSessions;
exports.cleanupExpiredMatchingSessions = cleanupExpiredMatchingSessions;
exports.releaseEndedTempChatParticipants = releaseEndedTempChatParticipants;
