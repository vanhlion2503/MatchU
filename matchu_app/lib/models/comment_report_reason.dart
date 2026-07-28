import 'package:flutter/material.dart';
import 'package:matchu_app/models/post_report_reason.dart';

/// Categories tailored to content that can appear inside a comment or reply.
///
/// The existing report category types are reused so the report form and the
/// moderation payload remain compatible with post reports.
const List<PostReportCategory> commentReportCategories = [
  PostReportCategory(
    key: 'spam',
    title: 'Spam hoặc quảng cáo',
    icon: Icons.campaign_outlined,
    reasons: [
      PostReportReason(
        key: 'repeated_or_duplicate_comment',
        title: 'Bình luận lặp lại hoặc đăng quá nhiều lần',
      ),
      PostReportReason(
        key: 'irrelevant_or_flooding',
        title: 'Nội dung không liên quan hoặc làm loãng cuộc trò chuyện',
      ),
      PostReportReason(
        key: 'unsolicited_advertising',
        title: 'Quảng cáo, mời chào hoặc tuyển thành viên không mong muốn',
      ),
      PostReportReason(
        key: 'engagement_bait',
        title: 'Câu tương tác, kéo lượt thích hoặc dẫn dụ người dùng',
      ),
      PostReportReason(
        key: 'spam_other',
        title: 'Hình thức spam khác',
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
        title: 'Chửi bới, hạ nhục hoặc công kích cá nhân',
      ),
      PostReportReason(
        key: 'threat_or_intimidation',
        title: 'Đe dọa, uy hiếp hoặc gây áp lực tinh thần',
      ),
      PostReportReason(
        key: 'repeated_targeting',
        title: 'Liên tục nhắm vào hoặc quấy rối một người',
      ),
      PostReportReason(
        key: 'sexual_harassment',
        title: 'Quấy rối tình dục hoặc bình phẩm khiếm nhã',
      ),
      PostReportReason(
        key: 'encouraging_harassment',
        title: 'Kêu gọi người khác công kích hoặc làm nhục',
      ),
      PostReportReason(
        key: 'harassment_other',
        title: 'Hình thức quấy rối khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'hate_speech',
    title: 'Ngôn từ thù ghét hoặc phân biệt đối xử',
    icon: Icons.record_voice_over_outlined,
    reasons: [
      PostReportReason(
        key: 'identity_based_attack',
        title: 'Công kích dựa trên giới tính, dân tộc, tôn giáo hoặc vùng miền',
      ),
      PostReportReason(
        key: 'dehumanizing_language',
        title: 'Hạ thấp nhân phẩm hoặc coi một nhóm người là thấp kém',
      ),
      PostReportReason(
        key: 'promoting_discrimination',
        title: 'Cổ súy phân biệt đối xử hoặc loại trừ một nhóm người',
      ),
      PostReportReason(
        key: 'hate_speech_other',
        title: 'Ngôn từ thù ghét khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'inappropriate_content',
    title: 'Nội dung phản cảm hoặc nguy hiểm',
    icon: Icons.report_problem_outlined,
    reasons: [
      PostReportReason(
        key: 'sexual_or_explicit_content',
        title: 'Nội dung tình dục, khỏa thân hoặc gợi dục',
      ),
      PostReportReason(
        key: 'graphic_violence',
        title: 'Bạo lực, máu me hoặc nội dung gây ám ảnh',
      ),
      PostReportReason(
        key: 'self_harm_encouragement',
        title: 'Khuyến khích tự làm hại bản thân hoặc tự tử',
      ),
      PostReportReason(
        key: 'vulgar_or_obscene_language',
        title: 'Ngôn từ tục tĩu hoặc cực kỳ phản cảm',
      ),
      PostReportReason(
        key: 'dangerous_activity',
        title: 'Khuyến khích hành vi nguy hiểm hoặc trái pháp luật',
      ),
      PostReportReason(
        key: 'inappropriate_other',
        title: 'Nội dung phản cảm khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'scam',
    title: 'Lừa đảo hoặc liên kết nguy hiểm',
    icon: Icons.shield_outlined,
    reasons: [
      PostReportReason(
        key: 'phishing_or_account_theft',
        title: 'Liên kết giả mạo hoặc đánh cắp tài khoản',
      ),
      PostReportReason(
        key: 'money_or_payment_scam',
        title: 'Lừa chuyển tiền, thanh toán hoặc đầu tư',
      ),
      PostReportReason(
        key: 'fake_reward_or_giveaway',
        title: 'Phần thưởng, quà tặng hoặc ưu đãi giả',
      ),
      PostReportReason(
        key: 'fake_support_or_authority',
        title: 'Mạo danh nhân viên hỗ trợ hoặc cơ quan có thẩm quyền',
      ),
      PostReportReason(
        key: 'scam_other',
        title: 'Hình thức lừa đảo khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'privacy_violation',
    title: 'Xâm phạm quyền riêng tư',
    icon: Icons.privacy_tip_outlined,
    reasons: [
      PostReportReason(
        key: 'sharing_personal_information',
        title: 'Chia sẻ số điện thoại, địa chỉ hoặc thông tin cá nhân',
      ),
      PostReportReason(
        key: 'doxxing_or_tracking',
        title: 'Công khai danh tính, vị trí hoặc kêu gọi truy tìm',
      ),
      PostReportReason(
        key: 'non_consensual_private_content',
        title: 'Chia sẻ nội dung riêng tư khi chưa được đồng ý',
      ),
      PostReportReason(
        key: 'threatening_to_expose_information',
        title: 'Đe dọa phát tán thông tin hoặc nội dung riêng tư',
      ),
      PostReportReason(
        key: 'privacy_other',
        title: 'Hình thức xâm phạm quyền riêng tư khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'misinformation',
    title: 'Thông tin sai lệch hoặc gây hiểu nhầm',
    icon: Icons.fact_check_outlined,
    reasons: [
      PostReportReason(
        key: 'dangerous_false_information',
        title: 'Thông tin sai có thể gây nguy hiểm cho người khác',
      ),
      PostReportReason(
        key: 'fabricated_claim',
        title: 'Bịa đặt sự việc hoặc cáo buộc không có căn cứ',
      ),
      PostReportReason(
        key: 'manipulated_context',
        title: 'Cắt ghép hoặc trình bày sai ngữ cảnh để gây hiểu nhầm',
      ),
      PostReportReason(
        key: 'misinformation_other',
        title: 'Thông tin sai lệch khác',
        requiresCustomReason: true,
      ),
    ],
  ),
  PostReportCategory(
    key: 'other',
    title: 'Vi phạm khác',
    icon: Icons.more_horiz,
    reasons: [
      PostReportReason(
        key: 'community_guideline_violation',
        title: 'Vi phạm tiêu chuẩn cộng đồng nhưng không thuộc các mục trên',
      ),
      PostReportReason(
        key: 'custom_other_reason',
        title: 'Lý do khác',
        requiresCustomReason: true,
      ),
    ],
  ),
];
