const router = require('express').Router();
const controller = require('../controllers/post-management.controller');
const authenticate = require('../middlewares/authenticate.middleware');
const {
  requirePermission,
  requireAnyPermission
} = require('../middlewares/authorize.middleware');
const authorizeAction = require('../middlewares/post-action-authorize.middleware');
const csrfProtection = require('../middlewares/csrf.middleware');
const asyncHandler = require('../utils/async-handler');

router.get(
  '/posts',
  authenticate,
  requirePermission('posts.read'),
  csrfProtection,
  asyncHandler(controller.index)
);
router.get(
  '/posts/moderation',
  authenticate,
  requireAnyPermission('posts.moderate', 'reports.read'),
  csrfProtection,
  asyncHandler(controller.moderation)
);
router.get(
  '/posts/:postId',
  authenticate,
  requireAnyPermission('posts.read', 'posts.moderate', 'reports.read', 'posts.delete'),
  csrfProtection,
  asyncHandler(controller.show)
);
router.post(
  '/posts/:postId/actions',
  authenticate,
  csrfProtection,
  authorizeAction,
  asyncHandler(controller.action)
);

module.exports = router;
