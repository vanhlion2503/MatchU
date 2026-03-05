require("./src/shared/firebase");

const { getTurnCredentials } = require("./src/callables/getTurnCredentials");
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

exports.getTurnCredentials = getTurnCredentials;
exports.migrateTempChatMessages = migrateTempChatMessages;
exports.cleanupViewedImageMessage = cleanupViewedImageMessage;
exports.generateTelepathyAiInsight = generateTelepathyAiInsight;
exports.validateWordChainDictionary = validateWordChainDictionary;
exports.ensureTempChatModerationFields = ensureTempChatModerationFields;
exports.ensureUserReputationDefault = ensureUserReputationDefault;
exports.moderateTempChatMessage = moderateTempChatMessage;
