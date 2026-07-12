"use strict";

// Every entry is intentionally hand-written Vietnamese test content. The seed
// runner rotates the entries instead of producing near-duplicate sentences.
const CONTENT_BY_TOPIC = Object.freeze({
  "học-tập": [
    "Mình vừa thử học 25 phút rồi nghỉ 5 phút, bất ngờ là đỡ mất tập trung hẳn. Có bạn nào duy trì Pomodoro lâu dài không? 📚",
    "Tuần thi đến rồi. Mình chia mỗi môn thành ba phần: phải biết, nên biết và đọc thêm; làm phần khó nhất vào buổi sáng.",
    "Một mẹo nhỏ: sau mỗi chương, hãy tự viết năm câu hỏi mà không nhìn tài liệu.\n\nNếu trả lời chưa trôi chảy thì đó chính là phần cần ôn lại. Mình thường quay lại sau một ngày để kiểm tra lần nữa. #hoctap",
  ],
  "công-nghệ": [
    "Điện thoại gập trông rất thú vị, nhưng với sinh viên thì pin tốt và dùng bền vẫn quan trọng hơn thiết kế lạ.",
    "Bạn mong tính năng công nghệ nào trở nên phổ biến trong trường học nhất: bảng thông minh, trợ lý học tập hay thư viện số?",
    "Mình vừa dọn lại quyền truy cập của các ứng dụng và phát hiện khá nhiều app không cần dùng micro. Mọi người nhớ kiểm tra quyền riêng tư định kỳ nhé. 🔐",
  ],
  "lập-trình": [
    "Bug khó nhất hôm nay hóa ra chỉ là một dấu ngoặc đặt sai chỗ 😅",
    "Kinh nghiệm của mình khi đọc code cũ: chạy được test trước, vẽ lại luồng dữ liệu, rồi mới sửa từng phần nhỏ. Cách này chậm lúc đầu nhưng ít tạo lỗi dây chuyền.",
    "Nếu mới học lập trình, bạn chọn làm dự án nhỏ hoàn chỉnh hay học hết lý thuyết rồi mới bắt tay viết code? #coding",
  ],
  flutter: [
    "Flutter hot reload cứu mình một buổi chiều.",
    "Mình đang tách widget lớn thành các phần theo trách nhiệm thay vì theo kích thước. Code dễ đọc hơn và rebuild cũng dễ kiểm soát hơn.",
    "Có ai từng gặp danh sách cuộn bị giật vì xử lý ảnh trong build chưa? Mình chuyển phần nặng ra service và thêm cache thì cải thiện rõ rệt. #Flutter",
  ],
  firebase: [
    "Firestore Emulator đúng là người bạn tốt trước mỗi lần sửa security rules.",
    "Một bài học nhớ đời: counter và document tương tác phải cập nhật cùng transaction, nếu không số lượt thích rất dễ lệch khi mạng chập chờn.",
    "Mọi người thường tổ chức index Firestore theo màn hình truy vấn hay theo domain? Mình đang tìm cách giữ file index dễ bảo trì hơn. #Firebase",
  ],
  ai: [
    "AI giúp tóm tắt tài liệu nhanh, nhưng mình vẫn kiểm tra lại nguồn trước khi đưa vào bài làm.",
    "Theo bạn, kỹ năng quan trọng nhất khi dùng trợ lý AI là đặt câu hỏi rõ ràng hay biết đánh giá câu trả lời?",
    "Mình thử dùng AI để gợi ý dàn ý, sau đó tự viết lại bằng trải nghiệm của mình. Cách này vừa tiết kiệm thời gian vừa không làm mất giọng văn cá nhân. 🤖",
  ],
  "âm-nhạc": [
    "Một chiếc playlist nhẹ vào sáng mưa là đủ để tâm trạng tốt hơn. 🎧",
    "Mình thích nghe trọn một album theo thứ tự bài hát vì cảm giác như theo dõi một câu chuyện. Bạn thường nghe album hay bật ngẫu nhiên?",
    "Góc tìm nhạc mới: mỗi người để lại một bài đang nghe lặp lại tuần này nhé. Mình sẽ gom thành playlist chung. #amnhac",
  ],
  "phim-ảnh": [
    "Có bộ phim nào xem lần hai lại hay hơn lần đầu không?",
    "Tối qua mình xem một phim có nhịp rất chậm nhưng phần hình ảnh đẹp đến mức không muốn tua. Đôi khi không cần cao trào liên tục vẫn cuốn.",
    "Bình chọn cuối tuần: ra rạp xem phim phiêu lưu hay ở nhà cày một mini series sáu tập? 🍿",
  ],
  "bóng-đá": [
    "Trận bóng hay nhất là trận khiến cả nhóm chat im lặng ở phút bù giờ rồi cùng nổ tung vì bàn thắng.",
    "Mình thích xem một đội trẻ phối hợp tự tin hơn là chỉ chờ khoảnh khắc của ngôi sao. Mọi người quan tâm chiến thuật hay cầu thủ hơn?",
    "Kèo vui không phần thưởng: dự đoán tỉ số trận tối nay và chọn cầu thủ ghi bàn đầu tiên. ⚽ #bongda",
  ],
  "thể-thao": [
    "Chạy chậm vẫn là chạy. Hôm nay thêm được 500 mét so với tuần trước!",
    "Mình từng tập quá hăng rồi bỏ cuộc. Giờ chỉ đặt mục tiêu vận động 20 phút mỗi ngày, nhỏ nhưng đều và dễ duy trì hơn.",
    "Nếu chỉ được chọn một môn để chơi cùng bạn bè cuối tuần, bạn chọn cầu lông, bóng rổ hay đạp xe? 🏸",
  ],
  "du-lịch": [
    "Đi đâu không quan trọng bằng đi cùng người hợp gu.",
    "Mình hay lưu bản đồ offline, mang bình nước và chừa một buổi không có lịch trình. Chính khoảng trống đó thường tạo ra kỷ niệm hay nhất.",
    "Xin gợi ý một nơi đi hai ngày một đêm, ưu tiên nhiều cây xanh và có thể di chuyển bằng xe khách từ thành phố. #dulich",
  ],
  "đồ-ăn": [
    "Cơm nóng với trứng chiên vào ngày bận rộn vẫn là chân ái.",
    "Mình thử nấu mì trộn với rau, nấm và một quả trứng. Tổng thời gian chưa tới 15 phút mà đủ no cho buổi học tối.",
    "Bình chọn món ăn khuya: bánh mì, cháo hay mì? Đừng trả lời là cả ba nhé 😄 #food",
  ],
  "thời-trang": [
    "Mặc đồ khiến mình thoải mái thì tự nhiên sẽ tự tin hơn.",
    "Tủ đồ của mình ít món hơn sau khi chọn một bảng màu cố định. Áo quần phối được nhiều cách, sáng cũng đỡ mất thời gian suy nghĩ.",
    "Các bạn có mẹo giữ giày trắng sạch trong mùa mưa không? Mình cần một giải pháp nhanh cho lịch học dày. #thoitrang",
  ],
  "nhiếp-ảnh": [
    "Ánh sáng cửa sổ và một góc phòng gọn gàng đã đủ cho bức ảnh đẹp.",
    "Mình tập chụp cùng một con đường ở ba thời điểm trong ngày. Màu sắc và cảm xúc khác nhau nhiều hơn mình tưởng.",
    "Thử thách ảnh tuần này: kể một câu chuyện chỉ bằng ba khung hình, không cần máy xịn. Ai tham gia không? 📷",
  ],
  "trò-chơi": [
    "Chơi game co-op vui nhất là lúc cả đội cùng xử lý một pha hỏng kế hoạch.",
    "Mình thích game có thế giới nhỏ nhưng nhiều chi tiết hơn bản đồ rộng mà trống. Cảm giác khám phá bí mật rất đã.",
    "Tối nay team mình thiếu một người cho ván giải trí, ưu tiên vui vẻ và không áp lực thắng thua. Có ai tham gia không? 🎮",
  ],
  sách: [
    "Một cuốn sách đúng lúc có thể giống như cuộc trò chuyện mình đang cần.",
    "Mình bắt đầu ghi lại một câu ấn tượng sau mỗi buổi đọc. Sau một tháng, cuốn sổ nhỏ đã thành bản đồ suy nghĩ rất thú vị.",
    "Bạn có cuốn sách nào dưới 250 trang, dễ đọc nhưng vẫn khiến mình suy nghĩ lâu không? Xin một đề cử cho cuối tuần. #docsach",
  ],
  "tâm-sự": [
    "Hôm nay không năng suất lắm, nhưng mình đã cho bản thân được nghỉ mà không thấy có lỗi.",
    "Có những lúc mình thấy mọi người tiến rất nhanh còn mình đứng yên. Sau đó nhìn lại, mình vẫn đang đi, chỉ là theo nhịp riêng.",
    "Mọi người làm gì khi đầu óc quá đầy nhưng chưa sẵn sàng kể với ai? Mình thường đi bộ một vòng rồi viết ra giấy.",
  ],
  "tình-bạn": [
    "Bạn tốt là người gửi ảnh dìm nhưng vẫn có mặt khi mình cần. 😄",
    "Nhóm mình không nói chuyện mỗi ngày, nhưng gặp lại vẫn tự nhiên như chưa từng xa. Có lẽ tình bạn bền không cần lúc nào cũng ồn ào.",
    "Nếu thấy bạn thân đang thu mình, nên chủ động hỏi thẳng hay cho bạn ấy thêm không gian? Mình muốn quan tâm mà không gây áp lực.",
  ],
  "tình-yêu": [
    "Sự rõ ràng đôi khi lãng mạn hơn mọi lời đoán ý.",
    "Mình nghĩ một mối quan hệ tốt không làm hai người giống hệt nhau, mà giúp cả hai thấy an toàn khi khác biệt.",
    "Theo bạn, điều quan trọng hơn khi bắt đầu tìm hiểu là có nhiều sở thích chung hay cách giao tiếp hợp nhau? #chuyentinhcam",
  ],
  "đời-sống-sinh-viên": [
    "Niềm vui sinh viên: tiết cuối được nghỉ và xe buýt vừa tới. ✨",
    "Tháng này mình thử chia tiền thành bốn khoản ngay khi nhận: ăn uống, đi lại, học tập và dự phòng. Cuối tháng bớt cảnh nhìn ví rồi thở dài.",
    "Có câu lạc bộ nào bạn tham gia chỉ vì tò mò nhưng sau đó lại gắn bó lâu dài không? Kể mình nghe với. #sinhvien",
  ],
  "việc-làm": [
    "Một CV rõ ràng quan trọng hơn một CV có thật nhiều màu.",
    "Mình vừa sửa CV theo hướng nêu kết quả thay vì chỉ liệt kê nhiệm vụ.\n\nỞ mỗi dự án, mình ghi vấn đề, việc đã làm và kết quả đo được. Ví dụ nhỏ cùng con số cụ thể khiến câu chuyện thuyết phục hơn hẳn.",
    "Khi mới ra trường, bạn ưu tiên môi trường học được nhiều hay mức lương khởi điểm? Mình biết lý tưởng là có cả hai, nhưng nếu phải chọn thì sao?",
  ],
  "thực-tập": [
    "Ngày thực tập đầu tiên: hỏi đúng người quan trọng hơn cố tự đoán mọi thứ.",
    "Mình ghi lại các từ viết tắt và quy trình lạ trong tuần đầu. Đến cuối tuần đọc lại, cảm giác bớt ngợp và biết mình cần hỏi gì tiếp theo.",
    "Anh chị có lời khuyên nào để xin phản hồi từ mentor mà không chờ đến cuối kỳ thực tập không? #internship",
  ],
  "mẹo-cuộc-sống": [
    "Đặt đồ cần mang ra cạnh cửa từ tối hôm trước, sáng hôm sau nhẹ đầu hẳn.",
    "Mình dùng quy tắc hai phút: việc nào làm dưới hai phút thì xử lý ngay. Hộp thư gọn hơn và những việc nhỏ không còn bám theo cả ngày.",
    "Chia sẻ một mẹo tiết kiệm thời gian thật sự hiệu quả với bạn đi. Mình đang gom ý tưởng để thử trong tuần mới. #lifehack",
  ],
  "tin-cộng-đồng": [
    "Cuối tuần này thư viện trường có buổi đổi sách cũ, mang một cuốn đến và chọn một cuốn mang về.",
    "Nhóm tình nguyện đang cần người phân loại đồ dùng học tập vào sáng thứ bảy. Ai rảnh có thể đăng ký theo thông báo chính thức của câu lạc bộ.",
    "Khu tự học tầng ba sẽ đóng sớm hơn một giờ để bảo trì trong hôm nay. Mọi người chủ động chuyển sang phòng bên cạnh nhé. #congdong",
  ],
  "thảo-luận": [
    "Điểm số phản ánh kiến thức đến mức nào?",
    "Mình muốn mở một cuộc thảo luận nhỏ: học nhóm hiệu quả nhất khi mọi người cùng trình độ hay khi có sự chênh lệch để hỗ trợ nhau?",
    "Bình chọn nhanh: bài giảng trực tiếp, video ngắn hay tài liệu chữ giúp bạn nhớ lâu nhất? Hãy nói thêm lý do nếu có. #thaoluan",
  ],
  "hài-hước": [
    "Mình: ngủ sớm nhé. Cũng là mình lúc 1 giờ sáng: xem cách chim cánh cụt đi bộ. 😅",
    "Deadline không tự chạy, nhưng kỳ lạ là nó luôn đuổi kịp mình.",
    "Bình chọn tình huống sinh viên đáng sợ nhất: Wi-Fi mất trước giờ nộp bài, máy in hết giấy hay giảng viên nói “phần này dễ”?",
  ],
  "truyền-cảm-hứng": [
    "Chậm một chút không có nghĩa là đi sai hướng.",
    "Một năm trước mình còn sợ bắt đầu vì nghĩ chưa đủ giỏi.\n\nBây giờ dự án vẫn chưa hoàn hảo, nhưng nó đã tồn tại. Mỗi lần sửa một chi tiết nhỏ, mình lại thấy quyết định bắt đầu ngày ấy thật đáng giá.",
    "Nếu hôm nay chỉ làm được một việc nhỏ cho mục tiêu dài hạn, việc đó vẫn đáng tính. Tiến bộ không cần lúc nào cũng ồn ào. 🌱 #dongluc",
  ],
  "sức-khỏe": [
    "Mình bắt đầu để chai nước ngay cạnh bàn làm việc và bất ngờ là uống đủ nước dễ hơn hẳn.",
    "Có ai duy trì thói quen ngủ trước 11 giờ được lâu chưa? Mình đang thử giảm màn hình từ 10 giờ tối.",
    "Một buổi đi bộ nhẹ không giải quyết hết mọi chuyện, nhưng thường giúp mình bình tĩnh để nhìn vấn đề rõ hơn.",
    "Tuần này mình ưu tiên ba việc đơn giản: ngủ đủ, ăn đúng bữa và vận động mỗi ngày một chút.",
  ],
  "nấu-ăn": [
    "Bữa tối hôm nay chỉ có cơm, rau xào và trứng nhưng trình bày đẹp một chút là tự nhiên thấy ngon hơn.",
    "Mình vừa học cách nêm từng ít một thay vì cho tất cả gia vị ngay từ đầu. Món ăn dễ cứu hơn rất nhiều.",
    "Có món nào nấu dưới 20 phút mà vẫn đủ rau và đạm không? Cho mình xin ý tưởng cho tuần bận rộn.",
    "Cuối tuần mình định nấu một nồi lớn rồi chia phần cho ba ngày. Mọi người thường chuẩn bị món gì để không bị ngán?",
  ],
  "cà-phê": [
    "Một góc cửa sổ, ly cà phê ít đá và playlist quen thuộc là đủ cho buổi sáng dễ chịu.",
    "Mình đang tập phân biệt vị chua tự nhiên và vị đắng của cà phê, càng uống chậm càng thấy nhiều tầng vị.",
    "Bạn thích quán yên tĩnh để làm việc hay quán đông vui để trò chuyện? Mình chọn khác nhau tùy ngày.",
    "Hôm nay thử gọi món không quen và bất ngờ lại tìm được đồ uống mới hợp gu.",
  ],
  "thú-cưng": [
    "Bé mèo nhà mình có thể ngủ cả ngày nhưng đúng lúc mình họp là bắt đầu chạy vòng quanh phòng.",
    "Nuôi thú cưng dạy mình kiên nhẫn với những tiến bộ rất nhỏ, từ một bữa ăn đúng giờ đến lần đầu chịu cắt móng.",
    "Mọi người có mẹo nào giúp chó bớt lo khi nghe tiếng sấm không? Mình muốn chuẩn bị tốt hơn trước mùa mưa.",
    "Khoảnh khắc vui nhất hôm nay là được một bạn mèo lạ ngoài ngõ chủ động đến cọ chân.",
  ],
  "ngoại-ngữ": [
    "Mình đổi ngôn ngữ điện thoại sang tiếng Anh một tuần và học được khá nhiều từ dùng hàng ngày.",
    "Thay vì học danh sách từ rời, mình đang ghi cả câu có ngữ cảnh. Lúc nói nhớ ra nhanh hơn hẳn.",
    "Có ai muốn lập nhóm luyện nói 15 phút mỗi tối không? Ưu tiên sửa nhẹ nhàng và không ngại sai.",
    "Hôm nay mình nghe lại một đoạn podcast ba lần: lần đầu hiểu ý, lần hai ghi từ mới, lần ba nhại theo ngữ điệu.",
  ],
  "tài-chính-cá-nhân": [
    "Mình bắt đầu ghi chi tiêu theo nhóm thay vì nhớ trong đầu. Chỉ một tuần đã thấy rõ khoản nào đang vượt kế hoạch.",
    "Quỹ dự phòng nghe xa vời, nên mình đặt mục tiêu nhỏ là đủ cho một tuần trước rồi mới tăng dần.",
    "Mọi người thường quyết định một món đồ là nhu cầu hay mong muốn bằng cách nào? Mình đang thử chờ 48 giờ trước khi mua.",
    "Tháng này mình đặt ngân sách vui chơi riêng để tiêu thoải mái trong giới hạn mà không thấy có lỗi.",
  ],
  "khởi-nghiệp": [
    "Ý tưởng chỉ bắt đầu rõ khi mình nói chuyện với người thực sự gặp vấn đề đó, không phải khi ngồi chỉnh slide.",
    "Nhóm mình vừa bỏ một tính năng đã làm hai tuần vì người dùng không cần. Tiếc nhưng bài học rất đáng giá.",
    "Nếu có một tuần để kiểm chứng ý tưởng mới, bạn sẽ làm landing page, prototype hay phỏng vấn người dùng trước?",
    "Mình thích những sản phẩm giải quyết một việc nhỏ thật tốt hơn là cố làm mọi thứ ngay phiên bản đầu.",
  ],
  "thiết-kế": [
    "Một giao diện đẹp nhưng người dùng không biết bấm đâu thì vẫn chưa hoàn thành nhiệm vụ của thiết kế.",
    "Mình đang thử thiết kế màn hình ở trạng thái rỗng, lỗi và loading trước khi làm trạng thái đẹp nhất.",
    "Khoảng trắng không phải chỗ bị bỏ phí; dùng đúng thì nội dung dễ thở và dễ đọc hơn nhiều.",
    "Bạn thường bắt đầu một màn hình mới từ wireframe đen trắng hay chọn màu và typography trước?",
  ],
  "khoa-học": [
    "Đọc một nghiên cứu thú vị nhất ở phần phương pháp, vì nó cho biết kết luận được xây trên dữ liệu như thế nào.",
    "Mình vừa xem video giải thích vì sao bầu trời đổi màu lúc hoàng hôn và thấy những điều quen thuộc bỗng mới mẻ.",
    "Có chủ đề khoa học nào bạn từng nghĩ rất khó nhưng sau một lời giải thích đúng cách lại trở nên dễ hiểu không?",
    "Tuần này mình thử kiểm tra nguồn gốc của một thông tin trước khi chia sẻ, mất thêm vài phút nhưng yên tâm hơn.",
  ],
  "môi-trường": [
    "Mình mang theo túi vải không phải lúc nào cũng nhớ, nên để sẵn một chiếc trong balô và một chiếc cạnh cửa.",
    "Sống xanh với mình bắt đầu từ dùng hết đồ đang có, không phải mua ngay một bộ sản phẩm mới.",
    "Khu mình ở vừa có điểm thu gom pin cũ. Mọi người nhớ tách riêng thay vì bỏ chung với rác sinh hoạt nhé.",
    "Nếu mỗi người chọn một thói quen giảm rác dễ duy trì nhất, bạn sẽ bắt đầu từ việc nào?",
  ],
  "chuyện-công-sở": [
    "Một cuộc họp tốt nên kết thúc bằng việc ai làm gì và khi nào hoàn thành, nếu không rất dễ họp lại lần nữa.",
    "Mình đang tập phản hồi vào công việc cụ thể thay vì đánh giá con người. Không khí trao đổi nhẹ hơn nhiều.",
    "Có cách nào từ chối thêm việc khi lịch đã đầy mà vẫn rõ ràng và tôn trọng không? Cho mình xin kinh nghiệm.",
    "Hôm nay đồng đội chủ động ghi lại bối cảnh của một quyết định nhỏ, vài tuần sau đọc lại thấy cực kỳ hữu ích.",
  ],
  "gia-đình": [
    "Một cuộc gọi ngắn hỏi thăm đôi khi ý nghĩa hơn việc chờ đến lúc có thật nhiều chuyện mới liên lạc.",
    "Nhà mình có thói quen ăn chung một bữa cuối tuần, không cần món cầu kỳ nhưng ai cũng cố gắng có mặt.",
    "Càng lớn mình càng hiểu nhiều lời nhắc của bố mẹ xuất phát từ lo lắng, dù cách thể hiện đôi lúc chưa khéo.",
    "Mọi người có hoạt động gia đình nào đơn giản nhưng duy trì được nhiều năm không?",
  ],
  "sự-kiện": [
    "Cuối tuần có phiên chợ sáng tạo nhỏ, mình định đi sớm để xem các gian thủ công và tránh quá đông.",
    "Buổi workshop hôm nay hay nhất ở phần mọi người tự làm và nhận phản hồi, không chỉ ngồi nghe lý thuyết.",
    "Ai quan tâm công nghệ và thiết kế có muốn đi sự kiện cùng không? Mình thích có người trao đổi sau mỗi phiên.",
    "Mình vừa đăng ký một hoạt động cộng đồng dù chưa quen ai. Hy vọng sẽ mang về vài câu chuyện mới.",
  ],
});

const TOPIC_GROUPS = Object.freeze([
  ["công-nghệ", "lập-trình", "flutter", "firebase", "ai"],
  ["âm-nhạc", "phim-ảnh", "nhiếp-ảnh", "sách", "trò-chơi"],
  ["bóng-đá", "thể-thao"],
  ["du-lịch", "đồ-ăn", "thời-trang", "mẹo-cuộc-sống"],
  ["học-tập", "đời-sống-sinh-viên", "việc-làm", "thực-tập"],
  ["tâm-sự", "tình-bạn", "tình-yêu", "truyền-cảm-hứng"],
  ["tin-cộng-đồng", "thảo-luận", "hài-hước"],
  ["sức-khỏe", "nấu-ăn", "cà-phê", "thú-cưng"],
  ["ngoại-ngữ", "tài-chính-cá-nhân", "khởi-nghiệp", "chuyện-công-sở"],
  ["thiết-kế", "khoa-học", "môi-trường", "sự-kiện", "gia-đình"],
]);

const TOPICS = Object.freeze(Object.keys(CONTENT_BY_TOPIC));

module.exports = { CONTENT_BY_TOPIC, TOPIC_GROUPS, TOPICS };
