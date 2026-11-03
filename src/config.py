"""Doc cau hinh tu bien moi truong va file .env (neu co)."""
import os
from pathlib import Path

_BASE_DIR = Path(__file__).resolve().parent.parent


def _load_dotenv(path: Path | None = None) -> None:
    env_path = path or (_BASE_DIR / ".env")
    if not env_path.is_file():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if len(value) >= 2 and value[0] in "'\"" and value[-1] == value[0]:
            value = value[1:-1]
        if key and key not in os.environ:
            os.environ[key] = value


_load_dotenv()


def get(key: str, default: str = "") -> str:
    return os.environ.get(key, default)


WHISPER_MODEL = get("WHISPER_MODEL", "large-v3")
DEFAULT_LANGUAGE = get("DEFAULT_LANGUAGE", "") or None
SUMMARY_API_KEY = get("SUMMARY_API_KEY", "")
SUMMARY_BASE_URL = get("SUMMARY_BASE_URL", "https://api.openai.com/v1")
SUMMARY_MODEL = get("SUMMARY_MODEL", "gpt-4o-mini")


def llm_configured() -> bool:
    return bool(SUMMARY_API_KEY and SUMMARY_BASE_URL and SUMMARY_MODEL)
