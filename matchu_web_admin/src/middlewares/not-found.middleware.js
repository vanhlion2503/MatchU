module.exports = (req, res) => res.status(404).render('errors/404', { layout: 'layouts/auth-layout', pageTitle: 'Không tìm thấy trang' });
