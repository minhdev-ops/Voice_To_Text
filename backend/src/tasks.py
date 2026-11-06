"""Hang doi tac vu xu ly audio bat dong bo (kieu NoteX: PENDING/PROCESSING/SUCCESS)."""
from __future__ import annotations

import shutil
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Callable

from .config import DEFAULT_LANGUAGE
from .summarize import summarize_transcript
from .transcribe import transcribe_file


MAX_FINISHED_TASKS = 50


class TaskStore:
    """Task chay nen, mot worker de Whisper khong chay song song qua tai GPU/RAM.

    ponytail: task nam trong RAM, mat khi restart va chi phu hop 1 process.
    Doi sang SQLite/Redis khi can chay nhieu worker hoac giu task lau dai.
    """

    def __init__(self, workers: int = 1) -> None:
        self._lock = threading.Lock()
        self._items: dict[str, dict] = {}
        self._pool = ThreadPoolExecutor(max_workers=workers, thread_name_prefix="vtt-task")

    def submit(
        self,
        audio_path: Path,
        *,
        language: str | None = None,
        model_size: str | None = None,
        diarize: bool = False,
        num_speakers: int | None = None,
    ) -> dict:
        task_id = uuid.uuid4().hex
        with self._lock:
            self._prune_locked()
            self._items[task_id] = {
                "task_id": task_id,
                "status": "PENDING",
                "step": "queued",
                "progress": 0,
            }
        self._pool.submit(
            self._run, task_id, Path(audio_path), language, model_size, diarize, num_speakers
        )
        with self._lock:
            return dict(self._items[task_id])

    def _prune_locked(self) -> None:
        for finished in ("SUCCESS", "FAILURE"):
            if len(self._items) < MAX_FINISHED_TASKS:
                return
            for key in [k for k, v in self._items.items() if v["status"] == finished]:
                del self._items[key]
                if len(self._items) < MAX_FINISHED_TASKS:
                    return

    def get(self, task_id: str) -> dict | None:
        with self._lock:
            item = self._items.get(task_id)
            return dict(item) if item else None

    def _set(self, task_id: str, **fields) -> None:
        with self._lock:
            item = self._items.get(task_id)
            if item is not None:
                item.update(fields)

    def _run(
        self,
        task_id: str,
        audio_path: Path,
        language: str | None,
        model_size: str | None,
        diarize: bool,
        num_speakers: int | None,
    ) -> None:
        self._set(task_id, status="PROCESSING", step="transcribing", progress=2)
        try:
            total = _audio_duration(audio_path)

            def _progress(seconds: float, _message: str) -> None:
                if total > 0:
                    self._set(
                        task_id,
                        progress=max(2, min(90, int(seconds / total * 90))),
                    )

            transcript = transcribe_file(
                audio_path,
                language=language or DEFAULT_LANGUAGE,
                model_size=model_size,
                progress=_progress,
                diarize=diarize,
                num_speakers=num_speakers,
            )
            self._set(task_id, step="summarizing", progress=92)
            summary = summarize_transcript(
                transcript["text"], language=transcript["language"]
            )
            self._set(
                task_id,
                status="SUCCESS",
                step="done",
                progress=100,
                data={"transcript": transcript, "summary": summary},
            )
        except Exception as exc:  # noqa: BLE001 - loi task phai tra ve client
            self._set(task_id, status="FAILURE", step="failed", error=str(exc))
        finally:
            shutil.rmtree(audio_path.parent, ignore_errors=True)


def _audio_duration(path: Path) -> float:
    try:
        import soundfile as sf

        return float(sf.info(str(path)).duration)
    except Exception:  # noqa: BLE001 - khong biet do dai thi chi bao tien trinh mo ho
        return 0.0
