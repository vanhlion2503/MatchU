(() => {
  'use strict';

  const form = document.querySelector('[data-notification-composer]');
  if (!form) return;

  const audienceRadios = [...form.querySelectorAll('input[name="audienceType"]')];
  const segmentFields = form.querySelector('[data-segment-audience]');
  const singleFields = form.querySelector('[data-single-audience]');
  const sendMode = form.querySelector('[data-send-mode]');
  const scheduleFields = form.querySelector('[data-schedule-fields]');
  const actionType = form.querySelector('[data-action-type]');
  const actionValueWrap = form.querySelector('[data-action-value-wrap]');
  const titleInput = form.querySelector('[data-preview-title]');
  const bodyInput = form.querySelector('[data-preview-body]');
  const titleOutput = form.querySelector('[data-preview-title-output]');
  const bodyOutput = form.querySelector('[data-preview-body-output]');
  const publishLabel = form.querySelector('[data-publish-label]');
  const userSearch = form.querySelector('[data-user-search]');
  const userResults = form.querySelector('[data-user-results]');
  const estimateButton = form.querySelector('[data-estimate-audience]');
  const estimateOutput = form.querySelector('[data-estimate-output]');
  let userSearchTimer;

  function updateAudience() {
    const selected = audienceRadios.find((radio) => radio.checked)?.value || 'all';
    if (segmentFields) segmentFields.hidden = selected !== 'segment';
    if (singleFields) singleFields.hidden = selected !== 'single_user';
  }

  function updateSchedule() {
    const scheduled = sendMode?.value === 'scheduled';
    if (scheduleFields) scheduleFields.hidden = !scheduled;
    if (publishLabel) publishLabel.textContent = scheduled ? 'Lên lịch' : 'Gửi ngay';
  }

  function updateAction() {
    if (actionValueWrap) actionValueWrap.hidden = actionType?.value === 'inbox';
  }

  function updatePreview() {
    if (titleOutput) titleOutput.textContent = titleInput?.value.trim() || 'Tiêu đề thông báo';
    if (bodyOutput) bodyOutput.textContent = bodyInput?.value.trim() || 'Nội dung thông báo sẽ hiển thị tại đây.';
  }

  function showUserResults(users) {
    if (!userResults) return;
    userResults.replaceChildren();
    userResults.hidden = users.length === 0;
    users.forEach((user) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'notification-user-result';
      const name = document.createElement('strong');
      name.textContent = user.displayName;
      const detail = document.createElement('small');
      detail.textContent = `${user.email || 'Không có email'} · ${user.uid}`;
      button.append(name, detail);
      button.addEventListener('click', () => {
        userSearch.value = user.uid;
        userResults.hidden = true;
      });
      userResults.append(button);
    });
  }

  async function searchUsers() {
    const query = userSearch?.value.trim() || '';
    if (query.length < 2) {
      showUserResults([]);
      return;
    }
    try {
      const response = await fetch(`/notifications/users/search?q=${encodeURIComponent(query)}`, {
        headers: { Accept: 'application/json' }
      });
      if (!response.ok) return;
      const payload = await response.json();
      showUserResults(Array.isArray(payload.users) ? payload.users : []);
    } catch (_) {
      showUserResults([]);
    }
  }

  async function estimateAudience() {
    if (!estimateButton || !estimateOutput) return;
    estimateButton.disabled = true;
    estimateOutput.textContent = 'Đang tính toán...';
    const data = new URLSearchParams(new FormData(form));
    data.set('intent', 'save_draft');
    try {
      const response = await fetch('/notifications/audience-estimate', {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: data
      });
      const payload = await response.json();
      if (!response.ok || !payload.success) throw new Error(payload.message);
      const formatted = new Intl.NumberFormat('vi-VN').format(payload.estimatedUsers || 0);
      estimateOutput.textContent = payload.truncated
        ? `Ít nhất ${formatted} người trong ${payload.scannedUsers} hồ sơ đã quét.`
        : `Khoảng ${formatted} người dùng mục tiêu.`;
    } catch (_) {
      estimateOutput.textContent = 'Không thể ước tính lúc này.';
    } finally {
      estimateButton.disabled = false;
    }
  }

  audienceRadios.forEach((radio) => radio.addEventListener('change', updateAudience));
  sendMode?.addEventListener('change', updateSchedule);
  actionType?.addEventListener('change', updateAction);
  titleInput?.addEventListener('input', updatePreview);
  bodyInput?.addEventListener('input', updatePreview);
  userSearch?.addEventListener('input', () => {
    window.clearTimeout(userSearchTimer);
    userSearchTimer = window.setTimeout(searchUsers, 300);
  });
  estimateButton?.addEventListener('click', estimateAudience);
  form.addEventListener('submit', (event) => {
    const submitter = event.submitter;
    if (submitter?.value !== 'publish') return;
    const audience = audienceRadios.find((radio) => radio.checked)?.value;
    if (audience === 'all' && !window.confirm('Xác nhận phát hành thông báo tới toàn hệ thống?')) {
      event.preventDefault();
    }
  });

  updateAudience();
  updateSchedule();
  updateAction();
  updatePreview();
})();
