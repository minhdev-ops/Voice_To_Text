# SOFTWARE REQUIREMENTS SPECIFICATION (SRS) – VIETVOICE

*Ứng dụng chuyển giọng nói tiếng Việt thành văn bản offline và hỗ trợ ghi chép cuộc họp – Phiên bản 1.1 – 31/10/2026 – Android và iOS (Flutter) – Trạng thái: bản đặc tả đầy đủ, chờ xét duyệt*

## Kiểm soát tài liệu

| Phiên bản | Ngày | Nội dung |
| --- | --- | --- |
| 1.0 | – | Bản đặc tả đề xuất ban đầu. |
| 1.1 | 31/10/2026 | Bản đầy đủ: hợp nhất ưu tiên theo từng yêu cầu, chốt các quyết định thiết kế, định lượng chỉ tiêu, bổ sung yêu cầu còn thiếu, thêm ma trận truy vết. |

### Thay đổi chính so với v1.0

- Mỗi yêu cầu chức năng mang mức ưu tiên (MoSCoW) và giai đoạn triển khai ngay trong mục 3, đồng bộ với mục 12.
- Phát lại, xem chi tiết và đổi tên bản ghi được đưa vào MVP vì cần để kiểm tra kết quả nhận dạng.
- Chốt cách cấp phát mô hình, định dạng ghi âm, giới hạn thời lượng và định nghĩa thiết bị mục tiêu (mục 2.4 và 2.7).
- Định lượng các chỉ tiêu hiệu năng. Các con số là mục tiêu đề xuất, được xác nhận bằng spike kỹ thuật (mục 15).
- Tách trạng thái ghi âm khỏi trạng thái tác vụ nhận dạng; bổ sung các thực thể dữ liệu còn thiếu.
- Bổ sung: ghi âm nền, khôi phục sau sự cố, hàng đợi nhận dạng, tìm kiếm không dấu, xuất đúng font tiếng Việt, onboarding, cài đặt, quản lý dung lượng, bảo mật nâng cao.
- Mô tả đủ 12 màn hình; thêm ma trận truy vết, danh mục mã lỗi và danh sách vấn đề mở.

---

# 1. GIỚI THIỆU

## 1.1. Mục đích tài liệu

Tài liệu mô tả yêu cầu chức năng, phi chức năng, giao diện, dữ liệu và ràng buộc kỹ thuật của hệ thống VietVoice. Tài liệu là cơ sở cho: xác định phạm vi; thiết kế kiến trúc, cơ sở dữ liệu và giao diện; phát triển trên Android và iOS; tích hợp mô hình nhận dạng giọng nói tiếng Việt; kiểm thử, đánh giá hiệu năng và nghiệm thu. Mọi yêu cầu có mã định danh để truy vết giữa yêu cầu, thiết kế, triển khai và kiểm thử (xem mục 17).

## 1.2. Phạm vi sản phẩm

VietVoice là ứng dụng di động ghi âm, nhận dạng giọng nói tiếng Việt thành văn bản và quản lý nội dung hội thoại, theo mô hình **Offline-first**: các chức năng cốt lõi chạy trực tiếp trên thiết bị, không bắt buộc Internet sau khi đã cài đặt mô hình.

**Trong phạm vi:**

- Ghi âm bằng microphone, nhập tệp âm thanh có sẵn.
- Nhận dạng tiếng Việt có dấu, nhiều giọng vùng miền, có từ tiếng Anh xen kẽ.
- Phân biệt lượt nói của các người nói trong hội thoại.
- Chỉnh sửa, tìm kiếm, quản lý bản ghi và văn bản; phát lại đồng bộ theo từng đoạn.
- Xuất TXT, DOCX, PDF; chia sẻ qua hệ điều hành.
- Tạo tóm tắt, quyết định, công việc và biên bản cuộc họp (giai đoạn sau, tùy chọn).

**Ngoài phạm vi (phiên bản 1.x):** tài khoản và đồng bộ đám mây; dịch thuật; bot tự tham gia cuộc họp trực tuyến; xác định danh tính thật của người nói; giao diện tối ưu cho máy tính bảng và máy tính để bàn; nhận dạng các ngôn ngữ chính khác ngoài tiếng Việt (chỉ hỗ trợ từ tiếng Anh xen kẽ).

### 1.2.1. Mục tiêu sản phẩm

| Mã | Mục tiêu | Mô tả |
| --- | --- | --- |
| OBJ-01 | Nhận dạng tiếng Việt | Chuyển giọng nói tiếng Việt thành văn bản có dấu. |
| OBJ-02 | Hoạt động offline | Ghi âm và nhận dạng không cần Internet sau khi cài mô hình. |
| OBJ-03 | Tối ưu thiết bị | Hạn chế RAM, CPU, pin khi xử lý âm thanh. |
| OBJ-04 | Quản lý bản ghi | Lưu trữ và quản lý bản ghi âm cùng nội dung văn bản. |
| OBJ-05 | Nhận dạng hội thoại | Xác định và phân biệt lượt phát biểu của các người nói. |
| OBJ-06 | Hỗ trợ cuộc họp | Tạo tóm tắt, quyết định, danh sách công việc, biên bản. |
| OBJ-07 | Bảo mật dữ liệu | Bảo vệ bản ghi âm và văn bản lưu trên thiết bị. |
| OBJ-08 | Khả năng mở rộng | Thay thế hoặc bổ sung mô hình nhận dạng mà không đổi nghiệp vụ. |

## 1.3. Đối tượng sử dụng tài liệu

| Đối tượng | Mục đích |
| --- | --- |
| Product Owner | Xác định phạm vi, ưu tiên, mục tiêu sản phẩm. |
| Business Analyst | Phân tích và quản lý yêu cầu. |
| UI/UX Designer | Thiết kế giao diện và luồng điều hướng. |
| Developer | Triển khai ứng dụng, tích hợp mô hình AI. |
| Tester/QA | Xây dựng và thực hiện kiểm thử. |
| Giảng viên/người đánh giá | Đánh giá tính đầy đủ và phù hợp của hệ thống. |

## 1.4. Quy ước trình bày

- **Từ ngữ:** “phải” = bắt buộc (Must); “nên” = mong muốn (Should); “có thể” = tùy chọn (Could); “không được” = cấm.
- **Ưu tiên (MoSCoW):** M = Must have, S = Should have, C = Could have.
- **Giai đoạn:** P1 = MVP, P2 = Nâng cao nhận dạng, P3 = Quản lý nội dung, P4 = Trợ lý cuộc họp (xem mục 12).
- **Mục tiêu đề xuất (ĐX):** con số do tài liệu đề xuất, chưa được đo thực tế; phải được xác nhận hoặc điều chỉnh bằng spike kỹ thuật (mục 15) trước khi dùng làm tiêu chí nghiệm thu.
- **Mã yêu cầu:** FR (chức năng), NFR (phi chức năng), BR (nghiệp vụ), UI, UC, DEC (quyết định thiết kế), AT/PT (kiểm thử), RSK (rủi ro), SP (spike), ERR (mã lỗi).

## 1.5. Thuật ngữ và định nghĩa

| Thuật ngữ | Giải thích |
| --- | --- |
| ASR / STT | Automatic Speech Recognition / Speech-to-Text – nhận dạng giọng nói, chuyển giọng nói thành văn bản. |
| Offline-first | Ưu tiên xử lý và lưu trữ dữ liệu trên thiết bị. |
| VAD | Voice Activity Detection – phát hiện đoạn có tiếng nói. |
| Diarization | Phân đoạn lượt nói theo người nói; không xác định danh tính thật. |
| WER / CER | Word / Character Error Rate – tỷ lệ lỗi từ / ký tự. Cách tính cho tiếng Việt xem Phụ lục B. |
| RTF | Real-Time Factor = thời gian xử lý / thời lượng âm thanh. |
| INT8 | Lượng tử hóa mô hình sang số nguyên 8-bit. |
| Chunking | Chia âm thanh thành các đoạn nhỏ để xử lý. |
| Transcript | Văn bản tạo từ âm thanh, gồm nhiều Segment. |
| Segment | Một đoạn (lượt nói/câu) của transcript, có thời gian bắt đầu, kết thúc. |
| Hotword | Từ khóa được ưu tiên khi giải mã, nếu mô hình hỗ trợ. |
| FTS | Full-Text Search – tìm kiếm toàn văn trên cơ sở dữ liệu cục bộ. |
| NFC | Dạng chuẩn hóa Unicode dựng sẵn, bắt buộc để dấu tiếng Việt thống nhất khi lưu và tìm kiếm. |
| Meeting Minutes | Biên bản cuộc họp. |

## 1.6. Tài liệu tham khảo

- ISO/IEC/IEEE 29148:2018 – Requirements engineering (https://www.iso.org/standard/72089.html).
- Tài liệu chính thức của Flutter và của sherpa-onnx.
- Tài liệu về các mô hình ASR, VAD và Speaker Diarization được lựa chọn.
- Tài liệu nền tảng: chính sách ghi âm nền, quyền riêng tư và nhãn dữ liệu của Apple App Store và Google Play.

---

# 2. MÔ TẢ TỔNG QUAN

## 2.1. Bối cảnh sản phẩm

VietVoice là ứng dụng độc lập trên thiết bị di động, gồm các thành phần: (1) giao diện Flutter; (2) ghi âm và quản lý âm thanh; (3) tiền xử lý âm thanh; (4) phát hiện giọng nói (VAD); (5) nhận dạng tiếng Việt (ASR); (6) hậu xử lý văn bản; (7) quản lý bản ghi và transcript; (8) phân biệt người nói; (9) tóm tắt và biên bản; (10) xuất và chia sẻ.

Luồng dữ liệu chính:

```text
Microphone / Tệp âm thanh
   → Tiền xử lý (giải mã, mono 16 kHz, chuẩn hóa)
   → VAD → Chia đoạn (chunking)
   → ASR Engine → Hậu xử lý văn bản
   → Transcript Manager → CSDL cục bộ (SQLite + FTS) + Tệp âm thanh
   → Chỉnh sửa / Tìm kiếm / Diarization / Tóm tắt / Xuất
```

**Nguyên tắc kiến trúc:**

- Giao diện tách biệt với xử lý AI; mô hình ASR không gắn cứng vào giao diện (truy cập qua interface trừu tượng).
- Âm thanh và văn bản được quản lý độc lập nhưng có liên kết.
- Tác vụ xử lý dài chạy bất đồng bộ, ngoài luồng giao diện, có trạng thái và có thể khôi phục.
- Chức năng cốt lõi không phụ thuộc máy chủ bên ngoài.
- Bộ nhớ sử dụng không tăng theo độ dài bản ghi (xử lý theo luồng/đoạn).

## 2.2. Nhóm người dùng

Hệ thống có một vai trò duy nhất là **Người dùng ứng dụng**, không yêu cầu tài khoản. Ba nhóm dưới đây là persona để phân tích nhu cầu, không phải vai trò phân quyền.

| Persona | Mô tả | Nhu cầu chính |
| --- | --- | --- |
| Người dùng thông thường | Cá nhân ghi âm và chuyển giọng nói thành văn bản. | Ghi nhanh, chuyển văn bản, chép lại, chia sẻ. |
| Người ghi chép cuộc họp | Ghi âm cuộc họp và lập biên bản. | Phân biệt người nói, tóm tắt, quyết định, công việc. |
| Người học tập | Ghi lại bài giảng. | Ghi dài, tìm kiếm trong nội dung, xuất tài liệu. |

## 2.3. Môi trường vận hành

| Thành phần | Yêu cầu |
| --- | --- |
| Android | Android 10 trở lên (mục tiêu ban đầu). |
| iOS | iOS 15 trở lên (mục tiêu ban đầu). |
| Framework / ngôn ngữ | Flutter / Dart; mã gốc (native) cho phần ghi âm nền khi cần. |
| ASR runtime | sherpa-onnx hoặc runtime tương đương. |
| Lưu trữ | SQLite (Drift) với FTS5 và hệ thống tệp của ứng dụng. |
| Âm thanh đầu vào | Microphone hoặc tệp được hỗ trợ. |
| Internet | Không bắt buộc cho ghi âm và nhận dạng; cần cho lần tải mô hình đầu tiên và AI Summary trực tuyến. |

Phiên bản hệ điều hành tối thiểu chính thức được xác nhận sau khi kiểm tra tương thích thư viện trên thiết bị thật (SP-01).

## 2.4. Thiết bị mục tiêu (ĐX)

Danh sách máy cụ thể được chốt khi có thiết bị thử nghiệm (vấn đề mở OI-03). Các nhóm sau là cơ sở cho kiểm thử hiệu năng.

| Nhóm | Android (tham chiếu) | iOS (tham chiếu) | Mô hình dự kiến |
| --- | --- | --- | --- |
| A – Cấu hình thấp | RAM 3–4 GB, SoC phổ thông đời 2019–2021 | iPhone 8 / X (RAM 2–3 GB) | Lightweight |
| B – Cấu hình trung bình | RAM 6–8 GB, SoC tầm trung | iPhone 11 / 12 (RAM 4 GB) | Balanced |
| C – Cấu hình cao | RAM ≥ 8 GB, SoC cao cấp | iPhone 13 Pro trở lên (RAM ≥ 6 GB) | Accuracy |

Ứng dụng không được kết luận “tương thích mọi điện thoại” dựa trên một thiết bị.

## 2.5. Ràng buộc thiết kế

| Mã | Ràng buộc | Mô tả |
| --- | --- | --- |
| CON-01 | Cross-platform | Phát triển bằng Flutter. |
| CON-02 | Offline-first | Ghi âm và ASR cốt lõi chạy offline. |
| CON-03 | Tài nguyên hạn chế | Mô hình chọn theo khả năng xử lý của điện thoại. |
| CON-04 | Thay thế mô hình | Không phụ thuộc duy nhất một mô hình ASR. |
| CON-05 | Quyền riêng tư | Không tự động tải âm thanh hay văn bản lên máy chủ ngoài. |
| CON-06 | Bộ nhớ | Không đọc toàn bộ bản ghi dài vào RAM; xử lý theo đoạn. |
| CON-07 | Bản quyền | Mô hình và thư viện có giấy phép phù hợp để phân phối. |
| CON-08 | Kích thước gói | Gói cài đặt (không gồm mô hình) ≤ 100 MB (ĐX), phù hợp giới hạn của store. |

## 2.6. Giả định và phụ thuộc

| Mã | Giả định/phụ thuộc | Mô tả |
| --- | --- | --- |
| ASM-01 | Microphone | Thiết bị có microphone hoạt động. |
| ASM-02 | Dung lượng | Thiết bị còn đủ dung lượng cho âm thanh và mô hình. |
| ASM-03 | Mô hình | Người dùng tải mô hình ở lần chạy đầu (cần Internet một lần). Sau đó dùng offline hoàn toàn. |
| ASM-04 | Quyền truy cập | Người dùng cấp quyền microphone, thông báo và truy cập tệp khi cần. |
| ASM-05 | Thiết bị | Hiệu năng nhận dạng phụ thuộc cấu hình thiết bị. |
| ASM-06 | AI Summary | Nếu dùng dịch vụ AI trực tuyến, cần Internet và sự đồng ý của người dùng. |
| ASM-07 | Hệ điều hành | Ghi âm nền tuân theo giới hạn của Android (foreground service) và iOS (background audio). |

## 2.7. Các quyết định thiết kế đã chốt

Các quyết định dưới đây giải quyết những điểm mơ hồ của v1.0. Mọi thay đổi phải được xét duyệt lại.

| Mã | Quyết định | Lý do / hệ quả |
| --- | --- | --- |
| DEC-01 | Mô hình ASR **không** đóng gói trong gói cài đặt; tải ở lần chạy đầu (khuyến nghị Wi-Fi), có kiểm tra toàn vẹn. Có thể phát hành biến thể “Lite” đóng gói mô hình nhẹ nếu store cho phép (OI-01). | Giữ gói cài đặt nhỏ; cho phép đổi mô hình. Lần đầu cần Internet, sau đó offline hoàn toàn. |
| DEC-02 | Ghi âm trực tiếp ở định dạng WAV PCM 16-bit, mono, 16 kHz; tùy chọn nén sang M4A (AAC) sau khi kết thúc. | Khớp đầu vào ASR, tránh giải mã lại. Ước tính ≈ 115 MB/giờ (WAV); 2 giờ ≈ 230 MB. |
| DEC-03 | Giới hạn mặc định: mỗi bản ghi hoặc tệp nhập tối đa 4 giờ và 1 GB (cấu hình được); yêu cầu dung lượng trống tối thiểu 200 MB để bắt đầu ghi. | Bảo vệ thiết bị; giá trị ĐX, điều chỉnh sau SP-02. |
| DEC-04 | Một tác vụ ASR chạy tại một thời điểm; các tác vụ khác xếp hàng. Tác vụ có thể tiếp tục từ đoạn đã lưu cuối cùng sau khi ứng dụng khởi động lại. | Giới hạn RAM/CPU/pin; đáp ứng NFR-REL-03. |
| DEC-05 | Lưu transcript gồm hai lớp: văn bản ASR gốc (bất biến) và văn bản người dùng chỉnh sửa, cùng cấu trúc Segment; Segment là nguồn sự thật, `content` của Transcript chỉ là bản ghép (cache). | Tránh trùng lặp và lệch dữ liệu; cho phép hoàn nguyên. |
| DEC-06 | Trạng thái ghi âm (RecordingState) tách khỏi trạng thái tác vụ (TaskState). | Tránh trộn hai vòng đời khác nhau (mục 6.2). |
| DEC-07 | Tìm kiếm dùng SQLite FTS5 trên cột đã chuẩn hóa NFC và bản không dấu, để gõ “hop” vẫn tìm được “họp”. | Phù hợp thói quen gõ tiếng Việt trên di động. |
| DEC-08 | WER báo cáo theo âm tiết (tiếng), sau chuẩn hóa văn bản; báo cáo thêm CER (Phụ lục B). | Tiếng Việt viết tách âm tiết, tránh mơ hồ khi tách từ. |

---

# 3. YÊU CẦU CHỨC NĂNG

Mỗi yêu cầu có **ưu tiên** (M/S/C) và **giai đoạn** (P1–P4) ngay trong bảng, đồng bộ với mục 12. Dấu M\* nghĩa là bắt buộc khi tính năng chứa yêu cầu đó được phát hành (tính năng tự nó có thể ở mức Should).

## 3.1. Quản lý mô hình ASR (MOD)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-MOD-01 | Kiểm tra trạng thái mô hình khi khởi động và trước mỗi lần nhận dạng. Kết quả: READY, NOT\_INSTALLED hoặc INVALID. Kiểm tra: thư mục tồn tại, đủ tệp thành phần, cấu hình hợp lệ. Checksum đầy đủ kiểm tra khi cài đặt; khi khởi động chỉ kiểm tra kích thước và siêu dữ liệu để khởi động nhanh. | M | P1 |
| FR-MOD-02 | Tải mô hình: hiển thị tên, dung lượng, tiến trình; cho phép hủy; tiếp tục tải từ vị trí đã tải khi mất kết nối; kiểm tra dung lượng trống ≥ 1,5 lần kích thước mô hình trước khi tải; cảnh báo khi dùng mạng di động; kiểm tra SHA-256 sau khi tải; thông báo thành công hoặc thất bại kèm nguyên nhân. | M | P1 |
| FR-MOD-03 | Xem thông tin mô hình (tên, phiên bản, dung lượng, ngôn ngữ, giấy phép, trạng thái cài đặt và sử dụng); chọn mô hình đang dùng; xóa mô hình đã cài (không cho xóa khi có tác vụ đang dùng). Đổi mô hình không làm thay đổi các chức năng nghiệp vụ khác. | M | P1 |
| FR-MOD-04 | Ba chế độ Lightweight, Balanced, Accuracy; gợi ý chế độ theo cấu hình thiết bị dựa trên bảng benchmark (SP-03); người dùng được chọn khác. Mặc định dựa trên kết quả đo thực tế, không mặc định rằng mô hình lớn hơn là phù hợp hơn. | S | P2 |
| FR-MOD-05 | Kiểm tra tương thích (kiến trúc CPU, RAM khả dụng, phiên bản runtime) trước khi kích hoạt mô hình; cảnh báo và chặn khi thiết bị không đủ tài nguyên (ERR-MOD-03). | M | P1 |
| FR-MOD-06 | Mục “Giới thiệu” hiển thị giấy phép của mô hình và thư viện bên thứ ba. | S | P1 |
| FR-MOD-07 | Cập nhật mô hình: thông báo khi có phiên bản mới, cập nhật thủ công; mô hình cũ chỉ bị xóa sau khi mô hình mới được xác thực. | C | P3 |

## 3.2. Khởi đầu và quyền truy cập (ONB)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-ONB-01 | Lần chạy đầu hiển thị giới thiệu ngắn (tối đa 3 màn) và dẫn tới tải mô hình; có thể bỏ qua và quay lại sau. | M | P1 |
| FR-ONB-02 | Xin quyền theo ngữ cảnh: microphone khi bắt đầu ghi, thông báo khi cần. Giải thích mục đích trước khi hiện hộp thoại hệ thống; hướng dẫn mở Cài đặt khi quyền bị từ chối vĩnh viễn. | M | P1 |
| FR-ONB-03 | Hiển thị lưu ý quyền riêng tư: dữ liệu lưu trên thiết bị; người dùng chịu trách nhiệm xin sự đồng ý của người bị ghi âm theo quy định pháp luật. Người dùng xác nhận một lần. | M | P1 |

## 3.3. Ghi âm trực tiếp (REC)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-REC-01 | Bắt đầu ghi âm. Điều kiện: có quyền microphone, không có phiên ghi âm khác, dung lượng trống ≥ 200 MB (DEC-03). Kết quả: bắt đầu thu, hiển thị trạng thái và thời lượng. | M | P1 |
| FR-REC-02 | Tạm dừng: dừng thu, giữ dữ liệu đã ghi, hiển thị trạng thái, cho phép tiếp tục. | M | P1 |
| FR-REC-03 | Tiếp tục: nối vào cùng bản ghi; các đoạn âm thanh được quản lý liền mạch như một tệp logic. | M | P1 |
| FR-REC-04 | Kết thúc: dừng microphone, hoàn tất tệp, ghi nhận thời lượng và dung lượng, lưu bản ghi, đề xuất chuyển sang nhận dạng. | M | P1 |
| FR-REC-05 | Hiển thị trạng thái, thời lượng, chỉ báo mức âm lượng (cập nhật ≥ 10 lần/giây), trạng thái microphone và lỗi. | M | P1 |
| FR-REC-06 | Gián đoạn: cuộc gọi đến, mất audio focus, báo thức → tự động tạm dừng, lưu dữ liệu, thông báo, cho phép tiếp tục. Đổi nguồn thu (tai nghe có dây, Bluetooth) → tiếp tục với nguồn khả dụng hoặc tạm dừng kèm thông báo. Hệ điều hành thu hồi quyền hoặc cạn dung lượng → dừng an toàn, giữ dữ liệu đã ghi. | M | P1 |
| FR-REC-07 | Tên bản ghi tự động theo ngày giờ (ví dụ `Cuoc_hop_nhom_2026-10-31_09-00`); đổi tên được; xử lý ký tự không hợp lệ và tên trùng. | M | P1 |
| FR-REC-08 | Ghi âm nền: tiếp tục ghi khi khóa màn hình hoặc chuyển sang ứng dụng khác. Android dùng foreground service kèm thông báo thường trực; iOS dùng chế độ background audio. | M | P1 |
| FR-REC-09 | Khôi phục sau sự cố: dữ liệu ghi xuống đĩa theo khối ≤ 5 giây. Khi ứng dụng bị đóng đột ngột, lần mở sau phải phát hiện phiên dang dở, khôi phục phần đã ghi thành bản ghi hợp lệ và thông báo người dùng. | M | P1 |
| FR-REC-10 | Hiển thị thời gian ghi còn lại ước tính theo dung lượng trống; cảnh báo khi còn dưới 10 phút; dừng an toàn khi cạn dung lượng. | S | P1 |
| FR-REC-11 | Tùy chọn nén bản ghi sang M4A sau khi kết thúc (DEC-02); chỉ xóa WAV khi M4A đã hợp lệ. | S | P3 |

## 3.4. Nhập tệp âm thanh (IMP)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-IMP-01 | Chọn tệp âm thanh từ trình chọn tệp của hệ điều hành. | M | P1 |
| FR-IMP-02 | Kiểm tra định dạng. P1 bắt buộc WAV, MP3, M4A; AAC và FLAC xác nhận sau SP-01. Danh sách chính thức phụ thuộc khả năng giải mã của thư viện tích hợp. | M | P1 |
| FR-IMP-03 | Kiểm tra tệp: tồn tại, đọc được, có dữ liệu âm thanh, thời lượng ≤ giới hạn (DEC-03), định dạng hỗ trợ. Nếu không hợp lệ, báo nguyên nhân cụ thể bằng mã lỗi (ERR-IMP-xx). | M | P1 |
| FR-IMP-04 | Chuẩn hóa: giải mã và chuyển theo luồng về định dạng mô hình yêu cầu (ví dụ mono 16 kHz); thông số lấy từ cấu hình mô hình; không nạp toàn bộ tệp vào RAM. | M | P1 |
| FR-IMP-05 | Sao chép tệp vào vùng lưu trữ của ứng dụng kèm tiến trình và kiểm tra dung lượng, để bảo đảm BR-04 và BR-06; không sửa tệp gốc. | M | P1 |
| FR-IMP-06 | Nhập từ Share Sheet hoặc “Mở bằng VietVoice” từ ứng dụng khác. | S | P3 |

## 3.5. Nhận dạng giọng nói tiếng Việt (ASR)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-ASR-01 | Chuyển âm thanh thành văn bản bằng mô hình chạy trực tiếp trên thiết bị; không yêu cầu Internet. | M | P1 |
| FR-ASR-02 | Tạo văn bản tiếng Việt có dấu thanh, chuẩn NFC. Ví dụ: đầu ra thô của mô hình “chúng ta cần hoàn thành báo cáo trước thứ sáu”; sau hậu xử lý (FR-TXT-03): “Chúng ta cần hoàn thành báo cáo trước thứ sáu.” Kết quả thực tế phụ thuộc chất lượng âm thanh và mô hình. | M | P1 |
| FR-ASR-03 | Hướng đến nhận dạng giọng miền Bắc, Trung, Nam. Hệ thống phải được đánh giá bằng tập dữ liệu đại diện (mục 11.3) và báo cáo WER theo từng vùng miền. | M | P1 |
| FR-ASR-04 | Âm thanh dài: chia đoạn theo VAD, độ dài đoạn tối đa theo cấu hình mô hình (mặc định 30 giây). Khi không có khoảng lặng, cắt cứng với vùng chồng lấn 1–2 giây và loại phần trùng khi ghép. Giữ thứ tự bằng chỉ số tuần tự. RAM không tăng theo độ dài bản ghi. | M | P1 |
| FR-ASR-05 | Nhận dạng gần thời gian thực khi ghi: dùng mô hình streaming nếu có, hoặc VAD kết hợp nhận dạng theo đoạn. Độ trễ hiển thị ≤ 3 giây sau khi kết thúc câu nói (ĐX). Giao diện phân biệt văn bản tạm thời, văn bản đã xác nhận và trạng thái đang xử lý. Bật/tắt được. Kết quả cuối cùng có thể được nhận dạng lại từ tệp ghi sau khi kết thúc. | M | P2 |
| FR-ASR-06 | Lỗi theo đoạn: ghi nhận đoạn lỗi (thời điểm, mã lỗi), tiếp tục các đoạn còn lại, không mất kết quả trước đó, đặt trạng thái PARTIAL, thông báo người dùng và cho phép “Thử lại đoạn lỗi”. | M | P1 |
| FR-ASR-07 | Hiển thị tiến trình: phần trăm, thời lượng đã xử lý, thời lượng còn lại ước tính (khi đủ dữ liệu), trạng thái, lỗi. | M | P1 |
| FR-ASR-08 | Hủy nhận dạng: dừng an toàn, giữ kết quả đã lưu, không xóa âm thanh gốc, cập nhật trạng thái CANCELLED. | M | P1 |
| FR-ASR-09 | Tiền xử lý: chuẩn hóa âm lượng, VAD, lọc nhiễu; speech enhancement nếu đủ tài nguyên. Có thể tắt. Chỉ bật mặc định khi đo đạc chứng minh không làm tăng WER (SP-04). | S | P2 |
| FR-ASR-10 | Giữ nguyên từ tiếng Anh, tên công nghệ và thuật ngữ xen kẽ trong câu tiếng Việt; đánh giá riêng (NFR-ACC-02). | S | P2 |
| FR-ASR-11 | Từ điển tùy chỉnh: thêm, sửa, xóa từ khóa và thuật ngữ. Dùng hotwords nếu mô hình hỗ trợ; nếu không, thay thế hậu kỳ theo cặp “cụm nhận dạng → cụm đúng”. Giao diện cho biết cơ chế đang dùng. | S | P2 |
| FR-ASR-12 | Lưu kết quả: mỗi Segment (nội dung, thời gian bắt đầu và kết thúc, độ tin cậy nếu có) được lưu ngay khi nhận dạng xong và liên kết với bản ghi tương ứng. | M | P1 |
| FR-ASR-13 | Hàng đợi: một tác vụ chạy tại một thời điểm (DEC-04), hiển thị vị trí hàng đợi. Sau khi khởi động lại, tác vụ dang dở tiếp tục từ đoạn đã lưu cuối cùng. | M | P1 |
| FR-ASR-14 | Chạy nền: nhận dạng tiếp tục khi ứng dụng ở nền trong phạm vi hệ điều hành cho phép; thông báo khi hoàn tất hoặc lỗi. | S | P2 |

## 3.6. Xử lý hậu kỳ văn bản (TXT)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-TXT-01 | Chuẩn hóa: bỏ khoảng trắng thừa, chuẩn hóa dấu câu và xuống dòng, ghép đoạn, chuẩn NFC; giữ nguyên nội dung và ý nghĩa. | M | P1 |
| FR-TXT-02 | Phân đoạn văn bản thành câu hoặc đoạn (theo khoảng nghỉ của VAD và dấu câu) để dễ đọc và chỉnh sửa. | M | P1 |
| FR-TXT-03 | Tự động thêm dấu câu và viết hoa khi có mô hình phù hợp cho tiếng Việt (SP-05); nếu không có, ẩn chức năng. | S | P2 |
| FR-TXT-04 | Chỉnh sửa: thêm, xóa, sửa từ, sửa dấu câu, chia hoặc gộp đoạn. | M | P1 |
| FR-TXT-05 | Lưu tự động (≤ 5 giây sau thay đổi hoặc khi rời màn hình), ghi thời điểm sửa gần nhất; hoàn tác và làm lại trong phiên chỉnh sửa. | M | P1 |
| FR-TXT-06 | Đánh dấu đoạn có độ tin cậy thấp chỉ khi mô hình cung cấp confidence; không gán độ tin cậy giả. | S | P2 |
| FR-TXT-07 | Giữ bản ASR gốc bất biến (DEC-05); cho phép xem so sánh và hoàn nguyên từng đoạn hoặc toàn bộ về bản gốc. | M | P1 |
| FR-TXT-08 | Lịch sử phiên bản chỉnh sửa (tối thiểu 10 phiên bản gần nhất). | C | P3 |
| FR-TXT-09 | Tìm và thay thế trong transcript. | S | P3 |

## 3.7. Phân biệt người nói (DIA)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-DIA-01 | Phân chia nội dung hội thoại thành các lượt phát biểu. | S | P2 |
| FR-DIA-02 | Gán nhãn từng lượt phát biểu (Người nói 1, Người nói 2, …). | S | P2 |
| FR-DIA-03 | Đổi tên nhãn người nói (ví dụ Người nói 1 → Nguyễn Văn A); đổi tên áp dụng cho toàn bản ghi. | M\* | P2 |
| FR-DIA-04 | Gán lại người nói cho một đoạn khi hệ thống nhận dạng nhầm. | M\* | P2 |
| FR-DIA-05 | Khi không xác định được người nói, gán nhãn “Không xác định”, không suy đoán danh tính. Diarization chỉ phân biệt đặc điểm giọng nói. | M\* | P2 |
| FR-DIA-06 | Người dùng có thể chỉ định số người nói trước khi chạy; mặc định tự động ước lượng. | S | P2 |
| FR-DIA-07 | Gộp hai nhãn người nói thành một. | S | P2 |

## 3.8. Quản lý bản ghi (MNG)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-MNG-01 | Danh sách bản ghi: tên, ngày tạo, thời lượng, trạng thái nhận dạng, dung lượng; mặc định mới nhất trước; tải theo trang khi quá 200 mục. | M | P1 |
| FR-MNG-02 | Xem chi tiết bản ghi: thông tin, trạng thái, mô hình đã dùng. | M | P1 |
| FR-MNG-03 | Đổi tên bản ghi. | M | P1 |
| FR-MNG-04 | Phát lại âm thanh: phát, tạm dừng, tua, tốc độ 0,75× đến 2×. | M | P1 |
| FR-MNG-05 | Tạm dừng và tiếp tục phát; nhớ vị trí phát; xử lý gián đoạn âm thanh (ví dụ cuộc gọi đến). | M | P1 |
| FR-MNG-06 | Xóa bản ghi: bắt buộc xác nhận. Xóa vĩnh viễn, không thể khôi phục: tệp âm thanh, transcript, segment, người nói, tóm tắt, công việc, tác vụ liên quan và chỉ mục tìm kiếm. Nếu xóa dừng giữa chừng, phần còn lại được dọn ở lần khởi động sau. | M | P1 |
| FR-MNG-07 | Sắp xếp theo ngày mới nhất, ngày cũ nhất, tên, thời lượng. | M | P3 |
| FR-MNG-08 | Lọc theo ngày tạo, trạng thái nhận dạng, loại bản ghi (ghi âm hoặc nhập tệp), khoảng thời gian. | S | P3 |
| FR-MNG-09 | Chọn nhiều và xóa nhiều bản ghi cùng lúc. | S | P3 |
| FR-MNG-10 | Xóa riêng tệp âm thanh, giữ transcript, để tiết kiệm dung lượng; khi đó các chức năng phát lại bị vô hiệu và hiển thị rõ lý do. | S | P3 |

## 3.9. Đồng bộ văn bản với âm thanh (SYN)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-SYN-01 | Lưu timestamp (bắt đầu, kết thúc) của từng Segment khi mô hình hoặc quy trình cung cấp. Dữ liệu được lưu từ P1, hiển thị và sử dụng ở P3. | S | P3 |
| FR-SYN-02 | Chọn một đoạn văn bản để phát lại phần âm thanh tương ứng. | S | P3 |
| FR-SYN-03 | Khi phát âm thanh, tô sáng đoạn văn bản tương ứng. | S | P3 |
| FR-SYN-04 | Nếu thiếu timestamp chính xác, ẩn các chức năng đồng bộ và vẫn cho phát lại bình thường. | M | P3 |

## 3.10. Tìm kiếm nội dung (SEA)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-SEA-01 | Tìm bản ghi theo tên. | M | P3 |
| FR-SEA-02 | Tìm từ khóa trong nội dung transcript (SQLite FTS5). | M | P3 |
| FR-SEA-03 | Kết quả hiển thị: tên bản ghi, đoạn chứa từ khóa (tô sáng từ khóa), thời gian tạo, vị trí tương ứng nếu có timestamp. | M | P3 |
| FR-SEA-04 | Tìm kiếm hoạt động khi không có Internet. | M | P3 |
| FR-SEA-05 | Tìm không phân biệt hoa thường và dấu (DEC-07); kết quả khớp đúng dấu xếp trước. | S | P3 |

## 3.11. Tóm tắt và biên bản cuộc họp (AI)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-AI-01 | Tạo bản tóm tắt từ transcript; không bổ sung thông tin không có trong bản ghi. | S | P4 |
| FR-AI-02 | Trích xuất chủ đề chính, nội dung thảo luận, vấn đề được đề cập, kết luận và quyết định. | S | P4 |
| FR-AI-03 | Trích xuất công việc: nội dung, người phụ trách và thời hạn nếu được nói rõ; nếu không thì ghi “Chưa xác định” (BR-09). | S | P4 |
| FR-AI-04 | Tạo biên bản theo cấu trúc: tên cuộc họp, thời gian, thành phần tham gia (nếu có dữ liệu), nội dung thảo luận, quyết định, công việc cần thực hiện, vấn đề chưa giải quyết. | S | P4 |
| FR-AI-05 | Cho phép chỉnh sửa nội dung do AI tạo trước khi lưu hoặc xuất. | M\* | P4 |
| FR-AI-06 | Phân biệt trực quan nội dung AI tổng hợp với transcript gốc (nhãn “Do AI tạo”); bản tóm tắt không thay thế transcript gốc. | M\* | P4 |
| FR-AI-07 | Nếu dùng dịch vụ AI trực tuyến: tắt mặc định; thông báo rõ dữ liệu nào được gửi; xin đồng ý rõ ràng; không gửi tệp âm thanh gốc; cho phép hủy; cho phép thu hồi đồng ý trong Cài đặt. | M | P4 |
| FR-AI-08 | Khi offline và không có mô hình tóm tắt cục bộ, thông báo AI Summary không khả dụng; không làm gián đoạn ghi âm và ASR. | M\* | P4 |
| FR-AI-09 | Transcript quá dài: chia thành phần, tóm tắt từng phần rồi tổng hợp. Nếu AI trả kết quả không hợp lệ, báo lỗi và giữ nguyên transcript. | S | P4 |
| FR-AI-10 | Chọn mẫu biên bản (họp nhóm, bài giảng, phỏng vấn) và chỉnh sửa mẫu. | C | P4 |

## 3.12. Xuất và chia sẻ (EXP)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-EXP-01 | Xuất transcript thành TXT mã hóa UTF-8. | M | P1 |
| FR-EXP-02 | Xuất transcript hoặc biên bản thành DOCX. | S | P3 |
| FR-EXP-03 | Xuất transcript hoặc biên bản thành PDF. | S | P3 |
| FR-EXP-04 | Chia sẻ tệp âm thanh gốc qua chức năng chia sẻ của hệ điều hành. | S | P3 |
| FR-EXP-05 | Chia sẻ văn bản đã chỉnh sửa qua các ứng dụng được hệ điều hành hỗ trợ. | S | P3 |
| FR-EXP-06 | Kiểm tra trước khi xuất; thông báo nếu không có dữ liệu để xuất. | M | P1 |
| FR-EXP-07 | Tùy chọn nội dung xuất: có hoặc không nhãn người nói và timestamp; văn bản gốc hoặc đã chỉnh sửa. | S | P3 |
| FR-EXP-08 | DOCX và PDF hiển thị đúng đủ dấu thanh tiếng Việt (nhúng font Unicode); kiểm tra bằng mẫu văn bản chứa đầy đủ các dấu. | M\* | P3 |

## 3.13. Cài đặt và quản lý dung lượng (SET, STO)

| Mã | Yêu cầu | Ưu tiên | GĐ |
| --- | --- | --- | --- |
| FR-SET-01 | Cài đặt: chế độ mô hình, bật/tắt nhận dạng trực tiếp, nén M4A, giới hạn thời lượng, giao diện sáng/tối, ngôn ngữ giao diện (mặc định tiếng Việt), AI trực tuyến (mặc định tắt). | M | P1 |
| FR-SET-02 | Khóa ứng dụng bằng PIN hoặc sinh trắc học; khi bật, yêu cầu xác thực khi mở lại sau khi ở nền quá thời gian cấu hình (mặc định 30 giây). | S | P3 |
| FR-SET-03 | Xóa toàn bộ dữ liệu ứng dụng, có xác nhận hai bước. | S | P3 |
| FR-STO-01 | Màn hình dung lượng: tổng dung lượng dùng bởi âm thanh, mô hình, cơ sở dữ liệu; liệt kê các bản ghi lớn nhất. | S | P3 |
| FR-STO-02 | Cảnh báo khi dung lượng trống thấp (dưới 500 MB) và gợi ý dọn dẹp. | S | P3 |

---

# 4. YÊU CẦU GIAO DIỆN NGƯỜI DÙNG

## 4.1. Nguyên tắc thiết kế

- Dễ dùng với người dùng phổ thông; từ màn hình chính bắt đầu ghi âm trong tối đa 2 lần chạm.
- Hiển thị rõ trạng thái xử lý; không gây nhầm lẫn giữa văn bản tạm thời và văn bản hoàn chỉnh (văn bản tạm thời hiển thị màu nhạt, nghiêng; văn bản đã xác nhận hiển thị bình thường).
- Thao tác được bằng một tay; nút hành động chính nằm vùng ngón cái.
- Hỗ trợ tiếng Việt có dấu, giao diện sáng/tối, cỡ chữ theo cài đặt hệ thống.
- Khả năng truy cập: độ tương phản đạt WCAG 2.1 mức AA, vùng chạm tối thiểu 48 dp, có nhãn cho TalkBack và VoiceOver.
- Mọi màn hình danh sách và nội dung có trạng thái rỗng, đang tải và lỗi được thiết kế rõ ràng.

## 4.2. Cấu trúc điều hướng

Thanh điều hướng dưới gồm ba tab: **Bản ghi** (Home), **Tìm kiếm**, **Cài đặt**. Quản lý mô hình (UI-11) nằm trong Cài đặt. Nút ghi âm nổi trên Home mở màn hình Recording. Chạm vào một bản ghi mở Recording Detail, từ đó mở Transcript, Speaker Management, AI Summary và Export.

## 4.3. Danh sách và mô tả màn hình

| Mã | Màn hình | Thành phần chính | Yêu cầu liên quan |
| --- | --- | --- | --- |
| UI-01 | Home | Nút ghi âm mới; nút nhập tệp; danh sách bản ghi gần đây kèm trạng thái nhận dạng; thẻ trạng thái mô hình (sẵn sàng, chưa cài, lỗi); thanh điều hướng; cảnh báo dung lượng thấp. | FR-MNG-01, FR-MOD-01, FR-STO-02 |
| UI-02 | Recording | Nút bắt đầu, tạm dừng, tiếp tục, kết thúc; bộ đếm thời gian; chỉ báo âm lượng; thời gian ghi còn lại; công tắc nhận dạng trực tiếp; vùng văn bản tạm thời và đã xác nhận (nếu bật). | FR-REC-01..10, FR-ASR-05 |
| UI-03 | Import Audio | Trình chọn tệp; thông tin tệp (tên, định dạng, thời lượng, dung lượng); kết quả kiểm tra; tiến trình sao chép; nút bắt đầu nhận dạng. | FR-IMP-01..06 |
| UI-04 | Processing | Tên bản ghi; trạng thái; tiến trình, thời lượng đã xử lý và còn lại; vị trí hàng đợi; nút hủy; danh sách đoạn lỗi và nút thử lại. | FR-ASR-06..08, FR-ASR-13 |
| UI-05 | Transcript | Nội dung theo Segment; nhãn người nói; thời gian từng đoạn; chế độ chỉnh sửa; hoàn tác/làm lại; so sánh và hoàn nguyên về bản gốc; đánh dấu độ tin cậy thấp; nút phát đoạn; tìm và thay thế; lưu và xuất. | FR-TXT-01..09, FR-SYN-01..04 |
| UI-06 | Recording Detail | Trình phát (phát, tạm dừng, tua, tốc độ); thông tin bản ghi (ngày, thời lượng, dung lượng, định dạng, mô hình đã dùng); đổi tên; xóa; truy cập Transcript, AI Summary, Export. | FR-MNG-02..06, FR-MNG-10 |
| UI-07 | Speaker Management | Danh sách người nói; đổi tên; gộp; gán lại người nói cho đoạn; chỉ định số người nói trước khi chạy. | FR-DIA-01..07 |
| UI-08 | Search | Ô tìm kiếm; kết quả (tên bản ghi, đoạn chứa từ khóa tô sáng, ngày, vị trí); lọc và sắp xếp. | FR-SEA-01..05, FR-MNG-07..08 |
| UI-09 | AI Summary | Tóm tắt; nội dung thảo luận; quyết định; công việc (người phụ trách, thời hạn hoặc “Chưa xác định”); vấn đề chưa giải quyết; nhãn “Do AI tạo”; chỉnh sửa; hộp thoại đồng ý khi dùng AI trực tuyến. | FR-AI-01..10 |
| UI-10 | Export | Chọn định dạng (TXT, DOCX, PDF); tùy chọn nội dung (người nói, timestamp, bản gốc/đã sửa); xem trước; chia sẻ. | FR-EXP-01..08 |
| UI-11 | Model Management | Danh sách mô hình; dung lượng; ngôn ngữ; giấy phép; trạng thái cài đặt; tải, hủy, tiếp tục tải, xóa; chọn chế độ; tiến trình tải. | FR-MOD-01..07 |
| UI-12 | Settings | Các mục của FR-SET-01..03, từ điển tùy chỉnh (FR-ASR-11), quản lý dung lượng (FR-STO-01), giới thiệu và giấy phép, chính sách quyền riêng tư. | FR-SET, FR-STO, FR-ASR-11 |

---

# 5. YÊU CẦU PHI CHỨC NĂNG

Các con số đánh dấu (ĐX) là mục tiêu đề xuất, phải được xác nhận bằng spike (mục 15) và đo thực tế (mục 11) trước khi dùng làm tiêu chí nghiệm thu. Chỉ tiêu theo nhóm thiết bị tham chiếu ở mục 2.4.

## 5.1. Hiệu năng (PER)

| Mã | Yêu cầu | Chỉ tiêu (ĐX) | Kiểm chứng |
| --- | --- | --- | --- |
| NFR-PER-01 | Xử lý âm thanh dài theo đoạn, không nạp toàn bộ vào RAM. | RAM đỉnh của tiến trình khi nhận dạng: nhóm A ≤ 500 MB, B ≤ 800 MB, C ≤ 1,2 GB. RAM khi xử lý bản ghi 120 phút chênh không quá 10% so với bản ghi 30 phút. | PT-02, PT-06 |
| NFR-PER-02 | Tốc độ nhận dạng offline sau khi ghi. RTF = thời gian xử lý / thời lượng âm thanh. | Nhóm A (Lightweight) ≤ 1,0; nhóm B (Balanced) ≤ 1,0; nhóm C (Accuracy) ≤ 0,7. Đây là chỉ tiêu cần kiểm chứng, không cam kết mọi điện thoại đều đạt. | PT-01 |
| NFR-PER-03 | Chế độ streaming không làm giao diện bị treo. | Ít nhất 95% khung hình được vẽ trong ≤ 16 ms khi đang nhận dạng trực tiếp. | PT-03 |
| NFR-PER-04 | Giải phóng tài nguyên sau tác vụ; không quá một phiên ASR đồng thời. | Giải phóng mô hình sau 60 giây không dùng; sau 10 tác vụ liên tiếp, RAM không tăng quá 10% so với sau tác vụ đầu. | PT-02, PT-05 |
| NFR-PER-05 | Không chạy tác vụ nặng trên luồng giao diện; tiền xử lý và ASR chạy trên isolate hoặc luồng riêng. | Phản hồi thao tác chạm ≤ 100 ms trong khi đang nhận dạng. | PT-03 |
| NFR-PER-06 | Hạn chế tiêu thụ pin: không chạy ASR khi không có dữ liệu; giải phóng tài nguyên khi kết thúc; cho phép tắt nhận dạng trực tiếp. | Nhóm B, màn hình tắt, 60 phút: ghi âm không nhận dạng trực tiếp ≤ 8% pin; ghi kèm nhận dạng trực tiếp ≤ 20% pin. | PT-04 |
| NFR-PER-07 | Thời gian khởi động và hiển thị danh sách. | Khởi động nguội đến Home ≤ 3 giây (nhóm B); mở danh sách 1.000 bản ghi ≤ 1 giây. | PT-07 |
| NFR-PER-08 | Tốc độ tìm kiếm. | ≤ 1 giây với 1.000 bản ghi tổng khoảng 2 triệu từ. | PT-07 |
| NFR-PER-09 | Kích thước gói cài đặt. | ≤ 100 MB, không gồm mô hình (CON-08). | PT-07 |

## 5.2. Độ chính xác (ACC)

| Mã | Yêu cầu |
| --- | --- |
| NFR-ACC-01 | Đánh giá bằng tập dữ liệu tiếng Việt có transcript chuẩn do con người kiểm tra. Chỉ số: WER theo âm tiết, CER, tỷ lệ câu đúng hoàn toàn, tỷ lệ nhận đúng thuật ngữ. Báo cáo theo từng nhóm điều kiện, không chỉ trung bình chung (Phụ lục B). |
| NFR-ACC-03 | Hậu xử lý không đổi ý nghĩa: sau khi bỏ dấu câu và chuẩn hóa hoa thường, WER giữa văn bản trước và sau hậu xử lý chênh ≤ 0,5 điểm phần trăm. |
| NFR-ACC-04 | Người dùng được xem và sửa transcript gốc; bản tóm tắt AI không thay thế transcript gốc. |

### NFR-ACC-02 – Mục tiêu chất lượng (ĐX, xác nhận sau SP-06)

| Điều kiện kiểm thử | Mục tiêu |
| --- | --- |
| Âm thanh rõ, một người nói | WER ≤ 15% |
| Âm thanh rõ, hội thoại nhiều người | WER ≤ 20% |
| Nhiễu vừa | WER ≤ 25% và theo dõi mức chênh so với âm thanh rõ |
| Thuật ngữ tiếng Anh chuyên ngành | Tỷ lệ nhận đúng thuật ngữ ≥ 70%, báo cáo riêng |
| Giữa các vùng miền | Chênh lệch WER giữa vùng tốt nhất và vùng kém nhất ≤ 8 điểm phần trăm |

## 5.3. Khả năng sử dụng (USA)

| Mã | Yêu cầu |
| --- | --- |
| NFR-USA-01 | Người dùng mới bắt đầu ghi âm từ màn hình chính trong tối đa 2 lần chạm, không cần cấu hình phức tạp. |
| NFR-USA-02 | Trạng thái ghi âm, tạm dừng, nhận dạng, hoàn tất và lỗi được thể hiện rõ. |
| NFR-USA-03 | Thông báo lỗi dùng ngôn ngữ dễ hiểu, kèm hướng dẫn xử lý (danh mục ở Phụ lục A). |
| NFR-USA-04 | Hỗ trợ giao diện tiếng Việt. |
| NFR-USA-05 | Thao tác chỉnh sửa transcript dễ dùng trên màn hình điện thoại. |
| NFR-USA-06 | Đáp ứng yêu cầu truy cập ở mục 4.1 (tương phản, vùng chạm, trình đọc màn hình, cỡ chữ). |

## 5.4. Độ tin cậy (REL)

| Mã | Yêu cầu | Chỉ tiêu |
| --- | --- | --- |
| NFR-REL-01 | Bảo vệ dữ liệu đã lưu khi tác vụ nhận dạng lỗi. | Không mất dữ liệu đã lưu |
| NFR-REL-02 | Lỗi một đoạn không làm mất kết quả các đoạn trước. | Không mất dữ liệu |
| NFR-REL-03 | Xử lý được ứng dụng đóng hoặc khởi động lại bất ngờ. | Mất tối đa 5 giây âm thanh cuối và tối đa 1 đoạn kết quả nhận dạng |
| NFR-REL-04 | Thông báo khi tệp âm thanh lỗi hoặc không đọc được. | ERR-IMP-xx |
| NFR-REL-05 | Tránh bản ghi trùng do thao tác lặp (chạm hai lần). | Thao tác tạo bản ghi có tính idempotent |
| NFR-REL-06 | Ghi cơ sở dữ liệu theo giao dịch; kiểm tra toàn vẹn khóa ngoại và dữ liệu mồ côi khi khởi động. | Không có dữ liệu mồ côi sau khởi động |
| NFR-REL-07 | Di trú cơ sở dữ liệu (migration) giữ nguyên dữ liệu khi cập nhật ứng dụng. | Kiểm thử nâng cấp giữa các phiên bản |

## 5.5. Bảo mật và quyền riêng tư (SEC)

| Mã | Yêu cầu | Ưu tiên |
| --- | --- | --- |
| NFR-SEC-01 | Âm thanh và transcript lưu trong vùng dữ liệu riêng của ứng dụng; chỉ ra ngoài khi người dùng xuất hoặc chia sẻ. | M |
| NFR-SEC-02 | Không tự động tải âm thanh hoặc transcript lên máy chủ bên ngoài; không tích hợp SDK quảng cáo hoặc phân tích thu thập nội dung. Kiểm thử bằng giám sát lưu lượng mạng. | M |
| NFR-SEC-03 | Bật bảo vệ tệp của hệ điều hành cho dữ liệu ứng dụng (mã hóa lưu trữ của thiết bị, mức bảo vệ tệp iOS). | M |
| NFR-SEC-04 | Yêu cầu quyền microphone trước khi ghi âm. | M |
| NFR-SEC-05 | Chỉ truy cập các tệp người dùng chọn hoặc cấp quyền (trình chọn tệp hệ thống). | M |
| NFR-SEC-06 | Khi xóa bản ghi, xóa mọi dữ liệu liên quan theo FR-MNG-06. | M |
| NFR-SEC-07 | Nếu dùng AI trực tuyến, thông báo rõ nội dung gửi đi và xin đồng ý trước (FR-AI-07). | M |
| NFR-SEC-08 | Không tự động chia sẻ bản ghi, transcript hoặc biên bản với bên thứ ba. | M |
| NFR-SEC-09 | Mã hóa mức ứng dụng cho cơ sở dữ liệu và tệp âm thanh, khóa lưu trong Keystore hoặc Keychain. Chốt phương án sau SP-07 (đánh giá ảnh hưởng hiệu năng). | S |
| NFR-SEC-10 | Loại trừ dữ liệu ứng dụng khỏi sao lưu tự động của hệ điều hành (iCloud, Google), trừ khi người dùng chủ động bật. | M |
| NFR-SEC-11 | Chính sách quyền riêng tư và nhãn dữ liệu trên store (App Privacy, Data safety) khai báo chính xác. | M |
| NFR-SEC-12 | Khi bật khóa ứng dụng, che nội dung ở màn hình ứng dụng gần đây. | S |
| NFR-SEC-13 | Nhật ký chẩn đoán không chứa nội dung transcript hay đường dẫn tệp nhạy cảm. | M |

## 5.6. Tương thích (COM)

| Mã | Yêu cầu |
| --- | --- |
| NFR-COM-01 | Hỗ trợ Android và iOS theo mục 2.3. |
| NFR-COM-02 | Giao diện thích ứng các kích thước điện thoại phổ biến (chiều rộng khoảng 360–430 dp), sáng và tối. |
| NFR-COM-03 | Kiểm tra tương thích của mô hình với kiến trúc thiết bị và phiên bản runtime. |
| NFR-COM-04 | Thông báo khi thiết bị không đủ tài nguyên cho mô hình đã chọn. |
| NFR-COM-05 | Hỗ trợ bắt buộc kiến trúc arm64; có hỗ trợ 32-bit hay không chốt sau SP-01. |

## 5.7. Bảo trì và mở rộng (MAI), bản địa hóa (LOC)

| Mã | Yêu cầu |
| --- | --- |
| NFR-MAI-01 | Mã nguồn tổ chức thành các module độc lập (mục 13.2). |
| NFR-MAI-02 | Thành phần ASR tách khỏi giao diện thông qua interface trừu tượng. |
| NFR-MAI-03 | Bổ sung mô hình ASR mới bằng tệp mô tả cấu hình (manifest), không đổi mã nghiệp vụ. |
| NFR-MAI-04 | Bổ sung chức năng AI không làm thay đổi cấu trúc dữ liệu cốt lõi. |
| NFR-MAI-05 | Thông số mô hình (tần số lấy mẫu, độ dài đoạn, token, hỗ trợ streaming, hotwords) quản lý tập trung trong cấu hình. |
| NFR-MAI-06 | Độ phủ kiểm thử đơn vị lớp domain ≥ 70% (ĐX); có kiểm thử tích hợp pipeline ASR với tập âm thanh mẫu chuẩn. |
| NFR-LOC-01 | Chuỗi giao diện tách khỏi mã (l10n) để thêm ngôn ngữ sau; mặc định tiếng Việt. |
| NFR-LOC-02 | Mọi văn bản lưu, hiển thị và xuất chuẩn NFC, hỗ trợ đầy đủ dấu thanh; ngày giờ hiển thị theo định dạng của vùng. |

---

# 6. QUY TẮC NGHIỆP VỤ VÀ TRẠNG THÁI

## 6.1. Quy tắc nghiệp vụ

| Mã | Quy tắc | Mô tả |
| --- | --- | --- |
| BR-01 | Không ghi âm khi thiếu quyền | Phải có quyền microphone mới được ghi âm. |
| BR-02 | Một phiên ghi âm chính | Tại một thời điểm chỉ có một phiên ghi âm đang hoạt động. |
| BR-03 | Không bắt buộc Internet | Ghi âm và ASR cốt lõi chạy offline sau khi cài mô hình. |
| BR-04 | Không xóa âm thanh khi nhận dạng lỗi | Lỗi nhận dạng không tự động xóa âm thanh gốc. |
| BR-05 | Lưu transcript riêng | Transcript lưu độc lập với tệp âm thanh. |
| BR-06 | Bảo toàn nội dung gốc | Chỉnh sửa transcript không làm thay đổi tệp âm thanh. |
| BR-07 | Tóm tắt có nguồn | Nội dung tóm tắt dựa trên transcript đã có. |
| BR-08 | Không suy đoán người nói | Người nói chưa xác định gán nhãn “Không xác định”. |
| BR-09 | Không suy đoán nhiệm vụ | Người phụ trách và thời hạn chưa được nói rõ ghi “Chưa xác định”. |
| BR-10 | Xác nhận trước khi xóa | Bắt buộc xác nhận trước khi xóa bản ghi. |
| BR-11 | Kiểm tra mô hình | Chỉ nhận dạng khi mô hình ở trạng thái READY. |
| BR-12 | Lưu trạng thái xử lý | Mỗi tác vụ nhận dạng có trạng thái cụ thể (mục 6.3). |
| BR-13 | Một tác vụ ASR tại một thời điểm | Các tác vụ khác xếp hàng (DEC-04). |
| BR-14 | Văn bản ASR gốc bất biến | Chỉ lớp văn bản người dùng được chỉnh sửa (DEC-05). |
| BR-15 | Giới hạn thời lượng | Bản ghi hoặc tệp nhập vượt giới hạn cấu hình bị từ chối kèm thông báo (DEC-03). |

## 6.2. Trạng thái bản ghi (RecordingState)

Phản ánh vòng đời của tệp âm thanh, tách khỏi trạng thái nhận dạng (DEC-06).

| Trạng thái | Ý nghĩa | Chuyển tới |
| --- | --- | --- |
| RECORDING | Đang ghi âm. | PAUSED, SAVED |
| PAUSED | Tạm dừng ghi âm. | RECORDING, SAVED |
| SAVED | Âm thanh đã lưu đầy đủ (gồm bản nhập từ tệp). | – |
| RECOVERED | Bản ghi khôi phục sau sự cố, có thể ngắn hơn dự kiến. | – |

## 6.3. Trạng thái tác vụ nhận dạng (TaskState)

Mỗi tác vụ thuộc ProcessingTask; trạng thái hiển thị của bản ghi suy ra từ tác vụ mới nhất.

| Trạng thái | Ý nghĩa | Chuyển tới | Điều kiện |
| --- | --- | --- | --- |
| PENDING | Chờ trong hàng đợi. | PROCESSING, CANCELLED | Đến lượt chạy / người dùng hủy |
| PROCESSING | Đang nhận dạng. | COMPLETED, PARTIAL, FAILED, CANCELLED | Hết đoạn / có đoạn lỗi / lỗi nghiêm trọng / người dùng hủy |
| COMPLETED | Nhận dạng hoàn tất, mọi đoạn thành công. | PENDING | Người dùng chạy lại |
| PARTIAL | Chỉ một phần thành công. | PENDING | Thử lại đoạn lỗi |
| FAILED | Thất bại, không có kết quả dùng được. | PENDING | Người dùng thử lại |
| CANCELLED | Người dùng đã hủy. | PENDING | Chạy lại |

Khi ứng dụng khởi động lại, tác vụ ở trạng thái PROCESSING được chuyển về PENDING và tiếp tục từ đoạn đã lưu cuối cùng (FR-ASR-13).

---

# 7. QUY TRÌNH NGHIỆP VỤ CHÍNH

## 7.1. Tải mô hình lần đầu

1. Người dùng mở ứng dụng lần đầu và xem phần giới thiệu (FR-ONB-01, FR-ONB-03).
2. Hệ thống kiểm tra mô hình (FR-MOD-01): NOT\_INSTALLED.
3. Hệ thống hiển thị tên, dung lượng mô hình; kiểm tra dung lượng trống (≥ 1,5 lần).
4. Nếu đang dùng mạng di động, cảnh báo và xin xác nhận.
5. Tải mô hình, hiển thị tiến trình; nếu mất mạng thì tạm dừng và tiếp tục khi có mạng.
6. Kiểm tra SHA-256 và tương thích (FR-MOD-05). Nếu sai: xóa tệp tải, báo ERR-MOD-02 và cho thử lại.
7. Mô hình READY; người dùng sẵn sàng ghi âm hoặc nhập tệp.

## 7.2. Ghi âm và chuyển thành văn bản

1. Người dùng chọn Ghi âm mới. Hệ thống kiểm tra quyền microphone; nếu chưa có thì xin quyền. Nếu bị từ chối: thông báo không thể ghi âm, kết thúc.
2. Hệ thống kiểm tra dung lượng trống ≥ 200 MB; nếu không đủ thì thông báo và kết thúc.
3. Bắt đầu ghi; hiển thị thời lượng, mức âm lượng; nếu bật nhận dạng trực tiếp thì hiển thị văn bản tạm thời và văn bản đã xác nhận.
4. Người dùng tạm dừng và tiếp tục tùy ý; gián đoạn xử lý theo FR-REC-06.
5. Người dùng kết thúc; hệ thống lưu tệp, trạng thái SAVED.
6. Nếu mô hình READY: tạo tác vụ, xếp hàng, chuẩn hóa âm thanh, chia đoạn bằng VAD, nhận dạng từng đoạn và lưu từng Segment, hậu xử lý văn bản, hoàn tất. Nếu mô hình chưa sẵn sàng: thông báo cần cài mô hình, giữ bản ghi âm.
7. Người dùng xem transcript, chỉnh sửa, xuất.

## 7.3. Nhập tệp âm thanh

1. Người dùng chọn Nhập tệp và chọn tệp bằng trình chọn tệp.
2. Hệ thống kiểm tra tệp (tồn tại, đọc được, có âm thanh, thời lượng, định dạng). Không hợp lệ: thông báo nguyên nhân (ERR-IMP-xx), kết thúc.
3. Sao chép tệp vào vùng ứng dụng, tạo bản ghi (SAVED).
4. Kiểm tra mô hình; nếu chưa sẵn sàng thì giữ bản ghi và hướng dẫn cài mô hình.
5. Chuẩn hóa, chia đoạn, nhận dạng, ghép kết quả, lưu transcript, hiển thị kết quả.

## 7.4. Tạo biên bản cuộc họp

1. Người dùng mở transcript và chọn Tạo biên bản.
2. Hệ thống kiểm tra transcript có đủ nội dung. Nếu không: thông báo.
3. Hệ thống kiểm tra chế độ AI: mô hình cục bộ hoặc dịch vụ trực tuyến. Nếu không có cả hai (offline): thông báo chưa khả dụng (FR-AI-08).
4. Nếu dùng trực tuyến: hiển thị dữ liệu sẽ gửi, xin đồng ý; người dùng có thể hủy.
5. Tạo tóm tắt, trích xuất quyết định và công việc, hiển thị biên bản có nhãn “Do AI tạo”.
6. Người dùng kiểm tra, chỉnh sửa, lưu hoặc xuất.

## 7.5. Khôi phục sau khi ứng dụng bị đóng đột ngột

1. Khi khởi động, hệ thống phát hiện phiên ghi âm dang dở và/hoặc tác vụ ở trạng thái PROCESSING.
2. Phiên ghi âm dang dở được hoàn tất thành bản ghi RECOVERED từ các khối đã ghi; thông báo người dùng.
3. Tác vụ PROCESSING chuyển về PENDING và tiếp tục từ đoạn đã lưu cuối cùng.
4. Hệ thống kiểm tra toàn vẹn dữ liệu (NFR-REL-06) và dọn dữ liệu dang dở của thao tác xóa (FR-MNG-06).

---

# 8. ĐẶC TẢ USE CASE

## 8.1. Danh sách use case

Tác nhân chính của mọi use case là Người dùng.

| Mã | Use case | Yêu cầu liên quan |
| --- | --- | --- |
| UC-01 | Ghi âm mới | FR-REC-01, 05, 07, 10 |
| UC-02 | Tạm dừng ghi âm | FR-REC-02 |
| UC-03 | Tiếp tục ghi âm | FR-REC-03 |
| UC-04 | Kết thúc ghi âm | FR-REC-04 |
| UC-05 | Nhập tệp âm thanh | FR-IMP-01..05 |
| UC-06 | Nhận dạng giọng nói | FR-ASR-01..04, 06, 07, 12, 13 |
| UC-07 | Hủy nhận dạng | FR-ASR-08 |
| UC-08 | Xem transcript | FR-TXT-02, FR-SYN-02, 03 |
| UC-09 | Chỉnh sửa transcript | FR-TXT-04, 05, 07, 09 |
| UC-10 | Phát lại bản ghi | FR-MNG-04, 05 |
| UC-11 | Quản lý người nói | FR-DIA-01..07 |
| UC-12 | Tìm kiếm bản ghi | FR-SEA-01..05 |
| UC-13 | Tạo biên bản cuộc họp | FR-AI-01..10 |
| UC-14 | Xuất tài liệu | FR-EXP-01..08 |
| UC-15 | Quản lý mô hình ASR | FR-MOD-01..07 |
| UC-16 | Xóa bản ghi | FR-MNG-06, 09, 10 |
| UC-17 | Tải mô hình lần đầu | FR-ONB-01..03, FR-MOD-02 |
| UC-18 | Khôi phục sau sự cố | FR-REC-09, FR-ASR-13 |
| UC-19 | Quản lý từ điển tùy chỉnh | FR-ASR-11 |

## 8.2. UC-01 – Ghi âm mới

**Mục tiêu:** tạo một bản ghi âm mới. **Tiền điều kiện:** ứng dụng đã mở. **Hậu điều kiện:** bản ghi được tạo, âm thanh được lưu, trạng thái SAVED.

**Luồng chính:**

1. Người dùng chọn Ghi âm mới.
2. Hệ thống kiểm tra quyền microphone; nếu chưa có thì xin quyền và người dùng đồng ý.
3. Hệ thống kiểm tra dung lượng trống ≥ 200 MB và không có phiên ghi âm khác.
4. Hệ thống bắt đầu thu, hiển thị thời lượng và mức âm lượng, khởi động dịch vụ ghi nền.
5. Người dùng chọn Kết thúc (UC-04).
6. Hệ thống hoàn tất tệp, lưu bản ghi và hiển thị bản ghi mới, kèm đề xuất chuyển văn bản.

**Luồng ngoại lệ:**

- Người dùng từ chối quyền: thông báo không thể ghi âm và hướng dẫn mở Cài đặt (ERR-REC-01).
- Microphone đang được ứng dụng khác dùng: thông báo lỗi (ERR-REC-02).
- Thiếu dung lượng khi bắt đầu hoặc đang ghi: không bắt đầu, hoặc dừng an toàn và giữ phần đã ghi (ERR-REC-03).
- Cuộc gọi đến hoặc mất audio focus: tự động tạm dừng, cho phép tiếp tục (FR-REC-06).
- Ứng dụng bị đóng đột ngột: khôi phục ở lần mở sau (UC-18).

## 8.3. UC-05 – Nhập tệp âm thanh

**Mục tiêu:** đưa tệp âm thanh có sẵn vào ứng dụng. **Tiền điều kiện:** có tệp trong thiết bị. **Hậu điều kiện:** bản ghi được tạo với trạng thái SAVED.

**Luồng chính:** (1) Người dùng chọn Nhập tệp; (2) hệ thống mở trình chọn tệp; (3) người dùng chọn tệp; (4) hệ thống kiểm tra định dạng, độ đọc được, thời lượng; (5) hệ thống sao chép tệp vào vùng ứng dụng với tiến trình; (6) hệ thống tạo bản ghi và hỏi có nhận dạng ngay không.

**Luồng ngoại lệ:** định dạng không hỗ trợ (ERR-IMP-01); tệp hỏng hoặc không đọc được (ERR-IMP-02); vượt giới hạn thời lượng (ERR-IMP-03); thiếu dung lượng (ERR-IMP-04). Mọi trường hợp: thông báo nguyên nhân, không tạo bản ghi, không sửa tệp gốc.

## 8.4. UC-06 – Nhận dạng giọng nói

**Mục tiêu:** chuyển âm thanh của một bản ghi thành văn bản. **Tiền điều kiện:** có bản ghi SAVED/RECOVERED và mô hình READY. **Hậu điều kiện:** transcript được lưu và liên kết với bản ghi; tác vụ ở trạng thái COMPLETED hoặc PARTIAL.

**Luồng chính:**

1. Người dùng chọn bản ghi và chọn Chuyển thành văn bản.
2. Hệ thống kiểm tra mô hình (BR-11) và tạo tác vụ PENDING.
3. Khi đến lượt, hệ thống chuẩn hóa âm thanh (mono, 16 kHz) theo luồng.
4. Hệ thống chia đoạn bằng VAD.
5. Mô hình nhận dạng từng đoạn; hệ thống lưu từng Segment ngay khi xong và cập nhật tiến trình.
6. Hệ thống ghép kết quả theo thứ tự, loại phần trùng ở ranh giới đoạn.
7. Hệ thống hậu xử lý văn bản và lưu transcript.
8. Hệ thống hiển thị transcript.

**Luồng ngoại lệ:**

- Mô hình chưa cài: yêu cầu tải mô hình (UC-17).
- Tệp âm thanh không hợp lệ: thông báo lỗi (ERR-ASR-01).
- Một đoạn lỗi: ghi nhận, tiếp tục, trạng thái PARTIAL, cho phép thử lại (ERR-ASR-02).
- Thiếu bộ nhớ: dừng tác vụ an toàn, giữ âm thanh và kết quả đã lưu (ERR-ASR-03).
- Người dùng hủy: dừng tác vụ, giữ kết quả đã lưu, CANCELLED (UC-07).
- Ứng dụng bị đóng: tác vụ tiếp tục từ đoạn đã lưu (UC-18).

## 8.5. UC-09 – Chỉnh sửa transcript

**Mục tiêu:** sửa nội dung nhận dạng. **Tiền điều kiện:** transcript tồn tại. **Hậu điều kiện:** nội dung chỉnh sửa được lưu; bản ASR gốc không đổi.

**Luồng chính:** (1) Người dùng mở transcript; (2) chọn chế độ chỉnh sửa; (3) sửa, thêm, xóa, chia hoặc gộp đoạn; (4) hệ thống tự động lưu sau tối đa 5 giây và khi rời màn hình; (5) hệ thống cập nhật `edited_text` và thời điểm sửa; (6) người dùng có thể hoàn tác, hoặc hoàn nguyên đoạn về bản gốc.

**Ngoại lệ:** lưu thất bại (đầy bộ nhớ): giữ nội dung đang sửa trong bộ nhớ, thông báo và cho thử lại (ERR-STO-01).

## 8.6. UC-13 – Tạo biên bản cuộc họp

**Mục tiêu:** tạo biên bản dựa trên transcript. **Tiền điều kiện:** transcript tồn tại và đủ nội dung. **Hậu điều kiện:** biên bản được tạo và lưu, tách biệt với transcript gốc.

**Luồng chính:** (1) Người dùng mở transcript, chọn Tạo biên bản; (2) hệ thống kiểm tra chế độ AI (cục bộ hay trực tuyến); (3) nếu trực tuyến: hiển thị dữ liệu sẽ gửi và xin đồng ý; (4) hệ thống xử lý nội dung, tạo tóm tắt; (5) trích xuất quyết định; (6) trích xuất công việc (người phụ trách, thời hạn hoặc “Chưa xác định”); (7) hiển thị biên bản có nhãn “Do AI tạo”; (8) người dùng kiểm tra, chỉnh sửa, lưu.

**Luồng ngoại lệ:** không có Internet và không có mô hình cục bộ: thông báo không khả dụng (ERR-AI-01); người dùng từ chối đồng ý: không gửi, kết thúc; transcript quá dài: chia phần xử lý; AI trả kết quả không hợp lệ: báo lỗi, giữ nguyên transcript (ERR-AI-02).

## 8.7. UC-16 – Xóa bản ghi

**Tiền điều kiện:** bản ghi tồn tại và không có tác vụ đang chạy trên bản ghi đó (nếu có, hệ thống hỏi hủy tác vụ trước). **Luồng chính:** (1) Người dùng chọn Xóa; (2) hệ thống hiển thị xác nhận nêu rõ dữ liệu sẽ bị xóa vĩnh viễn; (3) người dùng xác nhận; (4) hệ thống xóa tệp âm thanh, transcript, segment, người nói, tóm tắt, công việc, tác vụ và chỉ mục tìm kiếm; (5) cập nhật danh sách. **Ngoại lệ:** xóa tệp thất bại giữa chừng: đánh dấu chờ dọn, tự dọn ở lần khởi động sau.

## 8.8. UC-17 – Tải mô hình lần đầu

Xem quy trình 7.1. **Hậu điều kiện:** mô hình READY và được chọn làm mô hình đang dùng. **Ngoại lệ:** không đủ dung lượng (ERR-MOD-01); sai checksum (ERR-MOD-02); thiết bị không tương thích (ERR-MOD-03); mất mạng (tạm dừng, tiếp tục khi có mạng); người dùng hủy (xóa tệp dang dở).

## 8.9. UC-18 – Khôi phục sau sự cố

Xem quy trình 7.5. **Hậu điều kiện:** không mất dữ liệu đã lưu theo NFR-REL-03; người dùng được thông báo về bản ghi được khôi phục.

---

# 9. YÊU CẦU DỮ LIỆU

## 9.1. Nguyên tắc

- Dùng cơ sở dữ liệu cục bộ SQLite (Drift). Khóa chính dạng UUID. Thời gian trong âm thanh lưu bằng **mili giây (số nguyên)**.
- Mọi văn bản chuẩn NFC. Khóa ngoại có ràng buộc; xóa Recording kéo theo xóa dữ liệu phụ thuộc (cascade).
- Segment là nguồn sự thật của nội dung văn bản; `Transcript.content_cache` chỉ là bản ghép để hiển thị nhanh (DEC-05).
- Tìm kiếm dùng bảng ảo FTS5 trên văn bản đã chuẩn hóa và bản không dấu (DEC-07).

## 9.2. Các thực thể

### Recording

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| recording\_id | UUID, PK | Mã bản ghi. |
| title | String | Tên bản ghi. |
| source\_type | Enum | RECORDED hoặc IMPORTED. |
| audio\_path | String | Đường dẫn tệp âm thanh (rỗng nếu đã xóa riêng âm thanh). |
| audio\_available | Boolean | Còn tệp âm thanh hay không (FR-MNG-10). |
| audio\_format | String | WAV, M4A, MP3... |
| sample\_rate, channels | Integer | Thông số âm thanh. |
| duration\_ms | Integer | Thời lượng. |
| file\_size | Integer | Dung lượng byte. |
| state | Enum | RecordingState (mục 6.2). |
| playback\_position\_ms | Integer | Vị trí phát gần nhất. |
| created\_at, updated\_at | DateTime | Thời điểm tạo và cập nhật. |

### AudioChunk

Các đoạn âm thanh của một phiên ghi (mỗi lần tạm dừng/tiếp tục hoặc khối ghi), dùng để ghép và khôi phục sau sự cố.

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| chunk\_id | UUID, PK | Mã đoạn. |
| recording\_id | UUID, FK | Bản ghi chứa đoạn. |
| sequence | Integer | Thứ tự. |
| file\_path | String | Tệp tạm của đoạn. |
| duration\_ms | Integer | Thời lượng. |

### Transcript

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| transcript\_id | UUID, PK | Mã transcript. |
| recording\_id | UUID, FK | Bản ghi liên kết. |
| model\_id | UUID, FK | Mô hình đã dùng. |
| language | String | Ngôn ngữ nhận dạng (vi). |
| version | Integer | Phiên bản (tăng khi nhận dạng lại). |
| is\_current | Boolean | Phiên bản đang dùng; mỗi bản ghi có đúng một transcript hiện hành. |
| content\_cache | Text | Bản ghép từ các Segment. |
| created\_at, updated\_at | DateTime | Thời điểm tạo và cập nhật. |

### TranscriptSegment

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| segment\_id | UUID, PK | Mã đoạn. |
| transcript\_id | UUID, FK | Transcript chứa đoạn. |
| speaker\_id | UUID, FK, nullable | Người nói; rỗng nếu không xác định. |
| sequence | Integer | Thứ tự đoạn. |
| start\_ms, end\_ms | Integer, nullable | Thời gian trong âm thanh nếu có. |
| original\_text | Text | Văn bản ASR gốc, bất biến. |
| edited\_text | Text, nullable | Văn bản người dùng sửa; rỗng nghĩa là chưa sửa. |
| confidence | Float, nullable | Độ tin cậy nếu mô hình cung cấp. |
| edited\_at | DateTime, nullable | Thời điểm sửa gần nhất. |

### Speaker

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| speaker\_id | UUID, PK | Mã người nói. |
| recording\_id | UUID, FK | Bản ghi liên quan. |
| label | String | Nhãn mặc định (Người nói 1...). |
| display\_name | String, nullable | Tên người dùng đặt. |

### ASRModel

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| model\_id | UUID, PK | Mã mô hình. |
| model\_name, version | String | Tên và phiên bản. |
| mode | Enum | LIGHTWEIGHT, BALANCED, ACCURACY. |
| model\_path | String | Đường dẫn lưu mô hình. |
| size\_bytes | Integer | Dung lượng. |
| language | String | Ngôn ngữ hỗ trợ. |
| sample\_rate | Integer | Tần số lấy mẫu yêu cầu. |
| supports\_streaming, supports\_hotwords | Boolean | Khả năng của mô hình. |
| sha256 | String | Mã kiểm tra toàn vẹn. |
| license | String | Giấy phép. |
| is\_installed, is\_active | Boolean | Trạng thái cài đặt và sử dụng. |

### ProcessingTask và TaskChunk

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| task\_id | UUID, PK | Mã tác vụ. |
| recording\_id | UUID, FK | Bản ghi cần xử lý. |
| model\_id | UUID, FK | Mô hình dùng. |
| task\_type | Enum | ASR, DIARIZATION, SUMMARY. |
| state | Enum | TaskState (mục 6.3). |
| progress | Float | Tiến trình 0–1. |
| error\_code, error\_message | String | Mã và thông báo lỗi. |
| queued\_at, started\_at, completed\_at | DateTime | Mốc thời gian. |
| **TaskChunk:** task\_id (FK), chunk\_index, start\_ms, end\_ms, state (PENDING, DONE, FAILED), error\_code | – | Theo dõi từng đoạn để tiếp tục và thử lại đoạn lỗi. Khóa chính (task\_id, chunk\_index). |

### MeetingSummary và ActionItem

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| summary\_id | UUID, PK | Mã bản tóm tắt. |
| recording\_id, transcript\_id | UUID, FK | Bản ghi và transcript nguồn. |
| summary\_content | Text | Nội dung tóm tắt. |
| discussion, decisions, unresolved\_issues | Text/JSON | Nội dung thảo luận, quyết định, vấn đề chưa giải quyết. |
| source | Enum | LOCAL\_MODEL hoặc ONLINE\_PROVIDER. |
| is\_edited | Boolean | Đã được người dùng chỉnh sửa. |
| created\_at, updated\_at | DateTime | Mốc thời gian. |
| **ActionItem:** action\_id (PK), summary\_id (FK), description, assignee (nullable), deadline (nullable), status (OPEN, DONE), sequence | – | Công việc; assignee và deadline rỗng hiển thị “Chưa xác định”. |

### CustomTerm và AppSetting

| Thuộc tính | Kiểu | Mô tả |
| --- | --- | --- |
| **CustomTerm:** term\_id (PK), phrase, replacement (nullable), type (HOTWORD hoặc REPLACEMENT), created\_at | – | Từ điển tùy chỉnh (FR-ASR-11). |
| **AppSetting:** key (PK), value | – | Cài đặt người dùng (FR-SET-01). |

## 9.3. Quan hệ giữa các thực thể

| Quan hệ | Bản số |
| --- | --- |
| Recording – AudioChunk | 1 – N |
| Recording – Transcript | 1 – N (đúng một bản is\_current) |
| Transcript – TranscriptSegment | 1 – N |
| Recording – Speaker | 1 – N |
| Speaker – TranscriptSegment | 0..1 – N |
| ASRModel – Transcript, ASRModel – ProcessingTask | 1 – N |
| Recording – ProcessingTask | 1 – N |
| ProcessingTask – TaskChunk | 1 – N |
| Recording – MeetingSummary | 1 – N |
| MeetingSummary – ActionItem | 1 – N |

---

# 10. GIAO TIẾP HỆ THỐNG

## 10.1. Microphone và âm thanh

Dùng API của hệ điều hành hoặc thư viện Flutter để: xin quyền microphone; thu âm (WAV PCM 16-bit mono 16 kHz, DEC-02); tạm dừng và tiếp tục; dừng và lưu tệp; nhận sự kiện gián đoạn (audio focus, cuộc gọi, đổi route); chạy ghi nền (foreground service, background audio). Phần ghi nền có thể cần mã native.

## 10.2. Giao tiếp với runtime ASR

Lớp trung gian `SpeechRecognizer` (interface) che giấu chi tiết runtime. Phương án ban đầu là sherpa-onnx nếu mô hình tiếng Việt được chọn tương thích (SP-01).

| Thao tác | Mô tả |
| --- | --- |
| initialize(modelConfig) | Nạp cấu hình và khởi tạo mô hình. |
| validate() | Kiểm tra mô hình hợp lệ và tương thích thiết bị. |
| recognizeChunk(pcm) | Nhận dạng một đoạn; trả về văn bản, mốc thời gian và độ tin cậy nếu có. |
| startStream(), feed(pcm), stop() | Nhận dạng streaming nếu mô hình hỗ trợ. |
| setHotwords(list) | Thiết lập từ khóa ưu tiên nếu hỗ trợ. |
| release() | Giải phóng tài nguyên. |

Tương tự, `VoiceActivityDetector`, `SpeakerDiarizer` và `PunctuationRestorer` là các interface tùy chọn, có thể thay thế độc lập.

## 10.3. Tải mô hình

Tải qua HTTPS từ nguồn do dự án chỉ định, dựa trên tệp mô tả (manifest) của mô hình. Ví dụ cấu trúc:

```json
{
  "id": "vi-zipformer-balanced",
  "name": "Zipformer Vietnamese (Balanced)",
  "version": "1.0.0",
  "mode": "BALANCED",
  "language": "vi",
  "sample_rate": 16000,
  "supports_streaming": false,
  "supports_hotwords": false,
  "files": [{"url": "https://…", "sha256": "…", "size": 0}],
  "license": "…"
}
```

Giá trị cụ thể do SP-01 và SP-06 xác định. Tệp tải có thể tiếp tục từ vị trí dang dở (HTTP Range).

## 10.4. Lưu trữ cục bộ

Lưu metadata bản ghi, transcript, người nói, tác vụ, từ điển, cài đặt; lưu đường dẫn tệp âm thanh; truy vấn và tìm kiếm offline; quản lý migration (NFR-REL-07).

## 10.5. Dịch vụ AI tóm tắt (tùy chọn)

Lớp tích hợp độc lập `SummaryProvider`, có thể là mô hình cục bộ hoặc nhà cung cấp trực tuyến. Với nhà cung cấp trực tuyến: cấu hình được nhà cung cấp; kiểm soát và hiển thị dữ liệu gửi đi; xử lý lỗi mạng và hết thời gian chờ; không gửi âm thanh; không ảnh hưởng ghi âm và ASR khi nhà cung cấp lỗi (FR-AI-07, FR-AI-08).

## 10.6. Hệ điều hành

Xuất tệp và chia sẻ qua Share Sheet; nhận tệp từ ứng dụng khác (FR-IMP-06); thông báo (hoàn tất nhận dạng, ghi nền); sinh trắc học cho khóa ứng dụng (FR-SET-02).

---

# 11. KIỂM THỬ VÀ TIÊU CHÍ NGHIỆM THU

## 11.1. Kiểm thử chức năng (AT)

| Mã | Nội dung kiểm thử | Kết quả mong đợi | Yêu cầu |
| --- | --- | --- | --- |
| AT-01 | Mở ứng dụng lần đầu | Hiển thị giới thiệu và dẫn tới tải mô hình | FR-ONB-01 |
| AT-02 | Tải mô hình khi mạng ổn định | Tải xong, SHA-256 khớp, mô hình READY | FR-MOD-02 |
| AT-03 | Ngắt mạng khi đang tải mô hình | Tạm dừng và tiếp tục từ vị trí cũ khi có mạng | FR-MOD-02 |
| AT-04 | Tải mô hình sai checksum | Báo ERR-MOD-02, xóa tệp tải | FR-MOD-02 |
| AT-05 | Ghi âm khi đã cấp quyền | Bắt đầu ghi, hiển thị thời lượng và mức âm lượng | FR-REC-01, 05 |
| AT-06 | Ghi âm khi chưa cấp quyền; từ chối quyền | Xin quyền; nếu từ chối: ERR-REC-01 và hướng dẫn | BR-01, FR-ONB-02 |
| AT-07 | Tạm dừng rồi tiếp tục ghi | Cùng một bản ghi, dữ liệu trước giữ nguyên | FR-REC-02, 03 |
| AT-08 | Kết thúc ghi âm | Tệp được lưu, thời lượng đúng (sai số ≤ 1 giây) | FR-REC-04 |
| AT-09 | Khóa màn hình, chuyển ứng dụng khác khi ghi 10 phút | Ghi liên tục không đứt đoạn | FR-REC-08 |
| AT-10 | Cuộc gọi đến khi đang ghi | Tự động tạm dừng, có thể tiếp tục | FR-REC-06 |
| AT-11 | Buộc đóng ứng dụng khi đang ghi | Lần mở sau có bản ghi RECOVERED, mất tối đa 5 giây cuối | FR-REC-09 |
| AT-12 | Nhập tệp WAV, MP3, M4A hợp lệ | Hệ thống đọc, sao chép và tạo bản ghi | FR-IMP-01..05 |
| AT-13 | Nhập tệp không hỗ trợ, tệp hỏng, tệp quá giới hạn | Báo ERR-IMP-01/02/03, không tạo bản ghi | FR-IMP-03 |
| AT-14 | Nhận dạng khi bật chế độ máy bay | Tạo được transcript | FR-ASR-01, BR-03 |
| AT-15 | Nhận dạng tiếng Việt có dấu | Kết quả có dấu thanh, chuẩn NFC | FR-ASR-02 |
| AT-16 | Nhận dạng bản ghi 60 phút | Xử lý theo đoạn, RAM đạt NFR-PER-01 | FR-ASR-04 |
| AT-17 | Mẫu có câu bị cắt ngang ranh giới đoạn | Không mất, không lặp từ tại ranh giới | FR-ASR-04 |
| AT-18 | Mô phỏng một đoạn lỗi | Trạng thái PARTIAL, các đoạn khác còn; thử lại được đoạn lỗi | FR-ASR-06 |
| AT-19 | Hủy nhận dạng | CANCELLED, giữ kết quả đã lưu và âm thanh gốc | FR-ASR-08 |
| AT-20 | Đóng ứng dụng khi đang nhận dạng | Khởi động lại tiếp tục từ đoạn đã lưu | FR-ASR-13 |
| AT-21 | Bắt đầu hai tác vụ nhận dạng | Chạy lần lượt, hiển thị vị trí hàng đợi | FR-ASR-13 |
| AT-22 | Chỉnh sửa transcript | Tự lưu trong 5 giây; hoàn tác/làm lại hoạt động | FR-TXT-04, 05 |
| AT-23 | Hoàn nguyên đoạn về bản ASR gốc | Văn bản gốc được khôi phục chính xác | FR-TXT-07 |
| AT-24 | Phát lại, tạm dừng, tua, đổi tốc độ | Âm thanh phát bình thường, nhớ vị trí | FR-MNG-04, 05 |
| AT-25 | Đổi tên bản ghi | Cập nhật tên thành công | FR-MNG-03 |
| AT-26 | Xóa bản ghi | Sau xác nhận, mọi dữ liệu liên quan bị xóa | FR-MNG-06 |
| AT-27 | Tìm kiếm nội dung, gồm gõ không dấu | Hiển thị kết quả phù hợp, tô sáng từ khóa | FR-SEA-02, 05 |
| AT-28 | Phân biệt người nói; đổi tên, gán lại nhãn | Hiển thị nhãn; chỉnh sửa được | FR-DIA-01..05 |
| AT-29 | Chọn đoạn văn bản để phát lại | Phát đúng phần âm thanh | FR-SYN-02 |
| AT-30 | Tạo biên bản khi có mô hình hoặc kết nối | Đúng cấu trúc; thiếu thông tin ghi “Chưa xác định” | FR-AI-01..05 |
| AT-31 | Tạo biên bản khi offline, không có mô hình | Báo ERR-AI-01; ghi âm và ASR vẫn dùng được | FR-AI-08 |
| AT-32 | Xuất TXT, DOCX, PDF | Tệp mở được, hiển thị đúng dấu tiếng Việt | FR-EXP-01..08 |
| AT-33 | Khởi động lại ứng dụng | Dữ liệu đã lưu vẫn tồn tại | NFR-REL-01 |
| AT-34 | Giám sát mạng khi dùng đủ chức năng cốt lõi | Không có yêu cầu mạng chứa dữ liệu người dùng | NFR-SEC-02 |
| AT-35 | Nâng cấp phiên bản ứng dụng | Dữ liệu được giữ nguyên | NFR-REL-07 |
| AT-36 | Không có Internet (sau khi cài mô hình) | Mọi chức năng cốt lõi vẫn hoạt động | BR-03 |

## 11.2. Kiểm thử hiệu năng (PT)

| Mã | Chỉ tiêu | Phương pháp |
| --- | --- | --- |
| PT-01 | Tốc độ nhận dạng (RTF) | Đo trên từng thiết bị tham chiếu, mỗi mô hình; chạy 3 lần lấy trung vị; ghi nhiệt độ và chế độ nguồn (Phụ lục B). |
| PT-02 | RAM | Theo dõi RAM đỉnh và RAM sau nhiều tác vụ trong lúc xử lý. |
| PT-03 | CPU và giao diện | Theo dõi CPU; đo số khung hình trễ bằng công cụ hiệu năng của Flutter. |
| PT-04 | Pin | Đo mức tiêu thụ trong cùng điều kiện: màn hình tắt, độ sáng và mạng cố định. |
| PT-05 | Độ ổn định | Chạy 10 phiên nhận dạng liên tiếp; kiểm tra rò rỉ RAM. |
| PT-06 | Âm thanh dài | Nhận dạng bản ghi 30, 60, 120 phút; ghi âm nền liên tục 4 giờ. |
| PT-07 | Khởi động, danh sách, tìm kiếm, kích thước gói | Theo NFR-PER-07, 08, 09. |

## 11.3. Kiểm thử chất lượng nhận dạng

Tập kiểm thử phải có: giọng nam và nữ; giọng miền Bắc, Trung, Nam; một người nói và nhiều người nói; môi trường yên tĩnh và có tiếng ồn; hội thoại có thuật ngữ tiếng Anh; tốc độ nói khác nhau. Mỗi mẫu có transcript chuẩn do con người kiểm tra. Tập kiểm thử không được trùng với dữ liệu huấn luyện của mô hình.

Kích thước đề xuất (ĐX): tổng ≥ 5 giờ, mỗi vùng miền ≥ 1 giờ, âm thanh có nhiễu ≥ 30 phút. Công thức và quy ước chuẩn hóa xem Phụ lục B. Kết quả báo cáo theo từng nhóm điều kiện, không chỉ trung bình chung, để tránh một con số tốt che giấu các trường hợp nhận dạng kém.

## 11.4. Kiểm thử trên thiết bị

Ứng dụng được thử nghiệm trên ít nhất một thiết bị mỗi nhóm A, B, C (mục 2.4) cho cả Android và iOS. Không kết luận ứng dụng tương thích với mọi điện thoại chỉ từ kết quả của một thiết bị. Mỗi nền tảng được kiểm thử riêng các tình huống ghi nền, gián đoạn và quyền truy cập.

---

# 12. PHÂN CHIA GIAI ĐOẠN TRIỂN KHAI

Danh sách dưới đây đồng bộ với cột GĐ của mục 3. Mỗi giai đoạn có tiêu chí kết thúc dựa trên kiểm thử ở mục 11.

| Giai đoạn | Yêu cầu | Kết quả cần đạt |
| --- | --- | --- |
| **P1 – MVP** | FR-MOD-01, 02, 03, 05, 06; FR-ONB-01..03; FR-REC-01..10; FR-IMP-01..05; FR-ASR-01, 02, 03, 04, 06, 07, 08, 12, 13; FR-TXT-01, 02, 04, 05, 07; FR-MNG-01..06; FR-EXP-01, 06; FR-SET-01 | Người dùng ghi âm (kể cả nền) hoặc nhập tệp, chuyển thành văn bản tiếng Việt offline, nghe lại, chỉnh sửa, lưu, xóa và xuất TXT. Qua AT-01..26, AT-33..36 và PT-01..07 trên các nhóm thiết bị. |
| **P2 – Nâng cao nhận dạng** | FR-ASR-05, 09, 10, 11, 14; FR-MOD-04; FR-TXT-03, 06; FR-DIA-01..07 | Nhận dạng gần thời gian thực, cải thiện chất lượng transcript, hỗ trợ hội thoại nhiều người. Qua AT-28 và các phép đo WER của NFR-ACC-02. |
| **P3 – Quản lý nội dung** | FR-MNG-07..10; FR-SYN-01..04; FR-SEA-01..05; FR-EXP-02..05, 07, 08; FR-TXT-08, 09; FR-REC-11; FR-IMP-06; FR-MOD-07; FR-SET-02, 03; FR-STO-01, 02 | Công cụ quản lý bản ghi và nội dung hoàn chỉnh: tìm kiếm, đồng bộ âm thanh–văn bản, xuất DOCX và PDF, khóa ứng dụng. Qua AT-27, 29, 32. |
| **P4 – Trợ lý cuộc họp** | FR-AI-01..10 | Tạo tóm tắt, quyết định, công việc và biên bản có cấu trúc, có kiểm soát dữ liệu gửi AI. Qua AT-30, 31. |

Ghi chú: dữ liệu thời gian của Segment (start\_ms, end\_ms) được lưu từ P1 để P3 không phải nhận dạng lại.

---

# 13. KIẾN TRÚC TRIỂN KHAI

## 13.1. Công nghệ đề xuất

| Thành phần | Công nghệ đề xuất | Vai trò |
| --- | --- | --- |
| Framework / ngôn ngữ | Flutter / Dart | Ứng dụng Android và iOS. |
| ASR runtime | sherpa-onnx (qua FFI) | Chạy mô hình nhận dạng offline. |
| Mô hình ASR | Zipformer tiếng Việt hoặc mô hình tương thích (chọn sau SP-01, SP-06) | Nhận dạng giọng nói. |
| VAD | Silero VAD hoặc tương đương (qua runtime) | Chia đoạn theo tiếng nói. |
| Thu âm | Plugin ghi âm Flutter kèm mã native cho ghi nền | Thu âm microphone. |
| Giải mã âm thanh | Thư viện giải mã phù hợp (SP-01) | Chuẩn hóa tệp nhập. |
| Cơ sở dữ liệu | SQLite với Drift, FTS5 | Metadata, transcript, tìm kiếm. |
| Lưu tệp | Thư mục dữ liệu của ứng dụng | Âm thanh và mô hình. |
| Xuất tài liệu | Thư viện tạo DOCX và PDF có nhúng font Unicode | Xuất tài liệu. |

Đây là phương án đề xuất, không bắt buộc duy nhất (CON-04). Mọi thư viện và mô hình phải qua rà soát giấy phép (CON-07).

## 13.2. Cấu trúc module

```text
lib/
├── core/                 # hằng số, lỗi, tiện ích, dịch vụ chung
├── data/                 # database (Drift), models, repositories, local_storage
├── features/
│   ├── onboarding/
│   ├── recording/        # data / domain / presentation
│   ├── audio_import/
│   ├── speech_to_text/   # asr_engine, audio_processor, vad, text_processor, task_queue
│   ├── transcript/
│   ├── speaker/
│   ├── recording_management/
│   ├── search/
│   ├── meeting_summary/
│   ├── export/
│   ├── model_management/
│   └── settings/
└── main.dart
```

## 13.3. Nguyên tắc xử lý ASR

1. Nhận dữ liệu từ microphone hoặc tệp nhập.
2. Kiểm tra định dạng và thông số âm thanh.
3. Giải mã và chuẩn hóa sample rate, số kênh theo luồng.
4. Phát hiện đoạn có tiếng nói bằng VAD (nếu cấu hình).
5. Chia đoạn theo độ dài tối đa của mô hình; cắt cứng với vùng chồng lấn khi không có khoảng lặng.
6. Đưa từng đoạn vào ASR Engine; nhận kết quả, timestamp, độ tin cậy nếu có.
7. Lưu ngay kết quả từng đoạn (Segment, TaskChunk) để có thể tiếp tục và thử lại.
8. Ghép theo thứ tự, loại phần trùng ở ranh giới.
9. Hậu xử lý văn bản, cập nhật chỉ mục tìm kiếm.
10. Cập nhật trạng thái tác vụ và giải phóng tài nguyên.

## 13.4. Mô hình đồng thời

- Giao diện chạy trên luồng chính; ghi âm, giải mã, VAD và ASR chạy trên isolate hoặc luồng native riêng.
- Hàng đợi tác vụ chạy tuần tự, mỗi lần một tác vụ ASR (BR-13); trạng thái truyền về giao diện qua luồng sự kiện.
- Ghi âm nền do dịch vụ native quản lý, độc lập với vòng đời màn hình.
- Khối âm thanh được ghi xuống đĩa theo khối ≤ 5 giây để phục vụ khôi phục (FR-REC-09).

---

# 14. RỦI RO VÀ PHƯƠNG ÁN GIẢM THIỂU

| Mã | Rủi ro | Mức độ | Phương án giảm thiểu |
| --- | --- | --- | --- |
| RSK-01 | Nhận dạng tiếng Việt chưa đủ chính xác | Cao | Xây dựng tập kiểm thử, so sánh nhiều mô hình (SP-06). |
| RSK-02 | Giọng vùng miền khác nhau | Cao | Đánh giá riêng từng vùng; mục tiêu chênh lệch WER (NFR-ACC-02). |
| RSK-03 | Thiết bị cấu hình thấp không chạy nổi mô hình | Cao | Mô hình Lightweight, kiểm tra tài nguyên (FR-MOD-05). |
| RSK-04 | Tốn RAM với âm thanh dài | Cao | Chia đoạn, xử lý bất đồng bộ, đo PT-06. |
| RSK-05 | Tiêu thụ pin cao | Trung bình | Cho phép tắt nhận dạng trực tiếp, chọn chế độ, đo PT-04. |
| RSK-06 | Tiếng ồn làm giảm độ chính xác | Cao | Thử VAD và speech enhancement (SP-04). |
| RSK-07 | Nhận dạng sai người nói | Trung bình | Cho phép chỉnh nhãn, gộp, gán lại (FR-DIA-03, 04, 07). |
| RSK-08 | Tóm tắt AI tạo thông tin sai | Cao | Người dùng kiểm tra; nhãn “Do AI tạo”; BR-07, BR-09. |
| RSK-09 | Mất dữ liệu khi ứng dụng bị đóng | Cao | Ghi theo khối, lưu từng đoạn, khôi phục (FR-REC-09, FR-ASR-13). |
| RSK-10 | Mô hình hoặc dữ liệu không tương thích giấy phép | Cao | Rà soát giấy phép trước khi phân phối (OI-06). |
| RSK-11 | Khác biệt giữa Android và iOS | Trung bình | Kiểm thử riêng từng nền tảng. |
| RSK-12 | Thiếu dung lượng lưu trữ | Trung bình | Kiểm tra và cảnh báo trước và trong khi ghi (FR-REC-10, FR-STO-02). |
| RSK-13 | Hệ điều hành hạn chế ghi âm và xử lý nền | Cao | Foreground service, background audio; thử nghiệm dài (SP-02). |
| RSK-14 | Không có mô hình streaming hoặc thêm dấu câu tiếng Việt chạy on-device | Cao | Dự phòng VAD cộng nhận dạng theo đoạn; ẩn tính năng nếu chưa đạt (SP-01, SP-05). |
| RSK-15 | Rủi ro pháp lý khi ghi âm người khác và xử lý dữ liệu cá nhân | Cao | Lưu ý và xác nhận của người dùng (FR-ONB-03); rà soát pháp lý (OI-05). |
| RSK-16 | Store từ chối do quyền nền hoặc khai báo dữ liệu | Trung bình | Khai báo chính xác (NFR-SEC-11); kiểm tra chính sách từ sớm. |

---

# 15. SPIKE KỸ THUẬT VÀ VẤN ĐỀ MỞ

## 15.1. Spike kỹ thuật

Các spike dưới đây phải hoàn thành trước khi chốt các giá trị (ĐX) và trước khi cam kết các tính năng có rủi ro.

| Mã | Nội dung | Đầu ra | Phục vụ |
| --- | --- | --- | --- |
| SP-01 | Chạy sherpa-onnx và mô hình tiếng Việt trên Flutter (FFI) cho Android và iOS; kiểm tra giải mã các định dạng âm thanh, kiến trúc CPU, phiên bản hệ điều hành tối thiểu. | Danh sách định dạng, OS và kiến trúc chính thức; xác nhận mô hình streaming hay offline. | FR-IMP-02, NFR-COM-05, mục 2.3 |
| SP-02 | Ghi âm dài và ghi nền 2–4 giờ trên Android và iOS, kèm gián đoạn. | Xác nhận giới hạn thời lượng và dung lượng (DEC-03). | FR-REC-06, 08, 09 |
| SP-03 | Benchmark RTF, RAM, pin theo nhóm thiết bị và theo mô hình. | Bảng benchmark; chế độ mặc định theo thiết bị. | NFR-PER-01..06, FR-MOD-04 |
| SP-04 | So sánh WER có và không có VAD, lọc nhiễu, speech enhancement. | Cấu hình tiền xử lý mặc định. | FR-ASR-09 |
| SP-05 | Khảo sát mô hình thêm dấu câu và viết hoa tiếng Việt chạy on-device. | Quyết định có phát hành FR-TXT-03 hay không. | FR-TXT-03 |
| SP-06 | Xây dựng tập kiểm thử và đo WER nền theo Phụ lục B. | Số liệu xác nhận hoặc điều chỉnh ngưỡng NFR-ACC-02. | NFR-ACC-01, 02 |
| SP-07 | Đo ảnh hưởng của mã hóa mức ứng dụng (cơ sở dữ liệu, tệp âm thanh). | Quyết định áp dụng NFR-SEC-09. | NFR-SEC-09 |
| SP-08 | Thử diarization on-device và hotwords: chất lượng, tài nguyên, nhận dạng streaming so với offline. | Quyết định phạm vi P2. | FR-DIA, FR-ASR-05, 11 |

## 15.2. Vấn đề mở

| Mã | Vấn đề | Người quyết định |
| --- | --- | --- |
| OI-01 | Có phát hành biến thể “Lite” đóng gói sẵn mô hình nhẹ không (DEC-01)? | Product Owner |
| OI-02 | Nơi lưu trữ và phân phối mô hình (CDN hay kho công khai), chi phí băng thông. | Product Owner, Developer |
| OI-03 | Danh sách thiết bị thử nghiệm cụ thể cho từng nhóm A, B, C. | QA |
| OI-04 | Chọn cách làm AI Summary: mô hình cục bộ, nhà cung cấp trực tuyến hay cả hai; chính sách dữ liệu. | Product Owner |
| OI-05 | Rà soát pháp lý về ghi âm cuộc họp và bảo vệ dữ liệu cá nhân; nội dung thông báo FR-ONB-03. | Product Owner, tư vấn pháp lý |
| OI-06 | Giấy phép cụ thể của mô hình và dữ liệu huấn luyện cho phân phối ứng dụng. | Developer, tư vấn pháp lý |

---

# 16. TIÊU CHÍ HOÀN THÀNH DỰ ÁN (DEFINITION OF DONE)

Dự án được xem là hoàn thành khi:

1. Ứng dụng cài đặt và chạy trên thiết bị tham chiếu của từng nhóm A, B, C, cả Android và iOS.
2. Người dùng ghi âm bằng microphone, kể cả khi ở nền và khi có gián đoạn.
3. Người dùng nhập được tệp WAV, MP3, M4A hợp lệ.
4. Hệ thống nhận dạng tiếng Việt offline sau khi cài mô hình (AT-14, AT-36).
5. Transcript xem, chỉnh sửa và hoàn nguyên được; bản ASR gốc không bị thay đổi.
6. Bản ghi được lưu và quản lý cục bộ; xóa theo đúng FR-MNG-06.
7. Bản ghi dài tối thiểu 120 phút được xử lý bằng chia đoạn, RAM trong ngưỡng NFR-PER-01.
8. Người dùng tìm kiếm nội dung (kể cả không dấu) và xuất transcript đúng dấu tiếng Việt.
9. Lỗi quan trọng không làm mất âm thanh gốc; khôi phục sau sự cố đạt NFR-REL-03.
10. Ứng dụng không tự động gửi bản ghi hay transcript ra ngoài (AT-34).
11. Kết quả WER theo từng nhóm, RTF, RAM, CPU và pin được ghi nhận trên thiết bị thử nghiệm, và đạt chỉ tiêu đã xác nhận qua spike hoặc có giải trình.
12. Mỗi tính năng triển khai có test case và kết quả kiểm thử; các AT tương ứng đều đạt.
13. Giấy phép thư viện và mô hình được rà soát; chính sách quyền riêng tư và nhãn dữ liệu store hoàn tất.
14. Rà soát pháp lý về ghi âm và dữ liệu cá nhân (OI-05) hoàn tất.
15. Các spike SP-01 đến SP-08 hoàn thành và các giá trị (ĐX) trong tài liệu được chốt hoặc điều chỉnh.

---

# 17. MA TRẬN TRUY VẾT

| Tính năng | Mục tiêu | Yêu cầu | Màn hình | Use case | Dữ liệu | Kiểm thử |
| --- | --- | --- | --- | --- | --- | --- |
| Quản lý mô hình | OBJ-02, 08 | FR-MOD-01..07 | UI-11 | UC-15, 17 | ASRModel | AT-02..04 |
| Khởi đầu và quyền | OBJ-07 | FR-ONB-01..03 | UI-01 | UC-17 | AppSetting | AT-01, 06 |
| Ghi âm | OBJ-04 | FR-REC-01..11 | UI-02 | UC-01..04, 18 | Recording, AudioChunk | AT-05..11, PT-06 |
| Nhập tệp | OBJ-04 | FR-IMP-01..06 | UI-03 | UC-05 | Recording | AT-12, 13 |
| Nhận dạng | OBJ-01, 02, 03 | FR-ASR-01..14 | UI-02, 04 | UC-06, 07, 18, 19 | Transcript, TranscriptSegment, ProcessingTask, TaskChunk, CustomTerm | AT-14..21, PT-01..05 |
| Hậu xử lý | OBJ-01 | FR-TXT-01..09 | UI-05 | UC-08, 09 | TranscriptSegment | AT-22, 23 |
| Người nói | OBJ-05 | FR-DIA-01..07 | UI-07 | UC-11 | Speaker | AT-28 |
| Quản lý bản ghi | OBJ-04 | FR-MNG-01..10, FR-STO | UI-01, 06 | UC-10, 16 | Recording | AT-24..26 |
| Đồng bộ | OBJ-04 | FR-SYN-01..04 | UI-05, 06 | UC-08, 10 | TranscriptSegment | AT-29 |
| Tìm kiếm | OBJ-04 | FR-SEA-01..05 | UI-08 | UC-12 | Chỉ mục FTS | AT-27, PT-07 |
| Tóm tắt và biên bản | OBJ-06 | FR-AI-01..10 | UI-09 | UC-13 | MeetingSummary, ActionItem | AT-30, 31 |
| Xuất và chia sẻ | OBJ-04 | FR-EXP-01..08 | UI-10 | UC-14 | – | AT-32 |
| Cài đặt | OBJ-03, 07 | FR-SET-01..03 | UI-12 | – | AppSetting | AT-34 |
| Bảo mật và độ tin cậy | OBJ-07 | NFR-SEC, NFR-REL | UI-12 | – | – | AT-33..35 |

---

# PHỤ LỤC A – DANH MỤC MÃ LỖI VÀ THÔNG BÁO

| Mã | Tình huống | Thông báo gợi ý | Hành động |
| --- | --- | --- | --- |
| ERR-REC-01 | Quyền microphone bị từ chối | Cần quyền microphone để ghi âm. | Nút “Mở Cài đặt” |
| ERR-REC-02 | Microphone đang được ứng dụng khác dùng | Microphone đang được ứng dụng khác sử dụng. Hãy đóng ứng dụng đó rồi thử lại. | Thử lại |
| ERR-REC-03 | Thiếu dung lượng | Bộ nhớ gần đầy. Phần đã ghi được giữ lại. Hãy giải phóng dung lượng. | Mở quản lý dung lượng |
| ERR-REC-04 | Phiên ghi bị gián đoạn, chỉ khôi phục một phần | Bản ghi bị gián đoạn. Đã khôi phục phần ghi được. | Xem bản ghi |
| ERR-IMP-01 | Định dạng không hỗ trợ | Định dạng tệp chưa được hỗ trợ. | Hiển thị danh sách định dạng hỗ trợ |
| ERR-IMP-02 | Tệp hỏng hoặc không đọc được | Không đọc được tệp âm thanh này. | Chọn tệp khác |
| ERR-IMP-03 | Vượt giới hạn thời lượng | Tệp dài hơn giới hạn cho phép. | Hiển thị giới hạn |
| ERR-IMP-04 | Thiếu dung lượng để sao chép | Không đủ dung lượng để nhập tệp. | Mở quản lý dung lượng |
| ERR-MOD-01 | Không đủ dung lượng tải mô hình | Cần thêm dung lượng trống để tải mô hình. | Mở quản lý dung lượng |
| ERR-MOD-02 | Mô hình tải về bị lỗi (sai checksum) | Tệp mô hình bị lỗi. | Tải lại |
| ERR-MOD-03 | Thiết bị không đủ tài nguyên hoặc không tương thích | Thiết bị chưa đủ tài nguyên cho mô hình này. | Chọn mô hình nhẹ hơn |
| ERR-MOD-04 | Mất kết nối khi tải mô hình | Mất kết nối. Việc tải sẽ tiếp tục khi có mạng. | Tiếp tục khi có mạng |
| ERR-ASR-01 | Tệp âm thanh không hợp lệ khi nhận dạng | Không thể xử lý tệp âm thanh này. | Chọn tệp khác |
| ERR-ASR-02 | Một số đoạn nhận dạng thất bại | Một số đoạn chưa nhận dạng được. | Thử lại các đoạn lỗi |
| ERR-ASR-03 | Thiếu bộ nhớ khi nhận dạng | Thiếu bộ nhớ. Nhận dạng đã dừng; kết quả đã có được giữ lại. | Thử lại hoặc chọn mô hình nhẹ hơn |
| ERR-ASR-04 | Mô hình chưa sẵn sàng | Chưa có mô hình nhận dạng sẵn sàng. | Mở Quản lý mô hình |
| ERR-AI-01 | Không có Internet và không có mô hình tóm tắt cục bộ | Tính năng tóm tắt chưa khả dụng khi không có kết nối. | Quay lại transcript |
| ERR-AI-02 | Kết quả AI không hợp lệ | Không tạo được biên bản. Transcript của bạn không bị ảnh hưởng. | Thử lại |
| ERR-AI-03 | Lỗi mạng hoặc quá thời gian chờ khi dùng AI trực tuyến | Không kết nối được dịch vụ tóm tắt. | Thử lại |
| ERR-STO-01 | Lưu dữ liệu thất bại | Không lưu được thay đổi. Nội dung đang sửa vẫn được giữ. | Thử lại |
| ERR-EXP-01 | Không có dữ liệu để xuất | Chưa có nội dung để xuất. | Quay lại |

---

# PHỤ LỤC B – PHƯƠNG PHÁP ĐO WER VÀ RTF

## B.1. WER cho tiếng Việt

Công thức: **WER = (S + D + I) / N**, trong đó S là số đơn vị bị thay thế, D bị xóa, I bị chèn, N là tổng số đơn vị trong transcript chuẩn.

- **Đơn vị tính (DEC-08):** âm tiết, tức mỗi tiếng tách bởi khoảng trắng. Từ tiếng Anh xen kẽ tính mỗi từ một đơn vị. CER được báo cáo kèm.
- **Chuẩn hóa trước khi so:** Unicode NFC; chữ thường; bỏ dấu câu; số quy ước một cách thống nhất (transcript chuẩn viết số bằng chữ, hoặc cả hai phía cùng chuyển sang chữ số); từ viết tắt và tên riêng theo bảng quy ước của tập kiểm thử.
- **Phân nhóm báo cáo:** vùng miền, giới tính, một hay nhiều người nói, môi trường (yên tĩnh, nhiễu), tốc độ nói, có hay không thuật ngữ tiếng Anh. Kèm khoảng tin cậy (ví dụ bootstrap).
- **Tỷ lệ nhận đúng thuật ngữ:** số lần thuật ngữ trong danh sách chuẩn được nhận dạng đúng chia cho số lần xuất hiện.
- **Công cụ:** dùng một công cụ tính WER thống nhất cho mọi lần đo; cố định phiên bản.

## B.2. RTF

RTF = thời gian xử lý / thời lượng âm thanh. Đo từ lúc bắt đầu giải mã đến khi có kết quả cuối cùng, không gồm thời gian tải mô hình. Mỗi phép đo chạy ít nhất 3 lần và lấy trung vị; ghi nhiệt độ thiết bị, chế độ tiết kiệm pin, mức pin và bản dựng ứng dụng. Thiết bị chạy ở điều kiện ổn định (không sạc nhanh, không chạy ứng dụng nặng khác).
