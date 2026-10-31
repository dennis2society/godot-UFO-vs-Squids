#!/usr/bin/env python3
"""Composes the gameplay loop, an original 174 BPM drum and bass track, as music.ogg.

Everything is synthesized here, so the track has no samples or licences to worry about.
Needs numpy, scipy and ffmpeg. The seed keeps every run identical.
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44100
BPM = 174
BARS = 64
STEPS_PER_BAR = 16
STEP = 60.0 / BPM / 4.0
LENGTH = round(BARS * STEPS_PER_BAR * STEP * RATE)
HERE = Path(__file__).parent
TAU = 2.0 * np.pi
rng = np.random.default_rng(174)

# Which bars each part plays in: intro, first drop, breakdown, second drop, last drop.
INTRO, DROP_A, BREAK, DROP_B, DROP_C = range(0, 8), range(8, 24), range(24, 32), range(32, 48), range(48, 64)
DROPS = [*DROP_A, *DROP_B, *DROP_C]

CHORDS = [  # A minor: Am, F, C, G, as MIDI notes, two bars each.
    (57, 60, 64), (53, 57, 60), (60, 64, 67), (55, 59, 62),
]
BASS_LINE = [  # Bar 1 and 2 of a bass riff in (step, MIDI note) pairs. Rests hold the note.
    (0, 33), (6, 33), (10, 36), (14, 33),
    (16, 29), (22, 29), (26, 31), (30, 28),
]
LEAD = [69, 72, 76, 74, 72, 69, 67, 64, 69, 76, 79, 76, 74, 72, 69, 72]


def hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def step_sample(step):
    return round(step * STEP * RATE)


def bar_sample(bar):
    return step_sample(bar * STEPS_PER_BAR)


def lowpass(signal, cutoff, order=2):
    """Filters twice around the loop, so the tail of the end lands on the start."""
    sos = butter(order, cutoff, "low", fs=RATE, output="sos")
    return sosfilt(sos, np.concatenate([signal, signal]))[len(signal):]


def highpass(signal, cutoff):
    sos = butter(2, cutoff, "high", fs=RATE, output="sos")
    return sosfilt(sos, signal)


def bandpass(signal, low, high):
    sos = butter(2, [low, high], "band", fs=RATE, output="sos")
    return sosfilt(sos, signal)


def saw(frequency):
    """A saw wave following a frequency per sample."""
    phase = np.cumsum(frequency) / RATE
    return 2.0 * (phase - np.floor(phase + 0.5))


def place(track, sound, at, gain=1.0, pan=0.0):
    """Mixes a mono sound into a stereo track, wrapping past the end to the start."""
    left = gain * np.cos((pan + 1.0) * np.pi / 4.0)
    right = gain * np.sin((pan + 1.0) * np.pi / 4.0)
    where = (at + np.arange(len(sound))) % LENGTH
    np.add.at(track[0], where, sound * left)
    np.add.at(track[1], where, sound * right)


def kick():
    t = np.arange(int(0.22 * RATE)) / RATE
    sweep = np.cumsum(55.0 + 190.0 * np.exp(-t * 55.0)) / RATE
    body = np.sin(TAU * sweep) * np.exp(-t * 22.0)
    click = rng.normal(0.0, 1.0, len(t)) * np.exp(-t * 500.0) * 0.5
    return np.tanh((body + click) * 2.2)


def snare():
    t = np.arange(int(0.2 * RATE)) / RATE
    tone = np.sin(TAU * 195.0 * t) * np.exp(-t * 32.0)
    tone += 0.5 * np.sin(TAU * 330.0 * t) * np.exp(-t * 45.0)
    noise = bandpass(rng.normal(0.0, 1.0, len(t)), 900.0, 7500.0) * np.exp(-t * 20.0)
    return np.tanh(tone * 0.9 + noise * 1.5)


def hat(length, decay):
    t = np.arange(int(length * RATE)) / RATE
    return highpass(rng.normal(0.0, 1.0, len(t)), 7000.0) * np.exp(-t * decay)


def drum_stems():
    drums = np.zeros((2, LENGTH))
    hats = np.zeros((2, LENGTH))
    pump = np.zeros(LENGTH)  # Hits that push the bass and pads down.
    kicks, snares = kick(), snare()
    closed, open_hat = hat(0.05, 160.0), hat(0.2, 22.0)

    # Two bars of chopped break, in the spirit of a classic funk drum solo.
    kick_a = [0, 2, 10, 11, 16, 18, 26]
    snare_a = [4, 12, 20, 28]
    ghosts_a = [7, 9, 15, 23, 25, 30]
    kick_b = [0, 3, 10, 16, 19, 26, 27]
    ghosts_b = [6, 9, 14, 22, 23, 25, 31]

    for bar in range(0, BARS, 2):
        start = bar * STEPS_PER_BAR
        in_drop = bar in DROPS
        variant_b = bar in DROP_B or (bar in DROP_C and bar % 4 == 2)
        if in_drop or bar >= 28 and bar < 32:
            for step in kick_b if variant_b else kick_a:
                place(drums, kicks, step_sample(start + step), 0.62)
                pump_hit(pump, step_sample(start + step), 0.9)
            for step in snare_a:
                place(drums, snares, step_sample(start + step), 0.95)
                pump_hit(pump, step_sample(start + step), 0.55)
            for step in ghosts_b if variant_b else ghosts_a:
                place(drums, snares, step_sample(start + step), 0.2 + 0.1 * rng.random(), -0.1)
        if bar % 8 == 6 and in_drop:  # A snare fill leads into every eighth bar.
            for step in range(24, 32):
                place(drums, snares, step_sample(start + step), 0.25 + 0.05 * (step - 24), 0.1)
        for step in range(0, 32, 2):
            soft = 0.5 if step % 4 else 0.8
            place(hats, closed, step_sample(start + step), soft * 0.4, 0.25)
            if in_drop:
                place(hats, closed, step_sample(start + step + 1), 0.16 * rng.random() + 0.08, -0.25)
            if step % 8 == 6:
                place(hats, open_hat, step_sample(start + step), 0.22, -0.2)
    return drums, hats, pump


def pump_hit(pump, at, depth):
    length = int(0.14 * RATE)
    shape = depth * np.linspace(1.0, 0.0, length) ** 2
    where = (at + np.arange(length)) % LENGTH
    pump[where] = np.maximum(pump[where], shape)


def frequency_track(notes, transpose=0):
    """Holds each (step, note) of a two-bar riff until the next, repeating to the end."""
    track = np.zeros(LENGTH)
    for bar in range(0, BARS, 2):
        for i, (step, note) in enumerate(notes):
            start = step_sample(bar * STEPS_PER_BAR + step)
            next_step = notes[i + 1][0] if i + 1 < len(notes) else 32
            end = step_sample(bar * STEPS_PER_BAR + next_step)
            track[start:end] = hz(note + transpose)
    glide = int(0.012 * RATE)
    return np.convolve(np.concatenate([track[-glide:], track]), np.ones(glide) / glide, "valid")[:LENGTH]


def reese():
    """Detuned saws through a filter that opens and closes, with a clean sine beneath."""
    frequency = frequency_track(BASS_LINE, 12)
    stems = []
    for detune in (0.994, 1.006):
        wave_ = saw(frequency * detune) + 0.6 * saw(frequency * 2.0 * detune)
        dark = lowpass(np.tanh(wave_ * 1.6), 420.0)
        bright = lowpass(np.tanh(wave_ * 2.4), 1900.0)
        sweep = 0.5 - 0.5 * np.cos(TAU * np.arange(LENGTH) / bar_sample(4))
        stems.append(dark * (1.0 - sweep) + bright * sweep)
    sub = np.sin(TAU * np.cumsum(frequency / 2.0) / RATE)
    return np.array([stems[0] * 0.9 + sub * 0.26, stems[1] * 0.9 + sub * 0.26])


def pads():
    pad = np.zeros((2, LENGTH))
    for bar in range(0, BARS, 2):
        notes = CHORDS[(bar // 2) % len(CHORDS)]
        begin = bar_sample(bar)
        length = bar_sample(bar + 2) - begin
        t = np.arange(length) / RATE
        shape = np.minimum(t / 0.15, 1.0) * np.minimum((length / RATE - t) / 0.15, 1.0)
        for note in notes:
            for detune, pan in ((0.997, -0.6), (1.003, 0.6)):
                tone = saw(np.full(length, hz(note) * detune)) * shape
                place(pad, tone, begin, 0.16, pan)
    return np.array([lowpass(pad[0], 1300.0), lowpass(pad[1], 1300.0)])


def leads():
    """A plucked minor riff with a dotted echo that bounces between the speakers."""
    dry = np.zeros((2, LENGTH))
    for bar in [*BREAK, *DROP_B, *DROP_C]:
        for i, step in enumerate((0, 3, 6, 10)):
            index = (bar * 4 + i) % len(LEAD)
            note = LEAD[index] + (12 if bar in DROP_C and bar % 8 >= 4 else 0)
            t = np.arange(int(0.24 * RATE)) / RATE
            tone = saw(np.full(len(t), hz(note))) + saw(np.full(len(t), hz(note) * 1.004))
            tone *= np.exp(-t * 11.0) * np.minimum(t / 0.002, 1.0)
            place(dry, tone, step_sample(bar * STEPS_PER_BAR + step), 0.3, 0.3 if i % 2 else -0.3)
    out = dry.copy()
    delay = step_sample(3)
    for echo in range(1, 5):
        tap = np.roll(dry, delay * echo, axis=1) * 0.5 ** echo
        out += tap[::-1] if echo % 2 else tap
    return np.array([lowpass(out[0], 3500.0), lowpass(out[1], 3500.0)])


def riser():
    """White noise swelling into each drop."""
    track = np.zeros((2, LENGTH))
    for bar in (8, 32, 48):
        length = bar_sample(2)
        t = np.linspace(0.0, 1.0, length)
        noise = highpass(rng.normal(0.0, 1.0, length), 1500.0) * t ** 3
        place(track, noise, bar_sample(bar) - length, 0.16, 0.0)
    return track


def bars_gate(bars):
    """A gain of 1 inside the listed bars, with short ramps so nothing clicks."""
    gate = np.zeros(LENGTH)
    for bar in bars:
        gate[bar_sample(bar):bar_sample(bar + 1)] = 1.0
    ramp = int(0.01 * RATE)
    return np.convolve(np.concatenate([gate[-ramp:], gate]), np.ones(ramp) / ramp, "valid")[:LENGTH]


def main():
    drums, hats, pump = drum_stems()
    bass = reese() * bars_gate([*DROPS, 30, 31])
    pad = pads() * (0.55 + 0.45 * bars_gate([*INTRO, *BREAK]))
    lead = leads()
    duck = 1.0 - pump

    mix = drums * 0.9 + hats * 1.5 + riser() + lead * 1.1 * duck
    mix += bass * 0.6 * duck + pad * 1.3 * duck
    mix = np.tanh(mix * 1.1)
    mix *= 0.8 / np.max(np.abs(mix))

    # The drop at the loop point would otherwise click into the quiet intro.
    seam = int(0.006 * RATE)
    mix[:, :seam] *= np.linspace(0.0, 1.0, seam)
    mix[:, -seam:] *= np.linspace(1.0, 0.0, seam)
    pcm = (mix.T * 32767.0).astype("<i2")

    with tempfile.TemporaryDirectory() as folder:
        source = Path(folder) / "music.wav"
        with wave.open(str(source), "wb") as out:
            out.setnchannels(2)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(pcm.tobytes())
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-c:a", "libvorbis",
             "-q:a", "5", str(HERE / "music.ogg")],
            check=True,
        )


if __name__ == "__main__":
    main()
