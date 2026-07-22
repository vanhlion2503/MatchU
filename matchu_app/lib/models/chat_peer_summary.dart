/// Rating and trust-related metadata shown for an anonymous chat peer.
class ChatPeerSummary {
  const ChatPeerSummary({
    required this.averageRating,
    required this.totalRatings,
    this.gender,
    this.isFaceVerified = false,
  });

  /// A low score is only treated as meaningful after a minimum sample size.
  static const double cautionThreshold = 3.6;
  static const int minimumRatingsForCaution = 5;

  final double averageRating;
  final int totalRatings;
  final String? gender;
  final bool isFaceVerified;

  bool get hasRatings => totalRatings > 0;

  bool get isNewcomer => totalRatings < minimumRatingsForCaution;

  bool get shouldShowSafetyCaution =>
      totalRatings >= minimumRatingsForCaution &&
      averageRating < cautionThreshold;

  factory ChatPeerSummary.fromMap(Map<String, dynamic> data) {
    final totalRatings =
        (data['totalChatRatings'] as num?)?.toInt().clamp(0, 1 << 31) ?? 0;
    final averageRating =
        ((data['avgChatRating'] as num?)?.toDouble() ?? 0)
            .clamp(0, 5)
            .toDouble();

    return ChatPeerSummary(
      averageRating: averageRating,
      totalRatings: totalRatings,
      gender: data['gender']?.toString(),
      isFaceVerified: data['isFaceVerified'] == true,
    );
  }
}
