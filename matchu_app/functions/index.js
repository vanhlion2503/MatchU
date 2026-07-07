require("./src/shared/firebase");

const { getTurnCredentials } = require("./src/callables/getTurnCredentials");
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
  ensureTempChatModerationFields,
  ensureUserReputationDefault,
  moderateTempChatMessage,
} = require("./src/triggers/tempChatModeration");
const {
  ensureUserReputationDailyDefaults,
  progressTempChat3Rooms3MinutesTask,
  progressMutualLikeLongChat5TimesTask,
  progressReceivedFiveStarRatingTask,
  progressQualifiedDailyPostTask,
} = require("./reputation/triggers");

exports.getTurnCredentials = getTurnCredentials;
exports.moderatePostText = moderatePostText;
exports.moderateCommentText = moderateCommentText;
exports.moderateImageContent = moderateImageContent;
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
exports.cleanupStaleUserDevices = cleanupStaleUserDevices;
exports.migrateTempChatMessages = migrateTempChatMessages;
exports.cleanupViewedImageMessage = cleanupViewedImageMessage;
exports.generateTelepathyAiInsight = generateTelepathyAiInsight;
exports.validateWordChainDictionary = validateWordChainDictionary;
exports.moderateUploadedPostVideo = moderateUploadedPostVideo;
exports.ensureTempChatModerationFields = ensureTempChatModerationFields;
exports.ensureUserReputationDefault = ensureUserReputationDefault;
exports.ensureUserReputationDailyDefaults = ensureUserReputationDailyDefaults;
exports.progressTempChat3Rooms3MinutesTask = progressTempChat3Rooms3MinutesTask;
exports.progressMutualLikeLongChat5TimesTask =
  progressMutualLikeLongChat5TimesTask;
exports.progressReceivedFiveStarRatingTask = progressReceivedFiveStarRatingTask;
exports.progressQualifiedDailyPostTask = progressQualifiedDailyPostTask;
exports.moderateTempChatMessage = moderateTempChatMessage;
