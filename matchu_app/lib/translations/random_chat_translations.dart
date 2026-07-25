import 'package:get/get.dart';

const randomChatEnglishTranslations = <String, String>{
  'Giới thiệu tổng quan': 'Overview',
  'MatchU ghép cặp ẩn danh theo tiêu chí của bạn và mở phòng chat tạm để làm quen nhanh.':
      'MatchU anonymously matches you based on your preferences and opens a temporary chat so you can get acquainted.',
  'Ghép cặp theo giới tính bạn chọn: Nam, Nữ hoặc Ngẫu nhiên.':
      'Match by your preferred gender: Male, Female, or Random.',
  'Mỗi phiên bắt đầu từ avatar ẩn danh để tăng an toàn khi làm quen.':
      'Each session starts with an anonymous avatar for a safer introduction.',
  'Chọn Trò chuyện hoặc Video call ẩn danh trước khi bắt đầu.':
      'Choose anonymous Chat or Video call before you start.',
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
  'Bước 3: Chọn Trò chuyện hoặc Video call rồi bắt đầu tìm kiếm.':
      'Step 3: Choose Chat or Video call, then start searching.',
  'Bước 4: Vào phòng chat tạm 7 phút để trò chuyện và quyết định tiếp tục.':
      'Step 4: Chat for seven minutes, then decide whether to continue.',
  'Bước 4: Làm quen trong phòng tạm và cùng thả tim nếu muốn tiếp tục.':
      'Step 4: Get acquainted in the temporary room and both like to continue.',
  'Luật chơi': 'Rules',
  'Bộ luật áp dụng cho matching chat để đảm bảo công bằng và an toàn.':
      'These matching rules help keep conversations fair and safe.',
  'Chỉ tính lượt khi ghép cặp thành công (không trừ lượt khi chỉ bấm tìm).':
      'A turn is used only after a successful match, not when you simply start searching.',
  'Tài khoản chưa xác thực: tối đa 10 lượt chat matching thành công/ngày, reset lúc 00:00.':
      'Unverified accounts get up to 10 successful chat matches per day, resetting at midnight.',
  'Video matching yêu cầu tài khoản đã xác thực khuôn mặt và tốn 1 gem khi ghép thành công.':
      'Video matching requires a face-verified account and costs 1 gem after a successful match.',
  'Chat tạm yêu cầu tối thiểu 80 điểm uy tín; video call yêu cầu tối thiểu 90 điểm uy tín.':
      'Temporary chat requires at least 80 reputation points; video matching requires at least 90.',
  'Nếu cả hai cùng thích nhau, hệ thống chuyển sang phòng chat lâu dài.':
      'If you both like each other, the conversation becomes a permanent chat.',
  'Phòng video kéo dài tối đa 8 phút; camera chỉ mở được sau 1 phút 30 giây.':
      'Video rooms last up to eight minutes; cameras unlock after 1 minute 30 seconds.',
  'Không spam, xúc phạm, quấy rối hoặc chia sẻ nội dung nhạy cảm.':
      'Do not spam, insult, harass, or share sensitive content.',
  'Vi phạm nhiều lần có thể bị cảnh báo, hạn chế hoặc khóa tính năng.':
      'Repeated violations may result in warnings, restrictions, or loss of access.',
  'Đang bắt đầu...': 'Starting...',
  'Đang tải lượt...': 'Loading turns...',
  'Bắt đầu tìm kiếm': 'Start searching',
  'Bắt đầu tìm kiếm video?': 'Start searching for a video match?',
  'Khi ghép đôi video thành công, hệ thống sẽ trừ 1 gem. Bạn có muốn tiếp tục?':
      'A successful video match will cost 1 gem. Do you want to continue?',
  'Không đủ gem': 'Not enough gems',
  'Mỗi lần ghép đôi video thành công cần 1 gem. Gem chỉ bị trừ sau khi hệ thống tạo phòng thành công.':
      'Each successful video match costs 1 gem. Gems are charged only after a room is created successfully.',
  'Bạn phải hoàn tất xác thực khuôn mặt trước khi video matching.':
      'Complete face verification before starting video matching.',
  'Loại hình...': 'Experience...',
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

  if (source == 'Không đủ gem • Cần 1 gem') {
    return 'Not enough gems • 1 gem required';
  }
  if (source == 'Bắt đầu tìm kiếm • 1 gem') {
    return 'Start searching • 1 gem';
  }
  final videoStart = RegExp(
    r'^Bắt đầu tìm kiếm • (\d+)/(\d+) • 1 gem$',
  ).firstMatch(source);
  if (videoStart != null) {
    return 'Start searching • ${videoStart[1]}/${videoStart[2]} • 1 gem';
  }

  return source;
}
