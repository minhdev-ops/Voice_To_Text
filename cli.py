#!/usr/bin/env python3
"""CLI: chuyen giong noi thanh text va tom tat cuoc hop.

Vi du:
  python cli.py meeting.mp3
  python cli.py meeting.mp3 --language vi --out ./output
  python cli.py meeting.mp3 --model small
  python cli.py --text-only transcript.txt
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from src.config import DEFAULT_LANGUAGE, WHISPER_MODEL
from src.core import process_audio, process_text
from src.summarize import render_markdown


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="voice-to-text",
        description="Ghi am cuoc hop -> chep loi -> tom tat co cau truc.",
    )
    p.add_argument("audio", nargs="?", help="Duong dan file audio (mp3/wav/m4a/...).")
    p.add_argument("--text-only", metavar="FILE",
                   help="Chi tom tat ban chep loi co san (bo qua buoc STT).")
    p.add_argument("--language", default=DEFAULT_LANGUAGE,
                   help="Ma nguon ngu (vi/en/...). De trong = tu nhan dien.")
    p.add_argument("--model", default=WHISPER_MODEL,
                   help="Kich thuoc Whisper: tiny/base/small/medium/large-v3.")
    p.add_argument("--out", default="output",
                   help="Thu muc luu ket qua (mac dinh: ./output).")
    p.add_argument("--no-save", action="store_true",
                   help="Khong ghi file ra dia, chi in ra man hinh.")
    return p


def main(argv: list | None = None) -> int:
    args = _build_parser().parse_args(argv)
    if args.text_only:
        text = Path(args.text_only).read_text(encoding="utf-8")
        result = process_text(text, language=args.language,
                              out_dir=None if args.no_save else args.out)
    elif args.audio:
        result = process_audio(
            args.audio,
            out_dir=None if args.no_save else args.out,
            language=args.language or None,
            model_size=args.model,
        )
    else:
        print("Thieu dau vao. Truyen file audio hoac dung --text-only FILE.", file=sys.stderr)
        return 2
    print("\n===== BAN CHEP LOI =====\n")
    print(result["transcript"]["text"] or "(trong)")
    print("\n===== TOM TAT CUOC HOP =====\n")
    print(render_markdown(result["summary"]))
    if not args.no_save and "outputs" in result:
        o = result["outputs"]
        print("\n===== DA LUU =====")
        print(" - Transcript :", o["transcript"])
        print(" - Summary    :", o["summary"])
        print(" - JSON       :", o["json"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
