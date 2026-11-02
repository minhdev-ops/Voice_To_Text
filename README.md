# Voice_To_Text

Ghi am cuoc hop -> **chep loi (speech-to-text)** -> **tom tat co cau truc**
(chu de, quyet dinh, viec can lam, van de bo ngo).

Ung dung chay **local** bang Whisper (faster-whisper), tan dung GPU neu co.
Tom tat mac dinh dung quy tac (khong can key), tu dong nang cap len LLM
khi ban cau hinh API.

## Tinh nang

- Chep loi audio (mp3/wav/m4a/...) da ngon ngu, mac dinh tieng Viet.
- Tom tat cuoc hop: tom tat chung, chu de, quyet dinh, action items, cau hoi bo ngo.
- Giao dien web (Streamlit) de ghi am/tai len va xem ket qua.
- CLI de chay nhanh hoac tich hop tu dong.
- Tom tat bang LLM (OpenAI-compatible) khi co API key; fallback quy tac neu khong.

## Cai dat

```bash
pip install -r requirements.txt
```

Lan dau chay se tai mo hinh Whisper (vai chuc–tram MB tuy kich thuoc).

## Cau hinh (tuy chon)

Sao chep `.env.example` thanh `.env` va dien neu muon tom tat bang LLM:

```
SUMMARY_API_KEY=sk-...
SUMMARY_BASE_URL=https://api.openai.com/v1
SUMMARY_MODEL=gpt-4o-mini
DEFAULT_LANGUAGE=vi
WHISPER_MODEL=base
```

> Khong co key -> ung dung van chay binh thuong voi tom tat theo quy tac.

## Su dung — Giao dien web

```bash
streamlit run app.py
```

Mo trinh duyet, tai len file audio (hoac ghi am), chon nguon ngu/mo hinh, nhan
**Xu ly & Tom tat**. Ket qua gom ban chep loi va tom tat, co nut tai ve.

## Su dung — CLI

```bash
# Chep loi + tom tat mot file audio
python cli.py meeting.mp3 --language vi --out ./output

# Dung mo hinh lon hon cho tieng Viet tot hon
python cli.py meeting.mp3 --model small

# Chi tom tat ban chep loi co san (bo qua STT)
python cli.py --text-only transcript.txt
```

Ket qua duoc luu vao thu muc `--out` (mac dinh `./output`):
`*_transcript.md`, `*_summary.md`, `*_result.json`.

## Cau truc ma nguon

```
src/
  config.py      # doc cau hinh (.env / env)
  transcribe.py  # chep loi bang faster-whisper
  summarize.py   # tom tat LLM + fallback quy tac
  core.py        # noi STT + tom tat, luu file
app.py           # giao dien Streamlit
cli.py           # giao dien dong lenh
```
