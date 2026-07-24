const rateLimit = require('express-rate-limit');
const standard = rateLimit({ windowMs: 15 * 60 * 1000, limit: 300, standardHeaders: 'draft-8', legacyHeaders: false, message: { success: false, message: 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau.' } });
const authSession = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: 'draft-8', legacyHeaders: false, message: { success: false, message: 'Quá nhiều lần đăng nhập. Vui lòng thử lại sau 15 phút.' } });
module.exports = { standard, authSession };
