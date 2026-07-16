import 'package:get/get.dart';

abstract final class NearbyTranslationKeys {
  static const error = 'nearby.error';
}

const nearbyVietnameseTranslations = <String, String>{
  NearbyTranslationKeys.error: 'Lỗi',
  'Tắt hiển thị vị trí': 'Tắt hiển thị vị trí',
  'Bật hiển thị vị trí': 'Bật hiển thị vị trí',
  'Bạn đang tắt hiển thị vị trí': 'Bạn đang tắt hiển thị vị trí',
  'Bật vị trí để xem những người ở quanh bạn':
      'Bật vị trí để xem những người ở quanh bạn',
  'Bật vị trí': 'Bật vị trí',
  'Không lấy được vị trí': 'Không lấy được vị trí',
  'Bật GPS': 'Bật GPS',
  'Không tìm thấy ai phù hợp': 'Không tìm thấy ai phù hợp',
  'Hãy thử tăng khoảng cách để tìm kiếm':
      'Hãy thử tăng khoảng cách để tìm kiếm',
  'Không cập nhật được trạng thái hiển thị vị trí.':
      'Không cập nhật được trạng thái hiển thị vị trí.',
  'Phiên đăng nhập chưa sẵn sàng. Vui lòng thử lại.':
      'Phiên đăng nhập chưa sẵn sàng. Vui lòng thử lại.',
  'Không tải được danh sách quanh bạn. Vui lòng thử lại.':
      'Không tải được danh sách quanh bạn. Vui lòng thử lại.',
  'Không tải được danh sách quanh bạn.': 'Không tải được danh sách quanh bạn.',
  'GPS đang tắt. Hãy bật dịch vụ vị trí rồi thử lại.':
      'GPS đang tắt. Hãy bật dịch vụ vị trí rồi thử lại.',
  'Không lấy được vị trí hiện tại. Hãy thử đứng ở nơi thoáng hơn rồi làm mới.':
      'Không lấy được vị trí hiện tại. Hãy thử đứng ở nơi thoáng hơn rồi làm mới.',
  'Ứng dụng chưa cấu hình quyền vị trí cho nền tảng này.':
      'Ứng dụng chưa cấu hình quyền vị trí cho nền tảng này.',
  'Không thể lấy vị trí lúc này. Vui lòng thử lại sau.':
      'Không thể lấy vị trí lúc này. Vui lòng thử lại sau.',
  'Bạn chưa cấp quyền vị trí cho MatchU.':
      'Bạn chưa cấp quyền vị trí cho MatchU.',
  'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở cài đặt ứng dụng để cấp lại quyền.':
      'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở cài đặt ứng dụng để cấp lại quyền.',
  'Đang xin quyền vị trí. Vui lòng chờ một chút rồi thử lại.':
      'Đang xin quyền vị trí. Vui lòng chờ một chút rồi thử lại.',
};

const nearbyEnglishTranslations = <String, String>{
  NearbyTranslationKeys.error: 'Error',
  'Tắt hiển thị vị trí': 'Hide my location',
  'Bật hiển thị vị trí': 'Show my location',
  'Bạn đang tắt hiển thị vị trí': 'Your location is hidden',
  'Bật vị trí để xem những người ở quanh bạn':
      'Show your location to see people nearby',
  'Bật vị trí': 'Show location',
  'Không lấy được vị trí': 'Unable to get your location',
  'Bật GPS': 'Turn on GPS',
  'Không tìm thấy ai phù hợp': 'No matching people found',
  'Hãy thử tăng khoảng cách để tìm kiếm': 'Try increasing the search radius',
  'Không cập nhật được trạng thái hiển thị vị trí.':
      'Unable to update your location visibility.',
  'Phiên đăng nhập chưa sẵn sàng. Vui lòng thử lại.':
      'Your login session is not ready. Please try again.',
  'Không tải được danh sách quanh bạn. Vui lòng thử lại.':
      'Unable to load people nearby. Please try again.',
  'Không tải được danh sách quanh bạn.': 'Unable to load people nearby.',
  'GPS đang tắt. Hãy bật dịch vụ vị trí rồi thử lại.':
      'Location services are off. Turn them on and try again.',
  'Không lấy được vị trí hiện tại. Hãy thử đứng ở nơi thoáng hơn rồi làm mới.':
      'Unable to get your current location. Move to an open area and refresh.',
  'Ứng dụng chưa cấu hình quyền vị trí cho nền tảng này.':
      'Location permission is not configured for this platform.',
  'Không thể lấy vị trí lúc này. Vui lòng thử lại sau.':
      'Your location is currently unavailable. Please try again later.',
  'Bạn chưa cấp quyền vị trí cho MatchU.':
      'You have not granted MatchU location access.',
  'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở cài đặt ứng dụng để cấp lại quyền.':
      'Location access was permanently denied. Open app settings to grant access.',
  'Đang xin quyền vị trí. Vui lòng chờ một chút rồi thử lại.':
      'A location permission request is in progress. Wait a moment and try again.',
};

String nearbyTr(String source) {
  final exact = source.tr;
  if (exact != source || Get.locale?.languageCode != 'en') return exact;

  final meters = RegExp(r'^Cách (\d+)m$').firstMatch(source);
  if (meters != null) return '${meters[1]} m away';

  final kilometers = RegExp(r'^Cách ([\d.]+)km$').firstMatch(source);
  if (kilometers != null) return '${kilometers[1]} km away';

  final people = RegExp(r'^Tìm thấy (\d+) người gần bạn$').firstMatch(source);
  if (people != null) return 'Found ${people[1]} people nearby';

  return source;
}
