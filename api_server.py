"""API server cho Voice_To_Text.

Nhan file audio (hoac text) -> chep loi (Whisper local) + tom tat -> tra ve JSON.
Frontend Flutter (app auvira) goi cac endpoint nay.

Chay:
  uvicorn api_server:app --host 0.0.0.0 --port 8000
Hoac:
  python api_server.py
"""
from __future__ import annotations

import tempfile
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from src.config import DEFAULT_LANGUAGE, WHISPER_MODEL
from src.core import process_audio, process_text
from src.summarize import configure_llm, llm_status, summarize_transcript
from src.transcribe import list_models

app = FastAPI(title="Voice To Text API", version="1.0.0")

# Cho phep Flutter (web/android) goi tu may khac trong luc phat trien.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health():
    return {"status": "ok", "model": WHISPER_MODEL, "llm": llm_status()["configured"]}


class LlmSettings(BaseModel):
    api_key: str | None = None
    base_url: str | None = None
    model: str | None = None


@app.get("/api/settings/summary")
def get_summary_settings():
    return llm_status()


@app.post("/api/settings/summary")
def set_summary_settings(req: LlmSettings):
    configure_llm(req.api_key, req.base_url, req.model)
    return llm_status()


class ResummarizeRequest(BaseModel):
    text: str
    language: str | None = None


@app.post("/api/resummarize")
def resummarize(req: ResummarizeRequest):
    """Tao lai tom tat cho mot ban chep loi da co (dung LLM neu da cau hinh)."""
    return summarize_transcript(req.text, language=req.language)


@app.get("/api/models")
def models():
    return {"models": list_models(), "default": WHISPER_MODEL}


class SummarizeRequest(BaseModel):
    text: str
    language: str | None = None


@app.post("/api/transcribe-chunk")
def transcribe_chunk(
    file: UploadFile = File(...),
    language: str | None = Form(None),
    model: str | None = Form(None),
):
    """Nhan dang nhanh mot doan ngan (dung cho chep loi truc tiep), khong tom tat."""
    from src.transcribe import transcribe_file

    suffix = Path(file.filename).suffix or ".wav"
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / f"chunk{suffix}"
        path.write_bytes(file.file.read())
        result = transcribe_file(
            path,
            language=language or None,
            model_size=model or "small",
        )
    return {
        "text": result["text"],
        "language": result["language"],
        "duration": result["duration"],
    }


@app.post("/api/summarize")
def summarize(req: SummarizeRequest):
    result = process_text(req.text, language=req.language, out_dir=None)
    return result["summary"]


@app.post("/api/transcribe")
def transcribe(
    file: UploadFile = File(...),
    language: str | None = Form(None),
    model: str | None = Form(None),
):
    suffix = Path(file.filename).suffix or ".wav"
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / f"input{suffix}"
        path.write_bytes(file.file.read())
        result = process_audio(
            path,
            out_dir=None,
            language=language or None,
            model_size=model,
        )
    return {
        "transcript": result["transcript"],
        "summary": result["summary"],
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
