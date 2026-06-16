import 'package:flutter/material.dart';

class UserProfileReportReason {
  const UserProfileReportReason({
    required this.key,
    required this.title,
    this.requiresCustomReason = false,
  });

  final String key;
  final String title;
  final bool requiresCustomReason;
}

class UserProfileReportCategory {
  const UserProfileReportCategory({
    required this.key,
    required this.title,
    required this.icon,
    required this.reasons,
  });

  final String key;
  final String title;
  final IconData icon;
  final List<UserProfileReportReason> reasons;
}

const List<UserProfileReportCategory> userProfileReportCategories = [
  UserProfileReportCategory(
    key: 'spam',
    title: 'Spam',
    icon: Icons.campaign_outlined,
    reasons: [
      UserProfileReportReason(
        key: 'repeated_posts',
        title: 'Đăng bài viết lặp lại nhiều lần',
      ),
      UserProfileReportReason(
        key: 'repeated_spam_comments',
        title: 'Bình luận spam dưới nhiều bài viết',
      ),
      UserProfileReportReason(
        key: 'bulk_ad_messages',
        title: 'Gửi tin nhắn quảng cáo hàng loạt',
      ),
      UserProfileReportReason(
        key: 'suspicious_links',
        title: 'Chia sẻ liên kết không rõ nguồn gốc',
      ),
      UserProfileReportReason(
        key: 'multi_account_spam',
        title: 'Tạo nhiều tài khoản để spam',
      ),
      UserProfileReportReason(
        key: 'ad_only_content',
        title: 'Nội dung chỉ nhằm quảng cáo, không có giá trị tương tác',
      ),
      UserProfileReportReason(
        key: 'other',
        title: 'Khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  UserProfileReportCategory(
    key: 'impersonation',
    title: 'Giả mạo người khác',
    icon: Icons.account_circle_outlined,
    reasons: [
      UserProfileReportReason(
        key: 'fake_celebrity',
        title: 'Giả mạo người nổi tiếng',
      ),
      UserProfileReportReason(
        key: 'fake_friend_or_contact',
        title: 'Giả mạo bạn bè hoặc người quen',
      ),
      UserProfileReportReason(
        key: 'stolen_avatar',
        title: 'Sử dụng ảnh đại diện của người khác',
      ),
      UserProfileReportReason(
        key: 'stolen_identity_info',
        title: 'Dùng tên, thông tin cá nhân của người khác',
      ),
      UserProfileReportReason(
        key: 'fake_brand_or_org',
        title: 'Giả mạo thương hiệu, tổ chức hoặc cộng đồng',
      ),
      UserProfileReportReason(
        key: 'confusing_clone_account',
        title: 'Tạo tài khoản giống tài khoản thật để gây nhầm lẫn',
      ),
      UserProfileReportReason(
        key: 'other',
        title: 'Khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  UserProfileReportCategory(
    key: 'harassment',
    title: 'Quấy rối hoặc xúc phạm',
    icon: Icons.gpp_bad_outlined,
    reasons: [
      UserProfileReportReason(
        key: 'personal_insults',
        title: 'Chửi bới, xúc phạm cá nhân',
      ),
      UserProfileReportReason(
        key: 'threat_or_pressure',
        title: 'Đe dọa hoặc gây áp lực tinh thần',
      ),
      UserProfileReportReason(
        key: 'private_message_harassment',
        title: 'Quấy rối qua tin nhắn riêng',
      ),
      UserProfileReportReason(
        key: 'identity_based_attacks',
        title: 'Công kích ngoại hình, giới tính, vùng miền hoặc cá nhân',
      ),
      UserProfileReportReason(
        key: 'repeated_negative_comments',
        title: 'Bình luận tiêu cực lặp lại nhiều lần',
      ),
      UserProfileReportReason(
        key: 'brigading',
        title: 'Kêu gọi người khác tấn công một tài khoản',
      ),
      UserProfileReportReason(
        key: 'other',
        title: 'Khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  UserProfileReportCategory(
    key: 'inappropriate_content',
    title: 'Nội dung không phù hợp',
    icon: Icons.report_problem_outlined,
    reasons: [
      UserProfileReportReason(
        key: 'disturbing_media',
        title: 'Hình ảnh hoặc video phản cảm',
      ),
      UserProfileReportReason(
        key: 'violent_content',
        title: 'Nội dung bạo lực',
      ),
      UserProfileReportReason(
        key: 'hate_content',
        title: 'Nội dung kích động thù ghét',
      ),
      UserProfileReportReason(
        key: 'misleading_false_content',
        title: 'Nội dung gây hiểu nhầm hoặc sai sự thật',
      ),
      UserProfileReportReason(
        key: 'vulgar_language',
        title: 'Ngôn từ thô tục, thiếu văn minh',
      ),
      UserProfileReportReason(
        key: 'age_inappropriate_content',
        title: 'Nội dung không phù hợp với độ tuổi người dùng',
      ),
      UserProfileReportReason(
        key: 'other',
        title: 'Khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  UserProfileReportCategory(
    key: 'scam',
    title: 'Lừa đảo',
    icon: Icons.shield_outlined,
    reasons: [
      UserProfileReportReason(
        key: 'money_transfer_scam',
        title: 'Lừa đảo chuyển tiền',
      ),
      UserProfileReportReason(
        key: 'phishing_personal_info',
        title: 'Giả danh để xin thông tin cá nhân',
      ),
      UserProfileReportReason(
        key: 'account_stealing_link',
        title: 'Gửi đường link đánh cắp tài khoản',
      ),
      UserProfileReportReason(
        key: 'untrusted_sales',
        title: 'Rao bán sản phẩm hoặc dịch vụ không uy tín',
      ),
      UserProfileReportReason(
        key: 'fake_rewards',
        title: 'Hứa hẹn phần thưởng giả',
      ),
      UserProfileReportReason(
        key: 'fake_support_staff',
        title: 'Mạo danh nhân viên hỗ trợ hoặc quản trị viên',
      ),
      UserProfileReportReason(
        key: 'other',
        title: 'Khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  UserProfileReportCategory(
    key: 'other',
    title: 'Khác',
    icon: Icons.more_horiz,
    reasons: [
      UserProfileReportReason(
        key: 'suspicious_behavior',
        title: 'Hành vi đáng ngờ',
      ),
      UserProfileReportReason(
        key: 'community_guideline_violation',
        title: 'Vi phạm quy định cộng đồng',
      ),
      UserProfileReportReason(
        key: 'abnormal_account_activity',
        title: 'Tài khoản có hoạt động bất thường',
      ),
      UserProfileReportReason(
        key: 'uncomfortable_but_uncategorized',
        title: 'Nội dung gây khó chịu nhưng không thuộc mục trên',
      ),
      UserProfileReportReason(
        key: 'custom_other_reason',
        title: 'Lý do khác do người dùng tự nhập',
        requiresCustomReason: true,
      ),
    ],
  ),
];
