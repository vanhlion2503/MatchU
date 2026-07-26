(() => {
  const modal = document.getElementById('userActionModal');
  if (!modal) return;

  const form = document.getElementById('userActionForm');
  const actionInput = document.getElementById('userActionInput');
  const title = document.getElementById('userActionModalTitle');
  const reason = document.getElementById('actionReason');
  const amount = document.getElementById('actionAmount');
  const duration = document.getElementById('actionDuration');
  const submit = document.getElementById('userActionSubmit');
  const featureField = modal.querySelector('.action-feature-field');
  const durationField = modal.querySelector('.action-duration-field');
  const amountField = modal.querySelector('.action-amount-field');
  const reasonField = modal.querySelector('.action-reason-field');
  const warning = modal.querySelector('.action-warning');

  const reasonRequired = new Set(['warn', 'restrict', 'suspend', 'ban', 'adjust_gem', 'adjust_reputation']);
  const destructive = new Set(['suspend', 'ban', 'reset_face_verification']);

  modal.addEventListener('show.bs.modal', (event) => {
    const button = event.relatedTarget;
    const action = button?.dataset.userAction || '';
    const actionTitle = button?.dataset.actionTitle || 'Xác nhận thao tác';

    form.reset();
    actionInput.value = action;
    title.textContent = actionTitle;
    reason.required = reasonRequired.has(action);
    amount.required = action === 'adjust_gem' || action === 'adjust_reputation';
    duration.required = action === 'restrict' || action === 'suspend';
    reasonField.classList.toggle('d-none', action === 'revoke_sessions'
      || action === 'reset_face_verification'
      || action === 'send_password_reset'
      || action === 'restore');
    featureField.classList.toggle('d-none', action !== 'restrict');
    durationField.classList.toggle('d-none', action !== 'restrict' && action !== 'suspend');
    amountField.classList.toggle('d-none', action !== 'adjust_gem' && action !== 'adjust_reputation');
    warning.classList.toggle('alert-danger', destructive.has(action));
    warning.classList.toggle('alert-warning', !destructive.has(action));
    submit.classList.toggle('btn-danger', destructive.has(action));
    submit.classList.toggle('btn-primary', !destructive.has(action));
    submit.textContent = destructive.has(action) ? 'Xác nhận xử lý' : 'Xác nhận';
  });

  form.addEventListener('submit', () => {
    submit.disabled = true;
    submit.innerHTML = '<span class="spinner-border spinner-border-sm me-2" aria-hidden="true"></span>Đang xử lý';
  });
})();
