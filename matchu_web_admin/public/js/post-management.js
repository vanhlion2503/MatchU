(() => {
  const modal = document.getElementById('postActionModal');
  if (!modal) return;

  const form = document.getElementById('postActionForm');
  const actionInput = document.getElementById('postActionInput');
  const title = document.getElementById('postActionModalTitle');
  const description = document.getElementById('postActionDescription');
  const reason = document.getElementById('postActionReason');
  const warning = document.getElementById('postActionWarning');
  const submit = document.getElementById('postActionSubmit');
  const confirmationGroup = document.getElementById('postDeleteConfirmationGroup');
  const confirmation = document.getElementById('postDeleteConfirmation');
  const confirmationValue = document.getElementById('postDeleteConfirmationValue');
  const destructiveActions = new Set(['reject', 'review', 'delete_permanently']);

  modal.addEventListener('show.bs.modal', (event) => {
    const button = event.relatedTarget;
    const action = button?.dataset.postAction || '';
    const isDestructive = destructiveActions.has(action);
    const isPermanentDelete = action === 'delete_permanently';
    const expectedConfirmation = button?.dataset.confirmationValue || '';

    form.reset();
    actionInput.value = action;
    title.textContent = button?.dataset.actionTitle || 'Xác nhận quyết định';
    description.textContent = button?.dataset.actionDescription || '';
    warning.classList.toggle('alert-danger', isDestructive);
    warning.classList.toggle('alert-warning', !isDestructive);
    submit.classList.toggle('btn-danger', isDestructive);
    submit.classList.toggle('btn-primary', !isDestructive);
    submit.disabled = false;
    confirmationGroup?.classList.toggle('d-none', !isPermanentDelete);
    if (confirmation) {
      confirmation.required = isPermanentDelete;
      confirmation.dataset.expectedValue = expectedConfirmation;
      confirmation.setCustomValidity('');
    }
    if (confirmationValue && expectedConfirmation) {
      confirmationValue.textContent = expectedConfirmation;
    }
    submit.textContent = isPermanentDelete
      ? 'Xóa vĩnh viễn'
      : action === 'reject' ? 'Xác nhận gỡ bài' : 'Xác nhận';
  });

  modal.addEventListener('shown.bs.modal', () => reason.focus());
  confirmation?.addEventListener('input', () => confirmation.setCustomValidity(''));
  form.addEventListener('submit', (event) => {
    if (
      actionInput.value === 'delete_permanently'
      && confirmation.value.trim() !== confirmation.dataset.expectedValue
    ) {
      event.preventDefault();
      confirmation.setCustomValidity('Mã bài viết không khớp.');
      confirmation.reportValidity();
      confirmation.focus();
      return;
    }
    submit.disabled = true;
    submit.innerHTML = '<span class="spinner-border spinner-border-sm me-2" aria-hidden="true"></span>Đang xử lý';
  });
})();
