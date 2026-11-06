"""Tom tat cuoc hop: trich xuat chu de, quyet dinh, viec can lam.

Hai che do:
  * LLM       : goi API tuong thich OpenAI (cau hinh qua .env).
  * Rule-based: khong can mang/key, trich xuat theo tu khoa tieng Viet.
"""
from __future__ import annotations

import json
import re
import unicodedata

import requests

from . import config as _cfg

# Cau hinh LLM co the doi luc chay (tu ung dung), khong can khoi dong lai server.
_RUNTIME: dict = {}


def configure_llm(api_key: str | None = None, base_url: str | None = None,
                  model: str | None = None) -> None:
    if api_key is not None:
        _RUNTIME["api_key"] = api_key.strip()
    if base_url is not None:
        _RUNTIME["base_url"] = base_url.strip()
    if model is not None:
        _RUNTIME["model"] = model.strip()


def _api_key() -> str:
    return _RUNTIME.get("api_key", _cfg.SUMMARY_API_KEY) or ""


def _base_url() -> str:
    return _RUNTIME.get("base_url", _cfg.SUMMARY_BASE_URL) or ""


def _model() -> str:
    return _RUNTIME.get("model", _cfg.SUMMARY_MODEL) or ""


def llm_configured() -> bool:
    return bool(_api_key() and _base_url() and _model())


def llm_status() -> dict:
    key = _api_key()
    return {
        "configured": bool(key and _base_url() and _model()),
        "base_url": _base_url(),
        "model": _model(),
        "key_hint": (("***" + key[-4:]) if len(key) >= 8 else ("***" if key else "")),
        "source": "runtime" if _RUNTIME.get("api_key") else "env",
    }

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
  "open_questions": ["cau hoi/con bo ngo (hoac [])"],
  "mind_map": {"root": "ten cuoc hop", "branches": [{"label": "chu de 1", "children": ["y kien 1", "y kien 2"]}]},
  "flashcards": [{"q": "cau hoi", "a": "dap an"}],
  "quiz": [{"q": "cau hoi trac nghiem", "options": ["A", "B", "C", "D"], "answer": 0}],
  "slides": [{"title": "tieu de slide", "bullets": ["y kien 1", "y kien 2"]}]
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
    url = _base_url().rstrip("/") + "/chat/completions"
    payload = {
        "model": _model(),
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": USER_PROMPT_TEMPLATE.replace("{transcript}", transcript)},
        ],
        "temperature": 0.2,
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
        data = _extract_json(content)
        if not data:
            return summarize_with_rules(transcript)
        return _normalize(data)
    except Exception as exc:
        print(f"[warn] Goi LLM that bai ({exc}); dung tom tat theo quy tac.")
        return summarize_with_rules(transcript)


_ACTION_RE = re.compile(
    r"\b(can|can phai|se|phai|phu trach|chiu trach nhiem|co trach nhiem|"
    r"hoan thanh|thuc hien|trien khai|phan cong|giao cho|giao viec|hen|dang ky|"
    r"kiem tra lai|chuan bi bao cao|de xuat|yeu cau)\b",
    re.IGNORECASE,
)
_DECISION_RE = re.compile(
    r"\b(quyet dinh|thong nhat|dong y|thong qua|nhat tri|phe duyet|ket luan|duyet)\b",
    re.IGNORECASE,
)
_QUESTION_RE = re.compile(r"\?|khong ro|chua ro|bo ngo|de ngo|chua quyet dinh", re.IGNORECASE)
_SPLIT_RE = re.compile(r"(?<=[.!?])\s+|\n+")




def _remove_diacritics(text: str) -> str:
    text = text.replace("đ", "d").replace("Đ", "D")
    return "".join(
        c for c in unicodedata.normalize("NFD", text)
        if unicodedata.category(c) != "Mn"
    )

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
        "mind_map": {},
        "flashcards": [],
        "quiz": [],
        "slides": [],
        "method": "rule",
    }


def summarize_with_rules(transcript: str) -> dict:
    sentences = _split_sentences(transcript)
    norm_sentences = _split_sentences(_remove_diacritics(transcript))
    if not sentences:
        return _empty_summary()
    action_items = []
    decisions = []
    open_questions = []
    for raw, norm in zip(sentences, norm_sentences):
        is_question = bool(_QUESTION_RE.search(norm))
        is_decision = bool(_DECISION_RE.search(norm))
        if is_question:
            open_questions.append(raw)
        if is_decision:
            decisions.append(raw)
        if _ACTION_RE.search(norm) and not is_question and not is_decision:
            action_items.append({
                "task": raw,
                "owner": _extract_owner(raw),
                "due": _extract_due(raw),
            })
    return {
        "summary": _extractive_summary(sentences),
        "topics": _extract_topics(transcript),
        "decisions": _dedupe(decisions)[:20],
        "action_items": action_items[:30],
        "open_questions": _dedupe(open_questions)[:20],
        "mind_map": _build_mind_map(transcript),
        "flashcards": _build_flashcards(transcript, sentences, _extract_topics(transcript)),
        "quiz": _build_quiz(transcript, sentences, action_items),
        "slides": _build_slides(transcript, sentences),
        "method": "rule",
    }


def _dedupe(items: list) -> list:
    seen, out = set(), []
    for x in items:
        key = _remove_diacritics(str(x)).lower().strip()
        if key and key not in seen:
            seen.add(key)
            out.append(x)
    return out


def _content_words(norm_text: str) -> list:
    return [w for w in _tokenize(norm_text) if w not in _STOPWORDS and len(w) > 1]


def _extractive_summary(
    sentences: list[str],
    max_sentences: int = 4,
    max_chars: int = 420,
) -> str:
    """Tom tat trich xuat: chon cau 'trung tam' nhat thay vi lay 3 cau dau."""
    if len(sentences) <= 2:
        return " ".join(sentences)

    norms = [_remove_diacritics(s) for s in sentences]
    df: dict = {}
    for n in norms:
        for w in set(_content_words(n)):
            df[w] = df.get(w, 0) + 1
    total = len(sentences)

    scores = []
    for i, n in enumerate(norms):
        words = _content_words(n)
        if not words:
            scores.append(0.0)
            continue
        score = sum((df.get(w, 0) / total) ** 1.5 for w in words)
        score /= len(words) ** 0.5
        if i == 0:
            score *= 1.15
        elif i == total - 1:
            score *= 1.05
        if len(words) < 4:
            score *= 0.6
        scores.append(score)

    ranked = sorted(range(total), key=lambda i: -scores[i])
    chosen = sorted(ranked[:max_sentences])
    out: list[str] = []
    used = 0
    for i in chosen:
        s = sentences[i]
        if out and used + len(s) > max_chars:
            break
        out.append(s)
        used += len(s) + 1
    return " ".join(out) if out else sentences[0]


_OWNER_RE = re.compile(
    r"giao\s+(?:cho|việc cho)\s+([A-ZĐÀÁẢÃẠĂÂÊÔƠƯ][\wÀ-ỹ]{1,20})",
    re.UNICODE,
)
_DUE_RE = re.compile(
    r"(?:trước|hạn|chậm nhất|deadline)\s+(?:ngày\s*)?"
    r"(\d{1,2}(?:/\d{1,2})?|thứ\s*\d|tuần sau|tháng sau|cuối tuần)",
    re.IGNORECASE,
)


_OWNER2_RE = re.compile(
    r"^(?:(?:Anh|Chị|Ông|Bà|Bạn|Em|Đồng chí)\s+)?"
    r"([A-ZĐÀÁẢÃẠĂÂÊÔƠƯ][\wÀ-ỹ]{1,15})\s+(?:sẽ|phải|cần)",
    re.UNICODE,
)


def _extract_owner(sentence: str) -> str | None:
    m = _OWNER_RE.search(sentence)
    if m:
        return m.group(1)
    m2 = _OWNER2_RE.search(sentence)
    return m2.group(1) if m2 else None


def _extract_due(sentence: str) -> str | None:
    m = _DUE_RE.search(sentence)
    return m.group(0).strip() if m else None


_STOPWORDS = {
    "va", "cac", "cua", "cho", "trong", "de", "duoc", "la", "nhung", "nay", "do",
    "voi", "tu", "khi", "da", "se", "co", "khong", "mot", "nguoi", "chung", "ta",
    "toi", "ban", "anh", "chi", "em", "ve", "rat", "cung", "dang", "thi", "nhu",
    "tai", "theo", "vao", "ra", "len", "xuong", "qua", "lai", "nao", "gi", "the",
    "hay", "hoac", "nen", "vi", "boi", "den", "di", "noi", "vay", "roi", "nhe",
    "cai", "chiec", "con", "moi", "vua", "biet", "lam", "sao", "nhi", "oi", "a",
    "no", "ho", "minh", "ban", "cung", "that", "qua", "hon", "kem", "moi",
}

_NUM_RE = re.compile(r"^\d+$")


def _tokenize(text: str) -> list:
    return re.findall(r"[\w]+", text.lower(), re.UNICODE)


def _extract_topics(text: str, top_n: int = 6) -> list:
    """Trich cum tu khoa co nghia (1-3 tu) theo tan suat, uu tien cum dai hon."""
    words = _tokenize(text)
    if not words:
        return []
    norm = [_remove_diacritics(w) for w in words]
    counts: dict = {}
    for n in (3, 2, 1):
        for i in range(len(words) - n + 1):
            gram = norm[i:i + n]
            if any(len(g) < 2 or _NUM_RE.match(g) for g in gram):
                continue
            if any(g in _STOPWORDS for g in gram):
                continue
            phrase = " ".join(words[i:i + n])
            counts[phrase] = counts.get(phrase, 0) + 1
    scored = [(p, c * (len(p.split()) ** 1.6)) for p, c in counts.items()]
    scored.sort(key=lambda kv: (-kv[1], -len(kv[0])))
    out: list = []
    out_tokens: list = []
    for phrase, _ in scored:
        toks = set(_remove_diacritics(phrase).split())
        if any(phrase in o or o in phrase for o in out):
            continue
        # Bo cum chi trung 2 tu tro len voi cum da chon (tranh "sach marketing them").
        if len(toks) >= 2 and any(
            len(t) >= 2 and len(toks & t) >= 1 for t in out_tokens
        ):
            continue
        out.append(phrase)
        out_tokens.append(toks)
        if len(out) >= top_n:
            break
    return out


def _build_mind_map(transcript: str) -> dict:
    """Xay dung som do tu cac chu de chinh, moi nhanh co cac y chinh lien quan."""
    sentences = _split_sentences(transcript)
    topics = _extract_topics(transcript, top_n=5)
    branches = []
    for t in topics:
        t_norm = _remove_diacritics(t).lower()
        related = [
            s for s in sentences
            if t_norm in _remove_diacritics(s).lower() and len(s) > 12
        ][:3]
        branches.append({"label": t, "children": related})
    return {"root": "Cuoc hop", "branches": branches}


def _build_slides(transcript: str, sentences: list) -> list:
    """Tao slide don gian tu cac cau trung tam."""
    if len(sentences) <= 2:
        return [{"title": "Cuoc hop", "bullets": sentences[:3]}]
    topics = _extract_topics(transcript, top_n=5)
    slides = []
    for t in topics:
        related = [s for s in sentences if t.lower() in _remove_diacritics(s).lower()]
        bullets = related[:3] if related else sentences[:2]
        slides.append({"title": t, "bullets": bullets})
    return slides[:8]


    return slides[:8]


def _build_flashcards(transcript, sentences, topics):
    cards = []
    for t in topics[:4]:
        t_norm = _remove_diacritics(t).lower()
        related = [s for s in sentences if t_norm in _remove_diacritics(s).lower() and len(s) > 15]
        if related:
            cards.append({"q": t.capitalize() + " la gi?", "a": related[0]})
    questions = [s for s in sentences if "?" in s or _QUESTION_RE.search(_remove_diacritics(s))]
    for q in questions[:3]:
        cards.append({"q": q, "a": "Can lam ro trong cuoc hop tiep theo."})
    return cards[:8]


def _build_quiz(transcript, sentences, action_items):
    import random
    owners = []
    for a in action_items:
        ow = a.get("owner") if isinstance(a, dict) else None
        if ow:
            owners.append(ow)
    owners = list(dict.fromkeys(owners))
    quiz = []
    for a in action_items[:5]:
        if not isinstance(a, dict) or not a.get("owner"):
            continue
        task = (a.get("task") or "")[:55]
        opts = [a["owner"]] + [o for o in owners if o != a["owner"]][:3]
        if len(opts) < 2:
            continue
        random.shuffle(opts)
        quiz.append({"q": "Ai phu trach: " + task + "...?", "options": opts, "answer": opts.index(a["owner"])})
    return quiz





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
        "mind_map": data.get("mind_map") or {},
        "flashcards": data.get("flashcards") or [],
        "quiz": data.get("quiz") or [],
        "slides": data.get("slides") or [],
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
    if summary.get("quiz"):
        lines.append("## Cau hoi trac nghiem")
        for i, q in enumerate(summary["quiz"], 1):
            opts = q.get("options", []) if isinstance(q, dict) else []
            ans = q.get("answer", 0) if isinstance(q, dict) else 0
            lines.append(f"{i}. {q.get('q', '') if isinstance(q, dict) else q}")
            for j, opt in enumerate(opts):
                mark = "x" if j == ans else " "
                lines.append(f"   [{mark}] {opt}")
        lines.append("")
    if summary.get("slides"):
        lines.append("## Slides trinh bay")
        for i, s in enumerate(summary["slides"], 1):
            title = s.get("title", "") if isinstance(s, dict) else str(s)
            bullets = s.get("bullets", []) if isinstance(s, dict) else []
            lines.append(f"### Slide {i}: {title}")
            lines += [f"- {b}" for b in bullets]
            lines.append("")
    lines.append(f"_Phuong phap: {summary.get('method', 'unknown')}_")
    return "\n".join(lines)
