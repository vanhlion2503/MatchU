const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ejs = require('ejs');

const view = path.join(__dirname, '..', 'src', 'views', 'notifications', 'form.ejs');

function locals(hasPermission) {
  return {
    campaign: null,
    csrfToken: 'csrf-token',
    errorMessage: null,
    categoryLabels: {
      general: 'Thông báo hệ thống',
      maintenance: 'Thông báo bảo trì'
    },
    audienceLabels: {
      all: 'Toàn hệ thống',
      segment: 'Nhóm người dùng',
      single_user: 'Một người dùng'
    },
    hasPermission,
    form: {
      revision: 0,
      category: 'general',
      title: 'Thông báo',
      body: 'Nội dung',
      audienceType: 'segment',
      targetUserId: '',
      accountStatuses: ['active'],
      genders: [],
      platforms: ['android'],
      verification: '',
      activityDays: '',
      minAge: '',
      maxAge: '',
      minReputation: '',
      maxReputation: '',
      minAppVersion: '',
      maxAppVersion: '',
      interestTags: '',
      channelPush: true,
      channelInbox: true,
      sendMode: 'scheduled',
      scheduledAtLocal: '2026-08-01T20:00',
      actionType: 'inbox',
      actionValue: ''
    }
  };
}

test('renders the notification composer with protected publish controls', async () => {
  const html = await ejs.renderFile(view, locals(() => true));
  assert.match(html, /data-notification-composer/);
  assert.match(html, /name="_csrf" value="csrf-token"/);
  assert.match(html, /name="intent" value="save_draft"/);
  assert.match(html, /name="intent" value="publish"/);
  assert.match(html, /name="scheduledAtLocal"/);
});

test('hides publish when the admin has create-only permission', async () => {
  const html = await ejs.renderFile(view, locals(() => false));
  assert.doesNotMatch(html, /name="intent" value="publish"/);
  assert.match(html, /name="intent" value="save_draft"/);
});
