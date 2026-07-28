# MatchU Web Admin

Nền tảng quản trị MatchU dùng Node.js, Express, EJS và Firebase Admin SDK. Mật khẩu được Firebase Authentication kiểm tra ở trình duyệt; server chỉ nhận Firebase ID Token một lần để tạo session cookie HttpOnly.

## Yêu cầu và chạy dự án

- Node.js 18+ (khuyến nghị Node.js LTS).
- Một Firebase project có Authentication (Email/Password) và Firestore.

```bash
cd matchu_web_admin
npm install
copy .env.example .env
npm run dev
```

Production dùng `npm start`. Mở `http://localhost:3000`.

## Cấu hình `.env`

Điền các biến Firebase Admin cho môi trường local: `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, và `FIREBASE_PRIVATE_KEY`. Private key phải là một dòng có ký tự `\\n`, ví dụ `-----BEGIN PRIVATE KEY-----\\n...`.

Điền thêm `FIREBASE_WEB_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_APP_ID` cho Firebase Client SDK ở trang login. Các giá trị này là cấu hình public của Firebase Web App; tuyệt đối không truyền private key Admin xuống trình duyệt. Trong production, có thể bỏ ba biến Admin và dùng Application Default Credentials do môi trường deploy cung cấp.

Không commit `.env` hoặc JSON service account.

## Tạo admin đầu tiên

1. Trong Firebase Console, bật **Email/Password** và tạo tài khoản admin.
2. Lấy UID tại Firebase Authentication → Users (hoặc qua Firebase CLI/Admin SDK).
3. Trong Firestore, tạo document `adminProfiles/{UID}` với nội dung sau. Trường timestamp có thể để Firestore tạo hoặc bổ sung sau.

```json
{
  "uid": "FIREBASE_UID",
  "email": "admin@example.com",
  "displayName": "Super Admin",
  "avatarUrl": null,
  "role": "super_admin",
  "permissions": [],
  "status": "active"
}
```

`super_admin` có toàn quyền dù mảng `permissions` rỗng. Những role hợp lệ khác: `moderator`, `support`, `analyst`; chúng chỉ được cấp các màn hình có permission tương ứng. Tài khoản chỉ tồn tại trong Firebase Authentication sẽ không thể đăng nhập nếu không có profile active.

## Routes

| Method | Route | Mục đích |
| --- | --- | --- |
| GET | `/` | Điều hướng login/dashboard |
| GET | `/login` | Trang đăng nhập khách |
| POST | `/auth/session` | Xác minh token và tạo cookie |
| POST | `/auth/logout` | Xóa cookie và ghi audit log |
| GET | `/dashboard` | Tổng quan, cần `dashboard.read` |
| GET | `/users` | Danh sách, tìm kiếm và lọc tài khoản, cần `users.read` |
| GET | `/users/:uid` | Hồ sơ quản trị 360° của người dùng, cần `users.read` |
| POST | `/users/:uid/actions` | Thực hiện thao tác quản trị theo permission của từng hành động |
| GET | `/posts` | Danh sách, tìm kiếm và lọc bài viết, cần `posts.read` |
| GET | `/posts/moderation` | Chuyển hướng tương thích sang `/reports` |
| GET | `/posts/:postId` | Chi tiết bài, media, tín hiệu AI, báo cáo và lịch sử xử lý |
| POST | `/posts/:postId/actions` | Duyệt, gỡ, xem xét, bác báo cáo hoặc khôi phục bài viết |
| GET | `/reports` | Hàng đợi thống nhất cho báo cáo bài viết, hồ sơ và matching |
| GET | `/reports/:caseId` | Chi tiết đối tượng, bằng chứng, phân công và lịch sử xử lý |
| POST | `/reports/:caseId/actions` | Nhận xử lý, xem xét, kết luận, bác hoặc mở lại hồ sơ |

## Quản lý tài khoản người dùng

Module người dùng gồm danh sách có tìm kiếm/lọc/phân trang, thống kê trạng thái,
chi tiết hồ sơ, Firebase Authentication, thiết bị, hoạt động, báo cáo, vi phạm
kiểm duyệt và lịch sử quản trị.

Các permission hành động:

- `users.warn`
- `users.restrict`
- `users.suspend`
- `users.ban`
- `users.restore`
- `users.sessions.revoke`
- `users.security.manage`
- `users.verification.manage`
- `users.gems.adjust`
- `users.reputation.adjust`

`super_admin` luôn có toàn quyền. Hành động thay đổi dữ liệu được bảo vệ CSRF,
kiểm tra permission ở server, tạo lịch sử tại
`users/{uid}/adminActions` và ghi `adminAuditLogs`.

## Quản lý và kiểm duyệt bài viết

Module bài viết đọc trực tiếp collection `posts` và `postReports` hiện hữu, không thay đổi luồng
đăng bài trên ứng dụng mobile. Các quyết định thủ công dùng trạng thái kiểm duyệt tương thích với
mobile và bổ sung metadata tại `posts/{postId}.adminModeration`,
`moderationCases/{postId}` cùng subcollection `actions`.

Các permission:

- `posts.read`
- `posts.moderate`
- `posts.restore` (tùy chọn; `posts.moderate` vẫn được phép khôi phục)
- `posts.delete` (xóa vĩnh viễn bài viết đã xóa mềm; nên chỉ cấp cho quản trị viên cấp cao)
- `reports.read`
- `reports.manage` (nhận xử lý và chuyển sang xem xét)
- `reports.resolve` (kết luận, bác hoặc mở lại hồ sơ)

Admin SDK bỏ qua Firestore Rules nên mọi thao tác ghi đều được kiểm tra Joi, permission, CSRF và
thực hiện phía server. Báo cáo gốc được giữ nguyên trong luồng kiểm duyệt thông thường; thao tác
xóa vĩnh viễn sẽ dọn bài viết và dữ liệu liên quan sau khi xác nhận chính xác Post ID.

Tìm kiếm Admin dùng collection `adminPostSearchIndex`. Sau khi deploy trigger và Firestore index,
chạy backfill một lần cho các bài viết hiện có:

```bash
cd matchu_web_admin
npm run backfill:post-search-index
```

Chạy kiểm tra trước khi phát hành:

```bash
npm run check
```

## Quản lý báo cáo hợp nhất

Mobile tiếp tục ghi vào bốn collection hiện hữu: `postReports`, `commentReports`,
`userProfileReports` và `userMatchingReports`. Không có thay đổi đối với luồng gửi báo cáo trên ứng dụng.

Bốn Cloud Functions tạo projection vận hành tại `reportCases/{caseId}` và lưu bản
chuẩn hóa của từng báo cáo trong subcollection `reports`. Báo cáo mới cho một hồ sơ đã
kết thúc sẽ tự mở lại hồ sơ. Quyết định kiểm duyệt bài viết hoặc xử lý tài khoản được
thực hiện từ liên kết trong trang chi tiết báo cáo sẽ đồng bộ kết luận về report case.

Trước khi mở module trên production:

```bash
cd matchu_app
firebase deploy --only firestore:rules,firestore:indexes,functions
cd functions
npm run backfill:report-cases
```

Backfill có tính idempotent: chạy lại không làm tăng trùng số báo cáo vì mỗi projection
dùng khóa cố định theo collection nguồn và Report ID.

## Cấu trúc

`routes → middlewares → controllers → services → Firebase/Firestore`. `views/layouts` chứa hai layout tái sử dụng; header/sidebar/footer là partial. Các số liệu dashboard, biểu đồ, hoạt động gần đây và menu chưa có route là placeholder có chủ đích để bổ sung module sau.

## Bảo mật

Project dùng Helmet, rate limit toàn cục và nghiêm ngặt cho login, body limit, cookie HttpOnly/SameSite (Secure ở production), kiểm tra Firebase session cookie bị revoke, và kiểm tra role/permission ở server. Không lưu ID token tại Local Storage. TODO: khi thêm form thay đổi dữ liệu, tích hợp CSRF token (ví dụ `csurf` hoặc double-submit cookie) trước khi mở các route đó.
