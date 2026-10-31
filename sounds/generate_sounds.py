#!/usr/bin/env python3
"""Synthesizes the game's WAV files into this folder. Standard library only."""
import math
import random
import struct
from pathlib import Path

RATE = 44100
HERE = Path(__file__).parent


def write_wav(name, samples, loop=False):
    peak = max(abs(s) for s in samples)
    pcm = struct.pack(f"<{len(samples)}h", *(int(s / peak * 30000) for s in samples))
    fmt = struct.pack("<HHIIHH", 1, 1, RATE, RATE * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(pcm)) + pcm
    if loop:  # Godot reads the loop points from this "smpl" chunk on import.
        smpl = struct.pack("<9I", 0, 0, 1000000000 // RATE, 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    data = b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks
    (HERE / name).write_bytes(data)


def fade(samples, seconds=0.005):
    n = int(seconds * RATE)
    for i in range(n):
        samples[-1 - i] *= i / n
    return samples


def engine():
    # Whole-number frequencies complete whole cycles in 2 s, so the loop is seamless.
    out = []
    for i in range(2 * RATE):
        t = i / RATE
        wobble = 0.8 + 0.2 * math.sin(math.tau * 6 * t)
        hum = math.sin(math.tau * 70 * t) + 0.6 * math.sin(math.tau * 140 * t)
        hum += 0.3 * math.sin(math.tau * 211 * t) + 0.25 * math.sin(math.tau * 353 * t)
        out.append(hum * wobble)
    return out


def laser():
    out, phase = [], 0.0
    length = 0.18
    for i in range(int(length * RATE)):
        t = i / RATE
        phase += math.tau * (1500 * math.exp(-t * 11) + 180) / RATE
        tone = math.sin(phase) + 0.4 * math.sin(2 * phase)
        out.append(tone * math.exp(-t * 14))
    return fade(out)


def explosion():
    random.seed(1)
    out, low, phase = [], 0.0, 0.0
    length = 0.62
    for i in range(int(length * RATE)):
        t = i / RATE
        low += (random.uniform(-1, 1) - low) * (0.03 + 0.25 * math.exp(-t * 9))
        phase += math.tau * (110 * math.exp(-t * 5) + 35) / RATE
        out.append((low * 5 + math.sin(phase) * math.exp(-t * 7)) * math.exp(-t * 6))
    return fade(out, 0.02)


def hit():
    random.seed(2)
    out = []
    length = 0.4
    for i in range(int(length * RATE)):
        t = i / RATE
        clang = sum(math.sin(math.tau * f * t) for f in (523, 1187, 1913, 2671))
        thud = math.sin(math.tau * (90 + 80 * math.exp(-t * 30)) * t)
        crack = random.uniform(-1, 1) * math.exp(-t * 60)
        out.append(0.4 * clang * math.exp(-t * 11) + 2 * thud * math.exp(-t * 16) + crack)
    return fade(out, 0.02)


def rocket():
    random.seed(3)
    out, low = [], 0.0
    length = 0.6
    for i in range(int(length * RATE)):
        t = i / RATE
        low += (random.uniform(-1, 1) - low) * (0.05 + 0.3 * t)
        out.append(low * min(t * 30, 1) * math.exp(-t * 3.5))
    return fade(out, 0.03)


def pickup():
    out = []
    length = 0.32
    for i in range(int(length * RATE)):
        t = i / RATE
        note = 660 if t < 0.1 else 880 if t < 0.2 else 1320
        out.append(math.sin(math.tau * note * t) * math.exp(-t * 5))
    return fade(out, 0.02)


def charged():
    out = []
    length = 0.5
    for i in range(int(length * RATE)):
        t = i / RATE
        rise = 900 + 900 * min(t / 0.12, 1)
        tone = sum(math.sin(math.tau * rise * m * t) / m for m in (1, 1.5, 2.01))
        out.append(tone * min(t * 80, 1) * math.exp(-t * 6))
    return fade(out, 0.02)


def blink():
    out, phase = [], 0.0
    length = 0.28
    for i in range(int(length * RATE)):
        t = i / RATE
        phase += math.tau * (2600 * math.exp(-t * 16) + 250) / RATE
        out.append(math.sin(phase) * math.sin(math.tau * 37 * t) * math.exp(-t * 7))
    return fade(out, 0.02)


write_wav("engine.wav", engine(), loop=True)
write_wav("laser.wav", laser())
write_wav("explosion.wav", explosion())
write_wav("hit.wav", hit())
write_wav("rocket.wav", rocket())
write_wav("pickup.wav", pickup())
write_wav("charged.wav", charged())
write_wav("blink.wav", blink())
