class InterestTags {
  InterestTags._();

  static const int maxSelected = 12;

  static const List<String> all = [
    '🎵 Âm nhạc',
    '🎤 K-pop',
    '🎧 US-UK',
    '🎶 V-pop',
    '🎸 Indie',
    '🎙️ Rap',
    '🎷 R&B',
    '🎺 Jazz',
    '🔊 EDM',
    '🎧 Lo-fi',
    '🎸 Guitar',
    '🎹 Piano',
    '🎤 Karaoke',
    '🎫 Concert',
    '🎪 Festival âm nhạc',
    '🎛️ DJ',
    '💿 Vinyl',
    '✍️ Sáng tác nhạc',
    '🎧 Nghe nhạc',
    '🎤 Hát karaoke',
    '🎸 Chơi guitar',
    '🎹 Chơi piano',
    '🎫 Đi concert',
    '🎼 Làm nhạc',
    '🎬 Phim ảnh',
    '👻 Phim kinh dị',
    '😂 Phim hài',
    '💕 Phim tình cảm',
    '💥 Phim hành động',
    '🎞️ Phim tài liệu',
    '🌸 Anime',
    '📚 Manga',
    '📺 Netflix',
    '🎙️ Podcast',
    '▶️ YouTube',
    '🎵 TikTok',
    '🎬 Xem phim',
    '🌸 Xem anime',
    '📚 Đọc manga',
    '🎙️ Nghe podcast',
    '📺 Cày series',
    '▶️ Làm video YouTube',
    '📖 Sách',
    '📕 Tiểu thuyết',
    '📚 Truyện tranh',
    '🌱 Sách self-help',
    '💼 Sách kinh doanh',
    '✍️ Viết lách',
    '📝 Thơ',
    '📰 Blogging',
    '📖 Đọc sách',
    '✍️ Viết nhật ký',
    '📝 Viết thơ',
    '📰 Viết blog',
    '📚 Sưu tầm sách',
    '📷 Nhiếp ảnh',
    '🎥 Quay video',
    '📹 Vlog',
    '🖼️ Chỉnh ảnh',
    '📷 Chụp ảnh',
    '🎥 Quay vlog',
    '🖼️ Edit ảnh',
    '🎞️ Dựng video',
    '🎨 Vẽ',
    '🖌️ Digital art',
    '📐 Thiết kế',
    '🧩 UI/UX',
    '🧶 Handmade',
    '📄 Origami',
    '🎨 Vẽ tranh',
    '🖌️ Vẽ digital',
    '📐 Thiết kế poster',
    '🧶 Làm đồ handmade',
    '📄 Gấp origami',
    '👗 Thời trang',
    '💄 Makeup',
    '🧴 Skincare',
    '🛍️ Mua sắm',
    '🧢 Streetwear',
    '🕰️ Vintage',
    '👗 Phối đồ',
    '💄 Trang điểm',
    '🧴 Chăm sóc da',
    '🛍️ Đi shopping',
    '👟 Săn sneaker',
    '✈️ Du lịch',
    '🏍️ Phượt',
    '🏕️ Camping',
    '🥾 Trekking',
    '🏖️ Biển',
    '⛰️ Núi',
    '🏝️ Resort',
    '🏡 Staycation',
    '✈️ Đi du lịch',
    '🏍️ Đi phượt',
    '🏕️ Đi camping',
    '🥾 Đi trekking',
    '🏖️ Đi biển',
    '⛰️ Đi leo núi',
    '🧳 Lập kế hoạch du lịch',
    '📍 Khám phá quán mới',
    '☕ Cafe',
    '🧋 Trà sữa',
    '🍵 Matcha',
    '🍸 Cocktail',
    '☕ Đi cafe',
    '🧋 Uống trà sữa',
    '🍵 Uống matcha',
    '🍸 Đi bar',
    '📍 Review quán',
    '🍳 Nấu ăn',
    '🧁 Làm bánh',
    '🍜 Ẩm thực Việt',
    '🍣 Đồ Nhật',
    '🥘 Đồ Hàn',
    '🌶️ Đồ Thái',
    '🍝 Đồ Âu',
    '🍖 BBQ',
    '🍲 Hotpot',
    '🍢 Street food',
    '🥗 Ăn chay',
    '🥑 Eat clean',
    '🍳 Tự nấu ăn',
    '🧁 Tự làm bánh',
    '🍜 Đi ăn món Việt',
    '🍣 Ăn sushi',
    '🥘 Ăn đồ Hàn',
    '🍲 Đi ăn lẩu',
    '🍢 Ăn street food',
    '🥗 Ăn healthy',
    '🏋️ Gym',
    '🧘 Yoga',
    '🤸 Pilates',
    '🏃 Chạy bộ',
    '🚴 Đạp xe',
    '🏊 Bơi lội',
    '⚽ Bóng đá',
    '🏀 Bóng rổ',
    '🏸 Cầu lông',
    '🎾 Tennis',
    '🏓 Pickleball',
    '🏐 Bóng chuyền',
    '⛳ Golf',
    '🛼 Trượt patin',
    '🛹 Skateboard',
    '🧗 Leo núi',
    '🥋 Võ thuật',
    '🥊 Boxing',
    '💃 Dance',
    '🕺 Zumba',
    '🏋️ Tập gym',
    '🧘 Tập yoga',
    '🤸 Tập pilates',
    '🚴 Đạp xe cuối tuần',
    '🏊 Đi bơi',
    '⚽ Chơi bóng đá',
    '🏀 Chơi bóng rổ',
    '🏸 Chơi cầu lông',
    '🎾 Chơi tennis',
    '🏐 Chơi bóng chuyền',
    '🛼 Trượt patin',
    '🛹 Trượt skateboard',
    '🥊 Tập boxing',
    '💃 Nhảy dance',
    '🎮 Esports',
    '📱 Game mobile',
    '🖥️ Game PC',
    '🎮 Console game',
    '🎲 Board game',
    '♟️ Cờ vua',
    '🐘 Cờ tướng',
    '🐺 Ma sói',
    '🎮 Chơi game',
    '📱 Chơi game mobile',
    '🖥️ Chơi game PC',
    '🎲 Chơi board game',
    '♟️ Chơi cờ vua',
    '🐺 Chơi ma sói',
    '🎮 Xem esports',
    '💻 Công nghệ',
    '👨‍💻 Lập trình',
    '🤖 AI',
    '📊 Data',
    '🔐 Cybersecurity',
    '📱 Gadget',
    '👨‍💻 Viết code',
    '🤖 Dùng AI',
    '📊 Phân tích data',
    '🔐 Học bảo mật',
    '📱 Vọc gadget',
    '🧪 Test app mới',
    '🚀 Startup',
    '💼 Kinh doanh',
    '📣 Marketing',
    '🎥 Content creator',
    '💰 Tài chính cá nhân',
    '📈 Đầu tư',
    '🪙 Crypto',
    '🏘️ Bất động sản',
    '🚀 Làm startup',
    '💼 Làm kinh doanh',
    '📣 Làm marketing',
    '🎥 Sáng tạo nội dung',
    '💰 Quản lý tài chính',
    '📈 Đầu tư dài hạn',
    '🪙 Theo dõi crypto',
    '🔬 Khoa học',
    '🔭 Thiên văn',
    '🏛️ Lịch sử',
    '🗺️ Địa lý',
    '🧠 Tâm lý học',
    '🤔 Triết học',
    '🔬 Tìm hiểu khoa học',
    '🔭 Ngắm sao',
    '🏛️ Tìm hiểu lịch sử',
    '🧠 Đọc tâm lý học',
    '🤔 Tranh luận triết học',
    '🌐 Học ngoại ngữ',
    '🇬🇧 Tiếng Anh',
    '🇯🇵 Tiếng Nhật',
    '🇰🇷 Tiếng Hàn',
    '🇨🇳 Tiếng Trung',
    '🌐 Học ngoại ngữ',
    '🇬🇧 Học tiếng Anh',
    '🇯🇵 Học tiếng Nhật',
    '🇰🇷 Học tiếng Hàn',
    '🇨🇳 Học tiếng Trung',
    '🗣️ Luyện speaking',
    '🤝 Tình nguyện',
    '🌍 Môi trường',
    '🫶 Hoạt động xã hội',
    '🤝 Đi tình nguyện',
    '🌍 Dọn rác môi trường',
    '🫶 Tham gia cộng đồng',
    '💝 Làm việc thiện',
    '🧘 Thiền',
    '🍃 Sống tối giản',
    '📓 Journaling',
    '🧘 Ngồi thiền',
    '🍃 Sống chậm',
    '📓 Viết journal',
    '🛌 Chăm sóc giấc ngủ',
    '🐾 Chăm sóc thú cưng',
    '🐱 Mèo',
    '🐶 Chó',
    '🐠 Cá cảnh',
    '🐾 Nuôi thú cưng',
    '🐶 Dắt chó đi dạo',
    '🐱 Chơi với mèo',
    '🐠 Nuôi cá cảnh',
    '🪴 Cây cảnh',
    '🌿 Làm vườn',
    '🏠 Trang trí nhà',
    '🕯️ Nến thơm',
    '🪴 Chăm cây',
    '🌿 Làm vườn',
    '🏠 Decor nhà',
    '🕯️ Đốt nến thơm',
    '🏍️ Xe máy',
    '🚗 Ô tô',
    '👟 Sneaker',
    '⌚ Đồng hồ',
    '🌸 Nước hoa',
    '🏍️ Chạy xe máy',
    '🚗 Lái xe',
    '👟 Sưu tầm sneaker',
    '⌚ Sưu tầm đồng hồ',
    '🌸 Sưu tầm nước hoa',
    '🤣 Meme',
    '🎙️ Hài độc thoại',
    '🤣 Xem meme',
    '🎙️ Xem stand-up comedy',
    '😄 Kể chuyện vui',
    '🚶 Đi dạo',
    '🌅 Ngắm hoàng hôn',
    '🌃 Chợ đêm',
    '🏛️ Bảo tàng',
    '🖼️ Triển lãm',
    '🎭 Nhạc kịch',
    '🎉 Sự kiện cộng đồng',
    '🌅 Ngắm hoàng hôn',
    '🌃 Đi chợ đêm',
    '🏛️ Đi bảo tàng',
    '🖼️ Đi triển lãm',
    '🎭 Xem nhạc kịch',
    '🎉 Đi sự kiện',
    '🧝 Cosplay',
    '🖋️ Thư pháp',
    '💐 Cắm hoa',
    '🍹 Pha chế',
    '☕ Barista',
    '🧝 Đi cosplay',
    '🖋️ Viết thư pháp',
    '💐 Học cắm hoa',
    '🍹 Tập pha chế',
    '☕ Học làm barista',
    '🧸 Sưu tầm',
    '🤖 Đồ chơi mô hình',
    '🎤 Karaoke gia đình',
    '🎧 ASMR',
    '🕵️ True crime',
    '🔮 Tarot',
    '✨ Astrology',
    '🧸 Sưu tầm mô hình',
    '🎤 Hát karaoke gia đình',
    '🎧 Nghe ASMR',
    '🕵️ Nghe true crime',
    '🔮 Xem tarot',
    '✨ Xem astrology',
  ];

  static final List<({String tag, String key})> _indexedTags = all
      .map((tag) => (tag: tag, key: fold(tag)))
      .toList(growable: false);

  static List<String> normalizeList(Iterable<String> tags) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final tag in tags) {
      final resolved = resolve(tag);
      if (resolved == null) continue;

      final key = fold(resolved);
      if (seen.add(key)) {
        normalized.add(resolved);
      }
    }

    return normalized.take(maxSelected).toList(growable: false);
  }

  static List<String> search(
    String query, {
    Iterable<String> excluding = const [],
  }) {
    final normalizedQuery = fold(query);
    if (normalizedQuery.isEmpty) return const [];

    final excluded = excluding.map(fold).toSet();

    return _indexedTags
        .where((item) => !excluded.contains(item.key))
        .where((item) => item.key.contains(normalizedQuery))
        .map((item) => item.tag)
        .take(18)
        .toList(growable: false);
  }

  static String? resolve(String input) {
    final key = fold(input);
    if (key.isEmpty) return null;

    for (final item in _indexedTags) {
      if (item.key == key) return item.tag;
    }

    return null;
  }

  static String fold(String input) {
    final lower = _stripLeadingIcon(input).trim().toLowerCase();
    if (lower.isEmpty) return '';

    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    final buffer = StringBuffer();
    for (final codePoint in lower.runes) {
      final char = String.fromCharCode(codePoint);
      final index = from.indexOf(char);
      buffer.write(index == -1 ? char : to[index]);
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _stripLeadingIcon(String input) {
    return input.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');
  }
}
