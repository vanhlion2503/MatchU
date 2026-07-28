(() => {
  const modal = document.getElementById('reportActionModal');
  if (!modal) return;

  const form = document.getElementById('reportActionForm');
  const actionInput = document.getElementById('reportActionInput');
  const title = document.getElementById('reportActionModalTitle');
  const reason = document.getElementById('reportActionReason');
  const resolution = document.getElementById('reportResolution');
  const resolutionField = modal.querySelector('.report-resolution-field');
  const reasonField = modal.querySelector('.report-action-reason-field');
  const warning = modal.querySelector('.report-action-warning');
  const submit = document.getElementById('reportActionSubmit');
  const reasonRequired = new Set(['resolve', 'dismiss', 'reopen']);

  modal.addEventListener('show.bs.modal', (event) => {
    const button = event.relatedTarget;
    const action = button?.dataset.reportAction || '';
    const isResolve = action === 'resolve';
    const isDismiss = action === 'dismiss';

    form.reset();
    actionInput.value = action;
    title.textContent = button?.dataset.actionTitle || 'Xác nhận thao tác';
    resolutionField.classList.toggle('d-none', !isResolve);
    resolution.disabled = !isResolve;
    resolution.required = isResolve;
    reason.required = reasonRequired.has(action);
    reasonField.classList.toggle('d-none', action === 'assign_to_me');
    warning.classList.toggle('alert-danger', isDismiss);
    warning.classList.toggle('alert-warning', !isDismiss);
    submit.classList.toggle('btn-danger', isDismiss);
    submit.classList.toggle('btn-primary', !isDismiss);
    submit.disabled = false;
    submit.textContent = isResolve ? 'Lưu kết luận' : isDismiss ? 'Bác báo cáo' : 'Xác nhận';
  });

  modal.addEventListener('shown.bs.modal', () => {
    if (!reasonField.classList.contains('d-none')) reason.focus();
  });
  form.addEventListener('submit', () => {
    submit.disabled = true;
    submit.innerHTML = '<span class="spinner-border spinner-border-sm me-2" aria-hidden="true"></span>Đang xử lý';
  });
})();
