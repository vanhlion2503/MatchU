# Quản lý chiến dịch thông báo

Module `/notifications` hỗ trợ bản nháp, gửi ngay, hẹn giờ, gửi toàn hệ thống,
gửi theo nhóm và gửi cho một người dùng. Nội dung được phân phối qua push FCM,
inbox ứng dụng hoặc cả hai.

Cloud Functions xử lý phân trang người nhận, chia lô, retry lỗi tạm thời và tổng
hợp số thiết bị được FCM chấp nhận/thất bại.

## Phân quyền

- `notifications.read`
- `notifications.create`
- `notifications.publish`
- `notifications.cancel`
- `notifications.retry`

`super_admin` luôn có toàn quyền.

## Triển khai

Deploy đồng thời Functions, Firestore Rules và indexes:

```bash
cd matchu_app
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Ứng dụng mobile phải được phát hành với payload `admin_campaign` và metadata
thiết bị `appVersion`, `buildNumber`, `locale` trước khi sử dụng bộ lọc phiên bản.

“FCM chấp nhận” chỉ có nghĩa Firebase đã nhận yêu cầu gửi; không đảm bảo người
dùng đã nhìn thấy hoặc đọc thông báo.
