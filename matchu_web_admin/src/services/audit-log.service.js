const { firestore, admin } = require('../config/firebase-admin');
async function writeAuditLog({ admin: currentAdmin, action, targetType = 'admin', targetId, metadata = {}, req }) {
  try {
    await firestore.collection('adminAuditLogs').add({ adminId: currentAdmin?.uid || null, adminEmail: currentAdmin?.email || null, action, targetType, targetId: targetId || currentAdmin?.uid || null, metadata, ipAddress: req.ip, userAgent: req.get('user-agent') || '', createdAt: admin.firestore.FieldValue.serverTimestamp() });
  } catch (error) { console.error('Unable to write audit log:', error.message); }
}
module.exports = { writeAuditLog };
