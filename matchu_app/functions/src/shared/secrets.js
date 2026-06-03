const { defineSecret } = require("firebase-functions/params");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const TWILIO_ACCOUNT_SID = defineSecret("TWILIO_ACCOUNT_SID");
const TWILIO_AUTH_TOKEN = defineSecret("TWILIO_AUTH_TOKEN");
const FACE_BACKUP_ENCRYPTION_KEY_B64 = defineSecret(
  "FACE_BACKUP_ENCRYPTION_KEY_B64"
);

module.exports = {
  GEMINI_API_KEY,
  TWILIO_ACCOUNT_SID,
  TWILIO_AUTH_TOKEN,
  FACE_BACKUP_ENCRYPTION_KEY_B64,
};
