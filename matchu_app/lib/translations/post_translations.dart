import 'package:get/get.dart';

abstract final class PostTranslationKeys {
  static const notice = 'post.notice';
  static const error = 'post.error';
  static const imageLimit = 'post.image_limit';
  static const imageLimitMessage = 'post.image_limit_message';
  static const reportSentMessage = 'post.report_sent_message';
  static const hiddenAuthorMessage = 'post.hidden_author_message';
  static const maxAttachmentsMessage = 'post.max_attachments_message';
  static const moderationRejected = 'post.moderation_rejected';
  static const moderationReview = 'post.moderation_review';
}

const postVietnameseTranslations = <String, String>{
  PostTranslationKeys.notice: 'Thông báo',
  PostTranslationKeys.error: 'Lỗi',
  PostTranslationKeys.imageLimit: 'Giới hạn ảnh',
  PostTranslationKeys.imageLimitMessage:
      'Chỉ lưu @remaining ảnh đầu tiên. Tối đa @max ảnh cho mỗi báo cáo.',
  PostTranslationKeys.reportSentMessage:
      'Chúng tôi sẽ xem xét bài viết của @author.',
  PostTranslationKeys.hiddenAuthorMessage: 'Đã ẩn bài viết từ @author.',
  PostTranslationKeys.maxAttachmentsMessage:
      'Mỗi bài viết chỉ được có tối đa @max tệp đính kèm.',
  PostTranslationKeys.moderationRejected: 'Bài viết bị từ chối',
  PostTranslationKeys.moderationReview: 'Cần xem xét',
  'Nổi bật': 'Nổi bật',
  'Mới nhất': 'Mới nhất',
  'Đăng': 'Đăng',
  'Người theo dõi': 'Người theo dõi',
  'Thư viện video': 'Thư viện video',
  'Hiển thị trong bảng tin công khai': 'Hiển thị trong bảng tin công khai',
  'Chỉ người theo dõi bạn mới xem': 'Chỉ người theo dõi bạn mới có thể xem',
  'Chỉ lưu cho bạn, không lên bảng tin công khai':
      'Chỉ bạn có thể xem bài viết này',
  'Chỉ người theo dõi bạn mới xem.': 'Chỉ người theo dõi bạn mới có thể xem.',
  'Chỉ bạn xem được bài viết này.': 'Chỉ bạn có thể xem bài viết này.',
  'Hủy đăng lại': 'Hủy đăng lại',
  'Đăng lại': 'Đăng lại',
  'Xóa bài đăng lại này khỏi hồ sơ của bạn.':
      'Xóa bài đăng lại này khỏi hồ sơ của bạn.',
  'Đăng lại bài viết này trên hồ sơ của bạn.':
      'Đăng lại bài viết này trên hồ sơ của bạn.',
  'Viết bài của bạn kèm bài viết gốc.': 'Viết bài của bạn kèm bài viết gốc.',
  'Cập nhật nội dung, thẻ và tệp đính kèm.':
      'Cập nhật nội dung, thẻ và tệp đính kèm.',
  'Thay đổi ai có thể xem bài viết này.':
      'Thay đổi người có thể xem bài viết này.',
  'Ẩn bài viết này khỏi trang tin.': 'Ẩn bài viết này khỏi bảng tin.',
  'Nhấn lần nữa để bỏ lưu bài viết.': 'Nhấn lần nữa để bỏ lưu bài viết.',
  'Đánh dấu để xem lại sau.': 'Đánh dấu để xem lại sau.',
  'Chia sẻ liên kết bài viết.': 'Chia sẻ liên kết bài viết.',
  'Ẩn bài viết từ tác giả này': 'Ẩn bài viết từ tác giả này',
  'Ẩn toàn bộ bài viết từ người này trong feed.':
      'Ẩn toàn bộ bài viết của người này khỏi bảng tin.',
  'Xóa vĩnh viễn bài viết này khỏi tài khoản của bạn.':
      'Xóa vĩnh viễn bài viết này khỏi tài khoản của bạn.',
  'Báo cáo bài viết': 'Báo cáo bài viết',
  'Gửi báo cáo nếu nội dung này không phù hợp.':
      'Báo cáo nếu nội dung này không phù hợp.',
  'Cập nhật nội dung bình luận của bạn.':
      'Cập nhật nội dung bình luận của bạn.',
  'Ẩn bình luận': 'Ẩn bình luận',
  'Chỉ ẩn bình luận này trên thiết bị của bạn.':
      'Chỉ ẩn bình luận này trên thiết bị của bạn.',
  'Xóa nội dung bình luận, phản hồi con vẫn được giữ.':
      'Xóa nội dung bình luận; các phản hồi vẫn được giữ lại.',
  'Bình luận đã xóa': 'Bình luận đã xóa',
  'Bình luận này đã bị xóa.': 'Bình luận này đã bị xóa.',
  'Đang tải phản hồi...': 'Đang tải phản hồi...',
  'Nhập bình luận...': 'Nhập bình luận...',
  'Bình luận...': 'Bình luận...',
  'Chỉnh sửa bình luận...': 'Chỉnh sửa bình luận...',
  'Chỉnh sửa bài viết...': 'Chỉnh sửa bài viết...',
  'Thêm nhận xét của bạn...': 'Thêm nhận xét của bạn...',
  'Có gì mới?': 'Có gì mới?',
  'Chưa có bài viết công khai nào.': 'Chưa có bài viết công khai nào.',
  'Hãy tạo bài viết mới hoặc kéo xuống để làm mới bảng tin.':
      'Hãy tạo bài viết mới hoặc kéo xuống để làm mới bảng tin.',
  'Chưa có bài viết từ người bạn theo dõi.':
      'Chưa có bài viết từ những người bạn theo dõi.',
  'Hãy theo dõi thêm người dùng hoặc kéo xuống để làm mới bảng tin.':
      'Hãy theo dõi thêm người dùng hoặc kéo xuống để làm mới bảng tin.',
  'Đã xảy ra lỗi khi tải bảng tin.': 'Đã xảy ra lỗi khi tải bảng tin.',
  'Bài viết không công khai sẽ không hiển thị trong bảng tin công khai.':
      'Bài viết không công khai sẽ không xuất hiện trên bảng tin công khai.',
  'Đang kiểm duyệt video': 'Đang kiểm duyệt video',
  'Bài viết sẽ hiển thị theo quyền riêng tư đã chọn sau khi video được duyệt.':
      'Bài viết sẽ hiển thị theo quyền riêng tư đã chọn sau khi video được duyệt.',
  'Đã ẩn bài viết khỏi bảng tin của bạn.':
      'Đã ẩn bài viết khỏi bảng tin của bạn.',
  'Đã xóa bài viết.': 'Đã xóa bài viết.',
  'Đã đăng lại bài viết thành công.': 'Đã đăng lại bài viết thành công.',
  'Đã hủy đăng lại bài viết.': 'Đã hủy đăng lại bài viết.',
  'Đã lưu bài viết vào lưu trữ.': 'Đã lưu bài viết.',
  'Đã bỏ lưu bài viết.': 'Đã bỏ lưu bài viết.',
  'Đã ẩn bình luận này khỏi thiết bị của bạn.':
      'Đã ẩn bình luận này khỏi thiết bị của bạn.',
  'Tính năng chia sẻ sẽ được triển khai ở bước tiếp theo.':
      'Tính năng chia sẻ sẽ sớm được cập nhật.',
  'Tính năng chia sẻ sẽ được cập nhật ở bước tiếp theo.':
      'Tính năng chia sẻ sẽ sớm được cập nhật.',
  'Video đã được duyệt và bài viết có thể hiển thị theo quyền riêng tư đã chọn.':
      'Video đã được duyệt và bài viết sẽ hiển thị theo quyền riêng tư đã chọn.',
  'Video vi phạm tiêu chuẩn cộng đồng nên bài viết đã bị ẩn.':
      'Video vi phạm Tiêu chuẩn cộng đồng nên bài viết đã bị ẩn.',
  'Video cần được quản trị viên xem xét trước khi hiển thị.':
      'Video cần được quản trị viên xem xét trước khi hiển thị.',
  'Đã chặn người dùng này.': 'Đã chặn người dùng này.',
  'Đã gỡ chặn người dùng này.': 'Đã gỡ chặn người dùng này.',
  'Đã bỏ ẩn bài viết từ người này.': 'Đã bỏ ẩn bài viết từ người này.',
  'Đã bật lại thông báo từ người này.': 'Đã bật lại thông báo từ người này.',
  'Không tìm thấy tác giả để chặn.': 'Không tìm thấy tác giả để chặn.',
  'Không tìm thấy người dùng này.': 'Không tìm thấy người dùng này.',
  'Không tìm thấy bài viết gốc để đăng lại.':
      'Không tìm thấy bài viết gốc để đăng lại.',
  'Không tìm thấy bài viết gốc để hủy đăng lại.':
      'Không tìm thấy bài viết gốc để hủy đăng lại.',
  'Không thể tải bảng tin lúc này. Vui lòng thử lại.':
      'Không thể tải bảng tin lúc này. Vui lòng thử lại.',
  'Không thể xử lý bài viết lúc này. Vui lòng thử lại.':
      'Không thể xử lý bài viết lúc này. Vui lòng thử lại.',
  'Không thể xử lý bình luận lúc này. Vui lòng thử lại.':
      'Không thể xử lý bình luận lúc này. Vui lòng thử lại.',
  'Mỗi bài viết chỉ có thể đăng 1 video.':
      'Mỗi bài viết chỉ có thể đăng một video.',
  'Mỗi bài viết chỉ có thể đăng 1 video. Chỉ video đầu tiên được thêm.':
      'Mỗi bài viết chỉ có thể đăng một video. Chỉ video đầu tiên được thêm.',
  'Cần quyền microphone để ghi âm.': 'Cần quyền truy cập micrô để ghi âm.',
  'Bài viết cần có nội dung hoặc tệp đính kèm.':
      'Bài viết cần có nội dung hoặc tệp đính kèm.',
  'Nội dung bài viết không được vượt quá 300 ký tự.':
      'Nội dung bài viết không được vượt quá 300 ký tự.',
  'Video không được nặng quá 150MB.':
      'Dung lượng video không được vượt quá 150 MB.',
  'Video chỉ được dài tối đa 1 phút.': 'Video chỉ được dài tối đa một phút.',
  'Bạn cần đăng nhập để bình luận.': 'Bạn cần đăng nhập để bình luận.',
  'Bạn cần đăng nhập để chỉnh sửa bình luận.':
      'Bạn cần đăng nhập để chỉnh sửa bình luận.',
  'Không thể chọn ảnh lúc này.': 'Không thể chọn ảnh lúc này.',
  'Vui lòng chọn lý do báo cáo.': 'Vui lòng chọn lý do báo cáo.',
  'Phiên đăng nhập đã hết hạn. Vui lòng thử lại.':
      'Phiên đăng nhập đã hết hạn. Vui lòng thử lại.',
  'Không tìm thấy tác giả bài viết.': 'Không tìm thấy tác giả bài viết.',
  'Vui lòng nhập lý do cụ thể.': 'Vui lòng nhập lý do cụ thể.',
  'Không thể gửi báo cáo. Vui lòng thử lại.':
      'Không thể gửi báo cáo. Vui lòng thử lại.',
  'Bạn cần đăng nhập để chỉnh sửa bài viết.':
      'Bạn cần đăng nhập để chỉnh sửa bài viết.',
  'Không tìm thấy bài viết để chỉnh sửa.':
      'Không tìm thấy bài viết để chỉnh sửa.',
  'Bài viết không còn tồn tại.': 'Bài viết không còn tồn tại.',
  'Bạn cần đăng nhập để đăng lại bài viết.':
      'Bạn cần đăng nhập để đăng lại bài viết.',
  'Bạn đã đăng lại bài viết này rồi.': 'Bạn đã đăng lại bài viết này.',
  'Bạn cần đăng nhập để hủy đăng lại.': 'Bạn cần đăng nhập để hủy đăng lại.',
  'Bạn chưa đăng lại bài viết này.': 'Bạn chưa đăng lại bài viết này.',
  'Bạn cần đăng nhập để xóa bài viết.': 'Bạn cần đăng nhập để xóa bài viết.',
  'Không tìm thấy bài viết để xóa.': 'Không tìm thấy bài viết để xóa.',
  'Bạn không thể xóa bài viết này.': 'Bạn không thể xóa bài viết này.',
  'Bạn cần đăng nhập để đăng bài viết.': 'Bạn cần đăng nhập để đăng bài viết.',
  'Bạn cần đăng nhập để lưu bài viết.': 'Bạn cần đăng nhập để lưu bài viết.',
  'Bài viết này không còn khả dụng.': 'Bài viết này không còn khả dụng.',
  'Nội dung bình luận không được để trống.':
      'Nội dung bình luận không được để trống.',
  'Bình luận không được vượt quá 300 ký tự.':
      'Bình luận không được vượt quá 300 ký tự.',
  'Không tìm thấy bình luận gốc để trả lời.':
      'Không tìm thấy bình luận gốc để trả lời.',
  'Không thể trả lời bình luận đã bị xóa.':
      'Không thể trả lời bình luận đã bị xóa.',
  'Bình luận không còn tồn tại.': 'Bình luận không còn tồn tại.',
  'Bạn cần đăng nhập để xóa bình luận.': 'Bạn cần đăng nhập để xóa bình luận.',
  'Bạn không thể xóa bình luận này.': 'Bạn không thể xóa bình luận này.',
  'Đăng bài viết lặp lại nhiều lần': 'Đăng bài viết lặp lại nhiều lần',
  'Bình luận spam dưới nhiều bài viết': 'Bình luận rác dưới nhiều bài viết',
  'Gửi tin nhắn quảng cáo hàng loạt': 'Gửi tin nhắn quảng cáo hàng loạt',
  'Chia sẻ liên kết không rõ nguồn gốc': 'Chia sẻ liên kết không rõ nguồn gốc',
  'Tạo nhiều tài khoản để spam': 'Tạo nhiều tài khoản để gửi nội dung rác',
  'Nội dung chỉ nhằm quảng cáo, không có giá trị tương tác':
      'Nội dung chỉ nhằm quảng cáo, không có giá trị tương tác',
  'Khác (Người dùng có thể nhập vào)': 'Khác (bạn có thể tự nhập)',
  'Giả mạo người khác': 'Giả mạo người khác',
  'Giả mạo người nổi tiếng': 'Giả mạo người nổi tiếng',
  'Giả mạo bạn bè hoặc người quen': 'Giả mạo bạn bè hoặc người quen',
  'Sử dụng ảnh đại diện của người khác': 'Sử dụng ảnh đại diện của người khác',
  'Dùng tên hoặc thông tin cá nhân của người khác':
      'Dùng tên hoặc thông tin cá nhân của người khác',
  'Giả mạo thương hiệu, tổ chức hoặc cộng đồng':
      'Giả mạo thương hiệu, tổ chức hoặc cộng đồng',
  'Tạo tài khoản giống tài khoản thật để gây nhầm lẫn':
      'Tạo tài khoản giống tài khoản thật để gây nhầm lẫn',
  'Quấy rối hoặc xúc phạm': 'Quấy rối hoặc xúc phạm',
  'Chửi bới, xúc phạm cá nhân': 'Chửi bới hoặc xúc phạm cá nhân',
  'Đe dọa hoặc gây áp lực tinh thần': 'Đe dọa hoặc gây áp lực tinh thần',
  'Quấy rối qua tin nhắn riêng': 'Quấy rối qua tin nhắn riêng',
  'Công kích ngoại hình, giới tính, vùng miền hoặc cá nhân':
      'Công kích ngoại hình, giới tính, vùng miền hoặc cá nhân',
  'Bình luận tiêu cực lặp lại nhiều lần':
      'Lặp lại bình luận tiêu cực nhiều lần',
  'Kêu gọi người khác tấn công một tài khoản':
      'Kêu gọi người khác tấn công một tài khoản',
  'Nội dung không phù hợp': 'Nội dung không phù hợp',
  'Hình ảnh hoặc video phản cảm trên trang cá nhân':
      'Hình ảnh hoặc video phản cảm',
  'Nội dung bạo lực hoặc gây khó chịu': 'Nội dung bạo lực hoặc gây khó chịu',
  'Nội dung kích động thù ghét': 'Nội dung kích động thù ghét',
  'Ngôn từ thô tục, thiếu văn minh': 'Ngôn từ thô tục hoặc thiếu văn minh',
  'Nội dung không phù hợp với độ tuổi người dùng':
      'Nội dung không phù hợp với độ tuổi người dùng',
  'Thông tin trên hồ sơ gây hiểu nhầm hoặc sai sự thật':
      'Thông tin gây hiểu nhầm hoặc sai sự thật',
  'Lừa đảo': 'Lừa đảo',
  'Lừa đảo chuyển tiền': 'Lừa đảo chuyển tiền',
  'Giả danh để xin thông tin cá nhân': 'Giả danh để lấy thông tin cá nhân',
  'Gửi đường link đánh cắp tài khoản': 'Gửi liên kết đánh cắp tài khoản',
  'Rao bán sản phẩm hoặc dịch vụ không uy tín':
      'Rao bán sản phẩm hoặc dịch vụ không uy tín',
  'Hứa hẹn phần thưởng giả': 'Hứa hẹn phần thưởng giả',
  'Mạo danh nhân viên hỗ trợ hoặc quản trị viên':
      'Mạo danh nhân viên hỗ trợ hoặc quản trị viên',
  'Hành vi đáng ngờ': 'Hành vi đáng ngờ',
  'Vi phạm quy định cộng đồng': 'Vi phạm quy định cộng đồng',
  'Tài khoản có hoạt động bất thường': 'Tài khoản có hoạt động bất thường',
  'Nội dung gây khó chịu nhưng không thuộc mục trên':
      'Nội dung gây khó chịu nhưng không thuộc các mục trên',
  'Lý do khác do người dùng tự nhập': 'Lý do khác do bạn tự nhập',
  'Ẩn bài viết này': 'Ẩn bài viết này',
  'Ẩn bài viết này khỏi feed của bạn.':
      'Ẩn bài viết này khỏi bảng tin của bạn.',
  'Ẩn toàn bộ bài viết của họ': 'Ẩn toàn bộ bài viết của họ',
  'Ẩn tất cả bài viết từ người dùng này trong feed.':
      'Ẩn tất cả bài viết của người dùng này khỏi bảng tin.',
  'Bạn sẽ không còn thấy hồ sơ, bài viết và tin nhắn từ tài khoản này.':
      'Bạn sẽ không còn thấy hồ sơ, bài viết và tin nhắn từ tài khoản này.',
  'Bài viết này không có nội dung văn bản.':
      'Bài viết này không có nội dung văn bản.',
  'Bạn có thể bổ sung bối cảnh hoặc dấu hiệu cụ thể để đội ngũ kiểm duyệt xem xét chính xác hơn.':
      'Bạn có thể bổ sung bối cảnh hoặc dấu hiệu cụ thể để đội ngũ kiểm duyệt xem xét chính xác hơn.',
  'Không thể tải Danh sách hạn chế lúc này. Vui lòng thử lại.':
      'Không thể tải Danh sách hạn chế lúc này. Vui lòng thử lại.',
  'Video đang được kiểm duyệt. Bài viết sẽ hiển thị sau khi được duyệt.':
      'Video đang được kiểm duyệt. Bài viết sẽ hiển thị sau khi được duyệt.',
  'Mục chi tiết': 'Mục chi tiết',
  'Lý do cụ thể': 'Lý do cụ thể',
};

const postEnglishTranslations = <String, String>{
  PostTranslationKeys.notice: 'Notification',
  PostTranslationKeys.error: 'Error',
  PostTranslationKeys.imageLimit: 'Photo limit',
  PostTranslationKeys.imageLimitMessage:
      'Only the first @remaining photos were kept. Each report can include up to @max photos.',
  PostTranslationKeys.reportSentMessage: "We'll review @author's post.",
  PostTranslationKeys.hiddenAuthorMessage:
      'Posts from @author have been hidden.',
  PostTranslationKeys.maxAttachmentsMessage:
      'Each post can contain up to @max attachments.',
  PostTranslationKeys.moderationRejected: 'Post rejected',
  PostTranslationKeys.moderationReview: 'Review required',
  'Nổi bật': 'Top',
  'Mới nhất': 'Latest',
  'Đăng': 'Post',
  'Người theo dõi': 'Followers',
  'Thư viện video': 'Video library',
  'Hiển thị trong bảng tin công khai': 'Visible in the public feed',
  'Chỉ người theo dõi bạn mới xem': 'Only your followers can view this post',
  'Chỉ lưu cho bạn, không lên bảng tin công khai':
      'Only you can view this post',
  'Chỉ người theo dõi bạn mới xem.': 'Only your followers can view this post.',
  'Chỉ bạn xem được bài viết này.': 'Only you can view this post.',
  'Hủy đăng lại': 'Undo repost',
  'Đăng lại': 'Repost',
  'Xóa bài đăng lại này khỏi hồ sơ của bạn.':
      'Remove this repost from your profile.',
  'Đăng lại bài viết này trên hồ sơ của bạn.': 'Repost this to your profile.',
  'Viết bài của bạn kèm bài viết gốc.':
      'Add your thoughts to the original post.',
  'Cập nhật nội dung, thẻ và tệp đính kèm.':
      'Update the content, tags, and attachments.',
  'Thay đổi ai có thể xem bài viết này.': 'Change who can view this post.',
  'Ẩn bài viết này khỏi trang tin.': 'Hide this post from your feed.',
  'Nhấn lần nữa để bỏ lưu bài viết.':
      'Tap again to remove this post from saved.',
  'Đánh dấu để xem lại sau.': 'Save this post for later.',
  'Chia sẻ liên kết bài viết.': 'Share a link to this post.',
  'Ẩn bài viết từ tác giả này': 'Hide posts from this author',
  'Ẩn toàn bộ bài viết từ người này trong feed.':
      'Hide all posts from this person in your feed.',
  'Xóa vĩnh viễn bài viết này khỏi tài khoản của bạn.':
      'Permanently delete this post from your account.',
  'Báo cáo bài viết': 'Report post',
  'Gửi báo cáo nếu nội dung này không phù hợp.':
      'Report this post if it is inappropriate.',
  'Cập nhật nội dung bình luận của bạn.': 'Update your comment.',
  'Ẩn bình luận': 'Hide comment',
  'Chỉ ẩn bình luận này trên thiết bị của bạn.':
      'Hide this comment on this device only.',
  'Xóa nội dung bình luận, phản hồi con vẫn được giữ.':
      'Delete this comment while keeping its replies.',
  'Bình luận đã xóa': 'Deleted comment',
  'Bình luận này đã bị xóa.': 'This comment has been deleted.',
  'Đang tải phản hồi...': 'Loading replies...',
  'Nhập bình luận...': 'Write a comment...',
  'Bình luận...': 'Comment...',
  'Chỉnh sửa bình luận...': 'Edit comment...',
  'Chỉnh sửa bài viết...': 'Edit your post...',
  'Thêm nhận xét của bạn...': 'Add your thoughts...',
  'Có gì mới?': "What's new?",
  'Chưa có bài viết công khai nào.': 'No public posts yet.',
  'Hãy tạo bài viết mới hoặc kéo xuống để làm mới bảng tin.':
      'Create a post or pull down to refresh your feed.',
  'Chưa có bài viết từ người bạn theo dõi.':
      'No posts from people you follow yet.',
  'Hãy theo dõi thêm người dùng hoặc kéo xuống để làm mới bảng tin.':
      'Follow more people or pull down to refresh your feed.',
  'Đã xảy ra lỗi khi tải bảng tin.':
      'An error occurred while loading the feed.',
  'Bài viết không công khai sẽ không hiển thị trong bảng tin công khai.':
      'Non-public posts will not appear in the public feed.',
  'Đang kiểm duyệt video': 'Video under review',
  'Bài viết sẽ hiển thị theo quyền riêng tư đã chọn sau khi video được duyệt.':
      'The post will follow your selected privacy setting after the video is approved.',
  'Đã ẩn bài viết khỏi bảng tin của bạn.': 'Post hidden from your feed.',
  'Đã xóa bài viết.': 'Post deleted.',
  'Đã đăng lại bài viết thành công.': 'Post reposted.',
  'Đã hủy đăng lại bài viết.': 'Repost removed.',
  'Đã lưu bài viết vào lưu trữ.': 'Post saved.',
  'Đã bỏ lưu bài viết.': 'Post removed from saved.',
  'Đã ẩn bình luận này khỏi thiết bị của bạn.':
      'Comment hidden on this device.',
  'Tính năng chia sẻ sẽ được triển khai ở bước tiếp theo.':
      'Sharing will be available soon.',
  'Tính năng chia sẻ sẽ được cập nhật ở bước tiếp theo.':
      'Sharing will be available soon.',
  'Video đã được duyệt và bài viết có thể hiển thị theo quyền riêng tư đã chọn.':
      'The video was approved and the post now follows your selected privacy setting.',
  'Video vi phạm tiêu chuẩn cộng đồng nên bài viết đã bị ẩn.':
      'The video violated our Community Standards, so the post was hidden.',
  'Video cần được quản trị viên xem xét trước khi hiển thị.':
      'The video needs administrator review before it can be shown.',
  'Đã chặn người dùng này.': 'User blocked.',
  'Đã gỡ chặn người dùng này.': 'User unblocked.',
  'Đã bỏ ẩn bài viết từ người này.': "This person's posts are visible again.",
  'Đã bật lại thông báo từ người này.':
      'Notifications from this person are enabled again.',
  'Không tìm thấy tác giả để chặn.': 'Unable to find the author to block.',
  'Không tìm thấy người dùng này.': 'User not found.',
  'Không tìm thấy bài viết gốc để đăng lại.':
      'The original post could not be found.',
  'Không tìm thấy bài viết gốc để hủy đăng lại.':
      'The original post could not be found to undo the repost.',
  'Không thể tải bảng tin lúc này. Vui lòng thử lại.':
      'Unable to load the feed right now. Please try again.',
  'Không thể xử lý bài viết lúc này. Vui lòng thử lại.':
      'Unable to process this post right now. Please try again.',
  'Không thể xử lý bình luận lúc này. Vui lòng thử lại.':
      'Unable to process this comment right now. Please try again.',
  'Mỗi bài viết chỉ có thể đăng 1 video.':
      'Each post can contain only one video.',
  'Mỗi bài viết chỉ có thể đăng 1 video. Chỉ video đầu tiên được thêm.':
      'Each post can contain only one video. Only the first video was added.',
  'Cần quyền microphone để ghi âm.':
      'Microphone access is required to record audio.',
  'Bài viết cần có nội dung hoặc tệp đính kèm.':
      'Add some content or an attachment before posting.',
  'Nội dung bài viết không được vượt quá 300 ký tự.':
      'Post content cannot exceed 300 characters.',
  'Video không được nặng quá 150MB.': 'The video cannot exceed 150 MB.',
  'Video chỉ được dài tối đa 1 phút.':
      'The video cannot be longer than one minute.',
  'Bạn cần đăng nhập để bình luận.': 'Log in to comment.',
  'Bạn cần đăng nhập để chỉnh sửa bình luận.': 'Log in to edit your comment.',
  'Không thể chọn ảnh lúc này.': 'Unable to select a photo right now.',
  'Vui lòng chọn lý do báo cáo.': 'Choose a reason for reporting.',
  'Phiên đăng nhập đã hết hạn. Vui lòng thử lại.':
      'Your session has expired. Please try again.',
  'Không tìm thấy tác giả bài viết.': 'Post author not found.',
  'Vui lòng nhập lý do cụ thể.': 'Enter a specific reason.',
  'Không thể gửi báo cáo. Vui lòng thử lại.':
      'Unable to submit the report. Please try again.',
  'Bạn cần đăng nhập để chỉnh sửa bài viết.': 'Log in to edit this post.',
  'Không tìm thấy bài viết để chỉnh sửa.': 'The post to edit was not found.',
  'Bài viết không còn tồn tại.': 'This post no longer exists.',
  'Bạn cần đăng nhập để đăng lại bài viết.': 'Log in to repost.',
  'Bạn đã đăng lại bài viết này rồi.': 'You already reposted this post.',
  'Bạn cần đăng nhập để hủy đăng lại.': 'Log in to undo this repost.',
  'Bạn chưa đăng lại bài viết này.': "You haven't reposted this post.",
  'Bạn cần đăng nhập để xóa bài viết.': 'Log in to delete this post.',
  'Không tìm thấy bài viết để xóa.': 'The post to delete was not found.',
  'Bạn không thể xóa bài viết này.': "You can't delete this post.",
  'Bạn cần đăng nhập để đăng bài viết.': 'Log in to create a post.',
  'Bạn cần đăng nhập để lưu bài viết.': 'Log in to save this post.',
  'Bài viết này không còn khả dụng.': 'This post is no longer available.',
  'Nội dung bình luận không được để trống.': 'Comment content cannot be empty.',
  'Bình luận không được vượt quá 300 ký tự.':
      'Comments cannot exceed 300 characters.',
  'Không tìm thấy bình luận gốc để trả lời.':
      'The original comment was not found.',
  'Không thể trả lời bình luận đã bị xóa.':
      "You can't reply to a deleted comment.",
  'Bình luận không còn tồn tại.': 'This comment no longer exists.',
  'Bạn cần đăng nhập để xóa bình luận.': 'Log in to delete a comment.',
  'Bạn không thể xóa bình luận này.': "You can't delete this comment.",
  'Đăng bài viết lặp lại nhiều lần': 'Repeatedly posting the same content',
  'Bình luận spam dưới nhiều bài viết': 'Spam comments across multiple posts',
  'Gửi tin nhắn quảng cáo hàng loạt': 'Sending bulk promotional messages',
  'Chia sẻ liên kết không rõ nguồn gốc': 'Sharing links from unknown sources',
  'Tạo nhiều tài khoản để spam': 'Creating multiple accounts to spam',
  'Nội dung chỉ nhằm quảng cáo, không có giá trị tương tác':
      'Purely promotional content with no meaningful interaction',
  'Khác (Người dùng có thể nhập vào)': 'Other (you can describe it)',
  'Giả mạo người khác': 'Impersonation',
  'Giả mạo người nổi tiếng': 'Impersonating a public figure',
  'Giả mạo bạn bè hoặc người quen': 'Impersonating a friend or acquaintance',
  'Sử dụng ảnh đại diện của người khác': "Using someone else's profile photo",
  'Dùng tên hoặc thông tin cá nhân của người khác':
      "Using someone else's name or personal information",
  'Giả mạo thương hiệu, tổ chức hoặc cộng đồng':
      'Impersonating a brand, organization, or community',
  'Tạo tài khoản giống tài khoản thật để gây nhầm lẫn':
      'Creating a lookalike account to mislead people',
  'Quấy rối hoặc xúc phạm': 'Harassment or insults',
  'Chửi bới, xúc phạm cá nhân': 'Insulting or verbally abusing someone',
  'Đe dọa hoặc gây áp lực tinh thần': 'Threats or emotional pressure',
  'Quấy rối qua tin nhắn riêng': 'Harassment through private messages',
  'Công kích ngoại hình, giới tính, vùng miền hoặc cá nhân':
      'Attacks based on appearance, gender, region, or identity',
  'Bình luận tiêu cực lặp lại nhiều lần': 'Repeated negative comments',
  'Kêu gọi người khác tấn công một tài khoản':
      'Encouraging others to target an account',
  'Nội dung không phù hợp': 'Inappropriate content',
  'Hình ảnh hoặc video phản cảm trên trang cá nhân':
      'Offensive images or videos',
  'Nội dung bạo lực hoặc gây khó chịu': 'Violent or disturbing content',
  'Nội dung kích động thù ghét': 'Hateful content',
  'Ngôn từ thô tục, thiếu văn minh': 'Abusive or vulgar language',
  'Nội dung không phù hợp với độ tuổi người dùng': 'Age-inappropriate content',
  'Thông tin trên hồ sơ gây hiểu nhầm hoặc sai sự thật':
      'Misleading or false profile information',
  'Lừa đảo': 'Scam or fraud',
  'Lừa đảo chuyển tiền': 'Money transfer scam',
  'Giả danh để xin thông tin cá nhân':
      'Impersonation to obtain personal information',
  'Gửi đường link đánh cắp tài khoản': 'Sending account-stealing links',
  'Rao bán sản phẩm hoặc dịch vụ không uy tín':
      'Selling untrustworthy products or services',
  'Hứa hẹn phần thưởng giả': 'Promising fake rewards',
  'Mạo danh nhân viên hỗ trợ hoặc quản trị viên':
      'Impersonating support staff or administrators',
  'Hành vi đáng ngờ': 'Suspicious behavior',
  'Vi phạm quy định cộng đồng': 'Community Guidelines violation',
  'Tài khoản có hoạt động bất thường': 'Unusual account activity',
  'Nội dung gây khó chịu nhưng không thuộc mục trên':
      'Disturbing content not covered above',
  'Lý do khác do người dùng tự nhập': 'Another reason you provide',
  'Ẩn bài viết này': 'Hide this post',
  'Ẩn bài viết này khỏi feed của bạn.': 'Hide this post from your feed.',
  'Ẩn toàn bộ bài viết của họ': 'Hide all their posts',
  'Ẩn tất cả bài viết từ người dùng này trong feed.':
      'Hide all posts from this user in your feed.',
  'Bạn sẽ không còn thấy hồ sơ, bài viết và tin nhắn từ tài khoản này.':
      'You will no longer see this account, its posts, or its messages.',
  'Bài viết này không có nội dung văn bản.': 'This post has no text content.',
  'Bạn có thể bổ sung bối cảnh hoặc dấu hiệu cụ thể để đội ngũ kiểm duyệt xem xét chính xác hơn.':
      'Add context or specific details to help our moderation team review this accurately.',
  'Không thể tải Danh sách hạn chế lúc này. Vui lòng thử lại.':
      'Unable to load restricted accounts right now. Please try again.',
  'Video đang được kiểm duyệt. Bài viết sẽ hiển thị sau khi được duyệt.':
      'The video is under review. The post will appear after approval.',
  'Mục chi tiết': 'Details',
  'Lý do cụ thể': 'Specific reason',
};

String postTr(String source) {
  final exact = source.tr;
  if (exact != source || Get.locale?.languageCode != 'en') return exact;
  const commonErrors = <String, String>{
    'Lỗi kết nối mạng. Vui lòng kiểm tra Internet.':
        'Network error. Check your internet connection.',
    'Lỗi hệ thống Firebase.': 'A system error occurred.',
    'Hết thời gian chờ phản hồi.': 'The request timed out.',
    'Dịch vụ Firebase tạm thời không khả dụng.':
        'The service is temporarily unavailable.',
    'Bạn không có quyền truy cập dữ liệu này.':
        "You don't have permission to access this data.",
    'Không tìm thấy dữ liệu.': 'Data not found.',
    'Dữ liệu đã tồn tại.': 'This data already exists.',
    'Đã xảy ra lỗi không xác định. Vui lòng thử lại.':
        'An unexpected error occurred. Please try again.',
  };
  final commonError = commonErrors[source];
  if (commonError != null) return commonError;
  final patterns = <(RegExp, String Function(Match))>[
    (RegExp(r'^(.+) đã đăng lại$'), (m) => '${m[1]} reposted'),
    (RegExp(r'^Đang trả lời (.+)$'), (m) => 'Replying to ${m[1]}'),
    (RegExp(r'^Ẩn (\d+) phản hồi$'), (m) => 'Hide ${m[1]} replies'),
    (RegExp(r'^Ẩn bài viết từ @(.+)$'), (m) => 'Hide posts from @${m[1]}'),
    (RegExp(r'^Ẩn bài viết từ (.+)\?$'), (m) => 'Hide posts from ${m[1]}?'),
    (RegExp(r'^Bài viết của (.+)$'), (m) => "${m[1]}'s post"),
    (
      RegExp(r'^Bài viết có (\d+) tệp đính kèm\.$'),
      (m) => 'This post has ${m[1]} attachments.',
    ),
    (
      RegExp(r'^Chọn một hành động tiếp theo với (.+) rồi bấm xác nhận\.$'),
      (m) => 'Choose what to do with ${m[1]}, then confirm.',
    ),
    (RegExp(r'^Đã xóa (.+)$'), (m) => 'Deleted ${m[1]}'),
    (RegExp(r'^Chỉnh sửa (.+)$'), (m) => 'Edited ${m[1]}'),
    (
      RegExp(r'^Đã ẩn bài viết từ (.+)\.$'),
      (m) => 'Posts from ${m[1]} have been hidden.',
    ),
    (
      RegExp(r'^Chỉ có thể đăng tối đa (\d+) tệp đính kèm cho mỗi bài viết\.$'),
      (m) => 'Each post can contain up to ${m[1]} attachments.',
    ),
    (
      RegExp(r'^Không thể chọn ảnh lúc này: (.+)$'),
      (m) => 'Unable to select a photo: ${m[1]}',
    ),
    (
      RegExp(r'^Không thể chụp ảnh lúc này: (.+)$'),
      (m) => 'Unable to take a photo: ${m[1]}',
    ),
    (
      RegExp(r'^Không thể chọn video lúc này: (.+)$'),
      (m) => 'Unable to select a video: ${m[1]}',
    ),
    (
      RegExp(r'^Không thể quay video lúc này: (.+)$'),
      (m) => 'Unable to record a video: ${m[1]}',
    ),
    (
      RegExp(r'^Không thể bắt đầu ghi âm lúc này: (.+)$'),
      (m) => 'Unable to start recording: ${m[1]}',
    ),
    (
      RegExp(r'^Không thể lưu ghi âm lúc này: (.+)$'),
      (m) => 'Unable to save the recording: ${m[1]}',
    ),
  ];
  for (final (pattern, replacement) in patterns) {
    final match = pattern.firstMatch(source);
    if (match != null) return replacement(match);
  }
  return source;
}
