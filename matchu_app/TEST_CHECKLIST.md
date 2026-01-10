# ✅ Checklist Test E2EE & Profile Completion

## 🎯 Test Case 1: Profile Completion Check

### Mục đích: 
Đảm bảo user có đầy đủ thông tin không bị đẩy vào complete-profile

### Các bước:
1. **Đảm bảo user đã có profile đầy đủ** trong Firestore:
   - Vào Firebase Console → `users/{uid}`
   - Kiểm tra có các fields: `fullname`, `nickname`, `birthday`, `gender`
   - Các fields này phải có giá trị (không null, không rỗng)

2. **Trên thiết bị mới** (hoặc clear app data):
   - Gỡ app hoặc clear app data
   - Cài lại app và đăng nhập với user đã có profile
   
3. **Kiểm tra kết quả**:
   - ✅ App phải vào `/main` (không vào `/complete-profile`)
   - ✅ Không có lỗi trong console

### Nếu fail:
- Kiểm tra các field trong Firestore có đầy đủ không
- Kiểm tra console logs xem có lỗi gì

---

## 🎯 Test Case 2: Thiết bị mới tạo Identity Key

### Mục đích:
Đảm bảo thiết bị mới tự động tạo identity key khi login

### Các bước:
1. **Trên thiết bị mới**: Đăng nhập user bất kỳ
2. **Kiểm tra Firebase Console**:
   - Vào `users/{uid}/devices`
   - Phải có document với `deviceId` mới
   - Document có: `publicKey`, `algorithm: "RSA-2048"`, `createdAt`

### Kết quả mong đợi:
- ✅ Identity key được tạo tự động
- ✅ Public key được lưu vào Firestore
- ✅ Không có lỗi

---

## 🎯 Test Case 3: Session Key Đa Thiết Bị (Cơ Bản)

### Setup:
- **User A**: 2 thiết bị (A1, A2)
- **User B**: 1 thiết bị (B1)

### Các bước:

#### 3.1 Tạo Room và Gửi Tin Nhắn
1. **Trên A1**: Mở chat với User B (tạo room mới)
2. **Kiểm tra Firestore**:
   - Vào `chatRooms/{roomId}/sessionKeys`
   - Phải có 3 documents (A1, A2, B1)
   - Mỗi document có: `userId`, `encryptedKey`, `createdAt`

3. **Trên A1**: Gửi tin nhắn "Test từ A1"
4. **Trên B1**: Kiểm tra tin nhắn hiển thị "Test từ A1" (plaintext, không phải ciphertext)

#### 3.2 Test Thiết Bị Thứ 2
1. **Trên A2**: Mở room chat với User B
2. **Kiểm tra**:
   - ✅ A2 thấy tin nhắn "Test từ A1"
   - ✅ Tin nhắn hiển thị plaintext (không phải ciphertext)
   - ✅ A2 có thể gửi tin nhắn mới

3. **Trên B1**: Kiểm tra nhận được tin nhắn từ A2

### Kết quả mong đợi:
- ✅ Session key được phân phối cho tất cả thiết bị
- ✅ Tất cả tin nhắn decrypt thành công
- ✅ Không có lỗi "InvalidCipherTextException"

---

## 🎯 Test Case 4: Thiết Bị Mới Join Room Đã Có Tin Nhắn

### Setup:
- Room đã có tin nhắn từ trước
- Thiết bị mới login sau

### Các bước:
1. **Trên A1 và B1**: Đã chat với nhau (có vài tin nhắn)
2. **Trên A2** (thiết bị mới):
   - Đăng nhập User A
   - Mở room chat với User B
   
3. **Kiểm tra**:
   - ✅ A2 thấy TẤT CẢ tin nhắn cũ
   - ✅ Tất cả tin nhắn decrypt thành công
   - ✅ A2 có thể gửi tin nhắn mới
   - ✅ A1 và B1 nhận được tin nhắn từ A2

### Kết quả mong đợi:
- ✅ Thiết bị mới nhận được session key
- ✅ Tin nhắn cũ vẫn decrypt được (vì không rotate key)
- ✅ Không có lỗi

---

## 🎯 Test Case 5: Test Nhanh (5 phút)

### Quy trình nhanh:
1. **User A (2 thiết bị) + User B (1 thiết bị)**
2. **A1**: Tạo room, gửi tin nhắn
3. **B1**: Kiểm tra nhận được tin nhắn (decrypt OK)
4. **A2**: Mở room, kiểm tra thấy tin nhắn cũ (decrypt OK)
5. **A2**: Gửi tin nhắn mới
6. **B1**: Kiểm tra nhận được tin từ A2

### Checklist nhanh:
- [ ] Session keys có trong Firestore cho tất cả thiết bị
- [ ] Tin nhắn hiển thị plaintext (không phải ciphertext)
- [ ] Không có lỗi trong console
- [ ] Thiết bị mới có thể decrypt tin nhắn cũ
- [ ] Tất cả thiết bị sync realtime

---

## 🐛 Nếu Gặp Lỗi

### Lỗi "InvalidCipherTextException":
1. **Kiểm tra session key**:
   - Vào Firestore → `chatRooms/{roomId}/sessionKeys`
   - Đảm bảo có document cho thiết bị đang lỗi
   
2. **Xóa và tạo lại**:
   - Xóa session keys cũ trong Firestore
   - Clear app data trên thiết bị
   - Login lại và tạo room mới

### Lỗi "PERMISSION_DENIED":
- Deploy lại Firestore rules (đã cung cấp trước đó)

### Vẫn vào complete-profile dù có đủ thông tin:
1. Kiểm tra Firestore: `users/{uid}` có đủ fields:
   - `fullname` (string, không rỗng)
   - `nickname` (string, không rỗng)
   - `birthday` (string, không null)
   - `gender` (string, không rỗng)
2. Nếu thiếu field nào → thêm vào Firestore hoặc update profile lại

---

## 📝 Ghi Chú Quan Trọng

1. **Session Key không rotate**: Mỗi room chỉ có 1 session key duy nhất
2. **Tin nhắn cũ luôn decrypt được**: Vì không rotate key
3. **Thiết bị mới tự động tạo identity key**: Khi login lần đầu
4. **Profile check dựa vào fields**: Không chỉ dựa vào flag `isProfileCompleted`

---

## ✅ Kết Quả Thành Công

Nếu tất cả test case pass:
- ✅ E2EE hoạt động đúng trên nhiều thiết bị
- ✅ Tin nhắn decrypt thành công
- ✅ Profile completion check hoạt động đúng
- ✅ Thiết bị mới tự động setup đúng


