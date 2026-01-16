import 'package:matchu_app/models/telepathy_question.dart';

class TelepathyQuestionBank {
  static final _pool = <TelepathyQuestion>[
    TelepathyQuestion(
      id: "drink",
      text: "Ăn uống: Trà sữa ?? hay Bia ???",
      left: "Trà sữa ??",
      right: "Bia ??",
    ),
    TelepathyQuestion(
      id: "travel",
      text: "Du l?ch: L?n n?i ?? hay Xu?ng bi?n ????",
      left: "L?n n?i ??",
      right: "Xu?ng bi?n ???",
    ),
    TelepathyQuestion(
      id: "money",
      text: "T?i ch?nh: Ti?t ki?m ?? hay Yolo (ti?u h?t) ???",
      left: "Ti?t ki?m ??",
      right: "Yolo (ti?u h?t) ??",
    ),
    TelepathyQuestion(
      id: "love",
      text: "T?nh y?u: C?ng khai ?? hay B? m?t ???",
      left: "C?ng khai ??",
      right: "B? m?t ??",
    ),
    TelepathyQuestion(
      id: "conflict",
      text: "X? l? m?u thu?n: C?i nhau cho ra ng? ra khoai ?? hay Im l?ng ch? ngu?i gi?n ???",
      left: "C?i nhau cho ra ng? ra khoai ??",
      right: "Im l?ng ch? ngu?i gi?n ??",
    ),
  ];

  static List<TelepathyQuestion> pickRandom(int count) {
    final list = List<TelepathyQuestion>.from(_pool)..shuffle();
    return list.take(count).toList();
  }
}
