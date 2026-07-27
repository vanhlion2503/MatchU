const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validatePostListQuery,
  validateModerationQueueQuery,
  validatePostId,
  validatePostAction
} = require('../src/validators/post-management.validator');

test('normalizes post list filters with safe defaults', () => {
  const { error, value } = validatePostListQuery({
    q: '  noi dung  ',
    moderation: 'review_required',
    limit: '50'
  });
  assert.equal(error, undefined);
  assert.equal(value.q, 'noi dung');
  assert.equal(value.moderation, 'review_required');
  assert.equal(value.limit, 50);
  assert.equal(value.lifecycle, '');
});

test('rejects unsupported moderation queue and unsafe post id', () => {
  assert.ok(validateModerationQueueQuery({ queue: 'unknown' }).error);
  assert.ok(validatePostId('../users/admin').error);
  assert.equal(validatePostId('repost_user-1_post-2').error, undefined);
});

test('requires a meaningful reason for every post decision', () => {
  assert.ok(validatePostAction({ action: 'reject', reason: 'bad' }).error);
  const valid = validatePostAction({
    action: 'reject',
    reason: 'Nội dung vi phạm tiêu chuẩn cộng đồng.'
  });
  assert.equal(valid.error, undefined);
  assert.equal(valid.value.action, 'reject');
});

test('rejects unknown post moderation action', () => {
  const { error } = validatePostAction({
    action: 'hard_delete',
    reason: 'Thao tác không được hỗ trợ.'
  });
  assert.ok(error);
});

test('requires confirmation for permanent deletion', () => {
  assert.ok(validatePostAction({
    action: 'delete_permanently',
    reason: 'Xóa dữ liệu theo yêu cầu quản trị.'
  }).error);

  const valid = validatePostAction({
    action: 'delete_permanently',
    reason: 'Xóa dữ liệu theo yêu cầu quản trị.',
    confirmation: 'post-1'
  });
  assert.equal(valid.error, undefined);
  assert.equal(valid.value.confirmation, 'post-1');
});
