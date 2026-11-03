"""Phan biet nguoi noi (speaker diarization) khong can GPU, khong can token.

Cach lam: voi moi doan (segment) do Whisper tra ve, tach audio tuong ung,
trich dac trung giong noi (MFCC + thong ke pho), roi gom nhom bang
AgglomerativeClustering. Chay hoan toan offline voi numpy/scipy/sklearn.

Do chinh xac du cho 2-6 nguoi noi trong cuoc hop/ghi am thong thuong.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

SR = 16000
N_MFCC = 20
N_MELS = 40
FRAME = 400   # 25 ms
HOP = 160     # 10 ms


def _mel_filterbank(n_mels: int, n_fft: int, sr: int) -> np.ndarray:
    """Bo loc tam giac tren thang mel (dung cong thuc HTK)."""
    def hz2mel(f):
        return 2595.0 * np.log10(1.0 + f / 700.0)

    def mel2hz(m):
        return 700.0 * (10.0 ** (m / 2595.0) - 1.0)

    low, high = hz2mel(0.0), hz2mel(sr / 2.0)
    points = np.linspace(low, high, n_mels + 2)
    hz = mel2hz(points)
    bins = np.floor((n_fft + 1) * hz / sr).astype(int)
    fb = np.zeros((n_mels, n_fft // 2 + 1), dtype=np.float32)
    for i in range(n_mels):
        left, center, right = bins[i], bins[i + 1], bins[i + 2]
        if center == left:
            center = left + 1
        if right == center:
            right = center + 1
        for k in range(left, min(center, fb.shape[1])):
            fb[i, k] = (k - left) / max(center - left, 1)
        for k in range(center, min(right, fb.shape[1])):
            fb[i, k] = (right - k) / max(right - center, 1)
    return fb


_FB_CACHE: dict = {}


def _mfcc(signal: np.ndarray) -> np.ndarray:
    """Ma tran MFCC (so khung x N_MFCC)."""
    if signal.size < FRAME:
        signal = np.pad(signal, (0, FRAME - signal.size))
    n_frames = 1 + (signal.size - FRAME) // HOP
    idx = np.arange(FRAME)[None, :] + HOP * np.arange(n_frames)[:, None]
    frames = signal[idx].astype(np.float32)
    frames *= np.hamming(FRAME).astype(np.float32)
    spec = np.abs(np.fft.rfft(frames, n=512))
    power = (spec ** 2) / 512
    key = 512
    if key not in _FB_CACHE:
        _FB_CACHE[key] = _mel_filterbank(N_MELS, 512, SR)
    mel = power @ _FB_CACHE[key].T
    logmel = np.log(mel + 1e-10)
    n = np.arange(N_MFCC)[:, None]
    k = np.arange(N_MELS)[None, :]
    dct = np.cos(np.pi / N_MELS * (k + 0.5) * n).astype(np.float32)
    return logmel @ dct.T


def _segment_embedding(signal: np.ndarray) -> np.ndarray | None:
    """Vector dac trung cho mot doan: MFCC mean/std + nang luong + do lech pho."""
    if signal.size < FRAME * 2:
        return None
    mf = _mfcc(signal)
    if mf.shape[0] < 2:
        return None
    # Bo khung im lang (nang luong thap) de khong lam nhieu cum.
    energy = np.log(np.mean(signal.reshape(-1, FRAME) ** 2, axis=1) + 1e-10)         if signal.size >= FRAME else np.array([0.0])
    keep = mf.shape[0]
    if energy.size >= keep:
        thr = np.percentile(energy[:keep], 20)
        mask = energy[:keep] >= thr
        if mask.sum() >= 2:
            mf = mf[mask]
    emb = np.concatenate([
        mf.mean(axis=0),
        mf.std(axis=0),
    ])
    return emb.astype(np.float32)


def _load_audio(audio_path: str | Path) -> np.ndarray:
    import soundfile as sf

    data, sr = sf.read(str(audio_path), dtype="float32", always_2d=True)
    mono = data.mean(axis=1)
    if sr != SR:
        # Noi suy tuyen tinh don gian (du cho dac trung giong noi).
        n = int(round(mono.size * SR / sr))
        x_old = np.linspace(0.0, 1.0, mono.size, endpoint=False)
        x_new = np.linspace(0.0, 1.0, n, endpoint=False)
        mono = np.interp(x_new, x_old, mono).astype(np.float32)
    return mono


def _normalize(emb: np.ndarray) -> np.ndarray:
    norm = np.linalg.norm(emb)
    return emb / norm if norm > 0 else emb


def diarize_segments(
    audio_path: str | Path,
    segments: list[dict],
    num_speakers: int | None = None,
) -> dict:
    """Gan nhan nguoi noi cho tung segment.

    Tra ve {"speakers": ["SPK_1", ...], "num_speakers": n, "method": "mfcc-ahc"}.
    """
    usable = [
        (i, s) for i, s in enumerate(segments)
        if float(s.get("end", 0)) - float(s.get("start", 0)) >= 0.4
        and str(s.get("text", "")).strip()
    ]
    if len(usable) < 2:
        labels = ["SPK_1"] * len(segments)
        return {"speakers": labels, "num_speakers": 1, "method": "passthrough"}

    audio = _load_audio(audio_path)
    embs, idxs = [], []
    for i, s in usable:
        a = max(0, int(float(s["start"]) * SR))
        b = min(audio.size, int(float(s["end"]) * SR))
        if b - a < FRAME * 2:
            continue
        emb = _segment_embedding(audio[a:b])
        if emb is None:
            continue
        embs.append(_normalize(emb))
        idxs.append(i)

    if len(embs) < 2:
        labels = ["SPK_1"] * len(segments)
        return {"speakers": labels, "num_speakers": 1, "method": "passthrough"}

    X = np.vstack(embs)

    if num_speakers and num_speakers >= 1:
        k = min(int(num_speakers), len(X))
    else:
        k = _best_k(X)

    if k <= 1:
        pred = np.zeros(len(X), dtype=int)
    else:
        from sklearn.cluster import AgglomerativeClustering

        model = AgglomerativeClustering(
            n_clusters=k, metric="cosine", linkage="average"
        )
        pred = model.fit_predict(X)

    # Doi so cum thanh SPK_1..n theo thu tu xuat hien de de doc.
    order: dict[int, str] = {}
    for p in pred:
        if int(p) not in order:
            order[int(p)] = f"SPK_{len(order) + 1}"

    labels = [None] * len(segments)
    for pos, seg_index in enumerate(idxs):
        labels[seg_index] = order[int(pred[pos])]
    fallback = order[0]
    labels = [lb or fallback for lb in labels]

    # Lam muot: hai doan lien tiep cung nguoi -> giu; nhieu doan ngan le loi -> theo hang xom.
    labels = _smooth(labels, segments)

    return {
        "speakers": labels,
        "num_speakers": len(set(labels)),
        "method": "mfcc-ahc",
    }


def _best_k(X: np.ndarray) -> int:
    """Chon so cum bang silhouette (1..min(6, n-1))."""
    from sklearn.cluster import AgglomerativeClustering
    from sklearn.metrics import silhouette_score

    best_k, best_score = 1, -1.0
    limit = min(6, len(X) - 1)
    for k in range(2, limit + 1):
        model = AgglomerativeClustering(
            n_clusters=k, metric="cosine", linkage="average"
        )
        pred = model.fit_predict(X)
        if len(set(pred)) < 2:
            continue
        score = silhouette_score(X, pred, metric="cosine")
        if score > best_score:
            best_k, best_score = k, float(score)
    return best_k if best_score >= 0.12 else 1


def _smooth(labels: list[str], segments: list[dict]) -> list[str]:
    """Gan lai nhan cho doan ngan (< 0.8 s) bi co lap, lay theo doan truoc do."""
    out = list(labels)
    for i in range(1, len(out) - 1):
        dur = float(segments[i].get("end", 0)) - float(segments[i].get("start", 0))
        if dur < 0.8 and out[i] != out[i - 1] and out[i - 1] == out[i + 1]:
            out[i] = out[i - 1]
    return out
