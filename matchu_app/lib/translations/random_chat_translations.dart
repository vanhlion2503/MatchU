import 'package:get/get.dart';

const randomChatEnglishTranslations = <String, String>{
  'Giới thiệu tổng quan': 'Overview',
  'MatchU ghép cặp ẩn danh theo tiêu chí của bạn và mở phòng chat tạm để làm quen nhanh.':
      'MatchU anonymously matches you based on your preferences and opens a temporary chat so you can get acquainted.',
  'Ghép cặp theo giới tính bạn chọn: Nam, Nữ hoặc Ngẫu nhiên.':
      'Match by your preferred gender: Male, Female, or Random.',
  'Mỗi phiên bắt đầu từ avatar ẩn danh để tăng an toàn khi làm quen.':
      'Each session starts with an anonymous avatar for a safer introduction.',
  'Tài khoản đã xác thực khuôn mặt dùng matching không giới hạn.':
      'Face-verified accounts can use matching without a daily limit.',
  'Cách chơi': 'How it works',
  'Làm theo 4 bước để bắt đầu trò chuyện và kết nối đúng người.':
      'Follow four steps to start chatting and meet the right person.',
  'Bước 1: Chọn avatar ẩn danh của bạn.':
      'Step 1: Choose your anonymous avatar.',
  'Bước 2: Chọn đối tượng muốn ghép (Nam/Nữ/Ngẫu nhiên).':
      'Step 2: Choose who you want to meet (Male/Female/Random).',
  'Bước 3: Nhấn nút Bắt đầu tìm kiếm và chờ hệ thống ghép cặp.':
      'Step 3: Tap Start searching and wait for a match.',
  'Bước 4: Vào phòng chat tạm 7 phút để trò chuyện và quyết định tiếp tục.':
      'Step 4: Chat for seven minutes, then decide whether to continue.',
  'Luật chơi': 'Rules',
  'Bộ luật áp dụng cho matching chat để đảm bảo công bằng và an toàn.':
      'These matching rules help keep conversations fair and safe.',
  'Chỉ tính lượt khi ghép cặp thành công (không trừ lượt khi chỉ bấm tìm).':
      'A turn is used only after a successful match, not when you simply start searching.',
  'Tài khoản chưa xác thực: tối đa 10 lượt ghép thành công/ngày, reset lúc 00:00.':
      'Unverified accounts get up to 10 successful matches per day, resetting at midnight.',
  'Nếu cả hai cùng thích nhau, hệ thống chuyển sang phòng chat lâu dài.':
      'If you both like each other, the conversation becomes a permanent chat.',
  'Không spam, xúc phạm, quấy rối hoặc chia sẻ nội dung nhạy cảm.':
      'Do not spam, insult, harass, or share sensitive content.',
  'Vi phạm nhiều lần có thể bị cảnh báo, hạn chế hoặc khóa tính năng.':
      'Repeated violations may result in warnings, restrictions, or loss of access.',
  'Đang bắt đầu...': 'Starting...',
  'Đang tải lượt...': 'Loading turns...',
  'Bắt đầu tìm kiếm': 'Start searching',
  'Vui lòng chọn avatar trước khi bắt đầu':
      'Choose an avatar before you start.',
  'Thiết lập mã PIN': 'Set up a PIN',
  'Bạn cần thiết lập mã PIN để bảo vệ tin nhắn trước khi bắt đầu tìm kiếm.':
      'Set up a PIN to protect your messages before you start searching.',
  'Nhập mã PIN': 'Enter your PIN',
  'Bạn cần nhập mã PIN để mở khóa bảo vệ tin nhắn trước khi bắt đầu tìm kiếm.':
      'Enter your PIN to unlock message protection before you start searching.',
  'Ngẫu nhiên': 'Random',
};

final randomChatVietnameseTranslations = <String, String>{
  for (final source in randomChatEnglishTranslations.keys) source: source,
};

String randomChatTr(String source) {
  final exact = source.tr;
  if (exact != source || Get.locale?.languageCode != 'en') return exact;

  final noTurns = RegExp(r'^Hết lượt hôm nay • 0/(\d+)$').firstMatch(source);
  if (noTurns != null) return 'No turns left today • 0/${noTurns[1]}';

  final start = RegExp(r'^Bắt đầu tìm kiếm • (\d+)/(\d+)$').firstMatch(source);
  if (start != null) return 'Start searching • ${start[1]}/${start[2]}';

  return source;
}
