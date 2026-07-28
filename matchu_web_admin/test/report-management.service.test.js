const test = require('node:test');
const assert = require('node:assert/strict');
const { __test } = require('../src/services/report-management.service');

function fakeDocument(id, data) {
  return { id, data: () => data };
}

test('normalizes report cases and rejects unsafe evidence URLs', () => {
  const reportCase = __test.normalizeCase(fakeDocument(`post_${'a'.repeat(40)}`, {
    type: 'post',
    targetId: 'post-1',
    reportedUid: 'user-1',
    status: 'open',
    reportCount: 2.9,
    categoryKeys: ['spam']
  }));
  const report = __test.normalizeReport(fakeDocument('projection-1', {
    id: 'report-1',
    reporterUid: 'reporter-1',
    imageUrls: ['javascript:alert(1)', 'https://storage.googleapis.com/evidence.jpg']
  }));

  assert.equal(reportCase.reportCount, 2);
  assert.deepEqual(report.categoryKeys, undefined);
  assert.deepEqual(report.imageUrls, ['https://storage.googleapis.com/evidence.jpg']);
});

test('matches operational report filters and current admin assignment', () => {
  const reportCase = {
    caseId: `profile_${'b'.repeat(40)}`,
    type: 'profile',
    targetId: 'user-2',
    reportedUid: 'user-2',
    postId: '',
    roomId: '',
    status: 'open',
    priority: 'high',
    assignedAdminId: 'admin-1',
    assignedAdminEmail: 'admin@example.com',
    latestReasonKey: 'scam',
    categoryKeys: ['scam']
  };
  const filters = { q: 'USER-2', priority: 'high', assignee: 'me' };
  assert.equal(__test.matchesFilters(reportCase, filters, { uid: 'admin-1' }), true);
  assert.equal(__test.matchesFilters(
    reportCase,
    { ...filters, assignee: 'unassigned' },
    { uid: 'admin-1' }
  ), false);
});

test('maps report actions to safe workflow states', () => {
  assert.deepEqual(
    __test.actionOutcome('start_review', {}, 'open'),
    { status: 'in_review', resolution: '' }
  );
  assert.deepEqual(
    __test.actionOutcome('dismiss', {}, 'open'),
    { status: 'dismissed', resolution: 'not_violation' }
  );
});

test('recognizes legacy comment cases and normalizes comment evidence safely', () => {
  const reportCase = __test.normalizeCase(fakeDocument(`post_${'c'.repeat(40)}`, {
    type: 'post',
    targetId: 'post-1',
    contextId: 'comment-1',
    postId: 'post-1',
    reportedUid: 'author-1'
  }));
  const report = __test.normalizeReport(fakeDocument('commentReports_report-1', {
    source: 'commentReports',
    commentId: 'comment-1',
    parentId: 'parent-1',
    commentContentPreview: 'Nội dung bình luận',
    commentImageUrl: 'javascript:alert(1)',
    commentVoiceUrl: 'https://storage.googleapis.com/comment.m4a'
  }));

  assert.equal(reportCase.subjectType, 'comment');
  assert.equal(reportCase.commentId, 'comment-1');
  assert.equal(report.commentImageUrl, '');
  assert.equal(report.commentVoiceUrl, 'https://storage.googleapis.com/comment.m4a');
  assert.equal(
    __test.matchesFilters(reportCase, {
      type: 'comment',
      source: '',
      priority: '',
      assignee: '',
      q: 'comment-1'
    }, { uid: 'admin-1' }),
    true
  );
  assert.equal(
    __test.matchesFilters(reportCase, {
      type: 'post',
      source: '',
      priority: '',
      assignee: '',
      q: ''
    }, { uid: 'admin-1' }),
    false
  );
});
