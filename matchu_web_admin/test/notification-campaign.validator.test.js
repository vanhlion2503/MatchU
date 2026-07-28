const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validateCampaign
} = require('../src/validators/notification-campaign.validator');

function validPayload(overrides = {}) {
  return {
    intent: 'publish',
    category: 'general',
    title: 'Thông báo MatchU',
    body: 'Nội dung thông báo dành cho người dùng.',
    audienceType: 'all',
    channelPush: 'on',
    channelInbox: 'on',
    sendMode: 'immediate',
    actionType: 'inbox',
    ...overrides
  };
}

test('allows an incomplete draft without publishing it', () => {
  const { error, value } = validateCampaign({
    intent: 'save_draft',
    title: '',
    body: '',
    audienceType: 'all'
  });
  assert.equal(error, undefined);
  assert.equal(value.channelPush, false);
  assert.equal(value.channelInbox, false);
});

test('requires content and a delivery channel when publishing', () => {
  const result = validateCampaign(validPayload({
    title: '',
    channelPush: undefined,
    channelInbox: undefined
  }));
  assert.ok(result.error);
});

test('requires a UID for a single-user campaign', () => {
  const result = validateCampaign(validPayload({
    audienceType: 'single_user',
    targetUserId: ''
  }));
  assert.ok(result.error);
});

test('accepts only allowlisted app routes and HTTPS links', () => {
  assert.equal(validateCampaign(validPayload({
    actionType: 'app_route',
    actionValue: 'settings'
  })).error, undefined);
  assert.ok(validateCampaign(validPayload({
    actionType: 'app_route',
    actionValue: '/admin'
  })).error);
  assert.ok(validateCampaign(validPayload({
    actionType: 'external_url',
    actionValue: 'http://example.com'
  })).error);
});
