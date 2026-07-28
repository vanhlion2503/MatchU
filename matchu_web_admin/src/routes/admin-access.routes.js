const router = require('express').Router();
const controller = require('../controllers/admin-access.controller');
const authenticate = require('../middlewares/authenticate.middleware');
const { requirePermission } = require('../middlewares/authorize.middleware');
const csrfProtection = require('../middlewares/csrf.middleware');
const asyncHandler = require('../utils/async-handler');

router.get(
  '/admins',
  authenticate,
  requirePermission('admins.manage'),
  csrfProtection,
  asyncHandler(controller.index)
);
router.post(
  '/admins',
  authenticate,
  requirePermission('admins.manage'),
  csrfProtection,
  asyncHandler(controller.grant)
);
router.post(
  '/admins/:uid/access',
  authenticate,
  requirePermission('admins.manage'),
  csrfProtection,
  asyncHandler(controller.updateAccess)
);
router.post(
  '/admins/:uid/status',
  authenticate,
  requirePermission('admins.manage'),
  csrfProtection,
  asyncHandler(controller.updateStatus)
);

module.exports = router;
