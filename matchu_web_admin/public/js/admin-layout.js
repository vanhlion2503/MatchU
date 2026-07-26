(() => {
  const body = document.body, toggle = document.getElementById('sidebarToggle'), overlay = document.getElementById('sidebarOverlay');
  const stored = localStorage.getItem('matchu-sidebar-collapsed');
  if (stored === 'true' && window.innerWidth > 991) body.classList.add('sidebar-collapsed');
  function toggleSidebar() { if (window.innerWidth <= 991) body.classList.toggle('sidebar-open'); else { body.classList.toggle('sidebar-collapsed'); localStorage.setItem('matchu-sidebar-collapsed', body.classList.contains('sidebar-collapsed')); } }
  toggle?.addEventListener('click', toggleSidebar); overlay?.addEventListener('click', () => body.classList.remove('sidebar-open'));
  window.addEventListener('resize', () => { if (window.innerWidth > 991) body.classList.remove('sidebar-open'); });

  function showAvatarFallback(image) {
    if (!image?.parentNode || image.dataset.fallbackApplied === 'true') return;
    image.dataset.fallbackApplied = 'true';
    const fallback = document.createElement('span');
    fallback.className = `${image.className} user-avatar-fallback`;
    fallback.textContent = image.dataset.avatarInitial || 'U';
    fallback.setAttribute('aria-label', image.alt || 'Avatar người dùng');
    image.replaceWith(fallback);
  }

  document.querySelectorAll('[data-avatar-image]').forEach((image) => {
    image.addEventListener('error', () => showAvatarFallback(image), { once: true });
    if (image.complete && image.naturalWidth === 0) showAvatarFallback(image);
  });
})();
