const test = require('node:test');
const assert = require('node:assert/strict');

process.env.NODE_ENV = 'test';
const { __test } = require('../src/services/post-management.service');
const {
  buildAdminPostSearchQueryTerms,
  buildAdminPostSearchTerms
} = require('../src/utils/post-search-index');

function fakeDocument(id, data) {
  return { id, data: () => data };
}

test('normalizes legacy post data without changing mobile defaults', () => {
  const post = __test.normalizePost(fakeDocument('post-1', {
    authorId: 'user-1',
    content: '  Xin chào MatchU  ',
    isPublic: false,
    media: [{ type: 'voice', url: 'https://storage.googleapis.com/audio.m4a' }],
    stats: { likeCount: -2, commentCount: 4.9 },
    author: { name: 'Nguyễn An', nickname: 'an' }
  }));
  assert.equal(post.postId, 'post-1');
  assert.equal(post.content, 'Xin chào MatchU');
  assert.equal(post.visibility, 'private');
  assert.equal(post.moderationStatus, 'approved');
  assert.equal(post.media[0].type, 'audio');
  assert.equal(post.stats.likeCount, 0);
  assert.equal(post.stats.commentCount, 4);
});

test('normalizes moderation aliases used by legacy and video flows', () => {
  assert.equal(__test.normalizeModerationStatus('processing'), 'pending_moderation');
  assert.equal(__test.normalizeModerationStatus('needs_review'), 'review_required');
  assert.equal(__test.normalizeModerationStatus(null), 'approved');
});

test('accepts only https media URLs for the admin preview', () => {
  assert.equal(__test.safeHttpsUrl('javascript:alert(1)'), '');
  assert.equal(__test.safeHttpsUrl('http://example.com/image.jpg'), '');
  assert.equal(
    __test.safeHttpsUrl('https://storage.googleapis.com/image.jpg'),
    'https://storage.googleapis.com/image.jpg'
  );
});

test('calculates operational priority from reports and AI severity', () => {
  assert.equal(__test.calculatePriority({
    moderationStatus: 'approved',
    reportCount: 10,
    videoModeration: null
  }), 'critical');
  assert.equal(__test.calculatePriority({
    moderationStatus: 'review_required',
    reportCount: 0,
    videoModeration: { overallSeverity: 2 }
  }), 'high');
  assert.equal(__test.calculatePriority({
    moderationStatus: 'approved',
    reportCount: 1,
    videoModeration: null
  }), 'medium');
});

test('matches post filters and respects resolved report cases', () => {
  const post = {
    postId: 'post-1',
    authorId: 'user-1',
    author: { name: 'Nguyễn An', nickname: 'an' },
    content: 'Bài viết âm nhạc',
    tags: ['music'],
    postType: 'post',
    media: [],
    mediaTypes: [],
    visibility: 'public',
    moderationStatus: 'approved',
    deletedAt: null,
    reportCount: 2,
    priority: 'medium',
    moderationCase: { status: 'resolved' }
  };
  const base = {
    q: '', type: '', media: '', visibility: '', moderation: '',
    lifecycle: '', report: '', priority: '', queue: ''
  };
  assert.equal(__test.matchesPostFilters(post, { ...base, q: 'ÂM NHẠC' }), true);
  assert.equal(__test.matchesPostFilters(post, { ...base, q: 'am nhac' }), true);
  assert.equal(__test.matchesPostFilters(post, { ...base, report: 'open' }), false);
  assert.equal(__test.matchesPostFilters(post, { ...base, report: 'resolved' }), true);
  assert.equal(__test.matchesPostDocumentFilters(post, { ...base, q: 'music' }), true);
  assert.equal(__test.matchesPostDocumentFilters(post, { ...base, q: 'không tồn tại' }), false);
  assert.equal(__test.matchesPostDocumentFilters(post, { ...base, queue: 'moderation' }), false);
  assert.equal(__test.matchesPostDocumentFilters(
    { ...post, moderationStatus: 'review_required' },
    { ...base, queue: 'moderation' }
  ), true);
});

test('reopens a resolved case when a newer community report arrives', () => {
  const post = {
    reportCount: 3,
    latestReportAt: new Date('2026-07-20T00:00:00Z'),
    moderationCase: {
      status: 'resolved',
      resolvedAt: new Date('2026-07-19T00:00:00Z')
    }
  };
  const base = {
    q: '', type: '', media: '', visibility: '', moderation: '',
    lifecycle: '', report: 'open', priority: '', queue: ''
  };
  Object.assign(post, {
    postId: 'post-2',
    authorId: 'user-2',
    author: { name: '', nickname: '' },
    content: '',
    tags: [],
    postType: 'post',
    media: [],
    mediaTypes: [],
    visibility: 'public',
    moderationStatus: 'approved',
    deletedAt: null,
    priority: 'medium'
  });
  assert.equal(__test.matchesPostFilters(post, base), true);
});

test('restores the last safe visibility before admin moderation', () => {
  assert.equal(__test.resolveRestoredVisibility({
    visibility: 'private',
    requestedVisibility: 'followers',
    adminModeration: { previousVisibility: 'public' }
  }), 'public');
  assert.equal(__test.resolveRestoredVisibility({
    visibility: 'private',
    requestedVisibility: 'followers'
  }), 'followers');
});

test('builds accent-insensitive admin search terms with substring ngrams', () => {
  const terms = buildAdminPostSearchTerms('post-1', {
    authorId: 'user-1',
    content: 'Âm nhạc mùa hè',
    author: { name: 'Nguyễn An' },
    tags: ['Giải trí']
  });
  assert.ok(terms.includes('nhac'));
  assert.ok(terms.includes('mua'));
  assert.ok(terms.includes('guy'));
  assert.ok(buildAdminPostSearchQueryTerms('nhạc mùa').includes('nhac'));
});
