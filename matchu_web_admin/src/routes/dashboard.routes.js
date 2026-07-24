const router = require('express').Router(); const controller = require('../controllers/dashboard.controller'); const authenticate = require('../middlewares/authenticate.middleware'); const { requirePermission } = require('../middlewares/authorize.middleware'); const asyncHandler = require('../utils/async-handler');
router.get('/dashboard', authenticate, requirePermission('dashboard.read'), asyncHandler(controller.index));
module.exports = router;
