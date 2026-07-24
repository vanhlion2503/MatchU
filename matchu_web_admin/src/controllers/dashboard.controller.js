async function index(req, res) { const statistics = { totalUsers: 0, totalPosts: 0, pendingReports: 0, pendingModeration: 0 }; res.render('dashboard/index', { layout: 'layouts/admin-layout', pageTitle: 'Tổng quan hệ thống', statistics }); }
module.exports = { index };
