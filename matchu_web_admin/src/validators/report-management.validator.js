const Joi = require('joi');
const { REPORT_CASE_ACTIONS } = require('../config/constants');

const reportTypes = ['post', 'comment', 'profile', 'matching'];
const reportStatuses = ['open', 'in_review', 'resolved', 'dismissed'];
const reportPriorities = ['normal', 'medium', 'high', 'critical'];
const resolutions = [
  'action_taken',
  'content_removed',
  'account_penalized',
  'no_action',
  'not_violation'
];

const listSchema = Joi.object({
  q: Joi.string().trim().max(120).allow('').default(''),
  type: Joi.string().valid('', ...reportTypes).default(''),
  status: Joi.string().valid('', ...reportStatuses).default(''),
  source: Joi.string().valid('', 'community', 'content_moderation').default(''),
  priority: Joi.string().valid('', ...reportPriorities).default(''),
  assignee: Joi.string().valid('', 'me', 'unassigned').default(''),
  cursor: Joi.string().trim().max(160).allow('').default(''),
  limit: Joi.number().integer().min(10).max(50).default(20)
});

const caseIdSchema = Joi.string()
  .trim()
  .pattern(/^(post|profile|matching)_[a-f0-9]{40}$/)
  .required();

const actionSchema = Joi.object({
  action: Joi.string().valid(...Object.values(REPORT_CASE_ACTIONS)).required(),
  reason: Joi.when('action', {
    is: Joi.valid(
      REPORT_CASE_ACTIONS.RESOLVE,
      REPORT_CASE_ACTIONS.DISMISS,
      REPORT_CASE_ACTIONS.REOPEN
    ),
    then: Joi.string().trim().min(5).max(500).required(),
    otherwise: Joi.string().trim().max(500).allow('').default('')
  }),
  resolution: Joi.when('action', {
    is: REPORT_CASE_ACTIONS.RESOLVE,
    then: Joi.string().valid(...resolutions).required(),
    otherwise: Joi.string().valid('', ...resolutions).default('')
  })
});

function validateReportListQuery(query) {
  return listSchema.validate(query, {
    abortEarly: true,
    stripUnknown: true,
    convert: true
  });
}

function validateReportCaseId(value) {
  return caseIdSchema.validate(value, { abortEarly: true, convert: true });
}

function validateReportAction(body) {
  return actionSchema.validate(body, {
    abortEarly: true,
    stripUnknown: true,
    convert: true
  });
}

module.exports = {
  validateReportListQuery,
  validateReportCaseId,
  validateReportAction,
  reportTypes,
  reportStatuses,
  reportPriorities,
  resolutions
};
