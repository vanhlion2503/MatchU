const admin = require('firebase-admin');
const { firebase, nodeEnv } = require('./env');

if (!admin.apps.length) {
  const hasServiceAccountEnv = firebase.projectId && firebase.clientEmail && firebase.privateKey;
  const options = hasServiceAccountEnv
    ? { credential: admin.credential.cert({ projectId: firebase.projectId, clientEmail: firebase.clientEmail, privateKey: firebase.privateKey.replace(/\\n/g, '\n') }) }
    : nodeEnv === 'production' ? { credential: admin.credential.applicationDefault() } : {};
  admin.initializeApp(options);
}
module.exports = { admin, auth: admin.auth(), firestore: admin.firestore() };
