# NoteX - Ghi chú & Họp AI

Ứng dụng ghi âm thông minh, chép lời và tóm tắt cuộc họp bằng AI. Chuyển đổi
giọng nói thành văn bản theo thời gian thực, tạo biên bản, sơ đồ tư duy, thẻ
ghi nhớ, quiz và slide thuyết trình.

## Tính năng chính

- **Ghi âm & Chép lời realtime**: Chuyển giọng nói thành văn bản theo thời gian
  thực, hỗ trợ nhiều ngôn ngữ (mặc định Tiếng Việt).
- **Tóm tắt thông minh**: Tóm tắt chung, chủ đề, quyết định, việc cần làm,
  câu hỏi còn bỏ ngỏ (LLM khi có API key, fallback quy tắc nếu không).
- **Sơ đồ tư duy**: Trực quan hóa cấu trúc cuộc họp thành mind map.
- **Thẻ ghi nhớ (Flashcards)**: Tự động tạo thẻ học tập từ nội dung.
- **Quiz trắc nghiệm**: Tạo câu hỏi ôn tập từ ghi chú.
- **Slides thuyết trình**: Tạo slide tóm tắt từ bản ghi.
- **Đa ngôn ngữ**: Dịch thuật bản chép lời sang 8 ngôn ngữ.
- **Phân biệt người nói (Diarization)**: Gán nhãn từng người nói trong cuộc họp.
- **Xuất file**: PDF, Word (.docx), văn bản (.txt).
- **Quản lý mô hình**: Chọn mô hình Whisper phù hợp (tiny → large-v3).

## Kiến trúc

- **Frontend**: Flutter (Material 3, theme tím NoteX)
- **Backend**: Python FastAPI + faster-whisper (STT local) + LLM summary

## Cài đặt Backend

```bash
pip install -r requirements.txt
python api_server.py            # mở cổng 0.0.0.0:8000
```

Cấu hình LLM (tùy chọn) trong `.env`:

```
SUMMARY_API_KEY=sk-...
SUMMARY_BASE_URL=https://api.openai.com/v1
SUMMARY_MODEL=gpt-4o-mini
DEFAULT_LANGUAGE=vi
WHISPER_MODEL=large-v3
```

## Chạy Flutter App

```bash
flutter pub get
flutter run
```

Cấu hình Backend URL trong màn hình Cài đặt:
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://127.0.0.1:8000`
- Cùng Wi-Fi: `http://<IP-máy-tính>:8000`

## Cấu trúc mã nguồn

```
lib/
  main.dart              # Entry point, theme, navigation
  theme.dart             # Design system NoteX (Material 3)
  screens/
    onboarding_screen.dart   # Màn hình chào đầu tiên
    home_screen.dart        # Danh sách bản ghi
    recording_screen.dart   # Ghi âm + chép lời realtime
    result_screen.dart      # 6 tabs: Chép lời/Tóm tắt/Sơ đồ/Bản dịch/Quiz/Slides
    search_screen.dart      # Tìm kiếm
    settings_screen.dart    # Cài đặt server/ASR/AI/Lịch
  data/                  # SQLite local storage
src/
  transcribe.py          # STT faster-whisper
  summarize.py           # Tóm tắt LLM + quy tắc (mind_map, flashcards, quiz, slides)
  translate.py           # Dịch thuật đa ngôn ngữ
  diarize.py             # Phân biệt người nói
```
