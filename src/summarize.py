"""Tom tat cuoc hop: trich xuat chu de, quyet dinh, viec can lam.

Hai che do:
  * LLM       : goi API tuong thich OpenAI (cau hinh qua .env).
  * Rule-based: khong can mang/key, trich xuat theo tu khoa tieng Viet.
"""
from __future__ import annotations

import json
import re

import requests

from .config import SUMMARY_API_KEY, SUMMARY_BASE_URL, SUMMARY_MODEL, llm_configured

SYSTEM_PROMPT = (
    "Ban la tro ly ghi chep cuoc hop chuyen nghiep. "
    "Tu ban chep loi (transcript) cuoc hop, hay trich xuat thong tin bang "
    "cung nguon ngu voi ban ghi (uu tien tieng Viet). "
    "Chi tra ve mot object JSON hop le, khong giai thich, khong markdown."
)

USER_PROMPT_TEMPLATE = """Hay phan tich ban ghi cuoc hop sau va tra ve JSON voi cau truc:
{
  "summary": "tom tat chung 3-5 cau ve cuoc hop",
  "topics": ["chu de chinh 1", "chu de chinh 2"],
  "decisions": ["quyet dinh da thong nhat 1"],
  "action_items": [
    {"task": "viec can lam", "owner": "nguoi phu trach (hoac null)", "due": "thoi han (hoac null)"}
  ],
  "open_questions": ["cau hoi/con bo ngo (hoac [])"]
}

Ban ghi cuoc hop:
{transcript}
"""


def _extract_json(text: str) -> dict:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError:
            pass
    return {}


def summarize_transcript(transcript: str, language: str | None = None) -> dict:
    if not transcript or not transcript.strip():
        return _empty_summary()
    if not llm_configured():
        return summarize_with_rules(transcript)
    url = SUMMARY_BASE_URL.rstrip("/") + "/chat/completions"
    payload = {
        "model": SUMMARY_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": USER_PROMPT_TEMPLATE.replace("{transcript}", transcript)},
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {SUMMARY_API_KEY}",
        "Content-Type": "application/json",
    }
    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=120)
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"]["content"]
        data = _extract_json(content)
        if not data:
            return summarize_with_rules(transcript)
        return _normalize(data)
    except Exception as exc:
        print(f"[warn] Goi LLM that bai ({exc}); dung tom tat theo quy tac.")
        return summarize_with_rules(transcript)


_ACTION_RE = re.compile(
    r"\b(can|se|phai|giao|lam|thuc hien|trien khai|hen|dang ky|nhan lam|phan cong|"
    r"co trach nhiem|chiu trach nhiem|bao cao|gui|hoan thanh|kiem tra|chuan bi)\b",
    re.IGNORECASE,
)
_DECISION_RE = re.compile(
    r"\b(quyet dinh|thong nhat|dong y|chot|thong qua|nhat tri|phe duyet|ket luan)\b",
    re.IGNORECASE,
)
_QUESTION_RE = re.compile(r"\?|khong ro|chua ro|bo ngo|de ngo|chua quyet dinh", re.IGNORECASE)
_SPLIT_RE = re.compile(r"(?<=[.!?])\s+|\n+")


def _split_sentences(text: str) -> list:
    parts = [s.strip(" \t\n-*\u2022") for s in _SPLIT_RE.split(text) if s.strip(" \t\n-*\u2022")]
    return [p for p in parts if len(p) >= 4]


def _empty_summary() -> dict:
    return {
        "summary": "",
        "topics": [],
        "decisions": [],
        "action_items": [],
        "open_questions": [],
        "method": "rule",
    }


def summarize_with_rules(transcript: str) -> dict:
    sentences = _split_sentences(transcript)
    if not sentences:
        return _empty_summary()
    action_items = []
    decisions = []
    open_questions = []
    for s in sentences:
        if _QUESTION_RE.search(s):
            open_questions.append(s)
        if _DECISION_RE.search(s):
            decisions.append(s)
        if _ACTION_RE.search(s):
            action_items.append({"task": s, "owner": None, "due": None})
    summary = " ".join(sentences[:3])
    if len(sentences) > 3:
        summary += " ..."
    return {
        "summary": summary,
        "topics": _extract_topics(transcript),
        "decisions": decisions[:20],
        "action_items": action_items[:30],
        "open_questions": open_questions[:20],
        "method": "rule",
    }


_STOPWORDS = {
    "va", "cac", "cua", "cho", "trong", "de", "duoc", "la", "nhung", "nay", "do",
    "voi", "tu", "khi", "da", "se", "co", "khong", "mot", "nguoi", "chung", "ta",
    "toi", "ban", "anh", "chi", "em", "ve", "rat", "cung", "dang", "thi", "nhu",
    "tai", "theo", "vao", "ra", "len", "xuong", "qua", "lai", "nao", "gi", "the",
}


def _extract_topics(text: str, top_n: int = 8) -> list:
    words = re.findall(r"[\w]+", text.lower())
    freq = {}
    for w in words:
        if len(w) < 3 or w in _STOPWORDS:
            continue
        freq[w] = freq.get(w, 0) + 1
    ranked = sorted(freq.items(), key=lambda kv: kv[1], reverse=True)
    return [w for w, _ in ranked[:top_n]]


def _normalize(data: dict) -> dict:
    action_items = []
    for it in data.get("action_items", []) or []:
        if isinstance(it, str):
            action_items.append({"task": it, "owner": None, "due": None})
        elif isinstance(it, dict):
            action_items.append({
                "task": str(it.get("task") or it.get("viec") or ""),
                "owner": it.get("owner") or it.get("nguoi phu trach"),
                "due": it.get("due") or it.get("thoi han"),
            })
    return {
        "summary": str(data.get("summary", "") or ""),
        "topics": [str(t) for t in (data.get("topics") or [])],
        "decisions": [str(d) for d in (data.get("decisions") or [])],
        "action_items": action_items,
        "open_questions": [str(q) for q in (data.get("open_questions") or [])],
        "method": "llm",
    }


def render_markdown(summary: dict) -> str:
    lines = []
    lines.append("## Tom tat chung")
    lines.append(summary.get("summary", "") or "_(khong co)_")
    lines.append("")
    lines.append("## Chu de chinh")
    if summary.get("topics"):
        lines += [f"- {t}" for t in summary["topics"]]
    else:
        lines.append("_(khong co)_")
    lines.append("")
    lines.append("## Quyet dinh da thong nhat")
    if summary.get("decisions"):
        lines += [f"- {d}" for d in summary["decisions"]]
    else:
        lines.append("_(khong co)_")
    lines.append("")
    lines.append("## Viec can lam (Action items)")
    if summary.get("action_items"):
        for it in summary["action_items"]:
            task = it.get("task", "")
            owner = it.get("owner")
            due = it.get("due")
            extra = []
            if owner:
                extra.append(f"nguoi phu trach: {owner}")
            if due:
                extra.append(f"han: {due}")
            suffix = f" _({', '.join(extra)})_" if extra else ""
            lines.append(f"- {task}{suffix}")
    else:
        lines.append("_(khong co)_")
    lines.append("")
    lines.append("## Cau hoi / van de con bo ngo")
    if summary.get("open_questions"):
        lines += [f"- {q}" for q in summary["open_questions"]]
    else:
        lines.append("_(khong co)_")
    lines.append("")
    lines.append(f"_Phuong phap: {summary.get('method', 'unknown')}_")
    return "\n".join(lines)
