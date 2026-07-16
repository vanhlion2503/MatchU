import 'package:get/get.dart';

abstract final class AuthTranslationKeys {
  static const error = 'auth.error';
  static const success = 'auth.success';
  static const registrationFailed = 'auth.registration_failed';
  static const loginFailed = 'auth.login_failed';
  static const otpError = 'auth.otp_error';
}

const authEnglishTranslations = <String, String>{
  AuthTranslationKeys.error: 'Error',
  AuthTranslationKeys.success: 'Success',
  AuthTranslationKeys.registrationFailed: 'Registration failed',
  AuthTranslationKeys.loginFailed: 'Login failed',
  AuthTranslationKeys.otpError: 'OTP error',
  'Lỗi': 'Error',
  'Thành công': 'Success',
  'Đăng ký thất bại': 'Registration failed',
  'Đăng nhập thất bại': 'Login failed',
  'Lỗi OTP': 'OTP error',
  'Đã xóa': 'Removed',
  'Không tìm thấy tài khoản đã lưu': 'Saved account not found',
  'Tài khoản này sẽ không còn được lưu': 'This account will no longer be saved',
  'Vui lòng nhập đầy đủ thông tin': 'Please complete all required fields',
  'Mật khẩu phải từ 6 ký tự trở lên': 'Password must be at least 6 characters',
  'Mật khẩu nhập lại không khớp': 'Passwords do not match',
  'Chưa xác minh': 'Not verified',
  'Vui lòng kiểm tra email.': 'Please check your email.',
  'Không tìm thấy user': 'User not found',
  'Đã gửi email xác minh': 'Verification email sent',
  'Số điện thoại không hợp lệ': 'Invalid phone number',
  'Số điện thoại này đã được sử dụng': 'This phone number is already in use',
  'Không thể gửi OTP. Vui lòng thử lại':
      'Unable to send the OTP. Please try again.',
  'Thiếu mã OTP': 'Please enter the OTP',
  '🎉 Đăng ký thành công': '🎉 Registration successful',
  'Vui lòng đăng nhập để tiếp tục': 'Please log in to continue',
  'Vui lòng đăng nhập bằng Google để tiếp tục':
      'Please log in with Google to continue',
  'Vui lòng đăng nhập bằng Google để xác minh OTP':
      'Please log in with Google to verify the OTP',
  'Tài khoản đã tồn tại': 'Account already exists',
  'Đăng nhập Google thất bại': 'Google sign-in failed',
  'Nhập email và mật khẩu': 'Enter your email and password',
  'Không tìm thấy phiên MFA': 'MFA session not found',
  'Phiên OTP không hợp lệ': 'Invalid OTP session',
  'OTP sai': 'Incorrect OTP',
  'Xác thực thất bại': 'Verification failed',
  'Thiếu ảnh đại diện': 'Profile photo required',
  'Vui lòng chọn ảnh đại diện để tiếp tục':
      'Choose a profile photo to continue',
  'Đăng xuất thất bại. Vui lòng thử lại.':
      'Unable to log out. Please try again.',
  'Vui lòng nhập email hợp lệ': 'Please enter a valid email address',
  'Đã gửi thành công': 'Email sent',
  'Vui lòng kiểm tra email để đặt lại mật khẩu':
      'Check your email to reset your password',
  'Không mở được Gmail': 'Unable to open Gmail',
  'Cắt ảnh': 'Crop photo',
  'Cập nhật avatar thành công': 'Profile photo updated',
  'Đã khôi phục avatar mặc định': 'Default profile photo restored',
  'Mã xác thực đã được gửi đến số \n': 'A verification code was sent to \n',
  'Chúng tôi đã gửi link xác minh đến ': 'We sent a verification link to ',
  '. Hãy mở email và xác nhận.': '. Open the email and confirm your address.',
  'Gửi lại OTP': 'Resend OTP',
  'Gửi lại mã': 'Resend code',
  'Gửi lại email': 'Resend email',
  'Chúng tôi sẽ gửi mã OTP qua tin nhắn SMS': 'We will send an OTP by SMS',
  'Không tạo được user': 'Unable to create the user',
  'User chưa đăng nhập': 'User is not logged in',
  'Bạn phải xác minh email trước khi dùng số điện thoại.':
      'Verify your email before using a phone number.',
  'Gửi OTP bị lỗi': 'Unable to send the OTP',
  'Không thể gửi OTP. Vui lòng thử lại.':
      'Unable to send the OTP. Please try again.',
  'Email chưa được xác minh': 'Email has not been verified',
  'Đã xảy ra lỗi khi xác minh OTP.':
      'An error occurred while verifying the OTP.',
  'Lỗi không xác định.': 'An unknown error occurred.',
  'Không tìm thấy số điện thoại xác minh MFA.':
      'MFA verification phone number not found.',
  'Không thể gửi OTP xác minh MFA.': 'Unable to send the MFA verification OTP.',
  'Đã xảy ra lỗi không xác định. Vui lòng thử lại.':
      'An unknown error occurred. Please try again.',
  'Email không hợp lệ.': 'Invalid email address.',
  'Tài khoản đã bị vô hiệu hóa.': 'This account has been disabled.',
  'Không tìm thấy tài khoản.': 'Account not found.',
  'Mật khẩu không chính xác.': 'Incorrect password.',
  'Email này đã được đăng ký.': 'This email address is already registered.',
  'Mật khẩu quá yếu, hãy chọn mật khẩu mạnh hơn.':
      'This password is too weak. Choose a stronger password.',
  'Vui lòng nhập email.': 'Please enter your email address.',
  'Tính năng đăng nhập bằng email/mật khẩu chưa được bật.':
      'Email and password sign-in is not enabled.',
  'Số điện thoại không hợp lệ.': 'Invalid phone number.',
  'Vui lòng nhập số điện thoại.': 'Please enter your phone number.',
  'Mã OTP đã hết hạn, vui lòng thử lại.':
      'The OTP has expired. Please try again.',
  'Mã OTP không đúng.': 'Incorrect OTP.',
  'Mã xác thực không hợp lệ.': 'Invalid verification code.',
  'Xác thực CAPTCHA thất bại.': 'CAPTCHA verification failed.',
  'Bạn đã gửi quá nhiều OTP. Vui lòng thử lại sau.':
      'Too many OTP requests. Please try again later.',
  'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.':
      'Too many attempts. Please try again later.',
  'Ứng dụng chưa được cấp phép sử dụng xác thực số điện thoại.':
      'The app is not authorized to use phone authentication.',
  'Tài khoản đã tồn tại với phương thức đăng nhập khác.':
      'An account already exists with another sign-in method.',
  'Tài khoản này đã liên kết với người dùng khác.':
      'This credential is linked to another user.',
  'Thông tin đăng nhập không hợp lệ hoặc đã hết hạn.':
      'The credential is invalid or has expired.',
  'Hành động này không được hỗ trợ trên nền tảng hiện tại.':
      'This action is not supported on the current platform.',
  'Vui lòng đăng nhập lại để tiếp tục.': 'Log in again to continue.',
  'Cần xác thực bước hai (MFA).': 'Two-factor authentication is required.',
  'Tài khoản yêu cầu xác minh nhiều lớp.':
      'This account requires multi-factor authentication.',
  'Phiên MFA không hợp lệ hoặc đã hết hạn.':
      'The MFA session is invalid or has expired.',
  'Thông tin MFA không hợp lệ.': 'Invalid MFA information.',
  'Lỗi kết nối mạng. Vui lòng kiểm tra Internet.':
      'Network error. Check your internet connection.',
  'Lỗi hệ thống Firebase.': 'Firebase system error.',
  'Hết thời gian chờ phản hồi.': 'The request timed out.',
  'Dịch vụ Firebase tạm thời không khả dụng.':
      'The service is temporarily unavailable.',
  'Bạn không có quyền truy cập dữ liệu này.':
      'You do not have permission to access this data.',
  'Không tìm thấy dữ liệu.': 'Data not found.',
  'Dữ liệu đã tồn tại.': 'The data already exists.',
  'API Key không hợp lệ.': 'Invalid API key.',
  'Ứng dụng Firebase đã bị xóa.': 'The Firebase app has been deleted.',
  'Thông tin đăng nhập đã hết hạn, vui lòng đăng nhập lại.':
      'Your credentials have expired. Log in again.',
  'Phiên đăng nhập đã hết hạn.': 'Your session has expired.',
  'Không tìm thấy người dùng.': 'User not found.',
};

final authVietnameseTranslations = <String, String>{
  for (final source in authEnglishTranslations.keys) source: source,
  AuthTranslationKeys.error: 'Lỗi',
  AuthTranslationKeys.success: 'Thành công',
  AuthTranslationKeys.registrationFailed: 'Đăng ký thất bại',
  AuthTranslationKeys.loginFailed: 'Đăng nhập thất bại',
  AuthTranslationKeys.otpError: 'Lỗi OTP',
};

String authTr(String source) {
  final exact = source.tr;
  if (exact != source || Get.locale?.languageCode != 'en') return exact;

  final patterns = <(RegExp, String Function(Match))>[
    (RegExp(r'^Gửi lại sau (\d+)s$'), (m) => 'Resend in ${m[1]}s'),
    (
      RegExp(r'^Không thể hủy luồng đăng ký: (.+)$'),
      (m) => 'Unable to cancel registration: ${m[1]}',
    ),
    (RegExp(r'^Exception: (.+)$'), (m) => authTr(m[1]!)),
  ];
  for (final (pattern, replacement) in patterns) {
    final match = pattern.firstMatch(source);
    if (match != null) return replacement(match);
  }
  return source;
}
