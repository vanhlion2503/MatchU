const router = require('express').Router();
const controller = require('../controllers/notification-campaign.controller');
const authenticate = require('../middlewares/authenticate.middleware');
const { requirePermission } = require('../middlewares/authorize.middleware');
const csrfProtection = require('../middlewares/csrf.middleware');
const asyncHandler = require('../utils/async-handler');

router.get(
  '/notifications',
  authenticate,
  requirePermission('notifications.read'),
  csrfProtection,
  asyncHandler(controller.index)
);
router.get(
  '/notifications/new',
  authenticate,
  requirePermission('notifications.create'),
  csrfProtection,
  asyncHandler(controller.create)
);
router.get(
  '/notifications/users/search',
  authenticate,
  requirePermission('notifications.create'),
  asyncHandler(controller.searchUsers)
);
router.post(
  '/notifications/audience-estimate',
  authenticate,
  requirePermission('notifications.create'),
  csrfProtection,
  asyncHandler(controller.audienceEstimate)
);
router.post(
  '/notifications',
  authenticate,
  requirePermission('notifications.create'),
  csrfProtection,
  (req, res, next) => req.body.intent === 'publish'
    ? requirePermission('notifications.publish')(req, res, next)
    : next(),
  asyncHandler(controller.store)
);
router.get(
  '/notifications/:campaignId',
  authenticate,
  requirePermission('notifications.read'),
  csrfProtection,
  asyncHandler(controller.show)
);
router.get(
  '/notifications/:campaignId/edit',
  authenticate,
  requirePermission('notifications.create'),
  csrfProtection,
  asyncHandler(controller.edit)
);
router.post(
  '/notifications/:campaignId',
  authenticate,
  requirePermission('notifications.create'),
  csrfProtection,
  (req, res, next) => req.body.intent === 'publish'
    ? requirePermission('notifications.publish')(req, res, next)
    : next(),
  asyncHandler(controller.update)
);
router.post(
  '/notifications/:campaignId/actions',
  authenticate,
  csrfProtection,
  (req, res, next) => {
    const permission = req.body.action === 'retry_failed'
      ? 'notifications.retry'
      : 'notifications.cancel';
    return requirePermission(permission)(req, res, next);
  },
  asyncHandler(controller.action)
);

module.exports = router;
