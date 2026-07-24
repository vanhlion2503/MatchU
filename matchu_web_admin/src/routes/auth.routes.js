const router = require('express').Router(); const controller = require('../controllers/auth.controller'); const guest = require('../middlewares/guest.middleware'); const authenticate = require('../middlewares/authenticate.middleware'); const asyncHandler = require('../utils/async-handler'); const { authSession } = require('../middlewares/rate-limit.middleware');
router.get('/login', guest, controller.loginPage);
router.post('/auth/session', authSession, asyncHandler(controller.createSession));
router.post('/auth/logout', authenticate, asyncHandler(controller.logout));
module.exports = router;
