const test = require('node:test');
const assert = require('node:assert/strict');

process.env.NODE_ENV = 'test';
const { __test } = require('../src/services/user-account.service');

function fakeDocument(id, data) {
  return { id, data: () => data };
}

test('normalizes legacy user data safely', () => {
  const user = __test.normalizeUser(fakeDocument('u-1', {
    fullname: ' Nguyễn An ',
    gem: -4,
    reputationScore: 76.9,
    followers: ['a', 'b'],
    accountStatus: '',
    isFaceVerified: true
  }));
  assert.equal(user.uid, 'u-1');
  assert.equal(user.fullname, 'Nguyễn An');
  assert.equal(user.gem, 0);
  assert.equal(user.reputationScore, 76);
  assert.equal(user.followersCount, 2);
  assert.equal(user.accountStatus, 'active');
  assert.equal(user.isFaceVerified, true);
});

test('matches search and risk filters', () => {
  const user = __test.normalizeUser(fakeDocument('firebase-uid', {
    fullname: 'Nguyễn Văn An',
    nickname: 'an.nguyen',
    email: 'an@example.com',
    totalReports: 3,
    trustWarnings: 1,
    reputationScore: 42
  }));
  assert.equal(__test.matchesFilters(user, {
    q: 'AN.NGUYEN', status: '', verification: '', activity: '', risk: 'reported'
  }), true);
  assert.equal(__test.matchesFilters(user, {
    q: '', status: '', verification: '', activity: '', risk: 'low_reputation'
  }), true);
  assert.equal(__test.matchesFilters(user, {
    q: 'không tồn tại', status: '', verification: '', activity: '', risk: ''
  }), false);
});
