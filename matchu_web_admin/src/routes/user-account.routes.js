const router = require('express').Router();
const controller = require('../controllers/user-account.controller');
const authenticate = require('../middlewares/authenticate.middleware');
const { requirePermission } = require('../middlewares/authorize.middleware');
const authorizeAction = require('../middlewares/user-action-authorize.middleware');
const csrfProtection = require('../middlewares/csrf.middleware');
const asyncHandler = require('../utils/async-handler');

router.get(
  '/users',
  authenticate,
  requirePermission('users.read'),
  csrfProtection,
  asyncHandler(controller.index)
);
router.get(
  '/users/:uid',
  authenticate,
  requirePermission('users.read'),
  csrfProtection,
  asyncHandler(controller.show)
);
router.post(
  '/users/:uid/actions',
  authenticate,
  csrfProtection,
  authorizeAction,
  asyncHandler(controller.action)
);

module.exports = router;
