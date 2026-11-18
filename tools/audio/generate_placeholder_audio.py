#!/usr/bin/env python3
"""Gera os sons provisórios do motor e do turbo da van.

Os arquivos são sintetizados do zero (pulsos, harmônicos e ruído filtrado),
sem gravações ou amostras de terceiros. Servem para validar o componente
`game/audio/van_engine_audio.gd` até a chegada de gravações definitivas.

Uso, a partir da raiz do repositório:

    python3 tools/audio/generate_placeholder_audio.py

Dependência: numpy. Saída: game/audio/sfx/*.wav (mono, 16 bits, 44,1 kHz).
Os loops contêm um número inteiro de ciclos de todos os componentes
periódicos e o ruído é filtrado de forma circular, então o fim emenda no
início sem estalo. Cada loop leva um chunk `smpl` com o ponto de loop, que o
importador WAV da Godot detecta no modo padrão "Detect From WAV".
A semente é fixa: rodar de novo produz arquivos idênticos.
"""

from __future__ import annotations

import struct
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44_100
LOOP_SECONDS = 1.6  # 55 Hz e 110 Hz cabem em número inteiro de ciclos, múltiplo de 8 explosões.
OUTPUT = Path(__file__).resolve().parents[2] / "game" / "audio" / "sfx"
RNG = np.random.default_rng(4_404_2026)


def spectral_filter(signal: np.ndarray, gain_of) -> np.ndarray:
    """Filtro circular no domínio da frequência; preserva a periodicidade do loop."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1.0 / SAMPLE_RATE)
    return np.fft.irfft(spectrum * gain_of(freqs), signal.size)


def lowpass(fc: float, order: int = 4):
    return lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def highpass(fc: float, order: int = 2):
    return lambda f: (f / fc) ** order / np.sqrt(1.0 + (f / fc) ** (2 * order))


def bandpass(low: float, high: float):
    return lambda f: highpass(low, 2)(f) * lowpass(high, 3)(f)


def normalize(signal: np.ndarray, peak: float) -> np.ndarray:
    signal = signal - signal.mean()
    return signal * (peak / np.max(np.abs(signal)))


def engine_loop(fire_hz: float, resonances: tuple[float, float], decay_ms: float,
                cutoff: float, noise_level: float, roughness: float) -> np.ndarray:
    """Motor V8 estilizado: explosões periódicas com ressonância de escapamento."""
    n = int(round(SAMPLE_RATE * LOOP_SECONDS))
    t = np.arange(n) / SAMPLE_RATE
    out = np.zeros(n)
    fires = int(round(fire_hz * LOOP_SECONDS))
    period = n / fires
    # Padrão irregular de 8 explosões dá o "ronco" típico de V8 cruzado.
    pattern = np.array([1.0, 0.78, 0.94, 0.72, 1.0, 0.84, 0.9, 0.76])
    pulse_len = int(SAMPLE_RATE * decay_ms * 6 / 1000)
    tp = np.arange(pulse_len) / SAMPLE_RATE
    envelope = np.exp(-tp / (decay_ms / 1000))
    f1, f2 = resonances
    for k in range(fires):
        jitter = RNG.normal(0.0, 0.025) * period
        start = int(round(k * period + jitter)) % n
        amp = pattern[k % 8] * (1.0 + RNG.normal(0.0, roughness))
        phase = RNG.uniform(0, 2 * np.pi)
        pulse = envelope * (np.sin(2 * np.pi * f1 * tp + phase) + 0.45 * np.sin(2 * np.pi * f2 * tp))
        pulse += envelope ** 2 * RNG.normal(0.0, 0.6, pulse_len)
        idx = (start + np.arange(pulse_len)) % n  # Posição circular: o loop fecha sem corte.
        out[idx] += amp * pulse
    # Corpo grave: ordem do virabrequim (metade das explosões) e fundamental.
    out += 0.55 * np.sin(2 * np.pi * fire_hz * t) + 0.35 * np.sin(2 * np.pi * fire_hz / 2 * t)
    noise = spectral_filter(RNG.normal(0.0, 1.0, n), bandpass(300.0, 3_500.0))
    out += noise_level * noise / np.max(np.abs(noise)) * np.max(np.abs(out))
    out = spectral_filter(out, lambda f: lowpass(cutoff)(f) * highpass(22.0, 2)(f))
    return normalize(out, 0.7)


def turbo_whistle_loop() -> np.ndarray:
    n = int(round(SAMPLE_RATE * LOOP_SECONDS))
    t = np.arange(n) / SAMPLE_RATE
    # 2250 Hz e vibrato de 5 Hz completam ciclos inteiros em 1,6 s.
    phase = 2 * np.pi * 2_250 * t + 0.6 * np.sin(2 * np.pi * 5 * t)
    tone = np.sin(phase) + 0.12 * np.sin(2 * phase) + 0.05 * np.sin(3 * phase)
    air = spectral_filter(RNG.normal(0.0, 1.0, n), bandpass(1_200.0, 6_500.0))
    air /= np.max(np.abs(air))
    return normalize(0.75 * tone + 0.35 * air, 0.6)


def turbo_release() -> np.ndarray:
    """Alívio de pressão (blow-off): ruído que desce de agudo para médio."""
    n = int(SAMPLE_RATE * 0.7)
    t = np.arange(n) / SAMPLE_RATE
    noise = RNG.normal(0.0, 1.0, n)
    bright = spectral_filter(noise, bandpass(2_500.0, 7_000.0))
    dark = spectral_filter(noise, bandpass(700.0, 2_600.0))
    sweep = np.clip(t / 0.35, 0.0, 1.0)
    body = (1.0 - sweep) * bright / np.max(np.abs(bright)) + sweep * dark / np.max(np.abs(dark))
    envelope = np.minimum(t / 0.008, 1.0) * np.exp(-t / 0.17)
    fade = np.clip((t[-1] - t) / 0.05, 0.0, 1.0)  # Termina em zero, sem estalo.
    return normalize(body * envelope * fade, 0.6)


def write_wav(path: Path, samples: np.ndarray, loop: bool) -> None:
    pcm = np.clip(np.round(samples * 32767.0), -32768, 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16)
    chunks = [b"fmt " + struct.pack("<I", len(fmt)) + fmt,
              b"data" + struct.pack("<I", len(pcm)) + pcm + (b"\0" if len(pcm) % 2 else b"")]
    if loop:
        # smpl: cabeçalho de 9 campos + um loop para frente, infinito, do primeiro ao último quadro.
        header = struct.pack("<9I", 0, 0, 1_000_000_000 // SAMPLE_RATE, 60, 0, 0, 0, 1, 0)
        loop_data = struct.pack("<6I", 0, 0, 0, samples.size - 1, 0, 0)
        smpl = header + loop_data
        chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    body = b"WAVE" + b"".join(chunks)
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)
    print(f"{path.relative_to(OUTPUT.parents[2])}: {samples.size / SAMPLE_RATE:.2f} s, loop={loop}")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    # Camada grave: marcha lenta/baixa rotação, 55 explosões por segundo.
    write_wav(OUTPUT / "engine_low_loop.wav",
              engine_loop(55.0, (170.0, 410.0), 7.0, 1_600.0, 0.05, 0.06), loop=True)
    # Camada sob carga: o dobro da frequência, mais brilho e aspereza.
    write_wav(OUTPUT / "engine_high_loop.wav",
              engine_loop(110.0, (290.0, 880.0), 4.0, 4_200.0, 0.12, 0.10), loop=True)
    write_wav(OUTPUT / "turbo_whistle_loop.wav", turbo_whistle_loop(), loop=True)
    write_wav(OUTPUT / "turbo_release.wav", turbo_release(), loop=False)


if __name__ == "__main__":
    main()
