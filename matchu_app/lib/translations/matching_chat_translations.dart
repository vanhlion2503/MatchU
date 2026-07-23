import 'package:get/get.dart';

abstract final class MatchingChatTranslationKeys {
  static const notice = 'matching_chat.notice';
  static const error = 'matching_chat.error';
  static const insufficientReputationTitle =
      'matching_chat.insufficient_reputation_title';
  static const tempChatReputationRequired =
      'matching_chat.temp_chat_reputation_required';
  static const videoReputationRequired =
      'matching_chat.video_reputation_required';
  static const understood = 'matching_chat.understood';
}

const matchingChatVietnameseTranslations = <String, String>{
  MatchingChatTranslationKeys.insufficientReputationTitle:
      'Điểm uy tín chưa đủ',
  MatchingChatTranslationKeys.tempChatReputationRequired:
      'Bạn cần ít nhất @required điểm uy tín để ghép đôi chat tạm. Điểm hiện tại: @score.',
  MatchingChatTranslationKeys.videoReputationRequired:
      'Bạn cần ít nhất @required điểm uy tín để ghép đôi video. Điểm hiện tại: @score.',
  MatchingChatTranslationKeys.understood: 'Đã hiểu',
  MatchingChatTranslationKeys.notice: 'Thông báo',
  MatchingChatTranslationKeys.error: 'Lỗi',
  'Mất kết nối': 'Mất kết nối',
  'Đã mất mạng, quay về trang tìm chat': 'Đã mất mạng, quay về trang tìm chat',
  'Thiếu avatar ẩn danh': 'Thiếu avatar ẩn danh',
  'Vui lòng chọn avatar trước khi tìm chat':
      'Vui lòng chọn avatar trước khi tìm chat',
  'Không tìm thấy thông tin tài khoản.': 'Không tìm thấy thông tin tài khoản.',
  'Không thể bắt đầu matching': 'Không thể bắt đầu ghép đôi',
  'Vui lòng thử lại sau ít phút.': 'Vui lòng thử lại sau ít phút.',
  'Không thể tạo phòng chat': 'Không thể tạo phòng chat',
  'Người kia đã rời phòng': 'Người kia đã rời phòng',
  'Đối phương đã thoát trò chơi Thần Giao Cách Cảm.':
      'Đối phương đã thoát trò chơi Thần Giao Cách Cảm.',
  'Đối phương đã thoát trò chơi Nối Từ.':
      'Đối phương đã thoát trò chơi Nối Từ.',
  'Không thể gửi tin nhắn lúc này.': 'Không thể gửi tin nhắn lúc này.',
  'Không thể tải tin nhắn. Vui lòng thử lại.':
      'Không thể tải tin nhắn. Vui lòng thử lại.',
  'Tin nhắn này vi phạm nguyên tắc cộng đồng':
      'Tin nhắn này vi phạm nguyên tắc cộng đồng',
  '⏰ Sắp hết giờ! Còn 30 giây': '⏰ Sắp hết giờ! Còn 30 giây',
  'Luân phiên nối 2 từ, sai là chịu phạt':
      'Luân phiên nối 2 từ, sai là chịu phạt',
  '👋 Xin chào!': '👋 Xin chào!',
  '😊 Hello~': '😊 Xin chào~',
  '✨ Rất vui được gặp bạn': '✨ Rất vui được gặp bạn',
  '💬 Hôm nay của bạn thế nào?': '💬 Hôm nay của bạn thế nào?',
  '🎧 Bạn hay nghe nhạc gì?': '🎧 Bạn hay nghe nhạc gì?',
  '☕ Cà phê hay trà?': '☕ Cà phê hay trà?',
  '🌍 Nếu được đi du lịch, bạn muốn đi đâu?':
      '🌍 Nếu được đi du lịch, bạn muốn đi đâu?',
  '🍜 Món bạn thích nhất là gì?': '🍜 Món bạn thích nhất là gì?',
  '🎬 Bộ phim bạn xem gần đây nhất?': '🎬 Bộ phim bạn xem gần đây nhất?',
  '🐶 Bạn thích chó hay mèo?': '🐶 Bạn thích chó hay mèo?',
  '🎯 Lúc rảnh bạn hay làm gì?': '🎯 Lúc rảnh bạn hay làm gì?',
  '🌙 Bạn là cú đêm hay dậy sớm?': '🌙 Bạn là cú đêm hay dậy sớm?',
  '🎵 Bài hát bạn nghe nhiều nhất gần đây?':
      '🎵 Bài hát bạn nghe nhiều nhất gần đây?',
  '⚽ Bạn có chơi thể thao không?': '⚽ Bạn có chơi thể thao không?',
  'Từ hệ thống': 'Từ hệ thống',
  'Từ đối phương': 'Từ đối phương',
  'Nhập 2 từ bất kỳ': 'Nhập 2 từ bất kỳ',
  'Đang suy nghĩ...': 'Đang suy nghĩ...',
  'Hơi khó rồi đây...': 'Hơi khó rồi đây...',
  'Tìm từ hợp lệ...': 'Tìm từ hợp lệ...',
  'Người kia đã sẵn sàng. Sẽ sớm bắt đầu ...':
      'Người kia đã sẵn sàng. Sẽ sớm bắt đầu ...',
  'Đang chờ đối phương chấp nhận ...': 'Đang chờ đối phương chấp nhận ...',
  'Từ phải gồm đúng 2 tiếng nha 😄\nVí dụ: mưa rào, bình yên':
      'Từ phải gồm đúng 2 tiếng nha 😄\nVí dụ: mưa rào, bình yên',
  'Từ này đã được dùng rồi, thử từ khác nhé!':
      'Từ này đã được dùng rồi, thử từ khác nhé!',
  'Từ này hơi lạ 🤔\nHãy chọn từ quen thuộc hơn':
      'Từ này hơi lạ 🤔\nHãy chọn từ quen thuộc hơn',
  'Hệ thống đã tự động tiếp tục để đảm bảo trải nghiệm cho cả hai.':
      'Hệ thống đã tự động tiếp tục để đảm bảo trải nghiệm cho cả hai.',
  'Hệ thống đã tự động chấp nhận để đảm bảo công bằng cho cả hai.':
      'Hệ thống đã tự động chấp nhận để đảm bảo công bằng cho cả hai.',
  'Từ mới cần nối tiếp theo từ trước nhé!':
      'Từ mới cần nối tiếp theo từ trước nhé!',
  'Chờ chút, chưa đến lượt bạn.': 'Chờ chút, chưa đến lượt bạn.',
  'Ván đang tạm dừng, thử lại sau nhé!': 'Ván đang tạm dừng, thử lại sau nhé!',
  'Chưa nhận được từ này, thử lại nhé!': 'Chưa nhận được từ này, thử lại nhé!',
  'Không tìm được từ phù hợp': 'Không tìm được từ phù hợp',
  'Nội dung không được để trống.': 'Nội dung không được để trống.',
  'Nội dung không phù hợp, hãy chỉnh sửa.':
      'Nội dung không phù hợp, hãy chỉnh sửa.',
  'Nội dung sẽ được kiểm duyệt tự động.':
      'Nội dung sẽ được kiểm duyệt tự động.',
  'Đối phương đang đặt câu hỏi': 'Đối phương đang đặt câu hỏi',
  'Hãy chuẩn bị để trả lời ngay khi nhận được.':
      'Hãy chuẩn bị để trả lời ngay khi nhận được.',
  'Lượt này sẽ được tự động chấp nhận để đảm bảo công bằng.':
      'Lượt này sẽ được tự động chấp nhận để đảm bảo công bằng.',
  'Bạn bắt buộc trả lời để hoàn tất cơ chế thưởng.':
      'Bạn bắt buộc trả lời để hoàn tất cơ chế thưởng.',
  'Đã đạt giới hạn từ chối. Hệ thống sẽ tự động chấp nhận lần tiếp theo.':
      'Đã đạt giới hạn từ chối. Hệ thống sẽ tự động chấp nhận lần tiếp theo.',
  'Hệ thống sẽ tự động chấp nhận nếu vượt quá giới hạn.':
      'Hệ thống sẽ tự động chấp nhận nếu vượt quá giới hạn.',
  'Hệ thống tự động chấp nhận để đảm bảo công bằng cho cả hai.':
      'Hệ thống tự động chấp nhận để đảm bảo công bằng cho cả hai.',
  'Cơ chế thưởng đã hoàn tất. Bạn có thể tiếp tục trò chuyện.':
      'Cơ chế thưởng đã hoàn tất. Bạn có thể tiếp tục trò chuyện.',
  'Đã khóa lựa chọn': 'Đã khóa lựa chọn',
  'Chạm để chọn': 'Chạm để chọn',
  'Đang gửi đáp án...': 'Đang gửi đáp án...',
  'Đang đối chiếu đáp án...': 'Đang đối chiếu đáp án...',
  'Đang chờ đối phương trả lời': 'Đang chờ đối phương trả lời',
  'Đang gửi...': 'Đang gửi...',
  'Đã chọn': 'Đã chọn',
  'Trùng khớp': 'Trùng khớp',
  'Tốc độ': 'Tốc độ',
  'Ẩn đáp án đối phương': 'Ẩn đáp án đối phương',
  'Xem đáp án đối phương': 'Xem đáp án đối phương',
  'Chưa trả lời': 'Chưa trả lời',
  '🎉 Bạn đã chiến thắng!': '🎉 Bạn đã chiến thắng!',
  '😅 Bạn đã thua.': '😅 Bạn đã thua.',
  'Hãy đặt một câu hỏi cho đối phương.': 'Hãy đặt một câu hỏi cho đối phương.',
  'Hãy chuẩn bị trả lời câu hỏi từ đối phương.':
      'Hãy chuẩn bị trả lời câu hỏi từ đối phương.',
  'Kết quả': 'Kết quả',
  'Hỏi': 'Hỏi',
  'Đáp': 'Đáp',
  'Duyệt': 'Duyệt',
  'Bạn ấy muốn trò chuyện thêm một chút nữa trước khi chơi':
      'Bạn ấy muốn trò chuyện thêm một chút nữa trước khi chơi',
};

const matchingChatEnglishTranslations = <String, String>{
  MatchingChatTranslationKeys.insufficientReputationTitle:
      'Insufficient reputation',
  MatchingChatTranslationKeys.tempChatReputationRequired:
      'You need at least @required reputation points to use temporary chat matching. Current score: @score.',
  MatchingChatTranslationKeys.videoReputationRequired:
      'You need at least @required reputation points to use video matching. Current score: @score.',
  MatchingChatTranslationKeys.understood: 'Got it',
  MatchingChatTranslationKeys.notice: 'Notice',
  MatchingChatTranslationKeys.error: 'Error',
  'Mất kết nối': 'Connection lost',
  'Đã mất mạng, quay về trang tìm chat':
      'You are offline. Returning to chat matching.',
  'Thiếu avatar ẩn danh': 'Anonymous avatar required',
  'Vui lòng chọn avatar trước khi tìm chat':
      'Choose an avatar before finding a chat partner.',
  'Không tìm thấy thông tin tài khoản.':
      'Account information could not be found.',
  'Không thể bắt đầu matching': 'Unable to start matching',
  'Vui lòng thử lại sau ít phút.': 'Please try again in a few minutes.',
  'Không thể tạo phòng chat': 'Unable to create the chat room',
  'Người kia đã rời phòng': 'The other person left the room',
  'Đối phương đã thoát trò chơi Thần Giao Cách Cảm.':
      'Your partner left the Telepathy game.',
  'Đối phương đã thoát trò chơi Nối Từ.':
      'Your partner left the Word Chain game.',
  'Không thể gửi tin nhắn lúc này.': 'Unable to send your message right now.',
  'Không thể tải tin nhắn. Vui lòng thử lại.':
      'Unable to load messages. Please try again.',
  'Tin nhắn này vi phạm nguyên tắc cộng đồng':
      'This message violates the Community Guidelines',
  '⏰ Sắp hết giờ! Còn 30 giây': '⏰ Time is almost up! 30 seconds left',
  'Luân phiên nối 2 từ, sai là chịu phạt':
      'Take turns chaining two-word phrases; mistakes carry a penalty',
  '👋 Xin chào!': '👋 Hi!',
  '😊 Hello~': '😊 Hello~',
  '✨ Rất vui được gặp bạn': '✨ Nice to meet you',
  '💬 Hôm nay của bạn thế nào?': '💬 How is your day going?',
  '🎧 Bạn hay nghe nhạc gì?': '🎧 What music do you listen to?',
  '☕ Cà phê hay trà?': '☕ Coffee or tea?',
  '🌍 Nếu được đi du lịch, bạn muốn đi đâu?':
      '🌍 If you could travel anywhere, where would you go?',
  '🍜 Món bạn thích nhất là gì?': '🍜 What is your favorite food?',
  '🎬 Bộ phim bạn xem gần đây nhất?': '🎬 What movie did you watch recently?',
  '🐶 Bạn thích chó hay mèo?': '🐶 Dogs or cats?',
  '🎯 Lúc rảnh bạn hay làm gì?': '🎯 What do you do in your free time?',
  '🌙 Bạn là cú đêm hay dậy sớm?': '🌙 Night owl or early bird?',
  '🎵 Bài hát bạn nghe nhiều nhất gần đây?':
      '🎵 What song have you played most recently?',
  '⚽ Bạn có chơi thể thao không?': '⚽ Do you play any sports?',
  'Từ hệ thống': 'System phrase',
  'Từ đối phương': "Partner's phrase",
  'Nhập 2 từ bất kỳ': 'Enter any two-word phrase',
  'Đang suy nghĩ...': 'Thinking...',
  'Hơi khó rồi đây...': 'This is a tricky one...',
  'Tìm từ hợp lệ...': 'Finding a valid phrase...',
  'Người kia đã sẵn sàng. Sẽ sớm bắt đầu ...':
      'Your partner is ready. Starting soon...',
  'Đang chờ đối phương chấp nhận ...': 'Waiting for your partner to accept...',
  'Từ phải gồm đúng 2 tiếng nha 😄\nVí dụ: mưa rào, bình yên':
      'The phrase must contain exactly two words 😄\nFor example: summer rain, inner peace',
  'Từ này đã được dùng rồi, thử từ khác nhé!':
      'This phrase has already been used. Try another one!',
  'Từ này hơi lạ 🤔\nHãy chọn từ quen thuộc hơn':
      'That phrase looks unusual 🤔\nChoose a more familiar one',
  'Hệ thống đã tự động tiếp tục để đảm bảo trải nghiệm cho cả hai.':
      'The system continued automatically to keep things moving for both players.',
  'Hệ thống đã tự động chấp nhận để đảm bảo công bằng cho cả hai.':
      'The system accepted automatically to keep the game fair for both players.',
  'Từ mới cần nối tiếp theo từ trước nhé!':
      'The new phrase must continue from the previous one!',
  'Chờ chút, chưa đến lượt bạn.': 'Wait a moment. It is not your turn yet.',
  'Ván đang tạm dừng, thử lại sau nhé!':
      'The game is paused. Try again shortly!',
  'Chưa nhận được từ này, thử lại nhé!':
      'This phrase was not received. Please try again!',
  'Không tìm được từ phù hợp': 'No suitable phrase was found',
  'Nội dung không được để trống.': 'Content cannot be empty.',
  'Nội dung không phù hợp, hãy chỉnh sửa.':
      'This content is inappropriate. Please edit it.',
  'Nội dung sẽ được kiểm duyệt tự động.':
      'Content will be moderated automatically.',
  'Đối phương đang đặt câu hỏi': 'Your partner is writing a question',
  'Hãy chuẩn bị để trả lời ngay khi nhận được.':
      'Get ready to answer when it arrives.',
  'Lượt này sẽ được tự động chấp nhận để đảm bảo công bằng.':
      'This response will be accepted automatically to keep things fair.',
  'Bạn bắt buộc trả lời để hoàn tất cơ chế thưởng.':
      'You must answer to complete the reward stage.',
  'Đã đạt giới hạn từ chối. Hệ thống sẽ tự động chấp nhận lần tiếp theo.':
      'The rejection limit has been reached. The next response will be accepted automatically.',
  'Hệ thống sẽ tự động chấp nhận nếu vượt quá giới hạn.':
      'The system will accept automatically if the limit is exceeded.',
  'Hệ thống tự động chấp nhận để đảm bảo công bằng cho cả hai.':
      'The system accepted automatically to keep things fair for both players.',
  'Cơ chế thưởng đã hoàn tất. Bạn có thể tiếp tục trò chuyện.':
      'The reward stage is complete. You can continue chatting.',
  'Đã khóa lựa chọn': 'Choice locked',
  'Chạm để chọn': 'Tap to choose',
  'Đang gửi đáp án...': 'Sending answer...',
  'Đang đối chiếu đáp án...': 'Comparing answers...',
  'Đang chờ đối phương trả lời': 'Waiting for your partner to answer',
  'Đang gửi...': 'Sending...',
  'Đã chọn': 'Selected',
  'Trùng khớp': 'Matches',
  'Tốc độ': 'Speed',
  'Ẩn đáp án đối phương': "Hide partner's answers",
  'Xem đáp án đối phương': "View partner's answers",
  'Chưa trả lời': 'Not answered',
  '🎉 Bạn đã chiến thắng!': '🎉 You won!',
  '😅 Bạn đã thua.': '😅 You lost.',
  'Hãy đặt một câu hỏi cho đối phương.': 'Ask your partner a question.',
  'Hãy chuẩn bị trả lời câu hỏi từ đối phương.':
      "Get ready to answer your partner's question.",
  'Kết quả': 'Result',
  'Hỏi': 'Ask',
  'Đáp': 'Answer',
  'Duyệt': 'Review',
  'Bạn ấy muốn trò chuyện thêm một chút nữa trước khi chơi':
      'Your partner would like to chat a little longer before playing',
};

String matchingChatTr(String source) {
  final exact = source.tr;
  if (exact != source || Get.locale?.languageCode != 'en') return exact;

  final patterns = <(RegExp, String Function(Match))>[
    (
      RegExp(r'^Nhập từ bắt đầu bằng "(.+)"$'),
      (m) => 'Enter a phrase starting with "${m[1]}"',
    ),
    (RegExp(r'^Từ khóa trước: (.+)$'), (m) => 'Previous phrase: ${m[1]}'),
    (
      RegExp(r"^Từ mới phải bắt đầu bằng '(.+)'$"),
      (m) => "The new phrase must start with '${m[1]}'",
    ),
    (RegExp(r'^Vượt quá (\d+) ký tự\.$'), (m) => 'Maximum ${m[1]} characters.'),
    (
      RegExp(r'^Đối phương đã yêu cầu trả lời lại \((\d+)/(\d+)\)\.$'),
      (m) => 'Your partner requested another answer (${m[1]}/${m[2]}).',
    ),
    (
      RegExp(r'^Bạn còn (\d+) lần yêu cầu trả lời lại\.$'),
      (m) => 'You have ${m[1]} retry requests left.',
    ),
    (
      RegExp(r'^Đối phương còn (\d+) quyền yêu cầu trả lời lại\.$'),
      (m) => 'Your partner has ${m[1]} retry requests left.',
    ),
    (RegExp(r'^Câu (\d+): (.+)$'), (m) => 'Question ${m[1]}: ${m[2]}'),
    (
      RegExp(r'^(\d+)/(\d+) câu trùng khớp$'),
      (m) => '${m[1]}/${m[2]} matching answers',
    ),
    (
      RegExp(r'^Wow! (\d+)% tương đồng! Hai bạn hợp cạ quá trời 😳$'),
      (m) => 'Wow! ${m[1]}% alike! You two are incredibly compatible 😳',
    ),
    (
      RegExp(r'^Wow! (\d+)% tương đồng! Hai bạn là tri kỷ thật lực đó 😳$'),
      (m) => 'Wow! ${m[1]}% alike! You two may be soulmates 😳',
    ),
    (
      RegExp(
        r"^Wow! (\d+)% tương đồng! Hai bạn là tri kỷ thật lực đó 😳 Ờ mà khoan… cả 2 đều chọn '(.+)', hẹn hò có dự định gì chưa\? 😉$",
      ),
      (m) =>
          "Wow! ${m[1]}% alike! You both chose '${matchingChatTr(m[2]!)}'. Any date plans yet? 😉",
    ),
    (
      RegExp(r'^Hợp nhau (\d+)%. Khá ổn đấy chứ! 🤝$'),
      (m) => '${m[1]}% compatible. That is pretty good! 🤝',
    ),
    (
      RegExp(
        r"^Hợp nhau (\d+)%. Khá ổn đấy chứ! 🤝 Nhưng mà này… bạn thích '(.+)' còn người kia lại thích '(.+)'. Hai bạn tính sao về vụ này\? 😄$",
      ),
      (m) =>
          "${m[1]}% compatible. You chose '${matchingChatTr(m[2]!)}', while your partner chose '${matchingChatTr(m[3]!)}'. What do you think? 😄",
    ),
    (
      RegExp(r'^Chỉ (\d+)% thôi 😅 Trái dấu đôi khi lại hút nhau mạnh!$'),
      (m) => 'Only ${m[1]}% 😅 Sometimes opposites attract!',
    ),
    (
      RegExp(r'^Chỉ (\d+)% thôi 😅 Đôi khi trái dấu lại hút nhau mạnh!$'),
      (m) => 'Only ${m[1]}% 😅 Sometimes opposites attract!',
    ),
    (
      RegExp(
        r"^Chỉ (\d+)% thôi à 😅 Hai cực nam châm trái dấu thường hút nhau mạnh lắm đấy! 🧲 Thử hỏi vì sao người kia lại chọn '(.+)' xem nào\? 😉$",
      ),
      (m) =>
          "Only ${m[1]}% 😅 Opposites often attract! Ask why your partner chose '${matchingChatTr(m[2]!)}'. 😉",
    ),
  ];
  for (final (pattern, replacement) in patterns) {
    final match = pattern.firstMatch(source);
    if (match != null) return replacement(match);
  }
  return source;
}
