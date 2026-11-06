"""API server cho NoteX.

Nhan file audio -> xep hang xu ly nen (Whisper local + tom tat) -> tra task_id.
Frontend Flutter goi cac endpoint nay va poll trang thai task.

Chay:
  uvicorn api_server:app --host 0.0.0.0 --port 8000
Hoac:
  python api_server.py
"""
from __future__ import annotations

import json
import re
import shutil
import tempfile
from hmac import compare_digest
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from src import models_registry
from src.config import DEFAULT_LANGUAGE, WHISPER_MODEL, get
from src.core import process_text
from src.summarize import configure_llm, llm_status, summarize_transcript
from src.tasks import TaskStore
from src.transcribe import list_models

app = FastAPI(title="NoteX API", version="1.0.0")

ALLOWED_AUDIO_SUFFIXES = {
    ".wav", ".mp3", ".m4a", ".ogg", ".flac", ".webm", ".aac", ".mp4", ".opus",
}
MAX_UPLOAD_BYTES = 1024 * 1024 * 1024  # 1 GB
MAX_JSON_BODY_BYTES = 2 * 1024 * 1024  # 2 MB text/translate
MAX_SEGMENTS = 5000
MIN_AUDIO_BYTES = 1024
MAX_SPEAKERS = 30
_LANGUAGE_RE = re.compile(r"^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$")
tasks = TaskStore()

# CORS: "*" chi phu hop dev local. Production dat CORS_ORIGINS=http://app.example.
_CORS_ORIGINS = [o.strip() for o in get("CORS_ORIGINS", "*").split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_CORS_ORIGINS,
    allow_credentials=_CORS_ORIGINS != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Gioi han body JSON de tran RAM / bi bom text khong gioi han.
@app.middleware("http")
async def _limit_json_body(request: Request, call_next):
    if request.url.path in ("/api/summarize", "/api/resummarize", "/api/translate"):
        length = request.headers.get("content-length")
        try:
            if length and int(length) > MAX_JSON_BODY_BYTES:
                return JSONResponse(
                    {"detail": f"Body qua lon (toi da {MAX_JSON_BODY_BYTES} bytes)"},
                    status_code=413,
                )
        except ValueError:
            return JSONResponse({"detail": "Content-Length khong hop le"}, status_code=400)
    return await call_next(request)

# Token chia se: bo trong = khong xac thuc (chi dung trong LAN tin cay).
API_TOKEN = get("API_TOKEN", "")


def _check_auth(authorization: str | None) -> None:
    if not API_TOKEN:
        return
    if not authorization or not compare_digest(authorization, f"Bearer {API_TOKEN}"):
        raise HTTPException(status_code=401, detail="Thieu hoac sai API token")


def _suffix(filename: str | None) -> str:
    name = filename or ""
    if "\x00" in name:
        raise HTTPException(status_code=400, detail="Filename chua ky tu khong hop le")
    suffix = Path(name).suffix.lower()
    if suffix not in ALLOWED_AUDIO_SUFFIXES:
        raise HTTPException(
            status_code=400,
            detail=f"Dinh dang audio khong ho tro: {suffix or '(khong ro)'}",
        )
    return suffix


def _model_or_none(name: str | None) -> str | None:
    if name in (None, ""):
        return None
    if name not in list_models():
        raise HTTPException(status_code=400, detail=f"Model khong hop le: {name}")
    return name


def _language_or_none(language: str | None) -> str | None:
    if language in (None, ""):
        return None
    if not _LANGUAGE_RE.match(language):
        raise HTTPException(status_code=400, detail=f"Ngon ngu khong hop le: {language}")
    return language


def _num_speakers_or_none(n: int | None) -> int | None:
    if n is None:
        return None
    if n < 1 or n > MAX_SPEAKERS:
        raise HTTPException(status_code=400, detail=f"num_speakers phai tu 1 den {MAX_SPEAKERS}")
    return n


@app.get("/api/health")
def health():
    return {"status": "ok", "model": WHISPER_MODEL, "llm": llm_status()["configured"]}


class LlmSettings(BaseModel):
    api_key: str | None = None
    base_url: str | None = None
    model: str | None = None


@app.get("/api/settings/summary")
def get_summary_settings(authorization: str | None = Header(None)):
    _check_auth(authorization)
    return llm_status()


@app.post("/api/settings/summary")
def set_summary_settings(req: LlmSettings, authorization: str | None = Header(None)):
    _check_auth(authorization)
    configure_llm(req.api_key, req.base_url, req.model)
    return llm_status()


class TranslateRequest(BaseModel):
    texts: list[str]
    target: str
    source: str | None = None


@app.get("/api/languages")
def languages():
    from src.translate import LANGUAGES

    return {"languages": [{"code": k, "name": v} for k, v in LANGUAGES.items()]}


@app.post("/api/translate")
def translate(req: TranslateRequest, authorization: str | None = Header(None)):
    """Dich ban chep loi sang ngon ngu khac (LLM neu da cau hinh)."""
    from src.translate import LANGUAGES, translate_auto

    _check_auth(authorization)
    if req.target not in LANGUAGES:
        raise HTTPException(status_code=400, detail=f"Ngon ngu dich khong ho tro: {req.target}")
    if req.source is not None and req.source not in LANGUAGES:
        raise HTTPException(status_code=400, detail=f"Ngon ngu nguon khong ho tro: {req.source}")
    if len(req.texts) > 1000:
        raise HTTPException(status_code=400, detail="Toi da 1000 doan ban dich")
    return translate_auto(req.texts, req.target, req.source)


class ResummarizeRequest(BaseModel):
    text: str
    language: str | None = None


@app.post("/api/resummarize")
def resummarize(req: ResummarizeRequest, authorization: str | None = Header(None)):
    """Tao lai tom tat cho mot ban chep loi da co (dung LLM neu da cau hinh)."""
    _check_auth(authorization)
    return summarize_transcript(req.text, language=req.language)


@app.get("/api/models")
def models():
    return {"models": list_models(), "default": WHISPER_MODEL}


# ---------------------------------------------------------------- mo hinh (UI-11)


@app.get("/api/models/status")
def models_status():
    return {
        "default": WHISPER_MODEL,
        "models": models_registry.list_status(),
        "download": models_registry.download_status(),
    }


class ModelRequest(BaseModel):
    name: str


@app.post("/api/models/download")
def model_download(req: ModelRequest, authorization: str | None = Header(None)):
    _check_auth(authorization)
    return models_registry.start_download(req.name)


@app.get("/api/models/download")
def model_download_status(authorization: str | None = Header(None)):
    _check_auth(authorization)
    return models_registry.download_status()


@app.post("/api/models/delete")
def model_delete(req: ModelRequest, authorization: str | None = Header(None)):
    _check_auth(authorization)
    return models_registry.delete_model(req.name)



# ------------------------------------------------------- phan biet nguoi noi (UI-07)


class DiarizeRequest(BaseModel):
    segments: list[dict]
    num_speakers: int | None = None


@app.post("/api/diarize")
def diarize(
    file: UploadFile = File(...),
    segments: str = Form(...),
    num_speakers: int | None = Form(None),
    authorization: str | None = Header(None),
):
    """Gan lai nhan nguoi noi cho transcript da co (khong chep loi lai)."""
    from src.diarize import diarize_segments

    _check_auth(authorization)
    suffix = _suffix(file.filename)
    try:
        segs = json.loads(segments)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="segments khong phai JSON hop le")
    if not isinstance(segs, list) or not all(isinstance(s, dict) for s in segs):
        raise HTTPException(status_code=400, detail="segments phai la danh sach cac doi tuong")
    if len(segs) > MAX_SEGMENTS:
        raise HTTPException(status_code=400, detail=f"Toi da {MAX_SEGMENTS} segments")
    num_speakers = _num_speakers_or_none(num_speakers)
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / f"audio{suffix}"
        path.write_bytes(file.file.read())
        info = diarize_segments(path, [dict(s) for s in segs], num_speakers=num_speakers)
    for seg, label in zip(segs, info["speakers"]):
        seg["speaker"] = label
    return {"segments": segs, **info}


class SummarizeRequest(BaseModel):
    text: str
    language: str | None = None


@app.post("/api/transcribe-chunk")
def transcribe_chunk(
    file: UploadFile = File(...),
    language: str | None = Form(None),
    model: str | None = Form(None),
    authorization: str | None = Header(None),
):
    """Nhan dang nhanh mot doan ngan (dung cho chep loi truc tiep), khong tom tat."""
    from src.transcribe import transcribe_file

    _check_auth(authorization)
    suffix = _suffix(file.filename)
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / f"chunk{suffix}"
        path.write_bytes(file.file.read())
        result = transcribe_file(
            path,
            language=_language_or_none(language),
            model_size=_model_or_none(model) or "small",
        )
    return {
        "text": result["text"],
        "language": result["language"],
        "duration": result["duration"],
    }


@app.post("/api/summarize")
def summarize(req: SummarizeRequest, authorization: str | None = Header(None)):
    _check_auth(authorization)
    if len(req.text) > 200_000:
        raise HTTPException(status_code=400, detail="Text qua dai (toi da 200.000 ky tu)")
    result = process_text(req.text, language=_language_or_none(req.language), out_dir=None)
    return result["summary"]


@app.post("/api/tasks", status_code=202)
def create_task(
    file: UploadFile = File(...),
    language: str | None = Form(None),
    model: str | None = Form(None),
    diarize: bool = Form(False),
    num_speakers: int | None = Form(None),
    authorization: str | None = Header(None),
):
    """Nhan file audio, xep hang xu ly nen. Giong NoteX: tra task_id de poll."""
    _check_auth(authorization)
    suffix = _suffix(file.filename)

    upload_dir = Path(tempfile.mkdtemp(prefix="vtt-upload-"))
    path = upload_dir / f"input{suffix}"
    size = 0
    try:
        with path.open("wb") as out:
            while chunk := file.file.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    raise HTTPException(status_code=413, detail="File qua lon (toi da 1 GB)")
                out.write(chunk)
        if size < MIN_AUDIO_BYTES:
            raise HTTPException(status_code=400, detail="File audio rong hoac qua nho")
        task = tasks.submit(
            path,
            language=_language_or_none(language),
            model_size=_model_or_none(model),
            diarize=diarize,
            num_speakers=_num_speakers_or_none(num_speakers),
        )
    except Exception:
        shutil.rmtree(upload_dir, ignore_errors=True)
        raise
    return {"task_id": task["task_id"], "status": task["status"]}

@app.get("/api/tasks/{task_id}")
def task_status(task_id: str):
    task = tasks.get(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Khong tim thay task")
    return task


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
