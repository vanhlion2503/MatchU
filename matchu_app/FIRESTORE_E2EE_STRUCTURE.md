# Cấu Trúc Firestore - E2EE Multi-Device

## 📁 Cấu Trúc Tổng Quan

```
users/
  {userId}/
    devices/
      {deviceId}/          ← Identity key (RSA public key)
        publicKey: "..."
        algorithm: "RSA-2048"
        platform: "android" | "ios"
        createdAt: Timestamp
        lastActiveAt: Timestamp

chatRooms/
  {roomId}/
    participants: ["userId1", "userId2"]
    e2ee: true
    lastMessage: "🔐 Tin nhắn được mã hóa"
    lastMessageType: "encrypted"
    lastMessageCipher: "..."
    lastMessageIv: "..."
    lastSenderId: "userId1"
    lastMessageAt: Timestamp
    createdAt: Timestamp
    ...
    
    sessionKeys/           ← Session keys (AES-256, encrypted bằng RSA)
      {deviceId1}/         ← Key cho device 1 của user 1
        userId: "userId1"
        encryptedKey: "..." (base64, RSA encrypted)
        createdAt: Timestamp
        
      {deviceId2}/         ← Key cho device 2 của user 1
        userId: "userId1"
        encryptedKey: "..." (base64, RSA encrypted)
        createdAt: Timestamp
        
      {deviceId3}/         ← Key cho device 1 của user 2
        userId: "userId2"
        encryptedKey: "..." (base64, RSA encrypted)
        createdAt: Timestamp
    
    messages/
      {messageId}/
        senderId: "userId1"
        ciphertext: "..." (base64, AES-GCM encrypted)
        iv: "..." (base64, 12 bytes)
        type: "text"
        createdAt: Timestamp
        ...
```

---

## 🔑 1. Users → Devices (Identity Keys)

**Path**: `users/{userId}/devices/{deviceId}`

### ✅ Cấu trúc đúng:

```json
{
  "publicKey": "-----BEGIN RSA PUBLIC KEY-----\nMIIBCgKCAQEAoZIT3gHzZo+bC1Ngg4mWv4bQlz/FThm6Ci+E4rbOHx4UZ+ON/\n... (full PEM)\n-----END RSA PUBLIC KEY-----",
  "algorithm": "RSA-2048",
  "platform": "android",
  "createdAt": "2026-01-10T09:15:40Z",
  "lastActiveAt": "2026-01-10T09:15:40Z"
}
```

### ❌ Cấu trúc SAI:
- ❌ Không có `privateKey` (chỉ lưu local)
- ❌ `algorithm` khác "RSA-2048"
- ❌ Thiếu `publicKey`

### 📝 Notes:
- Mỗi device có 1 document riêng
- `deviceId` là UUID (ví dụ: `08c2b85d-7743-43b2-8eb4-7fa64fd67898`)
- `publicKey` là PEM format (RSA-2048)
- `privateKey` KHÔNG lưu trong Firestore (chỉ lưu local bằng FlutterSecureStorage)

---

## 🔐 2. ChatRooms → SessionKeys

**Path**: `chatRooms/{roomId}/sessionKeys/{deviceId}`

### ✅ Cấu trúc đúng (KHÔNG ROTATE KEY):

```json
{
  "userId": "0lzC7hL5RWSERhDnQShjOvUbB6q1",
  "encryptedKey": "LvcbZVrGXqFpq3kV8LSSyhkiMOaudBnLGJ9rTP/WWOBdzUBQWZxHHinle/... (base64)",
  "createdAt": "2026-01-10T09:25:29Z"
}
```

### ❌ Cấu trúc SAI:
- ❌ Có field `epoch` (đã bỏ)
- ❌ `encryptedKey` không phải base64
- ❌ Thiếu `userId` hoặc `createdAt`

### 📝 Notes:
- **QUAN TRỌNG**: KHÔNG có field `epoch` (Option 1: Không rotate key)
- Mỗi device có 1 session key document
- `encryptedKey` là session key (32 bytes AES-256) được encrypt bằng RSA public key của device đó
- Tất cả devices trong room dùng CÙNG 1 session key (nhưng mỗi device có bản encrypted riêng)

---

## 📊 Ví Dụ Thực Tế

### Scenario: 2 Users, 3 Devices

**Users**:
- User A (`userId1`): 2 devices (Device A1, Device A2)
- User B (`userId2`): 1 device (Device B1)

**Room**: `room123`

### ✅ Cấu trúc Firestore đúng:

```
chatRooms/
  room123/
    participants: ["userId1", "userId2"]
    e2ee: true
    ...
    
    sessionKeys/
      deviceA1/              ← Device A1
        userId: "userId1"
        encryptedKey: "base64_encrypted_with_deviceA1_public_key"
        createdAt: "2026-01-10T09:25:29Z"
        
      deviceA2/              ← Device A2
        userId: "userId1"
        encryptedKey: "base64_encrypted_with_deviceA2_public_key"
        createdAt: "2026-01-10T09:25:30Z"
        
      deviceB1/              ← Device B1
        userId: "userId2"
        encryptedKey: "base64_encrypted_with_deviceB1_public_key"
        createdAt: "2026-01-10T09:25:30Z"
```

### 🔍 Giải thích:

1. **3 session key documents** = 3 devices
2. **Cùng 1 session key** (plaintext) nhưng:
   - Device A1: encrypt bằng public key của Device A1
   - Device A2: encrypt bằng public key của Device A2
   - Device B1: encrypt bằng public key của Device B1
3. **Không có `epoch`** - vì không rotate key
4. **`createdAt` gần giống nhau** - vì được phân phối cùng lúc

---

## ✅ Checklist Kiểm Tra

### Session Keys:
- [ ] Mỗi device có 1 session key document (keyed by `deviceId`)
- [ ] KHÔNG có field `epoch`
- [ ] Có đầy đủ: `userId`, `encryptedKey`, `createdAt`
- [ ] `encryptedKey` là base64 string
- [ ] Số lượng session keys = số lượng devices của tất cả participants

### Devices:
- [ ] Mỗi device có 1 document trong `users/{userId}/devices/{deviceId}`
- [ ] Có `publicKey` (PEM format)
- [ ] `algorithm` = "RSA-2048"
- [ ] Có `platform`, `createdAt`, `lastActiveAt`

### Messages:
- [ ] Messages có `ciphertext` và `iv` (base64)
- [ ] `ciphertext` được encrypt bằng AES-GCM với session key
- [ ] `iv` là 12 bytes (base64)

---

## 🔍 Ví Dụ Kiểm Tra Trong Console

### 1. Kiểm tra số lượng session keys:

```
Collection: chatRooms/{roomId}/sessionKeys
Expected: Số lượng = tổng số devices của tất cả participants
```

**Ví dụ**: 
- User A có 2 devices
- User B có 1 device
- **Expected**: 3 session key documents

### 2. Kiểm tra structure của 1 session key:

```json
{
  "userId": "0lzC7hL5RWSERhDnQShjOvUbB6q1",  ✅ String
  "encryptedKey": "LvcbZVrGXqFpq3kV8LSS...",  ✅ String (base64)
  "createdAt": Timestamp,                     ✅ Timestamp
  // KHÔNG có "epoch"                         ✅
}
```

### 3. Kiểm tra devices:

```
Collection: users/{userId}/devices
Expected: Mỗi device có 1 document với publicKey
```

---

## ❌ Common Mistakes

### 1. ❌ Có field `epoch`:
```json
{
  "userId": "...",
  "encryptedKey": "...",
  "epoch": 1,              ← ❌ SAI - Đã bỏ epoch
  "createdAt": "..."
}
```

### 2. ❌ Duplicate session keys cho cùng device:
```
sessionKeys/
  deviceA1/  ← Document 1
  deviceA1/  ← Document 2 (duplicate) ❌
```
→ Mỗi device chỉ có 1 document (keyed by deviceId)

### 3. ❌ Session keys với `encryptedKey` khác nhau cho cùng device:
→ Tất cả devices phải dùng CÙNG 1 session key (plaintext), chỉ khác cách encrypt

### 4. ❌ Missing `createdAt`:
```json
{
  "userId": "...",
  "encryptedKey": "..."
  // Thiếu createdAt ❌
}
```

---

## 📝 Notes Quan Trọng

1. **Session Key (Plaintext)**: 32 bytes (AES-256), KHÔNG lưu trong Firestore
2. **Encrypted Key**: Session key được encrypt bằng RSA-OAEP với public key của từng device
3. **Multi-Device**: Mỗi device có bản encrypted riêng, nhưng cùng 1 session key plaintext
4. **No Rotation**: Không rotate key → tin nhắn cũ luôn decrypt được
5. **Document ID**: Session key document ID = deviceId (UUID)

---

## 🧪 Test Structure

### Test 1: Single User, Single Device
```
Expected: 1 session key document
```

### Test 2: Single User, Multiple Devices
```
User A: 2 devices
Expected: 2 session key documents (cùng userId)
```

### Test 3: Multiple Users, Multiple Devices
```
User A: 2 devices
User B: 1 device
Expected: 3 session key documents (2 userId A, 1 userId B)
```

### Test 4: New Device Join
```
Before: 2 session keys
After: User A thêm device mới
Expected: 3 session keys (device mới được phân phối key)
```

