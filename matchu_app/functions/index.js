require("./src/shared/firebase");

const { getTurnCredentials } = require("./src/callables/getTurnCredentials");
const {
  touchReputationDailyOnAppOpen,
  getReputationDailyState,
  claimReputationTask,
} = require("./reputation/callables");
const {
  migrateTempChatMessages,
  cleanupViewedImageMessage,
} = require("./src/triggers/chatRoomEvents");
const {
  generateTelepathyAiInsight,
} = require("./src/triggers/telepathyInsight");
const {
  validateWordChainDictionary,
} = require("./src/triggers/wordChainValidation");
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
} = require("./reputation/triggers");

exports.getTurnCredentials = getTurnCredentials;
exports.touchReputationDailyOnAppOpen = touchReputationDailyOnAppOpen;
exports.getReputationDailyState = getReputationDailyState;
exports.claimReputationTask = claimReputationTask;
exports.migrateTempChatMessages = migrateTempChatMessages;
exports.cleanupViewedImageMessage = cleanupViewedImageMessage;
exports.generateTelepathyAiInsight = generateTelepathyAiInsight;
exports.validateWordChainDictionary = validateWordChainDictionary;
exports.ensureTempChatModerationFields = ensureTempChatModerationFields;
exports.ensureUserReputationDefault = ensureUserReputationDefault;
exports.ensureUserReputationDailyDefaults = ensureUserReputationDailyDefaults;
exports.progressTempChat3Rooms3MinutesTask = progressTempChat3Rooms3MinutesTask;
exports.progressMutualLikeLongChat5TimesTask =
  progressMutualLikeLongChat5TimesTask;
exports.progressReceivedFiveStarRatingTask = progressReceivedFiveStarRatingTask;
exports.moderateTempChatMessage = moderateTempChatMessage;
