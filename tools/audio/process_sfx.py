#!/usr/bin/env python3
"""Prepara os efeitos de gameplay a partir das gravações originais.

Lê tools/audio/sfx_sources.json. Para cada entrada cujo original exista em
tools/audio/source_recordings/sfx/<pasta>/, gera a versão processada em
game/audio/sfx/gameplay/<pasta>/. Originais ausentes são apenas relatados:
este script NUNCA sintetiza som nem cria arquivo sem gravação de origem.

Processamento (deliberadamente simples):
  1. recorte manual opcional (trim_start_s / trim_end_s) e recorte automático do silêncio
     das pontas, com folga para preservar o transiente e a cauda;
  2. remoção de componente contínuo (média);
  3. mixagem para mono (o Godot posiciona melhor fontes mono em 3D) — "mono": false mantém;
  4. fade-in curto (anti-estalo) e fade-out (cauda sem corte abrupto);
  5. ganho: normaliza o pico para target_peak_db (padrão -3 dBFS) + gain_db opcional,
     sem compressão, sem limitador, sem equalização;
  6. grava WAV PCM 16 bits na taxa original (sem reamostrar).

Aceita WAV PCM 8/16/24/32 bits e float32. Para MP3/OGG/FLAC converta antes para WAV.

Uso:
  python3 tools/audio/process_sfx.py            # processa o que tiver original
  python3 tools/audio/process_sfx.py --check    # só verifica os arquivos já processados
  python3 tools/audio/process_sfx.py --only ID  # uma entrada
Requer apenas Python 3 e numpy.
"""
import argparse
import glob
import json
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MANIFEST = os.path.join(HERE, "sfx_sources.json")
ORIGINALS = os.path.join(HERE, "source_recordings", "sfx")
OUTPUT = os.path.join(ROOT, "game", "audio", "sfx", "gameplay")

DEFAULTS = {
    "trim_start_s": None,
    "trim_end_s": None,
    "auto_trim": True,
    "silence_db": -50.0,
    "preroll_ms": 5.0,
    "tail_ms": 40.0,
    "fade_in_ms": 2.0,
    "fade_out_ms": 60.0,
    "mono": True,
    "target_peak_db": -3.0,
    "gain_db": 0.0,
}


def read_wav(path):
    """Devolve (amostras float32 [n, canais] em -1..1, taxa)."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("não é um WAV (converta MP3/OGG/FLAC para WAV antes)")
    pos = 12
    fmt = None
    raw = None
    while pos + 8 <= len(data):
        cid = data[pos:pos + 4]
        size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + size]
        if cid == b"fmt ":
            tag, ch, rate, _, _, bits = struct.unpack("<HHIIHH", body[:16])
            if tag == 0xFFFE and len(body) >= 26:
                tag = struct.unpack("<H", body[24:26])[0]
            fmt = (tag, ch, rate, bits)
        elif cid == b"data":
            raw = body
        pos += 8 + size + (size & 1)
    if fmt is None or raw is None:
        raise ValueError("WAV sem fmt/data")
    tag, ch, rate, bits = fmt
    if tag == 1 and bits == 16:
        x = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif tag == 1 and bits == 8:
        x = (np.frombuffer(raw, dtype="u1").astype(np.float32) - 128.0) / 128.0
    elif tag == 1 and bits == 24:
        b = np.frombuffer(raw[: len(raw) // 3 * 3], dtype="u1").reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v & 0x800000, v - 0x1000000, v)
        x = v.astype(np.float32) / 8388608.0
    elif tag == 1 and bits == 32:
        x = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    elif tag == 3 and bits == 32:
        x = np.frombuffer(raw, dtype="<f4").astype(np.float32)
    else:
        raise ValueError("formato WAV não suportado (tag=%d, bits=%d)" % (tag, bits))
    n = (len(x) // ch) * ch
    return x[:n].reshape(-1, ch), rate


def write_wav16(path, x, rate):
    """Grava [n, canais] float (-1..1) como PCM 16 bits."""
    ch = x.shape[1]
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    payload = pcm.tobytes()
    header = b"RIFF" + struct.pack("<I", 36 + len(payload)) + b"WAVEfmt "
    header += struct.pack("<IHHIIHH", 16, 1, ch, rate, rate * ch * 2, ch * 2, 16)
    header += b"data" + struct.pack("<I", len(payload))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(header + payload)


def db(v):
    return float(20.0 * np.log10(max(float(v), 1e-9)))


def process(x, rate, p):
    """Aplica o processamento. Devolve (saída, relatório)."""
    report = {}
    if p["trim_start_s"] is not None or p["trim_end_s"] is not None:
        a = int(round((p["trim_start_s"] or 0.0) * rate))
        b = int(round(p["trim_end_s"] * rate)) if p["trim_end_s"] is not None else len(x)
        x = x[max(a, 0):min(b, len(x))]
    if len(x) == 0:
        raise ValueError("recorte vazio")
    if p["mono"] and x.shape[1] > 1:
        x = x.mean(axis=1, keepdims=True)
    x = x - x.mean(axis=0, keepdims=True)
    if p["auto_trim"]:
        env = np.abs(x).max(axis=1)
        thr = 10.0 ** (p["silence_db"] / 20.0) * max(float(env.max()), 1e-9)
        idx = np.nonzero(env > thr)[0]
        if len(idx) == 0:
            raise ValueError("gravação sem conteúdo acima do limiar")
        start = max(int(idx[0] - p["preroll_ms"] / 1000.0 * rate), 0)
        end = min(int(idx[-1] + p["tail_ms"] / 1000.0 * rate), len(x))
        x = x[start:end]
        report["auto_trim_s"] = (round(start / rate, 3), round(end / rate, 3))
    n = len(x)
    fi = min(int(p["fade_in_ms"] / 1000.0 * rate), n // 4)
    fo = min(int(p["fade_out_ms"] / 1000.0 * rate), n // 2)
    if fi > 0:
        x[:fi] *= np.linspace(0.0, 1.0, fi, dtype=np.float32)[:, None]
    if fo > 0:
        x[n - fo:] *= np.linspace(1.0, 0.0, fo, dtype=np.float32)[:, None]
    peak = float(np.abs(x).max())
    if peak <= 0.0:
        raise ValueError("gravação silenciosa")
    gain_db = p["target_peak_db"] - db(peak) + p["gain_db"]
    x = x * (10.0 ** (gain_db / 20.0))
    out_peak = float(np.abs(x).max())
    if out_peak > 0.999:
        x = x * (0.999 / out_peak)
    report.update(gain_db=round(gain_db, 2), peak_db=round(db(np.abs(x).max()), 2),
                  rms_db=round(db(np.sqrt(np.mean(x ** 2))), 2),
                  duration_s=round(len(x) / rate, 3), channels=x.shape[1], rate=rate)
    return x, report


def check_file(path):
    """Verificação de um WAV já processado. Devolve lista de problemas."""
    problems = []
    try:
        x, rate = read_wav(path)
    except Exception as e:  # noqa: BLE001
        return ["ilegível: %s" % e]
    if len(x) == 0:
        return ["vazio"]
    peak = float(np.abs(x).max())
    if peak >= 0.999:
        problems.append("pico em %.2f dBFS (clipping)" % db(peak))
    if float(np.abs(x[:2]).max()) > 0.01:
        problems.append("começa sem fade (risco de estalo)")
    if float(np.abs(x[-2:]).max()) > 0.01:
        problems.append("termina sem fade (risco de corte abrupto)")
    if len(x) / rate > 8.0:
        problems.append("duração %.1f s é longa para um efeito curto" % (len(x) / rate))
    return problems


def find_original(entry):
    folder = os.path.join(ORIGINALS, entry["folder"])
    pattern = entry.get("original_glob")
    if not pattern:
        return None
    hits = sorted(glob.glob(os.path.join(folder, pattern)))
    hits = [h for h in hits if h.lower().endswith(".wav")]
    return hits[0] if hits else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="só verifica os WAVs já processados")
    ap.add_argument("--only", help="processa apenas esta entrada (id)")
    args = ap.parse_args()

    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    entries = [e for e in manifest["entries"] if not args.only or e["id"] == args.only]
    status = 0
    for entry in entries:
        out_path = os.path.join(OUTPUT, entry["folder"], entry["output"])
        if args.check:
            if not os.path.exists(out_path):
                print("[sem arquivo] %-34s %s" % (entry["id"], entry["output"]))
                continue
            problems = check_file(out_path)
            print("[%s] %-34s %s" % ("ok" if not problems else "PROBLEMA", entry["id"], "; ".join(problems)))
            status |= 1 if problems else 0
            continue
        src = find_original(entry)
        if src is None:
            print("[original ausente] %-34s esperado em source_recordings/sfx/%s/%s"
                  % (entry["id"], entry["folder"], entry.get("original_glob", "?")))
            continue
        params = dict(DEFAULTS)
        params.update(entry.get("process", {}))
        try:
            x, rate = read_wav(src)
            y, rep = process(x, rate, params)
        except Exception as e:  # noqa: BLE001
            print("[erro] %-34s %s" % (entry["id"], e))
            status = 1
            continue
        write_wav16(out_path, y, rate)
        print("[ok] %-34s -> %s  %s" % (entry["id"], os.path.relpath(out_path, ROOT), rep))
    return status


if __name__ == "__main__":
    sys.exit(main())
