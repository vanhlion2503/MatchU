import 'package:matchu_app/models/telepathy_question.dart';

class TelepathyQuestionBank {
  static final _pool = <TelepathyQuestion>[
    TelepathyQuestion(
      id: "drink",
      text: "Ăn uống: Trà sữa 🧋 hay Bia 🍺",
      left: "Trà sữa 🧋",
      right: "Bia 🍺",
    ),
    TelepathyQuestion(
      id: "travel",
      text: "Du lịch: Lên núi ⛰️ hay Xuống biển 🌊",
      left: "Lên núi ⛰️",
      right: "Xuống biển 🌊",
    ),
    TelepathyQuestion(
      id: "money",
      text: "Tài chính: Tiết kiệm 💰 hay YOLO (tiêu hết) 🔥",
      left: "Tiết kiệm 💰",
      right: "YOLO (tiêu hết) 🔥",
    ),
    TelepathyQuestion(
      id: "love",
      text: "Tình yêu: Công khai 💑 hay Bí mật 🤫",
      left: "Công khai 💑",
      right: "Bí mật 🤫",
    ),
    TelepathyQuestion(
      id: "conflict",
      text:
          "Xử lý mâu thuẫn: Cãi nhau cho ra ngô ra khoai 🗣️ hay Im lặng chờ nguôi giận 🤐",
      left: "Cãi nhau cho ra ngô ra khoai 🗣️",
      right: "Im lặng chờ nguôi giận 🤐",
    ),
  ];

  static List<TelepathyQuestion> pickRandom(int count) {
    final list = List<TelepathyQuestion>.from(_pool)..shuffle();
    return list.take(count).toList();
  }
}
