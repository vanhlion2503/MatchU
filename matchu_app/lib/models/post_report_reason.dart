import 'package:flutter/material.dart';

class PostReportReason {
  const PostReportReason({
    required this.key,
    required this.title,
    this.requiresCustomReason = false,
  });

  final String key;
  final String title;
  final bool requiresCustomReason;
}

class PostReportCategory {
  const PostReportCategory({
    required this.key,
    required this.title,
    required this.icon,
    required this.reasons,
  });

  final String key;
  final String title;
  final IconData icon;
  final List<PostReportReason> reasons;
}

const List<PostReportCategory> postReportCategories = [
  PostReportCategory(
    key: 'spam',
    title: 'Spam',
    icon: Icons.campaign_outlined,
    reasons: [
      PostReportReason(
        key: 'repeated_posts',
        title: 'Đăng bài viết lặp lại nhiều lần',
      ),
      PostReportReason(
        key: 'repeated_spam_comments',
        title: 'Bình luận spam dưới nhiều bài viết',
      ),
      PostReportReason(
        key: 'bulk_ad_messages',
        title: 'Gửi tin nhắn quảng cáo hàng loạt',
      ),
      PostReportReason(
        key: 'suspicious_links',
        title: 'Chia sẻ liên kết không rõ nguồn gốc',
      ),
      PostReportReason(
        key: 'multi_account_spam',
        title: 'Tạo nhiều tài khoản để spam',
      ),
      PostReportReason(
        key: 'ad_only_content',
        title: 'Nội dung chỉ nhằm quảng cáo, không có giá trị tương tác',
      ),
      PostReportReason(
        key: 'spam_other',
        title: 'Khác (Người dùng có thể nhập vào)',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'impersonation',
    title: 'Giả mạo người khác',
    icon: Icons.account_circle_outlined,
    reasons: [
      PostReportReason(key: 'fake_celebrity', title: 'Giả mạo người nổi tiếng'),
      PostReportReason(
        key: 'fake_friend_or_contact',
        title: 'Giả mạo bạn bè hoặc người quen',
      ),
      PostReportReason(
        key: 'stolen_avatar',
        title: 'Sử dụng ảnh đại diện của người khác',
      ),
      PostReportReason(
        key: 'stolen_identity_info',
        title: 'Dùng tên hoặc thông tin cá nhân của người khác',
      ),
      PostReportReason(
        key: 'fake_brand_or_org',
        title: 'Giả mạo thương hiệu, tổ chức hoặc cộng đồng',
      ),
      PostReportReason(
        key: 'confusing_clone_account',
        title: 'Tạo tài khoản giống tài khoản thật để gây nhầm lẫn',
      ),
      PostReportReason(
        key: 'impersonation_other',
        title: 'Khác (Người dùng có thể nhập vào)',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'harassment',
    title: 'Quấy rối hoặc xúc phạm',
    icon: Icons.gpp_bad_outlined,
    reasons: [
      PostReportReason(
        key: 'personal_insults',
        title: 'Chửi bới, xúc phạm cá nhân',
      ),
      PostReportReason(
        key: 'threat_or_pressure',
        title: 'Đe dọa hoặc gây áp lực tinh thần',
      ),
      PostReportReason(
        key: 'private_message_harassment',
        title: 'Quấy rối qua tin nhắn riêng',
      ),
      PostReportReason(
        key: 'identity_based_attacks',
        title: 'Công kích ngoại hình, giới tính, vùng miền hoặc cá nhân',
      ),
      PostReportReason(
        key: 'repeated_negative_comments',
        title: 'Bình luận tiêu cực lặp lại nhiều lần',
      ),
      PostReportReason(
        key: 'brigading',
        title: 'Kêu gọi người khác tấn công một tài khoản',
      ),
      PostReportReason(
        key: 'harassment_other',
        title: 'Khác (Người dùng có thể nhập vào)',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'inappropriate_content',
    title: 'Nội dung không phù hợp',
    icon: Icons.report_problem_outlined,
    reasons: [
      PostReportReason(
        key: 'disturbing_profile_media',
        title: 'Hình ảnh hoặc video phản cảm trên trang cá nhân',
      ),
      PostReportReason(
        key: 'violent_or_disturbing_content',
        title: 'Nội dung bạo lực hoặc gây khó chịu',
      ),
      PostReportReason(
        key: 'hate_content',
        title: 'Nội dung kích động thù ghét',
      ),
      PostReportReason(
        key: 'vulgar_language',
        title: 'Ngôn từ thô tục, thiếu văn minh',
      ),
      PostReportReason(
        key: 'age_inappropriate_content',
        title: 'Nội dung không phù hợp với độ tuổi người dùng',
      ),
      PostReportReason(
        key: 'misleading_profile_info',
        title: 'Thông tin trên hồ sơ gây hiểu nhầm hoặc sai sự thật',
      ),
      PostReportReason(
        key: 'inappropriate_other',
        title: 'Khác (Người dùng có thể nhập vào)',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'scam',
    title: 'Lừa đảo',
    icon: Icons.shield_outlined,
    reasons: [
      PostReportReason(
        key: 'money_transfer_scam',
        title: 'Lừa đảo chuyển tiền',
      ),
      PostReportReason(
        key: 'phishing_personal_info',
        title: 'Giả danh để xin thông tin cá nhân',
      ),
      PostReportReason(
        key: 'account_stealing_link',
        title: 'Gửi đường link đánh cắp tài khoản',
      ),
      PostReportReason(
        key: 'untrusted_sales',
        title: 'Rao bán sản phẩm hoặc dịch vụ không uy tín',
      ),
      PostReportReason(key: 'fake_rewards', title: 'Hứa hẹn phần thưởng giả'),
      PostReportReason(
        key: 'fake_support_staff',
        title: 'Mạo danh nhân viên hỗ trợ hoặc quản trị viên',
      ),
      PostReportReason(
        key: 'scam_other',
        title: 'Khác (Người dùng có thể nhập vào)',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'other',
    title: 'Khác',
    icon: Icons.more_horiz,
    reasons: [
      PostReportReason(key: 'suspicious_behavior', title: 'Hành vi đáng ngờ'),
      PostReportReason(
        key: 'community_guideline_violation',
        title: 'Vi phạm quy định cộng đồng',
      ),
      PostReportReason(
        key: 'abnormal_account_activity',
        title: 'Tài khoản có hoạt động bất thường',
      ),
      PostReportReason(
        key: 'uncomfortable_but_uncategorized',
        title: 'Nội dung gây khó chịu nhưng không thuộc mục trên',
      ),
      PostReportReason(
        key: 'custom_other_reason',
        title: 'Lý do khác do người dùng tự nhập',
        requiresCustomReason: true,
      ),
    ],
  ),
];
