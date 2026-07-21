import 'package:get/get.dart';

abstract final class LongChatTranslationKeys {
  static const error = 'long_chat.error';
  static const call = 'long_chat.call';
}

const longChatEnglishTranslations = <String, String>{
  LongChatTranslationKeys.error: 'Error',
  LongChatTranslationKeys.call: 'Call',
  'Lưu trữ': 'Archive',
  'Ghim': 'Pin',
  'Sao chép': 'Copy',
  'Chỉnh sửa': 'Edit',
  'Không tìm thấy kết quả': 'No results found',
  'Chưa có cuộc trò chuyện': 'No conversations yet',
  'Đánh dấu đã đọc': 'Mark as read',
  'Đánh dấu chưa đọc': 'Mark as unread',
  'Tắt thông báo': 'Mute notifications',
  'Bật thông báo': 'Turn notifications on',
  'Chặn người dùng': 'Block user',
  'Chặn người dùng?': 'Block user?',
  'Bạn có muốn chặn': 'Do you want to block',
  'người dùng này': 'this user',
  'Sau khi chặn, hai người sẽ không thể nhắn tin cho nhau.':
      'After blocking, you will no longer be able to message each other.',
  '30 phút': '30 minutes',
  '1 giờ': '1 hour',
  '3 giờ': '3 hours',
  '8 giờ': '8 hours',
  'Cho đến khi bật lại': 'Until turned back on',
  'Tin nhắn sẽ bị xóa vĩnh viễn khỏi tài khoản của bạn nhưng vẫn hiển thị với người kia. Tin nhắn mới từ họ sẽ xuất hiện như một cuộc trò chuyện mới.':
      'Messages will be permanently removed from your account but remain visible to the other person. New messages from them will appear as a new conversation.',
  'Không thể thực hiện thao tác.': 'Unable to complete the action.',
  'Vui lòng thử lại.': 'Please try again.',
  'Đang hoạt động': 'Active now',
  'Không hoạt động': 'Inactive',
  'Vừa xong': 'Just now',
  'Hôm nay': 'Today',
  'Hôm qua': 'Yesterday',
  'Đang thiết lập mã hóa, vui lòng đợi...':
      'Setting up encryption. Please wait...',
  '🔐 Đang thiết lập mã hóa…': '🔐 Setting up encryption…',
  '⚠️ Không thể giải mã tin nhắn': '⚠️ Unable to decrypt message',
  'Tin nhan duoc ma hoa': 'Encrypted message',
  'Tin nhan da bi xoa': 'Deleted message',
  '🔐 Tin nhắn được mã hóa': '🔐 Encrypted message',
  'Tin nhắn mới': 'New message',
  'Đã gửi một ảnh': 'Sent an image',
  'Ghi âm': 'Voice recording',
  'Ảnh': 'Image',
  'Không thể gửi tin nhắn.': 'Unable to send message.',
  'Không thể gửi ảnh.': 'Unable to send image.',
  'Cần quyền microphone để ghi âm.':
      'Microphone permission is required to record audio.',
  'Không thể bắt đầu ghi âm lúc này.': 'Unable to start recording right now.',
  'Không thể lưu ghi âm lúc này.': 'Unable to save the recording right now.',
  'Không thể gửi ghi âm.': 'Unable to send the recording.',
  'Đang thiết lập mã hóa, vui lòng thử lại.':
      'Encryption is being set up. Please try again.',
  'Không thể cập nhật tin nhắn.': 'Unable to update the message.',
  'Không thể xóa tin nhắn.': 'Unable to delete the message.',
  'Ảnh đã bị xóa': 'This image has been deleted',
  'Không thể tải ảnh': 'Unable to load the image',
  'Gửi ghi âm': 'Send recording',
  'Gửi ảnh': 'Send image',
  'Đang gửi ghi âm...': 'Sending recording...',
  'Đang gửi ảnh...': 'Sending image...',
  'Gọi video lại': 'Video call again',
  'Gọi lại': 'Call again',
  'Video call': 'Video call',
  'Cuộc gọi video': 'Video call',
  'Cuộc gọi thoại': 'Voice call',
  'Đối phương đang bận': 'The other person is busy',
  'Đang gọi...': 'Calling...',
  'Đang đổ chuông...': 'Ringing...',
  'Cuộc gọi đến': 'Incoming call',
  'Đang kết nối...': 'Connecting...',
  'Cuộc gọi đã kết thúc': 'Call ended',
  'Lỗi cuộc gọi': 'Call error',
  'Cuộc gọi bị từ chối': 'Call declined',
  'Không có phản hồi': 'No answer',
  'Unknown user': 'Unknown user',
  'Unable to redial this conversation.': 'Unable to redial this conversation.',
  'Unable to find receiver.': 'Unable to find the recipient.',
  'You must login before placing a call.':
      'You must log in before placing a call.',
  'Invalid room or receiver.': 'Invalid room or recipient.',
  'Cannot call your own account.': 'You cannot call your own account.',
  'A call is already in progress.': 'A call is already in progress.',
  'Unable to start call.': 'Unable to start the call.',
  'You must login before accepting a call.':
      'You must log in before accepting a call.',
  'Invalid call ID.': 'Invalid call ID.',
  'Call no longer exists.': 'This call no longer exists.',
  'This call is not assigned to current user.':
      'This call is not assigned to the current user.',
  'Call is no longer ringing.': 'This call is no longer ringing.',
  'Missing offer from caller.': 'The caller offer is missing.',
  'Unable to accept call.': 'Unable to accept the call.',
  'Không thể gọi vì một trong hai người đã chặn người còn lại.':
      'This call is unavailable because one of you has blocked the other.',
  'Không thể nhắn tin vì một trong hai người đã chặn người còn lại.':
      'Messaging is unavailable because one of you has blocked the other.',
  'Đã gửi báo cáo': 'Report sent',
  'Cảm ơn bạn đã giúp cộng đồng an toàn hơn ❤️':
      'Thank you for helping keep the community safe ❤️',
  'Chúng tôi sẽ xem xét và xử lý cẩn thận.':
      'We will review it and take appropriate action.',
  'Hãy báo cáo nếu bạn thấy hành vi không phù hợp. Chúng tôi sẽ xem xét và xử lý cẩn thận.':
      'Report any inappropriate behavior. We will review it and take appropriate action.',
  'Xác nhận mã PIN': 'Confirm PIN',
  'Nhập lại mã PIN để xác nhận': 'Enter the PIN again to confirm',
  'Tạo mã PIN để khôi phục tin nhắn trên thiết bị mới':
      'Create a PIN to restore messages on a new device',
  'Mã PIN phải đủ 6 số': 'The PIN must contain 6 digits',
  'Mã PIN không khớp': 'The PINs do not match',
  'Mã PIN phải đủ 6 chữ số': 'The PIN must contain 6 digits',
  'Bạn đã nhập sai mã PIN, vui lòng nhập lại':
      'Incorrect PIN. Please try again.',
  'Không thể kiểm tra mã PIN. Vui lòng thử lại.':
      'Unable to verify the PIN. Please try again.',
  'Không thể mở khóa bằng khuôn mặt. Vui lòng thử lại hoặc nhập mã PIN.':
      'Face unlock failed. Try again or enter your PIN.',
  'Không thể mở khóa bằng khuôn mặt. Vui lòng thử lại.':
      'Face unlock failed. Please try again.',
  'Nhập mã PIN để khôi phục tin nhắn cũ trên thiết bị này. Nếu quên mã PIN, bạn có thể đặt lại để bắt đầu khóa khôi phục mới.':
      'Enter your PIN to restore old messages on this device. If you forgot it, reset the PIN to create a new recovery key.',
  'Nhập mã PIN để khôi phục tin nhắn cũ trên thiết bị này.':
      'Enter your PIN to restore old messages on this device.',
  'Nếu quên mã PIN, bạn có thể đặt lại để bắt đầu khóa khôi phục mới.':
      'If you forgot your PIN, reset it to create a new recovery key.',
  'Việc này sẽ xóa toàn bộ tin nhắn đã mã hóa cũ trên thiết bị này':
      'This will delete all previously encrypted messages on this device.',
};

final longChatVietnameseTranslations = <String, String>{
  for (final source in longChatEnglishTranslations.keys) source: source,
  LongChatTranslationKeys.error: 'Lỗi',
  LongChatTranslationKeys.call: 'Cuộc gọi',
  'Unknown user': 'Người dùng không xác định',
  'Unable to redial this conversation.':
      'Không thể gọi lại trong cuộc trò chuyện này.',
  'Unable to find receiver.': 'Không tìm thấy người nhận cuộc gọi.',
  'You must login before placing a call.':
      'Bạn cần đăng nhập trước khi thực hiện cuộc gọi.',
  'Invalid room or receiver.': 'Phòng chat hoặc người nhận không hợp lệ.',
  'Cannot call your own account.': 'Bạn không thể gọi cho chính mình.',
  'A call is already in progress.': 'Một cuộc gọi khác đang diễn ra.',
  'Unable to start call.': 'Không thể bắt đầu cuộc gọi.',
  'You must login before accepting a call.':
      'Bạn cần đăng nhập trước khi nhận cuộc gọi.',
  'Invalid call ID.': 'Mã cuộc gọi không hợp lệ.',
  'Call no longer exists.': 'Cuộc gọi không còn tồn tại.',
  'This call is not assigned to current user.':
      'Cuộc gọi này không dành cho tài khoản hiện tại.',
  'Call is no longer ringing.': 'Cuộc gọi không còn đổ chuông.',
  'Missing offer from caller.': 'Thiếu thông tin kết nối từ người gọi.',
  'Unable to accept call.': 'Không thể nhận cuộc gọi.',
  'Video call': 'Gọi video',
};

String longChatTr(String source) {
  final exact = source.tr;
  if (exact != source || Get.locale?.languageCode != 'en') return exact;

  final patterns = <(RegExp, String Function(Match))>[
    (RegExp(r'^(\d+) phút trước$'), (m) => '${m[1]} minutes ago'),
    (RegExp(r'^(\d+) giờ trước$'), (m) => '${m[1]} hours ago'),
    (RegExp(r'^(\d+) ngày trước$'), (m) => '${m[1]} days ago'),
    (RegExp(r'^Đang trò chuyện (.+)$'), (m) => 'In call • ${m[1]}'),
    (
      RegExp(r'^(\d+) giờ (\d+) phút (\d+) giây$'),
      (m) => '${m[1]} hr ${m[2]} min ${m[3]} sec',
    ),
    (RegExp(r'^(\d+) phút (\d+) giây$'), (m) => '${m[1]} min ${m[2]} sec'),
    (RegExp(r'^(\d+) giây$'), (m) => '${m[1]} sec'),
    (RegExp(r'^Bạn đã gọi video$'), (_) => 'You made a video call'),
    (RegExp(r'^Bạn đã gọi thoại$'), (_) => 'You made a voice call'),
    (RegExp(r'^Cuộc gọi video đến$'), (_) => 'Incoming video call'),
    (RegExp(r'^Cuộc gọi thoại đến$'), (_) => 'Incoming voice call'),
    (RegExp(r'^Đã bỏ lỡ cuộc gọi video$'), (_) => 'Missed video call'),
    (RegExp(r'^Đã bỏ lỡ cuộc gọi thoại$'), (_) => 'Missed voice call'),
    (RegExp(r'^Cuộc gọi video đã bị từ chối$'), (_) => 'Video call declined'),
    (RegExp(r'^Cuộc gọi thoại đã bị từ chối$'), (_) => 'Voice call declined'),
    (RegExp(r'^Cuộc gọi video đã kết thúc$'), (_) => 'Video call ended'),
    (RegExp(r'^Cuộc gọi thoại đã kết thúc$'), (_) => 'Voice call ended'),
    (
      RegExp(r'^Cuộc gọi video • (.+)$'),
      (m) => 'Video call • ${longChatTr(m[1]!)}',
    ),
    (
      RegExp(r'^Cuộc gọi thoại • (.+)$'),
      (m) => 'Voice call • ${longChatTr(m[1]!)}',
    ),
  ];
  for (final (pattern, replacement) in patterns) {
    final match = pattern.firstMatch(source);
    if (match != null) return replacement(match);
  }
  return source;
}

String longChatPreview(String preview, {required bool isMe}) {
  const systemPreviews = {
    'Tin nhan duoc ma hoa',
    'Tin nhan da bi xoa',
    '🔐 Tin nhắn được mã hóa',
    'Tin nhắn mới',
    'Đã gửi một ảnh',
    'Ghi âm',
    'Ảnh',
    'Ảnh đã bị xóa',
  };
  final localizedPreview =
      systemPreviews.contains(preview) ? longChatTr(preview) : preview;
  if (!isMe) return localizedPreview;
  return Get.locale?.languageCode == 'en'
      ? 'You: $localizedPreview'
      : 'Bạn: $localizedPreview';
}
