"""Dich ban chep loi sang ngon ngu khac bang LLM da cau hinh (tuong thich OpenAI)."""
from __future__ import annotations

import json
import re

import requests

from . import config as _cfg
from .summarize import _api_key, _base_url, _model, llm_configured

LANGUAGES = {
    "vi": "Tiếng Việt",
    "en": "English",
    "zh": "中文",
    "ja": "日本語",
    "ko": "한국어",
    "fr": "Français",
    "es": "Español",
    "th": "ไทย",
}

SYSTEM_PROMPT = (
    "You are a professional interpreter. Translate the given transcript segments "
    "faithfully into the target language. Keep the same number of items and the "
    "same order. Do not add explanations, notes, or numbering. "
    "Return only valid JSON: {\"translations\": [\"...\", \"...\"]}."
)


class TranslateError(RuntimeError):
    pass


def _extract_json(text: str) -> dict:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    m = re.search(r"\{.*\}", text, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(0))
        except json.JSONDecodeError:
            pass
    return {}


def translate_texts(
    texts: list[str],
    target: str,
    source: str | None = None,
) -> dict:
    """Dich danh sach doan van ban sang ngon ngu dich.

    Tra ve {"translations": [...], "target": "en", "method": "llm"}.
    """
    if not texts:
        return {"translations": [], "target": target, "method": "llm"}
    if not llm_configured():
        raise TranslateError(
            "Chưa cấu hình AI. Vào Cài đặt → Tóm tắt bằng AI để nhập API key "
            "(OpenAI, Groq, Together hoặc Ollama)."
        )

    target_name = LANGUAGES.get(target, target)
    src_name = LANGUAGES.get(source or "", source or "ngôn ngữ gốc")

    out: list[str] = []
    # Chia lo nho de model khong bi cat bot doan.
    for start in range(0, len(texts), 30):
        chunk = texts[start:start + 30]
        payload_items = [{"i": i, "text": t} for i, t in enumerate(chunk)]
        user = (
            f"Source language: {src_name}\nTarget language: {target_name}\n\n"
            "Translate each item's \"text\" into the target language.\n"
            "Return JSON: {\"translations\": [\"...\"]} with exactly "
            f"{len(chunk)} strings in the same order.\n\n"
            + json.dumps(payload_items, ensure_ascii=False)
        )
        url = _base_url().rstrip("/") + "/chat/completions"
        payload = {
            "model": _model(),
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user},
            ],
            "temperature": 0.1,
            "response_format": {"type": "json_object"},
        }
        headers = {
            "Authorization": f"Bearer {_api_key()}",
            "Content-Type": "application/json",
        }
        try:
            resp = requests.post(url, json=payload, headers=headers, timeout=120)
            resp.raise_for_status()
            content = resp.json()["choices"][0]["message"]["content"]
        except Exception as exc:  # noqa: BLE001
            raise TranslateError(f"Không gọi được AI: {exc}") from exc

        data = _extract_json(content)
        got = data.get("translations")
        if not isinstance(got, list):
            raise TranslateError("AI trả về định dạng không hợp lệ.")
        got = [str(x) for x in got]
        if len(got) < len(chunk):
            got += [""] * (len(chunk) - len(got))
        out.extend(got[: len(chunk)])

    return {"translations": out, "target": target, "method": "llm"}


# ---------------------------------------------------------------- du phong mien phi

_GT_URL = "https://translate.googleapis.com/translate_a/single"


def _google_translate(text: str, target: str, source: str | None = None) -> str:
    """Dich qua endpoint cong khai cua Google (khong can key)."""
    params = {
        "client": "gtx",
        "sl": source or "auto",
        "tl": target,
        "dt": "t",
        "q": text,
    }
    resp = requests.get(_GT_URL, params=params, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    parts = data[0] if data else []
    return "".join(p[0] for p in parts if p and p[0])


def translate_texts_fallback(
    texts: list[str],
    target: str,
    source: str | None = None,
) -> dict:
    """Dich tung doan bang Google dich mien phi (chat luong kha, khong can key)."""
    out: list[str] = []
    for t in texts:
        if not t.strip():
            out.append("")
            continue
        try:
            out.append(_google_translate(t, target, source))
        except Exception:  # noqa: BLE001
            out.append("")
    if not any(x.strip() for x in out):
        return {
            "translations": [],
            "target": target,
            "method": "none",
            "error": "Chưa cấu hình AI nên không dịch được. "
                     "Vào Cài đặt → Tóm tắt bằng AI để nhập API key.",
        }
    return {"translations": out, "target": target, "method": "google"}


def translate_auto(
    texts: list[str],
    target: str,
    source: str | None = None,
) -> dict:
    """Uu tien LLM (chat luong cao). Chua cau hinh thi khong dich thay vi gui transcript ra Google."""
    if llm_configured():
        try:
            return translate_texts(texts, target, source)
        except TranslateError:
            pass
    if _cfg.get("ALLOW_EXTERNAL_TRANSLATE") != "1":
        return {
            "translations": [],
            "target": target,
            "method": "none",
            "error": "Chưa cấu hình AI tóm tắt. Gửi transcript ra Google dịch "
                     "bị tắt mặc định (quyền riêng tư); đặt ALLOW_EXTERNAL_TRANSLATE=1 "
                     "để bật hoặc cấu hình API key trong Cài đặt.",
        }
    return translate_texts_fallback(texts, target, source)
