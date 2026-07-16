import 'package:get/get.dart';

abstract final class ProfileTranslationKeys {
  static const error = 'profile.error';
  static const success = 'profile.success';
  static const notice = 'profile.notice';
}

const profileEnglishTranslations = <String, String>{
  ProfileTranslationKeys.error: 'Error',
  ProfileTranslationKeys.success: 'Success',
  ProfileTranslationKeys.notice: 'Notice',
  'Không tìm thấy hồ sơ người dùng.': 'User profile not found.',
  'Tài khoản chưa xác thực': 'Unverified account',
  'Tài khoản này chưa xác thực': 'This account is not verified',
  'Chưa có mô tả bản thân.': 'No bio yet.',
  'Chỉnh sửa mô tả': 'Edit bio',
  'Nhập mô tả của bạn...': 'Enter your bio...',
  'Theo dõi': 'Followers',
  'Đã theo dõi': 'Following',
  'Chưa có người theo dõi.': 'No followers yet.',
  'Bạn chưa theo dõi ai.': 'You are not following anyone yet.',
  'Điểm uy tín': 'Reputation score',
  'Giữ cách trò chuyện lịch sự để tăng độ uy tín và mở khóa nhiều tính năng hơn.':
      'Keep conversations respectful to improve your reputation and unlock more features.',
  'Tuyệt vời': 'Excellent',
  'Tốt': 'Good',
  'Trung bình': 'Average',
  'Thấp': 'Low',
  'Nhắn tin': 'Message',
  'Báo cáo người dùng': 'Report user',
  'Chọn nhóm lý do phù hợp nhất.':
      'Choose the most appropriate reason category.',
  'Mục chi tiết': 'Details',
  'Lý do cụ thể': 'Specific reason',
  'Nhập lý do khác': 'Enter another reason',
  'Chi tiết thêm': 'Additional details',
  'Mô tả thêm (không bắt buộc)': 'Additional description (optional)',
  'Bạn có thể bổ sung bối cảnh để đội ngũ kiểm duyệt xem xét chính xác hơn.':
      'Add context to help our moderation team review the report accurately.',
  'Ảnh đính kèm': 'Attachments',
  'Gửi báo cáo': 'Submit report',
  'Đã gửi báo cáo': 'Report submitted',
  'Chúng tôi sẽ xem xét báo cáo của bạn.': 'We will review your report.',
  'Vui lòng chọn lý do báo cáo.': 'Please select a report reason.',
  'Phiên đăng nhập đã hết hạn. Vui lòng thử lại.':
      'Your session has expired. Please try again.',
  'Vui lòng nhập lý do cụ thể.': 'Please enter a specific reason.',
  'Không thể chọn ảnh lúc này.': 'Unable to select images right now.',
  'Không thể gửi báo cáo. Vui lòng thử lại.':
      'Unable to submit the report. Please try again.',
  'Giới hạn ảnh': 'Image limit',
  'Đã chặn người dùng': 'User blocked',
  'Tài khoản này đã được thêm vào danh sách hạn chế.':
      'This account has been added to your restricted list.',
  'Chặn người dùng?': 'Block user?',
  'Bạn sẽ không còn thấy hồ sơ, bài viết và người dùng này trong các danh sách của bạn.':
      'You will no longer see this profile, their posts, or this user in your lists.',
  'Chặn luôn': 'Block now',
  'Không thể mở cuộc trò chuyện.': 'Unable to open the conversation.',
  'Không thể xem hồ sơ này': 'Unable to view this profile',
  'Bạn đã chặn người dùng này': 'You blocked this user',
  'Người dùng này hiện không khả dụng với tài khoản của bạn.':
      'This user is currently unavailable to your account.',
  'Có thể gỡ chặn trong Danh sách hạn chế.':
      'You can unblock them from the Restricted accounts list.',
  'Chỉnh sửa hồ sơ': 'Edit profile',
  'Đang kiểm tra nickname...': 'Checking username...',
  'Họ và tên': 'Full name',
  'Biệt danh': 'Username',
  'Ngày sinh': 'Date of birth',
  'Giới tính': 'Gender',
  'Nam': 'Male',
  'Nữ': 'Female',
  'Khác': 'Other',
  'Sở thích của bạn': 'Your interests',
  'Nhập sở thích': 'Enter an interest',
  'Không tìm thấy tag phù hợp': 'No matching interests found',
  'Lưu thay đổi': 'Save changes',
  'Chọn ngày': 'Select day',
  'Chọn tháng': 'Select month',
  'Chọn năm': 'Select year',
  'Không tìm thấy người dùng': 'User not found',
  'Vui lòng chọn giới tính': 'Please select a gender',
  'Vui lòng chọn ngày sinh': 'Please select your date of birth',
  'Bạn phải đủ 18 tuổi': 'You must be at least 18 years old',
  'Đã cập nhật hồ sơ': 'Profile updated',
  'Nickname có thể sử dụng': 'Username is available',
  'Nickname đã được sử dụng': 'Username is already taken',
  'Không thể kiểm tra nickname. Vui lòng thử lại':
      'Unable to check the username. Please try again.',
  'Không tìm thấy dữ liệu hồ sơ': 'Profile data not found',
  'Ngày sinh không hợp lệ': 'Invalid date of birth',
  'Vui lòng nhập họ và tên': 'Please enter your full name',
  'Họ và tên không được có nhiều khoảng trắng liên tiếp':
      'Full name cannot contain consecutive spaces',
  'Họ và tên không được chứa link hoặc username':
      'Full name cannot contain links or usernames',
  'Họ và tên chỉ gồm chữ cái tiếng Việt và khoảng trắng':
      'Full name may only contain letters and spaces',
  'Vui lòng nhập biệt danh': 'Please enter a username',
  'Biệt danh chỉ gồm chữ không dấu, số, dấu chấm (.) hoặc gạch dưới (_)':
      'Username may only contain unaccented letters, numbers, periods, or underscores',
  'Biệt danh không được toàn số, phải có ít nhất 1 chữ cái':
      'Username must contain at least one letter',
  'Biệt danh không được bắt đầu hoặc kết thúc bằng . hoặc _':
      'Username cannot start or end with a period or underscore',
  'Mã QR của tôi': 'My QR code',
  'Quét mã': 'Scan code',
  'Mã của tôi': 'My code',
  'Tải ảnh QR': 'Save QR image',
  'Đang chia sẻ...': 'Sharing...',
  'Chia sẻ mã': 'Share code',
  'Đang xử lý...': 'Processing...',
  'Tải ảnh QR từ thư viện': 'Choose a QR image from gallery',
  'Không thể mở camera': 'Unable to open the camera',
  'Không thể mở camera để quét mã.':
      'Unable to open the camera to scan a code.',
  'Đưa mã QR vào trong khung để quét':
      'Place the QR code inside the frame to scan',
  'Hỗ trợ QR hồ sơ MatchU và ảnh QR trong thư viện':
      'Supports MatchU profile QR codes and QR images from your gallery',
  'Quét mã này để thêm tôi làm bạn': 'Scan this code to connect with me',
  'Không bật được đèn': 'Unable to turn on the flashlight',
  'Thiết bị hiện không hỗ trợ hoặc camera chưa sẵn sàng.':
      'Your device does not support this feature or the camera is not ready.',
  'Không tìm thấy QR': 'QR code not found',
  'Ảnh này không có mã QR hợp lệ của MatchU.':
      'This image does not contain a valid MatchU QR code.',
  'Không quét được ảnh': 'Unable to scan the image',
  'Hãy thử chọn ảnh QR rõ hơn.': 'Try choosing a clearer QR image.',
  'Chưa có dữ liệu': 'No data available',
  'Không tìm thấy tài khoản hiện tại.': 'Current account not found.',
  'Đã sao chép': 'Copied',
  'Mã QR của bạn đã được sao chép để chia sẻ.':
      'Your QR code has been copied for sharing.',
  'Đã lưu ảnh QR': 'QR image saved',
  'Ảnh QR đã được lưu vào thư viện ảnh của máy.':
      'The QR image was saved to your photo library.',
  'Không lưu được ảnh': 'Unable to save the image',
  'Vui lòng mở lại tab Mã của tôi và cấp quyền lưu ảnh nếu được hỏi.':
      'Reopen the My code tab and allow photo access if prompted.',
  'Chia sẻ mã QR MatchU': 'Share MatchU QR code',
  'Mã QR MatchU của tôi': 'My MatchU QR code',
  'Quét mã QR này để thêm tôi làm bạn trên MatchU.':
      'Scan this QR code to connect with me on MatchU.',
  'Không mở được chia sẻ': 'Unable to open sharing',
  'Thiết bị hiện không hỗ trợ chia sẻ ảnh QR.':
      'Your device does not support sharing QR images.',
  'Không chia sẻ được mã QR': 'Unable to share the QR code',
  'Vui lòng mở lại tab Mã của tôi rồi thử lại.':
      'Reopen the My code tab and try again.',
  'QR không hợp lệ': 'Invalid QR code',
  'Mã này không phải mã hồ sơ MatchU.': 'This is not a MatchU profile code.',
  'Không mở được hồ sơ': 'Unable to open the profile',
  'Vui lòng kiểm tra kết nối rồi thử lại.':
      'Check your connection and try again.',
  'Không tìm thấy hồ sơ': 'Profile not found',
  'Tài khoản trong mã QR không còn tồn tại.':
      'The account in this QR code no longer exists.',
  'Danh sách hạn chế': 'Restricted accounts',
  'Bị chặn': 'Blocked',
  'Ẩn bài viết': 'Hidden posts',
  'Tắt thông báo': 'Muted',
  'Không thể tải danh sách': 'Unable to load the list',
  'Chưa chặn ai': 'No blocked accounts',
  'Chưa ẩn ai': 'No hidden accounts',
  'Chưa tắt thông báo ai': 'No muted accounts',
  'Gỡ chặn': 'Unblock',
  'Bỏ ẩn': 'Unhide',
  'Bật lại': 'Unmute',
  'Thử lại': 'Try again',
  'Vui lòng thử lại sau.': 'Please try again later.',
  'Những người bạn đã chặn sẽ xuất hiện ở đây.':
      'People you block will appear here.',
  'Những người bạn đã ẩn bài viết sẽ xuất hiện ở đây.':
      'People whose posts you hide will appear here.',
  'Những người bạn đã tắt thông báo sẽ xuất hiện ở đây.':
      'People you mute will appear here.',
  'Bài viết': 'Posts',
  'Bài đăng lại': 'Reposts',
  'Lưu trữ': 'Saved',
  'Bạn chưa có bài viết nào.': 'You have not posted anything yet.',
  'Người dùng này chưa có bài viết công khai nào.':
      'This user has no public posts yet.',
  'Bạn chưa đăng lại bài viết nào.': 'You have not reposted anything yet.',
  'Người dùng này chưa có bài đăng lại công khai.':
      'This user has no public reposts yet.',
  'Bạn chưa lưu bài viết nào.': 'You have not saved any posts yet.',
  'Không thể tải bài viết lúc này.': 'Unable to load posts right now.',
  'Xem thêm bài viết': 'Load more posts',
  'Đang xử lý bài viết...': 'Processing post...',
  'Bài viết cho người theo dõi': 'Followers-only post',
  'Bài viết riêng tư': 'Private post',
  'Spam': 'Spam',
  'Đăng bài viết lặp lại nhiều lần': 'Repeatedly posting the same content',
  'Bình luận spam dưới nhiều bài viết':
      'Posting spam comments on multiple posts',
  'Gửi tin nhắn quảng cáo hàng loạt': 'Sending bulk advertising messages',
  'Chia sẻ liên kết không rõ nguồn gốc': 'Sharing links from unknown sources',
  'Tạo nhiều tài khoản để spam': 'Creating multiple accounts to spam',
  'Nội dung chỉ nhằm quảng cáo, không có giá trị tương tác':
      'Content created only for advertising with no interaction value',
  'Giả mạo người khác': 'Impersonation',
  'Giả mạo người nổi tiếng': 'Impersonating a public figure',
  'Giả mạo bạn bè hoặc người quen': 'Impersonating a friend or acquaintance',
  'Sử dụng ảnh đại diện của người khác': "Using someone else's profile photo",
  'Dùng tên, thông tin cá nhân của người khác':
      "Using someone else's name or personal information",
  'Giả mạo thương hiệu, tổ chức hoặc cộng đồng':
      'Impersonating a brand, organization, or community',
  'Tạo tài khoản giống tài khoản thật để gây nhầm lẫn':
      'Creating a clone account to mislead people',
  'Quấy rối hoặc xúc phạm': 'Harassment or abuse',
  'Chửi bới, xúc phạm cá nhân': 'Personal insults or abuse',
  'Đe dọa hoặc gây áp lực tinh thần': 'Threats or emotional pressure',
  'Quấy rối qua tin nhắn riêng': 'Harassment through private messages',
  'Công kích ngoại hình, giới tính, vùng miền hoặc cá nhân':
      'Attacks based on appearance, gender, region, or identity',
  'Bình luận tiêu cực lặp lại nhiều lần': 'Repeated negative comments',
  'Kêu gọi người khác tấn công một tài khoản':
      'Encouraging others to attack an account',
  'Nội dung không phù hợp': 'Inappropriate content',
  'Hình ảnh hoặc video phản cảm': 'Disturbing images or videos',
  'Nội dung bạo lực': 'Violent content',
  'Nội dung kích động thù ghét': 'Hateful content',
  'Nội dung gây hiểu nhầm hoặc sai sự thật': 'Misleading or false content',
  'Ngôn từ thô tục, thiếu văn minh': 'Vulgar or offensive language',
  'Nội dung không phù hợp với độ tuổi người dùng': 'Age-inappropriate content',
  'Lừa đảo': 'Scam or fraud',
  'Lừa đảo chuyển tiền': 'Money transfer scam',
  'Giả danh để xin thông tin cá nhân':
      'Impersonation to obtain personal information',
  'Gửi đường link đánh cắp tài khoản': 'Sending account-stealing links',
  'Rao bán sản phẩm hoặc dịch vụ không uy tín':
      'Selling untrustworthy products or services',
  'Hứa hẹn phần thưởng giả': 'Promising fake rewards',
  'Mạo danh nhân viên hỗ trợ hoặc quản trị viên':
      'Impersonating support staff or administrators',
  'Hành vi đáng ngờ': 'Suspicious behavior',
  'Vi phạm quy định cộng đồng': 'Community guidelines violation',
  'Tài khoản có hoạt động bất thường': 'Unusual account activity',
  'Nội dung gây khó chịu nhưng không thuộc mục trên':
      'Uncomfortable content not covered above',
  'Lý do khác do người dùng tự nhập': 'Another reason entered by the user',
};

final profileVietnameseTranslations = <String, String>{
  for (final source in profileEnglishTranslations.keys) source: source,
  ProfileTranslationKeys.error: 'Lỗi',
  ProfileTranslationKeys.success: 'Thành công',
  ProfileTranslationKeys.notice: 'Thông báo',
};

String profileTr(String source) {
  final exact = source.tr;
  if (exact != source || Get.locale?.languageCode != 'en') return exact;

  final patterns = <(RegExp, String Function(Match))>[
    (
      RegExp(r'^Không thể tải hồ sơ: (.+)$'),
      (m) => 'Unable to load profile: ${profileTr(m[1]!)}',
    ),
    (RegExp(r'^Exception: (.+)$'), (m) => profileTr(m[1]!)),
    (
      RegExp(r'^Họ và tên phải từ (\d+) đến (\d+) ký tự$'),
      (m) => 'Full name must be ${m[1]}–${m[2]} characters long',
    ),
    (
      RegExp(r'^Biệt danh phải từ (\d+) đến (\d+) ký tự$'),
      (m) => 'Username must be ${m[1]}–${m[2]} characters long',
    ),
    (
      RegExp(r'^Bạn chỉ có thể đính kèm tối đa (\d+) ảnh\.$'),
      (m) => 'You can attach up to ${m[1]} images.',
    ),
    (
      RegExp(
        r'^Chỉ lưu (\d+) ảnh đầu tiên\. Tối đa (\d+) ảnh cho mỗi báo cáo\.$',
      ),
      (m) =>
          'Only the first ${m[1]} images were added. Each report can include up to ${m[2]} images.',
    ),
    (
      RegExp(r'^Chúng tôi sẽ xem xét tài khoản (.+)\.$'),
      (m) => 'We will review ${m[1]}\'s account.',
    ),
    (
      RegExp(r'^Ảnh QR đã được lưu tại (.+)\.$'),
      (m) => 'The QR image was saved to ${m[1]}.',
    ),
    (
      RegExp(
        r'^Bạn có muốn chặn (.+) không\? Nếu chặn, bạn sẽ không còn thấy hồ sơ, bài viết và tin nhắn từ tài khoản này\.$',
      ),
      (m) =>
          'Block ${m[1]}? You will no longer see this profile, their posts, or their messages.',
    ),
    (RegExp(r'^Đã chặn từ (.+)$'), (m) => 'Blocked since ${m[1]}'),
    (
      RegExp(r'^Bạn đã chọn tối đa (\d+) sở thích$'),
      (m) => 'You can select up to ${m[1]} interests',
    ),
    (RegExp(r'^Đã ẩn từ (.+)$'), (m) => 'Hidden since ${m[1]}'),
    (RegExp(r'^Đã tắt thông báo từ (.+)$'), (m) => 'Muted since ${m[1]}'),
  ];
  for (final (pattern, replacement) in patterns) {
    final match = pattern.firstMatch(source);
    if (match != null) return replacement(match);
  }
  return source;
}
