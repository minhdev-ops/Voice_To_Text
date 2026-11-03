"""Chep loi (speech-to-text) dung faster-whisper, chay local tren GPU/CPU."""
from __future__ import annotations

import threading
from pathlib import Path
from typing import Callable, Iterator

import tqdm

from .config import WHISPER_MODEL

_MODEL_CACHE: dict = {}
_MODEL_LOCK = threading.Lock()

VALID_MODELS = [
    "tiny", "tiny.en", "base", "base.en", "small", "small.en",
    "medium", "medium.en", "large-v1", "large-v2", "large-v3",
]


def list_models() -> list:
    return list(VALID_MODELS)


def _pick_device(device: str | None) -> str:
    if device and device != "auto":
        return device
    try:
        import ctypes
        ctypes.CDLL("libcublas.so.12")
        import torch
        return "cuda" if torch.cuda.is_available() else "cpu"
    except Exception:
        return "cpu"


def _load_model(size: str, device: str = "auto"):
    size = size or WHISPER_MODEL
    dev = _pick_device(device)
    key = (size, dev)
    with _MODEL_LOCK:
        if key in _MODEL_CACHE:
            return _MODEL_CACHE[key]
        from faster_whisper import WhisperModel
        # Một số backend CUDA không hỗ trợ float16 hiệu quả -> thử dần các loại.
        candidates = ["float16", "int8", "float32"] if dev == "cuda" else ["int8", "float32"]
        last_err = None
        for ct in candidates:
            try:
                model = WhisperModel(size, device=dev, compute_type=ct)
                break
            except Exception as e:  # noqa: BLE001
                last_err = e
                continue
        else:
            raise RuntimeError(f"Khong tai duoc Whisper model ({last_err})")
        _MODEL_CACHE[key] = model
        return model


def transcribe_file(
    audio_path: str | Path,
    language: str | None = None,
    model_size: str | None = None,
    device: str = "auto",
    progress: Callable | None = None,
) -> dict:
    audio_path = Path(audio_path)
    if not audio_path.is_file():
        raise FileNotFoundError(f"Khong tim thay file audio: {audio_path}")

    size = model_size or WHISPER_MODEL
    model = _load_model(size, device)
    dev = _pick_device(device)

    prompt = "Đây là bản ghi âm cuộc họp bằng tiếng Việt."

    def _run(vad: bool):
        it, inf = model.transcribe(
            str(audio_path),
            language=language,
            beam_size=10,
            best_of=5,
            vad_filter=vad,
            vad_parameters=dict(min_silence_duration_ms=500) if vad else None,
            condition_on_previous_text=False,
            initial_prompt=prompt,
        )
        segs: list = []
        parts: list = []
        total = getattr(inf, "duration", None) or 0.0
        bar = tqdm.tqdm(total=total, unit="s", desc="Dang chep loi",
                        disable=progress is not None or total <= 0)
        last = 0.0
        for seg in it:
            segs.append({
                "start": round(float(seg.start), 2),
                "end": round(float(seg.end), 2),
                "text": seg.text.strip(),
                "speaker": None,
            })
            parts.append(seg.text.strip())
            if progress is not None:
                progress(float(seg.end), "Dang chep loi...")
            else:
                bar.update(float(seg.end) - last)
                last = float(seg.end)
        bar.close()
        return {
            "text": " ".join(parts).strip(),
            "segments": segs,
            "language": getattr(inf, "language", language or "unknown"),
            "duration": round(total, 2),
            "model": size,
            "device": dev,
            "vad": vad,
        }

    result = _run(True)
    # VAD co the xoa sach am thanh nho -> thu lai khong loc truoc khi ket luan rong.
    if not result["text"]:
        retry = _run(False)
        if retry["text"]:
            retry["vad_fallback"] = True
            return retry
        result["vad_fallback"] = True
    return result


def stream_transcribe(
    audio_path: str | Path,
    language: str | None = None,
    model_size: str | None = None,
    device: str = "auto",
) -> Iterator[dict]:
    audio_path = Path(audio_path)
    size = model_size or WHISPER_MODEL
    model = _load_model(size, device)
    segments_iter, info = model.transcribe(
        str(audio_path), language=language, beam_size=5, vad_filter=True
    )
    for seg in segments_iter:
        yield {
            "start": round(float(seg.start), 2),
            "end": round(float(seg.end), 2),
            "text": seg.text.strip(),
            "speaker": None,
        }
