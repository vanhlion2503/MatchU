const router = require('express').Router();
const controller = require('../controllers/report-management.controller');
const authenticate = require('../middlewares/authenticate.middleware');
const { requirePermission } = require('../middlewares/authorize.middleware');
const authorizeAction = require('../middlewares/report-action-authorize.middleware');
const csrfProtection = require('../middlewares/csrf.middleware');
const asyncHandler = require('../utils/async-handler');

router.get(
  '/reports',
  authenticate,
  requirePermission('reports.read'),
  csrfProtection,
  asyncHandler(controller.index)
);
router.get(
  '/reports/:caseId',
  authenticate,
  requirePermission('reports.read'),
  csrfProtection,
  asyncHandler(controller.show)
);
router.post(
  '/reports/:caseId/actions',
  authenticate,
  csrfProtection,
  authorizeAction,
  asyncHandler(controller.action)
);

module.exports = router;
