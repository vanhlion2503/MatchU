const Joi = require('joi');
const {
  NOTIFICATION_CATEGORIES,
  NOTIFICATION_AUDIENCES,
  NOTIFICATION_STATUSES
} = require('../config/constants');

const categories = Object.values(NOTIFICATION_CATEGORIES);
const audiences = Object.values(NOTIFICATION_AUDIENCES);
const listStatuses = ['', ...Object.values(NOTIFICATION_STATUSES)];
const accountStatuses = ['active', 'restricted', 'suspended', 'banned'];
const genders = ['male', 'female', 'other'];
const platforms = ['android', 'ios'];

function asArray(value) {
  if (value == null || value === '') return [];
  return Array.isArray(value) ? value : [value];
}

function normalizePayload(body) {
  return {
    ...body,
    accountStatuses: asArray(body.accountStatuses),
    genders: asArray(body.genders),
    platforms: asArray(body.platforms),
    channelPush: body.channelPush === 'on' || body.channelPush === true,
    channelInbox: body.channelInbox === 'on' || body.channelInbox === true,
    interestTags: String(body.interestTags || '')
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean)
  };
}

const nullableNumber = Joi.alternatives().try(
  Joi.number().integer(),
  Joi.string().valid('')
);

const campaignSchema = Joi.object({
  intent: Joi.string().valid('save_draft', 'publish').required(),
  revision: Joi.number().integer().min(0).default(0),
  category: Joi.string().valid(...categories).default(NOTIFICATION_CATEGORIES.GENERAL),
  title: Joi.string().trim().max(120).allow('').default(''),
  body: Joi.string().trim().max(500).allow('').default(''),
  audienceType: Joi.string().valid(...audiences).default(NOTIFICATION_AUDIENCES.ALL),
  targetUserId: Joi.string().trim().max(128).allow('').default(''),
  accountStatuses: Joi.array().items(Joi.string().valid(...accountStatuses)).unique().default([]),
  genders: Joi.array().items(Joi.string().valid(...genders)).unique().default([]),
  platforms: Joi.array().items(Joi.string().valid(...platforms)).unique().default([]),
  verification: Joi.string()
    .valid('', 'face_verified', 'face_unverified', 'profile_completed', 'profile_incomplete')
    .default(''),
  activityDays: nullableNumber.default(''),
  minAge: nullableNumber.default(''),
  maxAge: nullableNumber.default(''),
  minReputation: nullableNumber.default(''),
  maxReputation: nullableNumber.default(''),
  minAppVersion: Joi.string().trim().max(40).allow('').default(''),
  maxAppVersion: Joi.string().trim().max(40).allow('').default(''),
  interestTags: Joi.array().items(Joi.string().trim().max(60)).max(20).unique().default([]),
  channelPush: Joi.boolean().default(false),
  channelInbox: Joi.boolean().default(false),
  sendMode: Joi.string().valid('immediate', 'scheduled').default('immediate'),
  scheduledAtLocal: Joi.string().trim().max(40).allow('').default(''),
  timeZone: Joi.string().valid('Asia/Bangkok').default('Asia/Bangkok'),
  actionType: Joi.string().valid('inbox', 'app_route', 'external_url').default('inbox'),
  actionValue: Joi.string().trim().max(500).allow('').default('')
}).custom((value, helpers) => {
  const activityDays = value.activityDays === '' ? null : Number(value.activityDays);
  if (activityDays != null && (activityDays < 1 || activityDays > 3650)) {
    return helpers.message({ custom: 'Khoảng hoạt động phải từ 1 đến 3650 ngày.' });
  }
  const minReputation = value.minReputation === '' ? null : Number(value.minReputation);
  const maxReputation = value.maxReputation === '' ? null : Number(value.maxReputation);
  if (minReputation != null && minReputation < 0) {
    return helpers.message({ custom: 'Điểm uy tín tối thiểu không hợp lệ.' });
  }
  if (maxReputation != null && maxReputation < 0) {
    return helpers.message({ custom: 'Điểm uy tín tối đa không hợp lệ.' });
  }
  if (minReputation != null && maxReputation != null && minReputation > maxReputation) {
    return helpers.message({ custom: 'Khoảng điểm uy tín không hợp lệ.' });
  }
  const minAge = value.minAge === '' ? null : Number(value.minAge);
  const maxAge = value.maxAge === '' ? null : Number(value.maxAge);
  if (minAge != null && (minAge < 13 || minAge > 120)) {
    return helpers.message({ custom: 'Tuổi tối thiểu không hợp lệ.' });
  }
  if (maxAge != null && (maxAge < 13 || maxAge > 120)) {
    return helpers.message({ custom: 'Tuổi tối đa không hợp lệ.' });
  }
  if (minAge != null && maxAge != null && minAge > maxAge) {
    return helpers.message({ custom: 'Khoảng tuổi không hợp lệ.' });
  }
  if (value.intent === 'save_draft') return value;
  if (value.title.length < 3) return helpers.message({ custom: 'Tiêu đề phải có ít nhất 3 ký tự.' });
  if (value.body.length < 3) return helpers.message({ custom: 'Nội dung phải có ít nhất 3 ký tự.' });
  if (!value.channelPush && !value.channelInbox) {
    return helpers.message({ custom: 'Phải chọn ít nhất một kênh gửi.' });
  }
  if (value.audienceType === NOTIFICATION_AUDIENCES.SINGLE_USER && !value.targetUserId) {
    return helpers.message({ custom: 'Vui lòng chọn người dùng nhận thông báo.' });
  }
  if (value.sendMode === 'scheduled' && !value.scheduledAtLocal) {
    return helpers.message({ custom: 'Vui lòng chọn thời gian gửi.' });
  }
  if (value.actionType !== 'inbox' && !value.actionValue) {
    return helpers.message({ custom: 'Vui lòng nhập đích đến khi mở thông báo.' });
  }
  if (
    value.actionType === 'app_route'
    && !['notifications', 'settings', 'account_security', 'reputation'].includes(value.actionValue)
  ) {
    return helpers.message({ custom: 'Màn hình ứng dụng không nằm trong danh sách cho phép.' });
  }
  if (value.actionType === 'external_url') {
    try {
      const url = new URL(value.actionValue);
      if (url.protocol !== 'https:') throw new Error('invalid protocol');
    } catch (_) {
      return helpers.message({ custom: 'Liên kết ngoài phải là URL HTTPS hợp lệ.' });
    }
  }
  return value;
});

const listSchema = Joi.object({
  status: Joi.string().valid(...listStatuses).default(''),
  category: Joi.string().valid('', ...categories).default(''),
  audienceType: Joi.string().valid('', ...audiences).default(''),
  limit: Joi.number().integer().min(10).max(100).default(30)
});

const actionSchema = Joi.object({
  _csrf: Joi.string().allow('').optional(),
  action: Joi.string().valid('cancel', 'retry_failed').required()
});

function validateCampaign(body) {
  return campaignSchema.validate(normalizePayload(body), {
    abortEarly: true,
    stripUnknown: true,
    convert: true
  });
}

function validateListQuery(query) {
  return listSchema.validate(query, {
    abortEarly: true,
    stripUnknown: true,
    convert: true
  });
}

function validateCampaignAction(body) {
  return actionSchema.validate(body, {
    abortEarly: true,
    stripUnknown: true
  });
}

module.exports = {
  validateCampaign,
  validateListQuery,
  validateCampaignAction,
  normalizePayload
};
