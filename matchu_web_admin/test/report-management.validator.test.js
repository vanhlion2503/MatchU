const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validateReportListQuery,
  validateReportCaseId,
  validateReportAction
} = require('../src/validators/report-management.validator');

test('normalizes report queue filters', () => {
  const { error, value } = validateReportListQuery({
    q: ' post-1 ',
    type: 'post',
    status: 'open',
    priority: 'high',
    assignee: 'me',
    limit: '50'
  });
  assert.equal(error, undefined);
  assert.equal(value.q, 'post-1');
  assert.equal(value.limit, 50);
});

test('accepts only generated report case ids', () => {
  assert.equal(validateReportCaseId(`post_${'a'.repeat(40)}`).error, undefined);
  assert.ok(validateReportCaseId('../reportCases/admin').error);
});

test('requires a conclusion and reason when resolving a report', () => {
  assert.ok(validateReportAction({ action: 'resolve', reason: 'Ngắn' }).error);
  const result = validateReportAction({
    action: 'resolve',
    reason: 'Đã kiểm tra đầy đủ bằng chứng cộng đồng.',
    resolution: 'action_taken'
  });
  assert.equal(result.error, undefined);
  assert.equal(result.value.resolution, 'action_taken');
});

test('allows assignment without a reason', () => {
  const result = validateReportAction({ action: 'assign_to_me' });
  assert.equal(result.error, undefined);
  assert.equal(result.value.reason, '');
});
