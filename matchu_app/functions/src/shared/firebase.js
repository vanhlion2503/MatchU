const { setGlobalOptions } = require("firebase-functions");
const admin = require("firebase-admin");

setGlobalOptions({ maxInstances: 10 });

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

module.exports = {
  admin,
  db,
};
