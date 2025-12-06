String firebaseErrorToVietnamese(String code) {
  switch (code) {
    /* =============================
       LỖI EMAIL / MẬT KHẨU
    ============================== */
    case "invalid-email":
      return "Email không hợp lệ.";
    case "user-disabled":
      return "Tài khoản đã bị vô hiệu hóa.";
    case "user-not-found":
      return "Không tìm thấy tài khoản.";
    case "wrong-password":
      return "Mật khẩu không chính xác.";
    case "email-already-in-use":
      return "Email này đã được đăng ký.";
    case "weak-password":
      return "Mật khẩu quá yếu, hãy chọn mật khẩu mạnh hơn.";
    case "missing-email":
      return "Vui lòng nhập email.";
    case "operation-not-allowed":
      return "Tính năng đăng nhập bằng email/mật khẩu chưa được bật.";

    /* =============================
       LỖI SỐ ĐIỆN THOẠI / OTP
    ============================== */
    case "invalid-phone-number":
      return "Số điện thoại không hợp lệ.";
    case "missing-phone-number":
      return "Vui lòng nhập số điện thoại.";
    case "session-expired":
      return "Mã OTP đã hết hạn, vui lòng thử lại.";
    case "invalid-verification-code":
      return "Mã OTP không đúng.";
    case "invalid-verification-id":
      return "Mã xác thực không hợp lệ.";
    case "captcha-check-failed":
      return "Xác thực CAPTCHA thất bại.";
    case "quota-exceeded":
      return "Bạn đã gửi quá nhiều OTP. Vui lòng thử lại sau.";
    case "too-many-requests":
      return "Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.";
    case "app-not-authorized":
      return "Ứng dụng chưa được cấp phép sử dụng xác thực số điện thoại.";

    /* =============================
       LỖI ĐĂNG NHẬP GOOGLE / PROVIDER
    ============================== */
    case "account-exists-with-different-credential":
      return "Tài khoản đã tồn tại với phương thức đăng nhập khác.";
    case "credential-already-in-use":
      return "Tài khoản này đã liên kết với người dùng khác.";
    case "invalid-credential":
      return "Thông tin đăng nhập không hợp lệ hoặc đã hết hạn.";
    case "operation-not-supported-in-this-environment":
      return "Hành động này không được hỗ trợ trên nền tảng hiện tại.";

    /* =============================
       MFA - ĐĂNG NHẬP / ĐĂNG KÝ 2 LỚP
    ============================== */
    case "requires-recent-login":
      return "Vui lòng đăng nhập lại để tiếp tục.";
    case "second-factor-required":
      return "Cần xác thực bước hai (MFA).";
    case "multi-factor-auth-required":
      return "Tài khoản yêu cầu xác minh nhiều lớp.";
    case "invalid-multi-factor-session":
      return "Phiên MFA không hợp lệ hoặc đã hết hạn.";
    case "invalid-multi-factor-info":
      return "Thông tin MFA không hợp lệ.";

    /* =============================
       LỖI LIÊN QUAN MẠNG / SERVER
    ============================== */
    case "network-request-failed":
      return "Lỗi kết nối mạng. Vui lòng kiểm tra Internet.";
    case "internal-error":
      return "Lỗi hệ thống Firebase.";
    case "timeout":
      return "Hết thời gian chờ phản hồi.";
    case "unavailable":
      return "Dịch vụ Firebase tạm thời không khả dụng.";

    /* =============================
       LỖI FIRESTORE (THÊM)
    ============================== */
    case "permission-denied":
      return "Bạn không có quyền truy cập dữ liệu này.";
    case "not-found":
      return "Không tìm thấy dữ liệu.";
    case "already-exists":
      return "Dữ liệu đã tồn tại.";

    /* =============================
       LỖI KHÁC
    ============================== */
    case "invalid-api-key":
      return "API Key không hợp lệ.";
    case "app-deleted":
      return "Ứng dụng Firebase đã bị xóa.";
    case "invalid-user-token":
      return "Thông tin đăng nhập đã hết hạn, vui lòng đăng nhập lại.";
    case "user-token-expired":
      return "Phiên đăng nhập đã hết hạn.";
    case "null-user":
      return "Không tìm thấy người dùng.";

    default:
      return "Đã xảy ra lỗi không xác định. Vui lòng thử lại.";
  }
}
