bool isUserOnline(DateTime? lastActiveAt){
  if(lastActiveAt == null) return false;

  return DateTime.now()
      .difference(lastActiveAt)
      .inMinutes < 2;
}

String formatLastActive(DateTime? time) {
  if (time == null) return "Không hoạt động";

  final diff = DateTime.now().difference(time);

  if (diff.inSeconds < 60) return "Vừa xong";
  if (diff.inMinutes < 60) return "${diff.inMinutes} phút trước";
  if (diff.inHours < 24) return "${diff.inHours} giờ trước";

  return "${diff.inDays} ngày trước";
}
