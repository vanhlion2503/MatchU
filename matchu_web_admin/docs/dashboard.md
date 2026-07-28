# Dashboard thống kê

Dashboard admin đọc dữ liệu từ các collection nghiệp vụ hiện có và không thay
đổi luồng ghi dữ liệu của ứng dụng mobile.

## Phạm vi dữ liệu

- Khoảng thời gian hỗ trợ: 7, 30 và 90 ngày.
- Múi giờ báo cáo: `Asia/Bangkok`.
- Dữ liệu kỳ trước được tải cùng lúc để tính tỷ lệ tăng/giảm.
- Mỗi nguồn dữ liệu lịch sử được giới hạn 5.000 document cho một lần tổng hợp.
- Kết quả được cache trong tiến trình Node.js tối đa 60 giây.

Dashboard tổng hợp:

- người dùng mới và người dùng có `lastActiveAt` trong kỳ;
- bài viết mới và tổng tương tác hiện tại của các bài viết đó;
- phòng `tempChats`, mutual like và chuyển đổi sang chat dài hạn;
- báo cáo bài viết, hồ sơ và matching;
- hàng đợi kiểm duyệt và case đang mở;
- giao dịch Gem;
- nhật ký quản trị gần đây.

## Quy ước số liệu

- “Hoạt động trong kỳ” là số người dùng có lần hoạt động gần nhất nằm trong kỳ,
  không phải DAU lịch sử.
- “Phiên ghép thành công” là số phòng `tempChats` được tạo trong kỳ. Collection
  matching queue hiện bị ghi đè theo UID nên không dùng để suy ra tổng lượt tìm.
- “Tương tác nội dung” là tổng counter hiện tại trên các bài viết được tạo trong
  kỳ, không phải số event tương tác phát sinh riêng trong kỳ.
- “Báo cáo mới” bao gồm `postReports`, `userProfileReports` và
  `userMatchingReports`.
- “Nội dung cần xử lý” gồm `pending_moderation` và `review_required`.
- “Gem economy” không phải doanh thu tiền tệ.

Khi một nguồn không truy vấn được hoặc chạm giới hạn an toàn, dashboard vẫn
render các phần còn lại và hiển thị cảnh báo dữ liệu một phần.

## Mở rộng khi lưu lượng tăng

Khi một nguồn thường xuyên đạt giới hạn quét, nên chuyển sang materialized
metrics theo ngày/giờ bằng Cloud Functions và giữ service hiện tại làm fallback.
Trigger tổng hợp cần idempotent và có job đối soát định kỳ trước khi loại bỏ
fallback đọc dữ liệu nguồn.
