"""Ung dung web (Streamlit): ghi am / tai len -> chep loi -> tom tat cuoc hop."""
from __future__ import annotations

import tempfile
from pathlib import Path

import streamlit as st

from src.config import DEFAULT_LANGUAGE, WHISPER_MODEL, llm_configured
from src.core import process_audio
from src.summarize import render_markdown
from src.transcribe import list_models

st.set_page_config(page_title="Voice To Text - Tom tat cuoc hop", page_icon="🎙️", layout="wide")

st.title("🎙️ Voice To Text — Chep loi & Tom tat cuoc hop")
st.caption(
    "Ghi am hoac tai len file audio cuoc hop. Ung dung chep loi (Whisper local) "
    "roi tom tat chu de, quyet dinh va viec can lam."
)

with st.sidebar:
    st.header("Cai dat")
    language = st.text_input(
        "Nguon ngu (de trong = tu nhan dien)", value=DEFAULT_LANGUAGE or ""
    ).strip() or None
    models = list_models()
    model = st.selectbox("Mo hinh Whisper", models, index=models.index(WHISPER_MODEL))
    st.divider()
    if llm_configured():
        st.success("✅ Da cau hinh LLM tom tat (chat luong cao).")
    else:
        st.info("ℹ️ Chua co API LLM -> dung tom tat theo quy tac (mien phi, khong can key). "
                "Dat SUMMARY_API_KEY trong .env de nang cap.")

tab_up, tab_rec = st.tabs(["📁 Tai len file", "🎤 Ghi am truc tiep"])

audio_bytes = None
audio_name = "recording.wav"

with tab_up:
    uploaded = st.file_uploader("Chon file audio", type=["mp3", "wav", "m4a", "ogg", "flac", "webm"])
    if uploaded:
        audio_bytes = uploaded.getvalue()
        audio_name = uploaded.name

with tab_rec:
    try:
        from streamlit_audiorecorder import audiorecorder
        st.write("Nhan de ghi am, nhan lai de dung:")
        rec = audiorecorder("🎤 Bat dau", "⏹️ Dung")
        if len(rec) > 0:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                rec.export(tmp.name, format="wav")
                audio_bytes = Path(tmp.name).read_bytes()
                audio_name = "recording.wav"
            st.audio(audio_bytes, format="audio/wav")
    except Exception as exc:
        st.warning(f"Ghi am trinh duyet khong kha dung tren moi truong nay ({exc}). "
                   "Hay dung tab 'Tai len file'.")

if audio_bytes:
    st.audio(audio_bytes, format="audio/wav" if audio_name.endswith("wav") else "audio/mpeg")
    if st.button("🚀 Xu ly & Tom tat", type="primary"):
        with tempfile.TemporaryDirectory() as td:
            suffix = Path(audio_name).suffix or ".wav"
            path = Path(td) / f"input{suffix}"
            path.write_bytes(audio_bytes)
            with st.status("Dang chep loi...", expanded=True) as status:
                progress_bar = st.progress(0.0)
                def _prog(frac, _msg):
                    progress_bar.progress(min(1.0, frac))
                try:
                    result = process_audio(
                        path, out_dir=None, language=language, model_size=model,
                        progress=_prog,
                    )
                except Exception as exc:
                    st.error(f"Loi khi xu ly: {exc}")
                    st.stop()
                status.update(label="Hoan tat!", state="complete", expanded=False)
            st.header("📝 Ban chep loi")
            st.write(result["transcript"]["text"])
            with st.expander("Xem theo thoi gian (segments)"):
                for s in result["transcript"]["segments"]:
                    st.markdown(f"`{s['start']:.1f}–{s['end']:.1f}s` — {s['text']}")
            st.header("🧠 Tom tat cuoc hop")
            st.markdown(render_markdown(result["summary"]))
            txt = result["transcript"]["text"]
            col1, col2 = st.columns(2)
            col1.download_button("Tai ban chep loi (.txt)", txt, file_name="transcript.txt")
            col2.download_button(
                "Tai tom tat (.md)", render_markdown(result["summary"]),
                file_name="summary.md",
            )
else:
    st.info("Hay tai len mot file audio hoac ghi am de bat dau.")
