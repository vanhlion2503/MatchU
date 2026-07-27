const { getUserStatistics } = require('../services/user-account.service');
const { getPostStatistics } = require('../services/post-management.service');

async function index(req, res) {
  const [users, posts] = await Promise.all([
    getUserStatistics(),
    getPostStatistics()
  ]);
  const statistics = {
    totalUsers: users.total,
    totalPosts: posts.total,
    pendingReports: posts.reportCount,
    pendingModeration: posts.pending + posts.reviewRequired
  };
  res.render('dashboard/index', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Tổng quan hệ thống',
    statistics
  });
}
module.exports = { index };
