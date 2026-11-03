"""Quan ly mo hinh Whisper: xem trang thai, tai ve, xoa khoi dia.

Dung cache cua huggingface_hub (cung noi faster-whisper luu model).
"""
from __future__ import annotations

import os
import shutil
import threading
import time
from pathlib import Path

from .config import WHISPER_MODEL

# Thong so tham khao (dung luong that tren dia se duoc do lai khi da cai).
CATALOG: dict[str, dict] = {
    "tiny": {"params": "39M", "size_mb": 78, "languages": "Đa ngôn ngữ (99)", "quality": "Nhanh nhất, độ chính xác thấp"},
    "base": {"params": "74M", "size_mb": 148, "languages": "Đa ngôn ngữ (99)", "quality": "Nhanh, phù hợp ghi chú ngắn"},
    "small": {"params": "244M", "size_mb": 486, "languages": "Đa ngôn ngữ (99)", "quality": "Cân bằng tốc độ / độ chính xác"},
    "medium": {"params": "769M", "size_mb": 1531, "languages": "Đa ngôn ngữ (99)", "quality": "Chính xác cao, cần nhiều RAM"},
    "large-v3": {"params": "1550M", "size_mb": 3091, "languages": "Đa ngôn ngữ (99)", "quality": "Chính xác nhất"},
    "large-v3-turbo": {"params": "809M", "size_mb": 1624, "languages": "Đa ngôn ngữ (99)", "quality": "Gần large-v3, nhanh gấp nhiều lần"},
}

_LOCK = threading.Lock()
_STATE: dict = {
    "name": None,
    "status": "idle",   # idle | downloading | done | error
    "error": None,
    "started": 0.0,
}


def _hub_dir() -> Path:
    env = os.environ.get("HF_HOME")
    if env:
        return Path(env) / "hub"
    return Path.home() / ".cache" / "huggingface" / "hub"


def _repo_dir(name: str) -> Path:
    return _hub_dir() / f"models--Systran--faster-whisper-{name}"


def _disk_size(name: str) -> int:
    """Tong dung luong that (di theo symlink trong snapshots)."""
    base = _repo_dir(name) / "snapshots"
    total = 0
    if not base.is_dir():
        return 0
    for root, _dirs, files in os.walk(base):
        for f in files:
            try:
                total += os.stat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total


def _is_installed(name: str) -> bool:
    return _disk_size(name) > 1_000_000


def list_status() -> list[dict]:
    out = []
    for name, meta in CATALOG.items():
        size = _disk_size(name)
        out.append({
            "name": name,
            "params": meta["params"],
            "size_mb": meta["size_mb"],
            "languages": meta["languages"],
            "quality": meta["quality"],
            "license": "MIT",
            "installed": size > 1_000_000,
            "disk_bytes": size,
            "is_default": name == WHISPER_MODEL,
        })
    return out


def download_status() -> dict:
    with _LOCK:
        st = dict(_STATE)
    name = st.get("name")
    if name:
        st["disk_bytes"] = _disk_size(name)
        st["total_bytes"] = int(CATALOG.get(name, {}).get("size_mb", 0)) * 1_000_000
        st["installed"] = _is_installed(name)
    return st


def start_download(name: str) -> dict:
    if name not in CATALOG:
        raise ValueError(f"Mo hinh khong hop le: {name}")
    if _is_installed(name):
        return {"status": "installed", "name": name}
    with _LOCK:
        if _STATE["status"] == "downloading" and _STATE["name"] != name:
            raise RuntimeError(f"Dang tai {_STATE['name']}, vui long doi")
        if _STATE["status"] == "downloading" and _STATE["name"] == name:
            return {"status": "downloading", "name": name}
        _STATE.update(name=name, status="downloading", error=None, started=time.time())
    threading.Thread(target=_worker, args=(name,), daemon=True).start()
    return {"status": "downloading", "name": name}


def _worker(name: str) -> None:
    try:
        from faster_whisper.utils import download_model

        download_model(name)
        with _LOCK:
            _STATE["status"] = "done"
    except Exception as e:  # noqa: BLE001
        with _LOCK:
            _STATE["status"] = "error"
            _STATE["error"] = str(e)


def delete_model(name: str) -> dict:
    if name not in CATALOG:
        raise ValueError(f"Mo hinh khong hop le: {name}")
    if name == WHISPER_MODEL:
        raise RuntimeError("Khong the xoa mo hinh dang dat lam mac dinh")
    if _STATE["status"] == "downloading" and _STATE["name"] == name:
        raise RuntimeError("Dang tai mo hinh nay, khong the xoa")

    # Go khoi bo nho neu dang cache.
    from .transcribe import _MODEL_CACHE

    for key in [k for k in _MODEL_CACHE if k[0] == name]:
        _MODEL_CACHE.pop(key, None)

    target = _repo_dir(name)
    if target.is_dir():
        shutil.rmtree(target, ignore_errors=True)
    return {"status": "deleted", "name": name}
