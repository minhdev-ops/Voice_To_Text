"""Loi xu ly: noi chep loi va tom tat, luu ket qua ra dia."""
from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Callable

from .config import DEFAULT_LANGUAGE
from .summarize import render_markdown, summarize_transcript
from .transcribe import transcribe_file


def process_audio(
    audio_path: str | Path,
    out_dir: str | Path | None = None,
    language: str | None = None,
    model_size: str | None = None,
    progress: Callable | None = None,
) -> dict:
    audio_path = Path(audio_path)
    language = language or DEFAULT_LANGUAGE
    transcript = transcribe_file(
        audio_path, language=language, model_size=model_size, progress=progress
    )
    summary = summarize_transcript(transcript["text"], language=transcript["language"])
    result = {
        "source": str(audio_path),
        "transcript": transcript,
        "summary": summary,
    }
    if out_dir:
        result["outputs"] = _save(result, Path(out_dir), audio_path)
    return result


def process_text(
    transcript_text: str,
    language: str | None = None,
    out_dir: str | Path | None = None,
) -> dict:
    summary = summarize_transcript(transcript_text, language=language)
    result = {
        "source": None,
        "transcript": {"text": transcript_text, "segments": [], "language": language or "vi"},
        "summary": summary,
    }
    if out_dir:
        result["outputs"] = _save(result, Path(out_dir), None)
    return result


def _save(result: dict, out_dir: Path, audio_path: Path | None) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base = audio_path.stem if audio_path else f"meeting_{stamp}"
    transcript_md = _transcript_to_markdown(result["transcript"])
    summary_md = render_markdown(result["summary"])
    transcript_path = out_dir / f"{base}_transcript.md"
    summary_path = out_dir / f"{base}_summary.md"
    json_path = out_dir / f"{base}_result.json"
    transcript_path.write_text(transcript_md, encoding="utf-8")
    summary_path.write_text(summary_md, encoding="utf-8")
    json_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return {
        "transcript": str(transcript_path),
        "summary": str(summary_path),
        "json": str(json_path),
    }


def _transcript_to_markdown(transcript: dict) -> str:
    lines = ["# Ban chep loi cuoc hop", ""]
    lang = transcript.get("language")
    dur = transcript.get("duration")
    meta = []
    if lang:
        meta.append(f"Nguon ngu: {lang}")
    if dur:
        meta.append(f"Do dai: {dur}s")
    if meta:
        lines.append(" | ".join(meta))
        lines.append("")
    segs = transcript.get("segments") or []
    if segs:
        for s in segs:
            ts = f"[{_fmt(s['start'])} -> {_fmt(s['end'])}]"
            lines.append(f"**{ts}** {s['text']}")
    else:
        lines.append(transcript.get("text", ""))
    return "\n".join(lines)


def _fmt(seconds: float) -> str:
    seconds = int(seconds)
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    return f"{h:02d}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"
