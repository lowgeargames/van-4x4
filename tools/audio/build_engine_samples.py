#!/usr/bin/env python3
"""Prepara as amostras do motor V8 do Van 4x4 a partir de gravações reais.

Entrada (preservada, nunca alterada):  tools/audio/source_recordings/
Saída (derivados para a Godot):        game/audio/sfx/

  v8_idle_loop.wav    marcha lenta (Mustang 1985), loop de ~6 s, tom nativo 47,5 Hz
  v8_accel_loop.wav   aceleração (Ford V8 5.0), tom normalizado, loop de ~1,6 s
  v8_rev_blip.wav     aceleração curta (Mustang 1969), efeito único, sem loop

Não há síntese: todo o som vem das gravações. O processamento se limita a
recorte, filtro passa-alta de 12 Hz, normalização de tom e de nível, EQ suave
de aproximação ao timbre da marcha lenta, crossfade de loop e fades.

Dependências: Python 3, numpy e ffmpeg (decodifica o MP3 e reamostra para 44,1 kHz).
Uso: python3 tools/audio/build_engine_samples.py
"""
from __future__ import annotations

import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "tools" / "audio" / "source_recordings"
OUT_DIR = ROOT / "game" / "audio" / "sfx"

TARGET_RMS_DB = -14.0
PEAK_LIMIT_DB = -2.0

# Os arquivos podem ter sido renomeados: tenta nomes e números de origem conhecidos.
SOURCES = {
    "idle": ("*mustang*1985*", "*78386*"),
    "accel": ("*v8*", "*455926*"),
    "rev": ("*mustang*1969*", "*653226*", "*revving*"),
}

# Frequência de explosões (Hz) em que cada amostra foi produzida; o componente de
# áudio calcula o pitch a partir delas. Veja o README para a estimativa.
IDLE_FIRING_HZ = 47.5
ACCEL_SPACING_HZ = 33.0          # espaçamento das linhas harmônicas = metade das explosões
ACCEL_FIRING_HZ = ACCEL_SPACING_HZ * 2.0
REV_FIRING_HZ = 66.7

BAND_CENTERS = np.array([40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500,
                         630, 800, 1000, 1250, 1600, 2000, 2500], dtype=float)


# ---------------------------------------------------------------- utilidades
def find_source(kind: str) -> Path:
    for pattern in SOURCES[kind]:
        matches = sorted(p for p in SOURCE_DIR.glob(pattern) if p.is_file())
        if matches:
            return matches[0]
    sys.exit(f"Gravação ausente ({kind}) em {SOURCE_DIR}; padrões: {SOURCES[kind]}")


def decode(path: Path) -> np.ndarray:
    """Decodifica para mono, 44,1 kHz, float. Estéreo vira média dos canais."""
    cmd = ["ffmpeg", "-v", "error", "-i", str(path), "-vn", "-ac", "1",
           "-ar", str(SR), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, check=True, stdout=subprocess.PIPE).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def rms_db(x: np.ndarray) -> float:
    return 20.0 * np.log10(np.sqrt(np.mean(x * x)) + 1e-12)


def peak_db(x: np.ndarray) -> float:
    return 20.0 * np.log10(np.max(np.abs(x)) + 1e-12)


def fft_filter(x: np.ndarray, gain_fn) -> np.ndarray:
    """Filtro de fase zero aplicado por FFT (com folga para não dar a volta)."""
    n = len(x)
    size = 1 << int(np.ceil(np.log2(n * 2)))
    spectrum = np.fft.rfft(x, size)
    freqs = np.fft.rfftfreq(size, 1.0 / SR)
    return np.fft.irfft(spectrum * gain_fn(freqs), size)[:n]


def highpass(x: np.ndarray, cutoff: float, order: int = 4) -> np.ndarray:
    return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(f, 1e-3)) ** (2 * order)))


def lowpass(x: np.ndarray, cutoff: float, order: int = 4) -> np.ndarray:
    return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2 * order)))


def band_levels(x: np.ndarray) -> np.ndarray:
    """Densidade espectral média (dB) em bandas de 1/3 de oitava."""
    size, hop = 8192, 4096
    window = np.hanning(size)
    acc = np.zeros(size // 2 + 1)
    count = 0
    for i in range(0, len(x) - size + 1, hop):
        acc += np.abs(np.fft.rfft(x[i:i + size] * window)) ** 2
        count += 1
    psd = acc / max(count, 1)
    freqs = np.fft.rfftfreq(size, 1.0 / SR)
    levels = []
    for c in BAND_CENTERS:
        sel = (freqs >= c / 2 ** (1 / 6)) & (freqs < c * 2 ** (1 / 6))
        levels.append(10.0 * np.log10(psd[sel].mean() + 1e-20))
    return np.array(levels)


def match_eq(x: np.ndarray, reference_levels: np.ndarray, strength: float, limit_db: float):
    """EQ suave: aproxima o formato espectral de x ao da referência (sem mexer no nível)."""
    diff = reference_levels - band_levels(x)
    diff -= diff.mean()
    gains_db = np.clip(strength * diff, -limit_db, limit_db)
    log_centers = np.log(BAND_CENTERS)

    def gain_fn(f):
        g = np.interp(np.log(np.maximum(f, 1e-3)), log_centers, gains_db)
        taper = np.clip((f - 20.0) / 20.0, 0.0, 1.0)   # sem ganho abaixo de ~20 Hz
        return 10.0 ** (g * taper / 20.0)

    return fft_filter(x, gain_fn), gains_db


def normalize(x: np.ndarray, rms_slice: slice | None = None) -> np.ndarray:
    ref = x if rms_slice is None else x[rms_slice]
    gain_db = TARGET_RMS_DB - rms_db(ref)
    gain_db = min(gain_db, PEAK_LIMIT_DB - peak_db(x))
    return x * 10.0 ** (gain_db / 20.0)


def resample_at(x: np.ndarray, pos: np.ndarray) -> np.ndarray:
    """Interpolação cúbica (Catmull-Rom) nas posições fracionárias `pos` (em amostras)."""
    i = np.floor(pos).astype(np.int64)
    f = pos - i
    last = len(x) - 1
    p0, p1, p2, p3 = (x[np.clip(i + k, 0, last)] for k in (-1, 0, 1, 2))
    return 0.5 * (2 * p1 + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f ** 2
                  + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3)


# ------------------------------------------------------ rastreio de tom (V8)
def track_spacing(x: np.ndarray, t0: float, t1: float, lo: float, hi: float,
                  window: float = 0.35, hop: float = 0.025, harmonics: int = 10):
    """Espaçamento das linhas harmônicas (Hz) ao longo do tempo, com continuidade."""
    w, h, size = int(window * SR), int(hop * SR), 1 << 16
    freqs = np.fft.rfftfreq(size, 1.0 / SR)
    df = freqs[1]
    cands = np.arange(lo, hi, 0.25)
    ref_band = (freqs > 20) & (freqs < 800)
    rows, times = [], []
    for i in range(int(t0 * SR), int(t1 * SR) - w, h):
        mag = np.abs(np.fft.rfft(x[i:i + w] * np.hanning(w), size))
        mag = np.log1p(mag / (np.median(mag[ref_band]) + 1e-9))
        row = []
        for f0 in cands:
            total = 0.0
            for k in range(1, harmonics + 1):
                j = int(round(k * f0 / df))
                total += mag[j - 3:j + 4].max()
            row.append(total)
        rows.append(row)
        times.append((i + w / 2) / SR)
    salience, times = np.array(rows), np.array(times)
    n_t, n_f = salience.shape
    jump = np.minimum(0.15 * np.abs(cands[:, None] - cands[None, :]) / 0.25, 5.0)
    cost = np.zeros((n_t, n_f))
    back = np.zeros((n_t, n_f), dtype=int)
    cost[0] = -salience[0]
    for t in range(1, n_t):
        total = cost[t - 1][None, :] + jump
        back[t] = np.argmin(total, axis=1)
        cost[t] = -salience[t] + total[np.arange(n_f), back[t]]
    path = np.zeros(n_t, dtype=int)
    path[-1] = int(np.argmin(cost[-1]))
    for t in range(n_t - 1, 0, -1):
        path[t - 1] = back[t][path[t]]
    return times, cands[path]


def flatten_pitch(x: np.ndarray, times, spacing, t_start: float, t_end: float):
    """Reamostra [t_start, t_end] com taxa variável para o tom ficar constante."""
    coeffs = np.polyfit(times, spacing, 3)
    fit = np.polyval(coeffs, times)
    residual = float(np.std(spacing - fit) / np.mean(fit))
    t = np.arange(int(t_start * SR), int(t_end * SR)) / SR
    s_t = np.polyval(coeffs, t)
    # dtau/dt = s(t)/s_ref: onde o tom é mais agudo que a referência, lê mais devagar.
    tau = np.cumsum(s_t / ACCEL_SPACING_HZ) / SR
    tau -= tau[0]
    tau_out = np.arange(int(tau[-1] * SR)) / SR
    source_t = np.interp(tau_out, tau, t)
    y = resample_at(x, source_t * SR)
    return y, (float(s_t[0]), float(s_t[-1]), residual)


def flatten_level(y: np.ndarray, window: float = 0.4, limit_db: float = 4.0,
                  circular: bool = False) -> np.ndarray:
    """Remove oscilações lentas de volume (sem tocar na dinâmica rápida do motor).

    Em `circular` a janela dá a volta no fim do loop, então a emenda continua contínua.
    """
    w = int(window * SR)
    padded = np.pad(y * y, (w, w), mode="wrap" if circular else "reflect")
    env = np.sqrt(np.convolve(padded, np.ones(w) / w, mode="same")[w:w + len(y)])
    gain = np.exp(np.mean(np.log(env + 1e-9))) / (env + 1e-9)
    limit = 10.0 ** (limit_db / 20.0)
    return y * np.clip(gain, 1.0 / limit, limit)


# ----------------------------------------------------------------- loops
def best_loop(xl: np.ndarray, starts, l_min: int, l_max: int, fade: int):
    """Acha (início, comprimento) cujo final continua o início com maior correlação."""
    best = None
    for s in starts:
        head = xl[s:s + fade]
        if s + l_max + fade > len(xl):
            continue
        region = xl[s + l_min:s + l_max + fade]
        size = 1 << int(np.ceil(np.log2(len(region) + len(head))))
        dot = np.fft.irfft(np.fft.rfft(region, size) * np.conj(np.fft.rfft(head, size)), size)
        dot = dot[:len(region) - len(head) + 1]
        csum = np.concatenate(([0.0], np.cumsum(region * region)))
        energy = csum[len(head):] - csum[:len(csum) - len(head)]
        ncc = dot / (np.sqrt(np.sum(head * head)) * np.sqrt(energy) + 1e-12)
        k = int(np.argmax(ncc))
        if best is None or ncc[k] > best[0]:
            best = (float(ncc[k]), int(s), int(l_min + k))
    return best


def make_loop(x: np.ndarray, start: int, length: int, fade: int):
    """Loop de `length` amostras: o final se funde ao início por crossfade."""
    seg = x[start:start + length + fade].copy()
    head, tail = seg[:fade], seg[length:length + fade]
    rho = float(np.clip(np.corrcoef(head, tail)[0, 1], 0.0, 1.0))
    u = (np.arange(fade) + 0.5) / fade
    fin, fout = np.sin(u * np.pi / 2), np.cos(u * np.pi / 2)
    # Mantém a potência: correlacionados somam em amplitude, independentes em potência.
    norm = 1.0 / np.sqrt(fin ** 2 + fout ** 2 + 2.0 * rho * fin * fout)
    out = seg[:length].copy()
    out[:fade] = (head * fin + tail * fout) * norm
    return out, rho


# ----------------------------------------------------------------- arquivos
def write_wav(path: Path, x: np.ndarray, loop: bool) -> None:
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    data = pcm.tobytes()
    chunks = b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16)
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if loop:
        # Chunk 'smpl' com um loop completo: a importação "Detect From WAV" da Godot o usa.
        smpl = struct.pack("<9I", 0, 0, round(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(pcm) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    path.write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def read_wav(path: Path):
    raw = path.read_bytes()
    assert raw[:4] == b"RIFF" and raw[8:12] == b"WAVE", "não é WAV"
    pos, samples, loop, fmt = 12, None, None, None
    while pos + 8 <= len(raw):
        tag, size = raw[pos:pos + 4], struct.unpack("<I", raw[pos + 4:pos + 8])[0]
        body = raw[pos + 8:pos + 8 + size]
        if tag == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif tag == b"data":
            samples = np.frombuffer(body, dtype="<i2")
        elif tag == b"smpl" and len(body) >= 60:
            loop = struct.unpack("<2I", body[44:52])
        pos += 8 + size + (size & 1)
    return fmt, samples, loop


def seam_report(x: np.ndarray) -> str:
    """Descontinuidade e variação de nível na emenda do loop (a emenda é o fim -> início)."""
    step = np.abs(np.diff(x))
    jump = abs(float(x[0]) - float(x[-1]))
    typical = float(np.percentile(step, 99))
    tiled = np.concatenate([x, x])
    win, hop = int(0.1 * SR), int(0.05 * SR)
    levels = np.array([rms_db(tiled[i:i + win]) for i in range(0, len(tiled) - win, hop)])
    around = [rms_db(tiled[len(x) - win // 2 + o:len(x) + win // 2 + o]) for o in (-int(0.05 * SR), 0, int(0.05 * SR))]
    return (f"salto na emenda {jump:.4f} (passo típico p99 {typical:.4f}, razão {jump / typical:.2f}); "
            f"nível 100 ms: min {levels.min():.1f} / máx {levels.max():.1f} dB; "
            f"na emenda {min(around):.1f}..{max(around):.1f} dB")


# --------------------------------------------------------------- principal
def build_idle(path: Path):
    x = highpass(decode(path), 12.0)
    region = x[int(1.8 * SR):int(17.6 * SR)]          # evita partida e desligamento
    fade = int(1.0 * SR)
    found = best_loop(lowpass(region, 300.0), range(0, int(3.0 * SR), int(0.2 * SR)),
                      int(5.4 * SR), int(6.6 * SR), fade)
    ncc, start, length = found
    loop, rho = make_loop(region, start, length, fade)
    loop = flatten_level(loop, 0.3, 3.0, circular=True)
    info = f"início {1.8 + start / SR:.2f} s, comprimento {length / SR:.3f} s, crossfade 1,0 s, correlação {ncc:.2f}/{rho:.2f}"
    return loop, info, x


def build_accel(path: Path, reference_levels: np.ndarray):
    x = highpass(decode(path), 12.0)
    times, spacing = track_spacing(x, 4.35, 6.8, 24.0, 46.0)
    y, (s0, s1, residual) = flatten_pitch(x, times, spacing, 4.55, 6.60)
    y = flatten_level(y)
    fade = int(0.5 * SR)
    found = best_loop(lowpass(y, 300.0), range(0, int(0.15 * SR), int(0.01 * SR)),
                      int(1.2 * SR), len(y) - fade - int(0.15 * SR), fade)
    ncc, start, length = found
    loop, rho = make_loop(y, start, length, fade)
    # EQ suave (±3 dB) e só então o nivelamento: um EQ forte reintroduzia oscilação de
    # volume no ritmo do loop (modulação 4x maior), que soava como "nhoum-nhoum".
    loop, gains = match_eq(loop, reference_levels, 0.4, 3.0)
    loop = flatten_level(loop, 0.3, 3.0, circular=True)
    info = (f"trecho 4,55–6,60 s (tom {s0:.1f}→{s1:.1f} Hz normalizado para {ACCEL_SPACING_HZ:.0f} Hz, "
            f"resíduo do ajuste {residual * 100:.1f}%), loop {length / SR:.3f} s, crossfade 0,5 s, "
            f"correlação {ncc:.2f}/{rho:.2f}, EQ {gains.min():+.1f}..{gains.max():+.1f} dB")
    return loop, info


def build_rev(path: Path, reference_levels: np.ndarray):
    x = highpass(decode(path), 12.0)
    y = x[:int(1.9 * SR)].copy()
    fade_in = int(0.005 * SR)
    y[:fade_in] *= np.sin(np.linspace(0.0, np.pi / 2, fade_in)) ** 2
    fade_out = int(0.4 * SR)
    y[-fade_out:] *= np.cos(np.linspace(0.0, np.pi / 2, fade_out)) ** 2
    y, gains = match_eq(y, reference_levels, 0.5, 6.0)
    info = f"0,00–1,90 s, fade-in 5 ms, fade-out 0,4 s, EQ {gains.min():+.1f}..{gains.max():+.1f} dB"
    return y, info


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    idle_path, accel_path, rev_path = (find_source(k) for k in ("idle", "accel", "rev"))
    print("Gravações:", idle_path.name, "|", accel_path.name, "|", rev_path.name)

    idle, info, _ = build_idle(idle_path)
    reference = band_levels(idle)
    print("idle :", info)
    accel, accel_info = build_accel(accel_path, reference)
    print("accel:", accel_info)
    rev, rev_info = build_rev(rev_path, reference)
    print("rev  :", rev_info)

    outputs = [
        ("v8_idle_loop.wav", normalize(idle), True),
        ("v8_accel_loop.wav", normalize(accel), True),
        ("v8_rev_blip.wav", normalize(rev, slice(0, SR)), False),
    ]
    for name, samples, loop in outputs:
        write_wav(OUT_DIR / name, samples, loop)

    print("\nVerificação (relendo os arquivos gravados):")
    for name, _, loop in outputs:
        fmt, pcm, loop_points = read_wav(OUT_DIR / name)
        x = pcm.astype(np.float64) / 32768.0
        clipped = int(np.sum(np.abs(pcm) >= 32767))
        print(f"  {name}: {len(pcm) / SR:.3f} s, {fmt[2]} Hz, {fmt[1]} canal, {fmt[5]} bits, "
              f"RMS {rms_db(x):.1f} dBFS, pico {peak_db(x):.1f} dBFS, amostras no limite {clipped}, "
              f"loop {loop_points}")
        if loop:
            print("     ", seam_report(x))


if __name__ == "__main__":
    main()
