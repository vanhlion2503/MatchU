const { firestore } = require('../config/firebase-admin');
const { VALID_ADMIN_ROLES } = require('../config/constants');

async function getActiveAdmin(uid) {
  const snapshot = await firestore.collection('adminProfiles').doc(uid).get();
  if (!snapshot.exists) return null;
  const profile = snapshot.data();
  if (profile.status !== 'active' || !VALID_ADMIN_ROLES.includes(profile.role)) return null;
  return { uid, email: profile.email || '', displayName: profile.displayName || profile.email || 'Admin', avatarUrl: profile.avatarUrl || null, role: profile.role, permissions: Array.isArray(profile.permissions) ? profile.permissions : [] };
}
async function updateLastLogin(uid) { return firestore.collection('adminProfiles').doc(uid).update({ lastLoginAt: new Date(), updatedAt: new Date() }); }
module.exports = { getActiveAdmin, updateLastLogin };
