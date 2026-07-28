const { ADMIN_ROLES } = require('./constants');

const ADMIN_STATUSES = Object.freeze({
  ACTIVE: 'active',
  INACTIVE: 'inactive'
});

const ROLE_LABELS = Object.freeze({
  [ADMIN_ROLES.SUPER_ADMIN]: 'Super Admin',
  [ADMIN_ROLES.MODERATOR]: 'Kiểm duyệt viên',
  [ADMIN_ROLES.SUPPORT]: 'Hỗ trợ người dùng',
  [ADMIN_ROLES.ANALYST]: 'Phân tích viên'
});

const ROLE_DESCRIPTIONS = Object.freeze({
  [ADMIN_ROLES.SUPER_ADMIN]: 'Toàn quyền quản trị và phân quyền hệ thống.',
  [ADMIN_ROLES.MODERATOR]: 'Xử lý người dùng, nội dung và hồ sơ báo cáo.',
  [ADMIN_ROLES.SUPPORT]: 'Hỗ trợ tài khoản và tiếp nhận hồ sơ người dùng.',
  [ADMIN_ROLES.ANALYST]: 'Theo dõi số liệu và dữ liệu vận hành ở chế độ đọc.'
});

const PERMISSION_GROUPS = Object.freeze([
  {
    key: 'overview',
    label: 'Tổng quan',
    icon: 'grid-1x2',
    permissions: [
      {
        key: 'dashboard.read',
        label: 'Xem tổng quan',
        description: 'Truy cập dashboard và các chỉ số vận hành.'
      }
    ]
  },
  {
    key: 'users',
    label: 'Người dùng',
    icon: 'people',
    permissions: [
      { key: 'users.read', label: 'Xem tài khoản', description: 'Tra cứu hồ sơ và lịch sử người dùng.' },
      { key: 'users.warn', label: 'Gửi cảnh báo', description: 'Gửi cảnh báo vi phạm đến người dùng.' },
      { key: 'users.restrict', label: 'Hạn chế tính năng', description: 'Khóa tạm thời một số tính năng.' },
      { key: 'users.suspend', label: 'Tạm khóa', description: 'Tạm khóa tài khoản có thời hạn.' },
      { key: 'users.ban', label: 'Cấm tài khoản', description: 'Cấm truy cập tài khoản người dùng.' },
      { key: 'users.restore', label: 'Khôi phục', description: 'Khôi phục tài khoản sau xử lý.' },
      { key: 'users.sessions.revoke', label: 'Thu hồi phiên', description: 'Đăng xuất người dùng khỏi mọi thiết bị.' },
      { key: 'users.security.manage', label: 'Hỗ trợ bảo mật', description: 'Gửi quy trình đặt lại mật khẩu.' },
      { key: 'users.verification.manage', label: 'Quản lý xác minh', description: 'Đặt lại trạng thái xác minh khuôn mặt.' },
      { key: 'users.gems.adjust', label: 'Điều chỉnh Gem', description: 'Thay đổi số dư Gem của người dùng.' },
      { key: 'users.reputation.adjust', label: 'Điều chỉnh uy tín', description: 'Thay đổi điểm uy tín của người dùng.' }
    ]
  },
  {
    key: 'content',
    label: 'Nội dung',
    icon: 'file-post',
    permissions: [
      { key: 'posts.read', label: 'Xem bài viết', description: 'Tra cứu nội dung và tín hiệu kiểm duyệt.' },
      { key: 'posts.moderate', label: 'Kiểm duyệt bài viết', description: 'Duyệt, gỡ hoặc chuyển bài sang xem xét.' },
      { key: 'posts.restore', label: 'Khôi phục bài viết', description: 'Khôi phục bài viết đã bị gỡ.' },
      { key: 'posts.delete', label: 'Xóa vĩnh viễn', description: 'Xóa vĩnh viễn bài viết và dữ liệu liên quan.', sensitive: true }
    ]
  },
  {
    key: 'reports',
    label: 'Báo cáo',
    icon: 'flag',
    permissions: [
      { key: 'reports.read', label: 'Xem báo cáo', description: 'Truy cập hàng đợi và chi tiết hồ sơ.' },
      { key: 'reports.manage', label: 'Tiếp nhận xử lý', description: 'Nhận và bắt đầu xem xét hồ sơ.' },
      { key: 'reports.resolve', label: 'Kết luận báo cáo', description: 'Kết luận, bác hoặc mở lại hồ sơ.' }
    ]
  },
  {
    key: 'notifications',
    label: 'Thông báo',
    icon: 'bell',
    permissions: [
      { key: 'notifications.read', label: 'Xem chiến dịch', description: 'Xem danh sách và kết quả gửi thông báo.' },
      { key: 'notifications.create', label: 'Soạn thông báo', description: 'Tạo và cập nhật bản nháp chiến dịch.' },
      { key: 'notifications.publish', label: 'Phát hành', description: 'Phát hành hoặc lên lịch chiến dịch.', sensitive: true },
      { key: 'notifications.cancel', label: 'Hủy chiến dịch', description: 'Hủy chiến dịch chưa hoàn tất.' },
      { key: 'notifications.retry', label: 'Thử gửi lại', description: 'Thử lại các lô gửi thất bại.' }
    ]
  },
  {
    key: 'governance',
    label: 'Quản trị hệ thống',
    icon: 'shield-lock',
    permissions: [
      { key: 'audit_logs.read', label: 'Xem nhật ký', description: 'Tra cứu nhật ký hoạt động quản trị.' },
      {
        key: 'admins.manage',
        label: 'Quản lý admin',
        description: 'Cấp quyền và quản lý admin cấp dưới.',
        sensitive: true,
        protected: true
      }
    ]
  }
]);

const ALL_ADMIN_PERMISSIONS = Object.freeze(
  PERMISSION_GROUPS.flatMap((group) => group.permissions.map((permission) => permission.key))
);

const PROTECTED_ADMIN_PERMISSIONS = Object.freeze(
  PERMISSION_GROUPS
    .flatMap((group) => group.permissions)
    .filter((permission) => permission.protected)
    .map((permission) => permission.key)
);

const ROLE_PERMISSION_PRESETS = Object.freeze({
  [ADMIN_ROLES.SUPER_ADMIN]: [],
  [ADMIN_ROLES.MODERATOR]: [
    'dashboard.read',
    'users.read',
    'users.warn',
    'users.restrict',
    'users.suspend',
    'users.restore',
    'posts.read',
    'posts.moderate',
    'posts.restore',
    'reports.read',
    'reports.manage',
    'reports.resolve'
  ],
  [ADMIN_ROLES.SUPPORT]: [
    'dashboard.read',
    'users.read',
    'users.warn',
    'users.sessions.revoke',
    'users.security.manage',
    'reports.read',
    'reports.manage'
  ],
  [ADMIN_ROLES.ANALYST]: [
    'dashboard.read',
    'users.read',
    'posts.read',
    'reports.read',
    'notifications.read',
    'audit_logs.read'
  ]
});

module.exports = {
  ADMIN_STATUSES,
  ROLE_LABELS,
  ROLE_DESCRIPTIONS,
  PERMISSION_GROUPS,
  ALL_ADMIN_PERMISSIONS,
  PROTECTED_ADMIN_PERMISSIONS,
  ROLE_PERMISSION_PRESETS
};
