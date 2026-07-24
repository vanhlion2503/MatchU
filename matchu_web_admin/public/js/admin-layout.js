(() => {
  const body = document.body, toggle = document.getElementById('sidebarToggle'), overlay = document.getElementById('sidebarOverlay');
  const stored = localStorage.getItem('matchu-sidebar-collapsed');
  if (stored === 'true' && window.innerWidth > 991) body.classList.add('sidebar-collapsed');
  function toggleSidebar() { if (window.innerWidth <= 991) body.classList.toggle('sidebar-open'); else { body.classList.toggle('sidebar-collapsed'); localStorage.setItem('matchu-sidebar-collapsed', body.classList.contains('sidebar-collapsed')); } }
  toggle?.addEventListener('click', toggleSidebar); overlay?.addEventListener('click', () => body.classList.remove('sidebar-open'));
  window.addEventListener('resize', () => { if (window.innerWidth > 991) body.classList.remove('sidebar-open'); });
})();
