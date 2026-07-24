const router = require('express').Router(); const { sessionCookieName } = require('../config/env');
router.get('/', (req, res) => res.redirect(req.cookies[sessionCookieName] ? '/dashboard' : '/login'));
router.use(require('./auth.routes')); router.use(require('./dashboard.routes'));
module.exports = router;
