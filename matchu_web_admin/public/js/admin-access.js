(() => {
  const root = document.getElementById('adminAccessRoot');
  if (!root) return;

  let rolePresets = {};
  try {
    rolePresets = JSON.parse(root.dataset.rolePresets || '{}');
  } catch {
    rolePresets = {};
  }

  const roleDescriptions = {
    super_admin: 'Toàn quyền quản trị và phân quyền hệ thống.',
    moderator: 'Xử lý người dùng, nội dung và hồ sơ báo cáo.',
    support: 'Hỗ trợ tài khoản và tiếp nhận hồ sơ người dùng.',
    analyst: 'Theo dõi số liệu và dữ liệu vận hành ở chế độ đọc.'
  };

  function updateRoleState(form) {
    const role = form.querySelector('[data-admin-role-select]')?.value || '';
    const isSuperAdmin = role === 'super_admin';
    const grid = form.querySelector('[data-permission-grid]');
    const note = form.querySelector('[data-super-admin-note]');
    const description = form.querySelector('[data-role-description]');
    grid?.classList.toggle('d-none', isSuperAdmin);
    note?.classList.toggle('d-none', !isSuperAdmin);
    if (description) description.textContent = roleDescriptions[role] || '';
    form.querySelectorAll('input[name="permissions"]').forEach((checkbox) => {
      checkbox.disabled = isSuperAdmin;
    });
  }

  function applyPreset(form) {
    const role = form.querySelector('[data-admin-role-select]')?.value || '';
    const preset = new Set(rolePresets[role] || []);
    form.querySelectorAll('input[name="permissions"]').forEach((checkbox) => {
      checkbox.checked = preset.has(checkbox.value);
    });
    updateRoleState(form);
  }

  function setProvisionMode(form) {
    const mode = form.querySelector('input[name="mode"]:checked')?.value || 'create';
    const createFields = form.querySelector('[data-grant-create-fields]');
    const existingFields = form.querySelector('[data-grant-existing-fields]');
    const creating = mode === 'create';
    createFields?.classList.toggle('d-none', !creating);
    existingFields?.classList.toggle('d-none', creating);
    createFields?.querySelectorAll('input').forEach((input) => {
      input.disabled = !creating;
      input.required = creating;
    });
    existingFields?.querySelectorAll('input').forEach((input) => {
      input.disabled = creating;
      input.required = !creating;
    });
  }

  function randomIndex(maximum) {
    const values = new Uint32Array(1);
    window.crypto.getRandomValues(values);
    return values[0] % maximum;
  }

  function generateStrongPassword() {
    const groups = [
      'ABCDEFGHJKLMNPQRSTUVWXYZ',
      'abcdefghijkmnopqrstuvwxyz',
      '23456789',
      '!@#$%&*_-+=?'
    ];
    const allCharacters = groups.join('');
    const characters = groups.map((group) => group[randomIndex(group.length)]);
    while (characters.length < 16) {
      characters.push(allCharacters[randomIndex(allCharacters.length)]);
    }
    for (let index = characters.length - 1; index > 0; index -= 1) {
      const swapIndex = randomIndex(index + 1);
      [characters[index], characters[swapIndex]] = [characters[swapIndex], characters[index]];
    }
    return characters.join('');
  }

  function updatePasswordPolicy(form) {
    const password = form.querySelector('[data-admin-password]')?.value || '';
    const confirmation = form.querySelector('[data-admin-password-confirmation]')?.value || '';
    const results = {
      length: password.length >= 9,
      lower: /[a-z]/.test(password),
      upper: /[A-Z]/.test(password),
      number: /[0-9]/.test(password),
      special: /[^A-Za-z0-9\s]/.test(password),
      match: Boolean(password) && password === confirmation
    };
    Object.entries(results).forEach(([key, valid]) => {
      const rule = form.querySelector(`[data-password-rule="${key}"]`);
      if (!rule) return;
      rule.classList.toggle('is-valid', valid);
      const icon = rule.querySelector('i');
      if (icon) icon.className = `bi bi-${valid ? 'check-circle-fill' : 'circle'}`;
    });
  }

  document.querySelectorAll('[data-admin-access-form]').forEach((form) => {
    const roleSelect = form.querySelector('[data-admin-role-select]');
    roleSelect?.addEventListener('change', () => updateRoleState(form));
    form.querySelector('[data-apply-role-preset]')?.addEventListener('click', () => applyPreset(form));
    form.addEventListener('submit', () => {
      const button = form.querySelector('button[type="submit"]');
      if (!button) return;
      button.disabled = true;
      button.innerHTML = '<span class="spinner-border spinner-border-sm me-2" aria-hidden="true"></span>Đang lưu';
    });
    updateRoleState(form);
  });

  const grantForm = document.querySelector('#grantAdminModal [data-admin-access-form]');
  if (grantForm) {
    applyPreset(grantForm);
    setProvisionMode(grantForm);
    grantForm.querySelectorAll('input[name="mode"]').forEach((radio) => {
      radio.addEventListener('change', () => setProvisionMode(grantForm));
    });
    grantForm.querySelectorAll('[data-admin-password], [data-admin-password-confirmation]')
      .forEach((input) => input.addEventListener('input', () => updatePasswordPolicy(grantForm)));
    grantForm.querySelector('[data-generate-password]')?.addEventListener('click', () => {
      const generated = generateStrongPassword();
      const password = grantForm.querySelector('[data-admin-password]');
      const confirmation = grantForm.querySelector('[data-admin-password-confirmation]');
      if (password) {
        password.value = generated;
        password.type = 'text';
      }
      if (confirmation) {
        confirmation.value = generated;
        confirmation.type = 'text';
      }
      grantForm.querySelectorAll('[data-password-toggle] i')
        .forEach((icon) => { icon.className = 'bi bi-eye-slash'; });
      updatePasswordPolicy(grantForm);
    });
    grantForm.querySelectorAll('[data-password-toggle]').forEach((button) => {
      button.addEventListener('click', () => {
        const input = document.getElementById(button.dataset.passwordTarget || '');
        if (!input) return;
        input.type = input.type === 'password' ? 'text' : 'password';
        const icon = button.querySelector('i');
        if (icon) icon.className = `bi bi-${input.type === 'password' ? 'eye' : 'eye-slash'}`;
      });
    });
    updatePasswordPolicy(grantForm);
  }

  const editModal = document.getElementById('editAdminModal');
  editModal?.addEventListener('show.bs.modal', (event) => {
    const button = event.relatedTarget;
    const form = editModal.querySelector('[data-edit-admin-form]');
    if (!button || !form) return;
    const uid = button.dataset.adminUid || '';
    const selectedPermissions = new Set(
      (button.dataset.adminPermissions || '').split(',').filter(Boolean)
    );
    form.action = `/admins/${encodeURIComponent(uid)}/access`;
    const identity = form.querySelector('[data-edit-admin-identity]');
    if (identity) {
      identity.textContent = `${button.dataset.adminName || 'Admin'} · ${button.dataset.adminEmail || uid}`;
    }
    const roleSelect = form.querySelector('[data-admin-role-select]');
    if (roleSelect) roleSelect.value = button.dataset.adminRole || '';
    form.querySelectorAll('input[name="permissions"]').forEach((checkbox) => {
      checkbox.checked = selectedPermissions.has(checkbox.value);
    });
    updateRoleState(form);
  });

  const statusModal = document.getElementById('adminStatusModal');
  statusModal?.addEventListener('show.bs.modal', (event) => {
    const button = event.relatedTarget;
    const form = statusModal.querySelector('[data-admin-status-form]');
    if (!button || !form) return;
    const nextStatus = button.dataset.nextStatus || '';
    const isDeactivate = nextStatus === 'inactive';
    const name = button.dataset.adminName || 'tài khoản này';
    form.action = `/admins/${encodeURIComponent(button.dataset.adminUid || '')}/status`;
    form.querySelector('[data-next-status-input]').value = nextStatus;
    form.querySelector('[data-status-modal-title]').textContent = isDeactivate
      ? 'Vô hiệu hóa quyền quản trị'
      : 'Kích hoạt lại quyền quản trị';
    const confirmation = form.querySelector('[data-status-confirmation]');
    confirmation.className = `admin-access-status-confirmation ${isDeactivate ? 'is-danger' : 'is-success'}`;
    confirmation.innerHTML = isDeactivate
      ? `<i class="bi bi-person-dash"></i><div><strong>Vô hiệu hóa ${escapeHtml(name)}?</strong><span>Tài khoản sẽ mất quyền truy cập trang quản trị ngay từ yêu cầu tiếp theo.</span></div>`
      : `<i class="bi bi-person-check"></i><div><strong>Kích hoạt lại ${escapeHtml(name)}?</strong><span>Tài khoản sẽ được sử dụng lại vai trò và phạm vi quyền hiện tại.</span></div>`;
    const reasonField = form.querySelector('[data-status-reason-field]');
    const reason = reasonField?.querySelector('textarea');
    reasonField?.classList.toggle('d-none', !isDeactivate);
    if (reason) {
      reason.required = isDeactivate;
      reason.value = '';
    }
    const submit = form.querySelector('[data-status-submit]');
    submit.className = `btn ${isDeactivate ? 'btn-danger' : 'btn-success'}`;
    submit.textContent = isDeactivate ? 'Vô hiệu hóa' : 'Kích hoạt lại';
  });

  function escapeHtml(value) {
    const element = document.createElement('span');
    element.textContent = String(value);
    return element.innerHTML;
  }
})();
