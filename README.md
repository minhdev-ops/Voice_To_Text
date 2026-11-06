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

Toàn bộ mã backend nằm trong thư mục `backend/`:

```bash
pip install -r backend/requirements.txt
cd backend
python api_server.py            # mở cổng 0.0.0.0:8000
# hoặc: uvicorn api_server:app --host 0.0.0.0 --port 8000
```

Cấu hình LLM (tùy chọn) trong `backend/.env` (sao chép từ `backend/.env.example`):

```
SUMMARY_API_KEY=sk-...
SUMMARY_BASE_URL=https://api.openai.com/v1
SUMMARY_MODEL=gpt-4o-mini
DEFAULT_LANGUAGE=vi
WHISPER_MODEL=large-v3
# Bảo mật (production)
# API_TOKEN=<chuoi ngau nhien>        # bat xac thuc Bearer tren cac endpoint
# CORS_ORIGINS=https://app.example    # khong dung "*" khi da co auth
# ALLOW_EXTERNAL_TRANSLATE=1          # cho phep fallback Google dich (mac dinh tat)
```

## Kiểm thử backend

```bash
cd backend
pip install pytest httpx
pytest tests -q                     # test unit (nhanh, stub Whisper)
REAL_MODEL=1 pytest tests -q        # them test voi Whisper that (can model)
```

## API backend (xử lý bất đồng bộ như NoteX)

Frontend không chờ backend xử lý xong trong một request. Luồng:

```text
POST /api/tasks   (multipart: file, language, model, diarize, num_speakers)
      -> 202 {"task_id": "...", "status": "PENDING"}
GET  /api/tasks/{task_id}
      -> PENDING | PROCESSING | SUCCESS | FAILURE
         kèm step, progress (0-100), data (transcript + summary) hoặc error
```

Task chạy nền, một worker (Whisper không chạy song song), kết quả giữ tối đa
50 task đã xong. Audio tải lên tối đa 1 GB, định dạng
wav/mp3/m4a/ogg/flac/webm/aac/mp4/opus.

## Triển khai production

- Chạy đúng 1 process uvicorn (`uvicorn api_server:app`): task queue nằm trong RAM,
  dùng nhiều worker sẽ mất task.
- Phía trước dùng nginx/Caddy để có HTTPS và giới hạn tốc độ (`limit_req`).
- Đặt `API_TOKEN`, chia sẻ cho app; không mở port ra Internet mà không có TLS + token.
- Mặc định dịch thuật khi chưa có LLM sẽ từ chối thay vì gửi transcript ra Google
  (quyền riêng tư). Bật bằng `ALLOW_EXTERNAL_TRANSLATE=1` nếu chấp nhận.
- `WHISPER_MODEL` GPU/CPU tự chọn; mô hình tải về `~/.cache/huggingface`.

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
backend/
  api_server.py          # FastAPI: toàn bộ xử lý AI (STT, tóm tắt, dịch, diarize)
  src/
    transcribe.py        # STT faster-whisper
    summarize.py         # Tóm tắt LLM + quy tắc (mind_map, flashcards, quiz, slides)
    translate.py         # Dịch thuật đa ngôn ngữ
    diarize.py           # Phân biệt người nói
```
