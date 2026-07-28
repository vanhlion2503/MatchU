(() => {
  document.querySelectorAll('[data-copy-value]').forEach((button) => {
    button.addEventListener('click', async () => {
      const value = button.dataset.copyValue || '';
      if (!value) return;
      try {
        await navigator.clipboard.writeText(value);
        const original = button.innerHTML;
        button.innerHTML = '<i class="bi bi-check2 me-1"></i>Đã sao chép';
        button.classList.add('text-success');
        window.setTimeout(() => {
          button.innerHTML = original;
          button.classList.remove('text-success');
        }, 1400);
      } catch {
        button.setAttribute('title', 'Không thể sao chép tự động');
      }
    });
  });

  document.querySelectorAll('.audit-detail-toggle').forEach((button) => {
    const target = document.querySelector(button.dataset.bsTarget);
    target?.addEventListener('show.bs.collapse', () => button.classList.add('is-open'));
    target?.addEventListener('hide.bs.collapse', () => button.classList.remove('is-open'));
  });
})();
