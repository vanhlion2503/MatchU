const router = require('express').Router();
const controller = require('../controllers/audit-log.controller');
const authenticate = require('../middlewares/authenticate.middleware');
const { requirePermission } = require('../middlewares/authorize.middleware');
const asyncHandler = require('../utils/async-handler');

router.get(
  '/admin-logs',
  authenticate,
  requirePermission('audit_logs.read'),
  asyncHandler(controller.index)
);

module.exports = router;
