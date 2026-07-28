# Nhật ký quản trị

## Mục tiêu

Module cung cấp một màn hình chỉ đọc tại `/admin-logs` để truy vết các lần đăng nhập và thao tác
quản trị quan trọng. Chỉ `super_admin` hoặc admin có permission `audit_logs.read` được truy cập.
Permission được kiểm tra tại server; việc ẩn menu chỉ là lớp giao diện bổ sung.

## Luồng dữ liệu

Các controller hiện có gọi `writeAuditLog` sau khi hoàn tất thao tác:

- Xác thực: đăng nhập, đăng nhập bị từ chối, đăng xuất.
- Người dùng: cảnh báo, hạn chế, tạm khóa, cấm, khôi phục, thu hồi phiên, đặt lại xác minh,
  đặt lại mật khẩu và điều chỉnh số dư/điểm uy tín.
- Bài viết: duyệt, từ chối, xem xét, bác báo cáo, khôi phục và xóa vĩnh viễn.
- Báo cáo: nhận xử lý, bắt đầu xem xét, kết luận, bác và mở lại.
- Thông báo: tạo/cập nhật nháp, phát hành, hủy và thử lại các lô lỗi.

Mỗi sự kiện mới được ghi vào `adminAuditLogs` với schema phiên bản 2:

```json
{
  "eventVersion": 2,
  "adminId": "Firebase UID",
  "adminEmail": "admin@matchu.app",
  "adminDisplayName": "Tên hiển thị tại thời điểm thao tác",
  "adminRole": "super_admin",
  "action": "USER_SUSPEND",
  "category": "users",
  "result": "success",
  "targetType": "user",
  "targetId": "Firebase UID của đối tượng",
  "metadata": {
    "reason": "Lý do",
    "before": {},
    "after": {}
  },
  "ipAddress": "IP do Express xác định qua trusted proxy",
  "userAgent": "User-Agent",
  "requestId": "UUID do server tạo",
  "createdAt": "Firestore server timestamp"
}
```

Log phiên bản cũ chưa có `category`, `result`, tên/role admin hoặc request ID vẫn hiển thị được.
Service suy luận phân hệ và kết quả từ `action` khi đọc.

## Tra cứu và hiệu năng

Firestore sắp xếp theo `createdAt` giảm dần và áp dụng khoảng ngày trước. Các bộ lọc cần tương thích
log cũ (từ khóa, admin, phân hệ, kết quả và loại đối tượng) được kiểm tra trong các lô ở server.
Mỗi request quét tối đa 1.000 bản ghi và trả 25/50/100 sự kiện. Khi chạm giới hạn, giao diện yêu
cầu thu hẹp khoảng ngày. Cách này không cần composite index mới và không làm mất log cũ.

Thống kê đầu trang gồm tổng số sự kiện và các chỉ số 24 giờ. Phần thống kê 24 giờ đọc tối đa
1.000 sự kiện và hiển thị dấu `+` nếu bị rút gọn.

## An toàn dữ liệu

- Không có route sửa hoặc xóa nhật ký.
- Metadata được làm sạch cả khi ghi và khi đọc.
- Các khóa chứa token, cookie, password, passcode, secret, credential, private key hoặc session
  bị thay bằng `[ĐÃ ẨN]`.
- Chuỗi, mảng, số khóa và độ sâu metadata đều có giới hạn để tránh tài liệu quá lớn.
- ID đối tượng được URL-encode trước khi tạo liên kết chi tiết.
- Request ID do server sinh, không tin giá trị do client gửi.

`writeAuditLog` vẫn là telemetry best-effort: lỗi ghi nhật ký không làm đảo ngược thao tác nghiệp vụ
đã thành công. Nếu hệ thống cần mức tuân thủ bắt buộc, giai đoạn tiếp theo nên dùng transactional
outbox cho các thao tác Firestore và hàng đợi bền vững cho thao tác Firebase Authentication.

## Vận hành đề xuất

- Không cấp `audit_logs.read` cho vai trò không cần xem IP và lịch sử quản trị.
- Theo dõi cảnh báo ghi log ở server.
- Chốt chính sách lưu trữ với yêu cầu pháp lý trước khi cấu hình TTL; không tự động xóa khi chưa có
  bản lưu trữ.
- Có thể bổ sung export CSV theo quyền riêng và lưu bản export vào vùng lưu trữ có thời hạn trong
  giai đoạn sau. Module hiện tại chủ động không xuất dữ liệu nhạy cảm ra file.
