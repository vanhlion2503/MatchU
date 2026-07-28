const Joi = require('joi');
const { VALID_ADMIN_ROLES } = require('../config/constants');
const {
  ADMIN_STATUSES,
  ALL_ADMIN_PERMISSIONS
} = require('../config/admin-access');

const assignableRole = Joi.string().valid(...VALID_ADMIN_ROLES).required();
const permissions = Joi.array()
  .items(Joi.string().valid(...ALL_ADMIN_PERMISSIONS))
  .unique()
  .max(ALL_ADMIN_PERMISSIONS.length)
  .default([]);

const listSchema = Joi.object({
  q: Joi.string().trim().max(120).allow('').default(''),
  role: Joi.string().valid('', ...VALID_ADMIN_ROLES).default(''),
  status: Joi.string().valid('', ...Object.values(ADMIN_STATUSES)).default('')
}).unknown(false);

const grantSchema = Joi.object({
  _csrf: Joi.any().strip(),
  identifier: Joi.string().trim().min(3).max(254).required(),
  role: assignableRole,
  permissions
}).unknown(false);

const accessSchema = Joi.object({
  _csrf: Joi.any().strip(),
  role: assignableRole,
  permissions
}).unknown(false);

const statusSchema = Joi.object({
  _csrf: Joi.any().strip(),
  status: Joi.string().valid(...Object.values(ADMIN_STATUSES)).required(),
  reason: Joi.when('status', {
    is: ADMIN_STATUSES.INACTIVE,
    then: Joi.string().trim().min(5).max(300).required(),
    otherwise: Joi.string().trim().max(300).allow('').default('')
  })
}).unknown(false);

function normalizePermissions(body) {
  if (!body?.permissions) return [];
  return Array.isArray(body.permissions) ? body.permissions : [body.permissions];
}

function requireDashboardPermission(result) {
  if (result.error || result.value.role === 'super_admin') return result;
  if (!result.value.permissions.includes('dashboard.read')) {
    return {
      error: new Error('Mọi tài khoản admin cần quyền xem tổng quan.'),
      value: result.value
    };
  }
  return result;
}

function validateListQuery(query) {
  return listSchema.validate(query, {
    abortEarly: false,
    convert: true,
    stripUnknown: false
  });
}

function validateGrant(body) {
  return requireDashboardPermission(grantSchema.validate({
    ...body,
    permissions: normalizePermissions(body)
  }, {
    abortEarly: false,
    convert: true,
    stripUnknown: true
  }));
}

function validateAccessUpdate(body) {
  return requireDashboardPermission(accessSchema.validate({
    ...body,
    permissions: normalizePermissions(body)
  }, {
    abortEarly: false,
    convert: true,
    stripUnknown: true
  }));
}

function validateStatusUpdate(body) {
  return statusSchema.validate(body, {
    abortEarly: false,
    convert: true,
    stripUnknown: true
  });
}

module.exports = {
  validateListQuery,
  validateGrant,
  validateAccessUpdate,
  validateStatusUpdate
};
