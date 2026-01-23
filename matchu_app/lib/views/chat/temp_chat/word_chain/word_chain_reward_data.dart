import 'package:flutter/material.dart';

class WordChainRewardQuestion {
  final String id;
  final String prompt;
  final String description;
  final IconData icon;

  const WordChainRewardQuestion({
    required this.id,
    required this.prompt,
    required this.description,
    required this.icon,
  });
}

const kWordChainRewardQuestions = [
  WordChainRewardQuestion(
    id: 'moment',
    prompt: 'Một khoảnh khắc vui gần đây của bạn?',
    description: 'Nhẹ nhàng và dễ bắt đầu câu chuyện.',
    icon: Icons.sentiment_satisfied_alt,
  ),
  WordChainRewardQuestion(
    id: 'music',
    prompt: 'Bài hát nào khiến bạn thấy chill?',
    description: 'Chia sẻ nhanh về gu âm nhạc.',
    icon: Icons.music_note_outlined,
  ),
  WordChainRewardQuestion(
    id: 'food',
    prompt: 'Món ăn nào bạn muốn thử cùng mình?',
    description: 'Gợi ý hẹn nhẹ nhàng, vui vẻ.',
    icon: Icons.restaurant_menu,
  ),
  WordChainRewardQuestion(
    id: 'travel',
    prompt: 'Nếu được đi du lịch miễn phí, bạn chọn đâu?',
    description: 'Một câu hỏi mở để khám phá sở thích.',
    icon: Icons.flight_takeoff,
  ),
  WordChainRewardQuestion(
    id: 'habit',
    prompt: 'Một thói quen nhỏ giúp bạn vui hơn?',
    description: 'Tích cực và dễ chia sẻ.',
    icon: Icons.favorite_border,
  ),
  WordChainRewardQuestion(
    id: 'nickname',
    prompt: 'Bạn muốn được gọi bằng biệt danh gì?',
    description: 'Thân thiện và tạo kết nối.',
    icon: Icons.tag_faces,
  ),
];
