// FILE: lib/controllers/game/telepathy_question_bank.dart

import 'dart:math';
import 'package:matchu_app/models/telepathy_question.dart';

class TelepathyQuestionBank {
  // 1. NHÓM VUI VẺ & SỞ THÍCH (Ice Breaking) - Dễ trả lời
  static final _funQuestions = [
    TelepathyQuestion(
      id: "food_pho",
      category: QuestionCategory.fun,
      text: "Sáng nay ăn gì: Phở nước 🍜 hay Bánh mì 🥖",
      left: "Phở nước 🍜",
      right: "Bánh mì 🥖",
    ),
    TelepathyQuestion(
      id: "pet_dog_cat",
      category: QuestionCategory.fun,
      text: "Vũ trụ thú cưng: Team Chó 🐶 hay Team Mèo 🐱",
      left: "Team Chó 🐶",
      right: "Team Mèo 🐱",
    ),
    TelepathyQuestion(
      id: "drink_tapioca",
      category: QuestionCategory.fun,
      text: "Giải khát: Trà sữa full topping 🧋 hay Bia lạnh cực đã 🍺",
      left: "Trà sữa 🧋",
      right: "Bia 🍺",
    ),
    TelepathyQuestion(
      id: "travel_view",
      category: QuestionCategory.fun,
      text: "Du lịch: Lên núi ngắm mây ⛰️ hay Xuống biển ngắm bikini 🌊",
      left: "Lên núi ⛰️",
      right: "Xuống biển 🌊",
    ),
    TelepathyQuestion(
      id: "movie_genre",
      category: QuestionCategory.fun,
      text: "Xem phim: Hành động cháy nổ 💥 hay Tình cảm sướt mướt 💘",
      left: "Hành động 💥",
      right: "Tình cảm 💘",
    ),
    TelepathyQuestion(
      id: "sleep_schedule",
      category: QuestionCategory.fun,
      text: "Sinh hoạt: Dậy sớm đón bình minh 🌅 hay Cú đêm chính hiệu 🌙",
      left: "Dậy sớm 🌅",
      right: "Cú đêm 🌙",
    ),
    TelepathyQuestion(
      id: "music_style",
      category: QuestionCategory.fun,
      text: "Nghe nhạc: Nhạc Việt chill 🇻🇳 hay Nhạc US-UK 🎧",
      left: "Nhạc Việt 🇻🇳",
      right: "US-UK 🎧",
    ),
    TelepathyQuestion(
      id: "snack_choice",
      category: QuestionCategory.fun,
      text: "Ăn vặt: Trà chanh chém gió 🍋 hay Cafe học bài ☕",
      left: "Trà chanh 🍋",
      right: "Cafe ☕",
    ),
    TelepathyQuestion(
      id: "weather",
      category: QuestionCategory.fun,
      text: "Thời tiết yêu thích: Trời mưa lãng mạn 🌧️ hay Nắng đẹp rực rỡ ☀️",
      left: "Trời mưa 🌧️",
      right: "Nắng đẹp ☀️",
    ),
  ];

  // 2. NHÓM LỐI SỐNG (Lifestyle) - Hiểu thói quen
  static final _lifestyleQuestions = [
    TelepathyQuestion(
      id: "money_manage",
      category: QuestionCategory.lifestyle,
      text: "Tài chính: Tiết kiệm lo tương lai 💰 hay YOLO tiêu hết cho sướng 🔥",
      left: "Tiết kiệm 💰",
      right: "YOLO 🔥",
    ),
    TelepathyQuestion(
      id: "weekend_vibe",
      category: QuestionCategory.lifestyle,
      text: "Cuối tuần rảnh: Ra đường tụ tập 🍻 hay Nằm nhà ngủ nướng 😴",
      left: "Ra đường 🍻",
      right: "Nằm nhà 😴",
    ),
    TelepathyQuestion(
      id: "social_media",
      category: QuestionCategory.lifestyle,
      text: "Mạng xã hội: Đăng story mỗi ngày 📸 hay Tàu ngầm âm thầm xem 🕵️",
      left: "Đăng suốt 📸",
      right: "Tàu ngầm 🕵️",
    ),
    TelepathyQuestion(
      id: "punctuality",
      category: QuestionCategory.lifestyle,
      text: "Giờ giấc: Đến sớm 5 phút ⌚ hay Cao su 10 phút 🐢",
      left: "Đến sớm ⌚",
      right: "Cao su 🐢",
    ),
    TelepathyQuestion(
      id: "daily_routine",
      category: QuestionCategory.lifestyle,
      text: "Sinh hoạt: Lập kế hoạch chi tiết 📋 hay Sống tùy hứng 🎲",
      left: "Có kế hoạch 📋",
      right: "Tùy hứng 🎲",
    ),
    TelepathyQuestion(
      id: "cleanliness",
      category: QuestionCategory.lifestyle,
      text: "Nhà cửa: Gọn gàng ngăn nắp ✨ hay Bừa vừa đủ sống 😅",
      left: "Ngăn nắp ✨",
      right: "Bừa chút 😅",
    ),
    TelepathyQuestion(
      id: "shopping_style",
      category: QuestionCategory.lifestyle,
      text: "Mua sắm: Thích săn sale 🏷️ hay Mua khi cần 🎯",
      left: "Săn sale 🏷️",
      right: "Khi cần 🎯",
    ),
    TelepathyQuestion(
      id: "phone_usage",
      category: QuestionCategory.lifestyle,
      text: "Điện thoại: Lúc nào cũng kè kè 📱 hay Chỉ dùng khi cần 📵",
      left: "Cầm suốt 📱",
      right: "Ít dùng 📵",
    ),
  ];

  // 3. NHÓM TÌNH YÊU (Love) - Quan trọng để hẹn hò
  static final _loveQuestions = [
    TelepathyQuestion(
      id: "date_split",
      category: QuestionCategory.love,
      text: "Hẹn hò đầu: Chia đôi tiền (50/50) 💸 hay Bạn nam trả hết 🎩",
      left: "Chia đôi 💸",
      right: "Nam trả hết 🎩",
    ),
    TelepathyQuestion(
      id: "love_public",
      category: QuestionCategory.love,
      text: "Yêu đương: Công khai MXH 📢 hay Yêu trong bí mật 🤫",
      left: "Công khai 📢",
      right: "Bí mật 🤫",
    ),
    TelepathyQuestion(
      id: "jealousy",
      category: QuestionCategory.love,
      text: "Khi ghen: Ghen lồng lộn 🌋 hay Ghen ngầm trong tim 💔",
      left: "Ghen lồng lộn 🌋",
      right: "Ghen ngầm 💔",
    ),
    TelepathyQuestion(
      id: "text_reply",
      category: QuestionCategory.love,
      text: "Nhắn tin: Rep ngay lập tức ⚡ hay Ngâm tin nhắn chờ rảnh ⏳",
      left: "Rep ngay ⚡",
      right: "Ngâm tin ⏳",
    ),
    TelepathyQuestion(
      id: "ex_lover",
      category: QuestionCategory.love,
      text: "Người yêu cũ: Làm bạn bình thường 🤝 hay Coi như đã chết 💀",
      left: "Làm bạn 🤝",
      right: "Cạch mặt 💀",
    ),
    TelepathyQuestion(
      id: "first_move",
      category: QuestionCategory.love,
      text: "Tán tỉnh: Chủ động bật đèn xanh 🚦 hay Đợi đối phương hiểu 🫣",
      left: "Chủ động 🚦",
      right: "Đợi hiểu 🫣",
    ),
    TelepathyQuestion(
      id: "dating_style",
      category: QuestionCategory.love,
      text: "Hẹn hò: Quan trọng cảm xúc ❤️ hay Sự ổn định lâu dài 🏡",
      left: "Cảm xúc ❤️",
      right: "Ổn định 🏡",
    ),
    TelepathyQuestion(
      id: "arguments",
      category: QuestionCategory.love,
      text: "Cãi nhau: Nói hết cho nhẹ lòng 🗯️ hay Né tránh cho yên 🤐",
      left: "Nói hết 🗯️",
      right: "Né tránh 🤐",
    ),
    TelepathyQuestion(
      id: "love_language",
      category: QuestionCategory.love,
      text: "Thể hiện yêu: Nói lời ngọt ngào 💌 hay Hành động thực tế 💪",
      left: "Nói lời 💌",
      right: "Hành động 💪",
    ),
  ];

  // 4. NHÓM SÂU SẮC (Deep) - Giá trị cốt lõi
  static final _deepQuestions = [
    TelepathyQuestion(
      id: "conflict_solve",
      category: QuestionCategory.deep,
      text: "Mâu thuẫn: Cãi cho ra lẽ ngay 🗣️ hay Im lặng chờ nguôi giận 🤐",
      left: "Cãi ngay 🗣️",
      right: "Im lặng 🤐",
    ),
    TelepathyQuestion(
      id: "life_priority",
      category: QuestionCategory.deep,
      text: "Ưu tiên lúc này: Sự nghiệp thăng tiến 💼 hay Gia đình hạnh phúc 🏠",
      left: "Sự nghiệp 💼",
      right: "Gia đình 🏠",
    ),
    TelepathyQuestion(
      id: "apology",
      category: QuestionCategory.deep,
      text: "Khi sai: Dễ dàng xin lỗi 🙏 hay Cái tôi cao khó mở lời 🗿",
      left: "Dễ xin lỗi 🙏",
      right: "Cái tôi cao 🗿",
    ),
    TelepathyQuestion(
      id: "trust_issue",
      category: QuestionCategory.deep,
      text: "Niềm tin: Tin người dễ dàng 🤍 hay Luôn giữ đề phòng 🛡️",
      left: "Tin dễ 🤍",
      right: "Đề phòng 🛡️",
    ),
    TelepathyQuestion(
      id: "life_goal",
      category: QuestionCategory.deep,
      text: "Mục tiêu sống: Hạnh phúc mỗi ngày 🌈 hay Thành công vang dội 🏆",
      left: "Hạnh phúc 🌈",
      right: "Thành công 🏆",
    ),
    TelepathyQuestion(
      id: "change_yourself",
      category: QuestionCategory.deep,
      text: "Bản thân: Thích ổn định như hiện tại 🧘 hay Luôn muốn thay đổi 🔄",
      left: "Ổn định 🧘",
      right: "Thay đổi 🔄",
    ),
    TelepathyQuestion(
      id: "loneliness",
      category: QuestionCategory.deep,
      text: "Cô đơn: Thích một mình để nạp năng lượng 🌌 hay Luôn cần ai đó bên cạnh 🤝",
      left: "Một mình 🌌",
      right: "Cần người 🤝",
    ),
  ];

  /// THUẬT TOÁN CHỌN "SMART MIX"
  /// Thay vì random lộn xộn, ta sẽ lấy theo công thức chuẩn phễu cảm xúc:
  /// 1. Fun (Mở bài vui vẻ)
  /// 2. Lifestyle (Tìm hiểu thói quen)
  /// 3. Love (Quan điểm yêu - 2 câu)
  /// 4. Deep (Kết bài sâu sắc)
  static List<TelepathyQuestion> pickSmartMix() {
    final random = Random();

    // Hàm phụ để lấy ngẫu nhiên n phần tử từ list
    List<T> pickN<T>(List<T> source, int n) {
      if (source.isEmpty) return [];
      var list = List<T>.from(source)..shuffle(random);
      return list.take(n).toList();
    }

    final selection = <TelepathyQuestion>[];

    // Cấu trúc bộ câu hỏi (Tổng 5 câu)
    selection.addAll(pickN(_funQuestions, 1));       // Câu 1: Khởi động
    selection.addAll(pickN(_lifestyleQuestions, 1)); // Câu 2: Thói quen
    selection.addAll(pickN(_loveQuestions, 2));      // Câu 3, 4: Quan trọng
    selection.addAll(pickN(_deepQuestions, 1));      // Câu 5: Chốt hạ

    return selection;
  }
}