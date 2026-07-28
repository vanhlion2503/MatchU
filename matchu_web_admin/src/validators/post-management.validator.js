const Joi = require('joi');
const { POST_MODERATION_ACTIONS } = require('../config/constants');

const postTypes = ['post', 'quote', 'repost'];
const mediaTypes = ['text', 'image', 'video', 'audio'];
const visibilities = ['public', 'followers', 'private'];
const moderationStatuses = ['approved', 'pending_moderation', 'review_required', 'rejected'];
const priorities = ['normal', 'medium', 'high', 'critical'];

const baseListFields = {
  q: Joi.string().trim().max(120).allow('').default(''),
  type: Joi.string().valid('', ...postTypes).default(''),
  media: Joi.string().valid('', ...mediaTypes).default(''),
  visibility: Joi.string().valid('', ...visibilities).default(''),
  moderation: Joi.string().valid('', ...moderationStatuses).default(''),
  lifecycle: Joi.string().valid('', 'active', 'deleted').default(''),
  report: Joi.string().valid('', 'reported', 'unreported', 'open', 'resolved').default(''),
  queue: Joi.string().valid('', 'moderation').default(''),
  priority: Joi.string().valid('', ...priorities).default(''),
  cursor: Joi.string().trim().max(160).allow('').default(''),
  limit: Joi.number().integer().min(10).max(50).default(20)
};

const listSchema = Joi.object(baseListFields);
const postIdSchema = Joi.string().trim().pattern(/^[A-Za-z0-9_-]{1,160}$/).required();
const actionSchema = Joi.object({
  action: Joi.string().valid(...Object.values(POST_MODERATION_ACTIONS)).required(),
  reason: Joi.string().trim().min(5).max(500).required(),
  confirmation: Joi.when('action', {
    is: POST_MODERATION_ACTIONS.DELETE_PERMANENTLY,
    then: Joi.string().trim().min(1).max(160).required(),
    otherwise: Joi.string().trim().max(160).allow('').default('')
  })
});

function validatePostListQuery(query) {
  return listSchema.validate(query, {
    abortEarly: true,
    stripUnknown: true,
    convert: true
  });
}

function validatePostId(value) {
  return postIdSchema.validate(value, { abortEarly: true, convert: true });
}

function validatePostAction(body) {
  return actionSchema.validate(body, {
    abortEarly: true,
    stripUnknown: true,
    convert: true
  });
}

module.exports = {
  validatePostListQuery,
  validatePostId,
  validatePostAction,
  postTypes,
  mediaTypes,
  visibilities,
  moderationStatuses,
  priorities
};
