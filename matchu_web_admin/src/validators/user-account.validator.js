const Joi = require('joi');
const {
  USER_ACCOUNT_STATUSES,
  USER_ACTIONS
} = require('../config/constants');

const allowedStatuses = Object.values(USER_ACCOUNT_STATUSES);
const allowedActions = Object.values(USER_ACTIONS);
const allowedFeatures = ['posts', 'comments', 'chat', 'matching', 'calls'];

const listSchema = Joi.object({
  q: Joi.string().trim().max(120).allow('').default(''),
  status: Joi.string().valid('', ...allowedStatuses).default(''),
  verification: Joi.string()
    .valid('', 'face_verified', 'face_unverified', 'profile_completed', 'profile_incomplete')
    .default(''),
  activity: Joi.string().valid('', 'online', 'offline').default(''),
  risk: Joi.string().valid('', 'reported', 'warned', 'low_reputation').default(''),
  cursor: Joi.string().trim().max(256).allow('').default(''),
  limit: Joi.number().integer().min(10).max(50).default(20)
});

const actionSchema = Joi.object({
  action: Joi.string().valid(...allowedActions).required(),
  reason: Joi.when('action', {
    is: Joi.valid(
      USER_ACTIONS.WARN,
      USER_ACTIONS.RESTRICT,
      USER_ACTIONS.SUSPEND,
      USER_ACTIONS.BAN,
      USER_ACTIONS.ADJUST_GEM,
      USER_ACTIONS.ADJUST_REPUTATION
    ),
    then: Joi.string().trim().min(5).max(500).required(),
    otherwise: Joi.string().trim().max(500).allow('').default('')
  }),
  features: Joi.when('action', {
    is: USER_ACTIONS.RESTRICT,
    then: Joi.array().items(Joi.string().valid(...allowedFeatures)).min(1).required(),
    otherwise: Joi.array().items(Joi.string()).default([])
  }),
  durationDays: Joi.when('action', {
    is: Joi.valid(USER_ACTIONS.RESTRICT, USER_ACTIONS.SUSPEND),
    then: Joi.number().integer().min(1).max(365).required(),
    otherwise: Joi.number().integer().min(1).max(365).optional()
  }),
  amount: Joi.when('action', {
    is: Joi.valid(USER_ACTIONS.ADJUST_GEM, USER_ACTIONS.ADJUST_REPUTATION),
    then: Joi.number().integer().min(-100000).max(100000).invalid(0).required(),
    otherwise: Joi.number().integer().optional()
  }),
  reportId: Joi.string().trim().max(160).allow('').default('')
});

function validateListQuery(query) {
  return listSchema.validate(query, {
    abortEarly: true,
    stripUnknown: true,
    convert: true
  });
}

function validateUserAction(body) {
  const normalized = {
    ...body,
    features: body.features
      ? (Array.isArray(body.features) ? body.features : [body.features])
      : []
  };
  if (normalized.durationDays === '') delete normalized.durationDays;
  if (normalized.amount === '') delete normalized.amount;
  return actionSchema.validate(normalized, {
    abortEarly: true,
    stripUnknown: true,
    convert: true
  });
}

module.exports = { validateListQuery, validateUserAction, allowedFeatures };
