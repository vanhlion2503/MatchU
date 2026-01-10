# Test Plan - E2EE Multi-Device

## 📋 Test Scenarios

### ✅ Scenario 1: Tạo Room Mới (Leader tạo key)
**Mục đích**: Test leader logic và tạo key lần đầu

**Steps**:
1. User A (uid nhỏ nhất - leader) vào room mới
2. Gửi tin nhắn "Hello"
3. Kiểm tra:
   - ✅ Session key được tạo trong Firestore (`chatRooms/{roomId}/sessionKeys/`)
   - ✅ Tin nhắn được encrypt và lưu
   - ✅ User A decrypt được tin nhắn của mình

**Expected**:
- Log: `🔒 Leader tạo session key cho room {roomId}`
- Session key document được tạo cho device của User A
- Tin nhắn hiển thị "Hello" (đã decrypt)

---

### ✅ Scenario 2: User Thứ 2 Join Room (Non-Leader)
**Mục đích**: Test non-leader không tạo key mới

**Steps**:
1. User B vào room đã có (User A đã tạo key)
2. Kiểm tra logs:
   - ✅ `🔒 Room {roomId} đã có session keys, không tạo key mới`
   - ✅ `🔒 Không phải leader ({leaderUid}), không tạo key mới` (nếu User B không phải leader)
3. User B gửi tin nhắn "Hi"
4. Kiểm tra:
   - ✅ User B nhận được session key từ Firestore
   - ✅ Tin nhắn của User B được encrypt
   - ✅ User A decrypt được tin nhắn của User B

**Expected**:
- User B không tạo key mới
- User B receive key từ Firestore
- Cả 2 users decrypt được tin nhắn của nhau

---

### ✅ Scenario 3: Device Mới Login (Realtime Listener)
**Mục đích**: Test device mới nhận key qua realtime listener

**Steps**:
1. User A có 1 device (Device 1) đã trong room và có session key
2. User A login trên Device 2 (thiết bị hoàn toàn mới)
3. Mở room đã có
4. Kiểm tra logs:
   - ✅ `🔒 Room {roomId} đã có session keys, không tạo key mới`
   - ✅ `🔒 Room đã có keys, listen realtime để nhận key...`
   - ✅ `🔒 Session key document created/updated for device {deviceId}`
   - ✅ `🔒 Đã nhận session key từ realtime listener`
5. Device 2 gửi tin nhắn "From Device 2"
6. Kiểm tra:
   - ✅ Device 2 decrypt được tất cả tin nhắn cũ
   - ✅ Device 1 decrypt được tin nhắn từ Device 2
   - ✅ Device 2 decrypt được tin nhắn từ Device 1

**Expected**:
- Device 2 nhận key tự động qua realtime listener
- Không bị "đứng" ở "🔒 Room đã có keys, đợi thiết bị khác phân phối key..."
- Decrypt được tin nhắn cũ và mới

---

### ✅ Scenario 4: Race Condition (2 Devices cùng vào room mới)
**Mục đích**: Test chỉ leader tạo key, không có duplicate keys

**Steps**:
1. User A (uid nhỏ nhất) và User B cùng vào room mới (gần như cùng lúc)
2. Kiểm tra logs:
   - ✅ User A (leader): `🔒 Leader tạo session key cho room {roomId}`
   - ✅ User B (non-leader): `🔒 Không phải leader ({leaderUid}), không tạo key mới`
3. Kiểm tra Firestore:
   - ✅ Chỉ có 1 session key được tạo (của leader)
   - ✅ User B receive key từ leader
4. Cả 2 users gửi tin nhắn
5. Kiểm tra:
   - ✅ Cả 2 users decrypt được tin nhắn của nhau

**Expected**:
- Chỉ leader tạo key
- Không có duplicate keys
- Cả 2 users decrypt được tin nhắn

---

### ✅ Scenario 5: Multi-Device (3+ Devices)
**Mục đích**: Test phân phối key cho nhiều devices

**Steps**:
1. User A có 2 devices (Device 1, Device 2)
2. User B có 1 device (Device 3)
3. Tạo room với User A (Device 1) và User B (Device 3)
4. Kiểm tra Firestore:
   - ✅ Session keys được tạo cho: Device 1, Device 2, Device 3
   - ✅ Log: `🔒 Distribution summary: X distributed, Y skipped`
5. User A login trên Device 2
6. Mở room → Device 2 nhận key
7. Gửi tin nhắn từ cả 3 devices
8. Kiểm tra:
   - ✅ Tất cả devices decrypt được tin nhắn

**Expected**:
- Key được phân phối cho tất cả devices
- Tất cả devices decrypt được tin nhắn

---

### ✅ Scenario 6: App Restart (Key đã có trong Storage)
**Mục đích**: Test notify system khi app restart

**Steps**:
1. User A trong room, đã có session key
2. Close app
3. Reopen app
4. Vào lại room
5. Kiểm tra:
   - ✅ Tin nhắn decrypt ngay lập tức (không hiển thị "🔐 Đang thiết lập mã hóa…")
   - ✅ Log: `🔒 Distribution summary: 0 distributed, X skipped`

**Expected**:
- Key được load từ storage
- Notify listeners được gọi
- Decrypt cache được clear và reload

---

### ✅ Scenario 7: Timeout (Không có device nào online)
**Mục đích**: Test timeout khi không có device nào phân phối key

**Steps**:
1. Room có session keys nhưng tất cả devices đã offline
2. Device mới login và vào room
3. Kiểm tra logs:
   - ✅ `🔒 Room đã có keys, listen realtime để nhận key...`
   - ✅ Sau 15s: `⏰ Timeout: Không nhận được session key sau 15 giây`
4. Khi device khác online → device mới nhận key
5. Kiểm tra:
   - ✅ Device mới decrypt được tin nhắn

**Expected**:
- Timeout sau 15 giây
- Khi device khác online, device mới vẫn nhận được key

---

## 🔍 Kiểm Tra Logs Quan Trọng

### ✅ Logs cần có:
- `🔒 Leader tạo session key cho room {roomId}` - Leader tạo key
- `🔒 Không phải leader ({leaderUid}), không tạo key mới` - Non-leader không tạo key
- `🔒 Room {roomId} đã có session keys, không tạo key mới` - Room đã có keys
- `🔒 Room đã có keys, listen realtime để nhận key...` - Device mới listen
- `🔒 Session key document created/updated for device {deviceId}` - Key được phân phối
- `🔒 Đã nhận session key từ realtime listener` - Key được nhận
- `🔒 Distributed session key to device {deviceId} (user: {userId})` - Key được phân phối
- `🔒 Distribution summary: X distributed, Y skipped` - Tổng kết phân phối

### ❌ Logs lỗi cần tránh:
- `❌ RSA decrypt failed` - Lỗi decrypt RSA
- `❌ Invalid session key length` - Key length sai
- `❌ Decrypt failed` - Lỗi decrypt message
- `❌ sessionKey write error` - Lỗi write Firestore
- `PERMISSION_DENIED` - Lỗi Firestore rules

---

## 🧪 Test Checklist

- [ ] Scenario 1: Leader tạo key
- [ ] Scenario 2: Non-leader join room
- [ ] Scenario 3: Device mới login (realtime listener)
- [ ] Scenario 4: Race condition (2 devices cùng vào)
- [ ] Scenario 5: Multi-device (3+ devices)
- [ ] Scenario 6: App restart
- [ ] Scenario 7: Timeout

---

## 📝 Notes

1. **Firestore Rules**: Đảm bảo rules đã được deploy (không có field `epoch`)
2. **Clean Test**: Xóa session keys cũ trong Firestore trước khi test scenarios mới
3. **Device IDs**: Mỗi device có deviceId riêng, kiểm tra trong `users/{uid}/devices/`
4. **Logs**: Bật verbose logging để theo dõi flow
5. **Network**: Test cả online và offline scenarios

---

## 🐛 Debug Tips

1. **Không decrypt được**: Kiểm tra session key length (phải = 32 bytes)
2. **Permission denied**: Kiểm tra Firestore rules
3. **Key không được phân phối**: Kiểm tra `ensureDistributedToAllDevices()` có được gọi không
4. **Realtime listener không hoạt động**: Kiểm tra deviceId và roomId
5. **Race condition**: Kiểm tra leader logic (uid nhỏ nhất)

