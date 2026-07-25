#!/usr/bin/env python3
"""Generate a small set of test samples for the M8's sampler.

Synthesised from scratch, so there is nothing to license and nothing to source.
Output is mono 44.1 kHz 16-bit WAV, which is what the M8 wants - the docs
recommend mono to reduce microSD load when several sample channels play at once.

These go in /Samples on the Teensy's microSD card. The card has to be physically
removed to write to it; the M8 Headless exposes no USB mass storage.

Usage: python3 scripts/make-test-samples.py [outdir]
"""

import math
import os
import random
import struct
import sys
import wave

RATE = 44100
random.seed(20260725)  # reproducible output


def write_wav(path, samples):
    """Write float samples in [-1, 1] as mono 16-bit PCM."""
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32767)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    return len(samples) / RATE


def env(n, attack=0.002, decay=0.3, curve=4.0):
    """Percussive envelope: short linear attack, exponential decay."""
    a = max(1, int(attack * RATE))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / RATE
            out.append(math.exp(-curve * t / decay))
    return out


def kick(dur=0.45):
    n = int(dur * RATE)
    e = env(n, decay=dur, curve=3.5)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        # pitch sweep 115 Hz -> 45 Hz gives the classic "thump"
        f = 45 + (115 - 45) * math.exp(-6.0 * t)
        phase += 2 * math.pi * f / RATE
        out.append(math.sin(phase) * e[i] * 0.95)
    return out


def snare(dur=0.22):
    n = int(dur * RATE)
    e = env(n, decay=dur, curve=5.0)
    out, phase, prev = [], 0.0, 0.0
    for i in range(n):
        phase += 2 * math.pi * 185 / RATE
        noise = random.uniform(-1, 1)
        # one-pole high pass to thin the noise out
        hp, prev = noise - prev * 0.6, noise
        out.append((math.sin(phase) * 0.35 + hp * 0.65) * e[i] * 0.72)
    return out


def hat(dur=0.06, curve=8.0):
    n = int(dur * RATE)
    e = env(n, attack=0.0005, decay=dur, curve=curve)
    out, prev = [], 0.0
    for i in range(n):
        noise = random.uniform(-1, 1)
        # aggressive high pass -> metallic
        hp, prev = noise - prev * 0.92, noise
        out.append(hp * e[i] * 0.55)
    return out


def clap(dur=0.3):
    n = int(dur * RATE)
    out, prev = [], 0.0
    # three quick bursts then a tail, which is what gives a clap its shape
    bursts = [0.0, 0.011, 0.023]
    for i in range(n):
        t = i / RATE
        amp = 0.0
        for b in bursts:
            if t >= b:
                amp = max(amp, math.exp(-55.0 * (t - b)))
        amp = max(amp, math.exp(-9.0 * t) * 0.32)
        noise = random.uniform(-1, 1)
        hp, prev = noise - prev * 0.75, noise
        out.append(hp * amp * 0.62)
    return out


def tone(freq, dur=1.0, shape="sine"):
    """Sustained tone for testing sampler pitching and looping."""
    n = int(dur * RATE)
    out, phase = [], 0.0
    for i in range(n):
        phase += 2 * math.pi * freq / RATE
        p = phase % (2 * math.pi)
        if shape == "sine":
            v = math.sin(p)
        elif shape == "saw":
            v = (p / math.pi) - 1.0
        elif shape == "square":
            v = 1.0 if p < math.pi else -1.0
        elif shape == "tri":
            v = 1.0 - 4.0 * abs(round(p / (2 * math.pi)) - (p / (2 * math.pi)))
        else:
            raise ValueError(shape)
        # 5 ms fades so looping and one-shots do not click
        f = min(1.0, i / (0.005 * RATE), (n - i) / (0.005 * RATE))
        out.append(v * f * 0.7)
    return out


# C3 = 130.81 Hz. Naming the pitch matters: the M8 pitches samples relative to
# the root note you set, so a known reference makes it obvious if it is right.
C3 = 130.81

BANK = {
    "KICK.wav": kick,
    "SNARE.wav": snare,
    "HAT_CL.wav": lambda: hat(0.06, 8.0),
    "HAT_OP.wav": lambda: hat(0.34, 1.6),
    "CLAP.wav": clap,
    "SINE_C3.wav": lambda: tone(C3, 1.0, "sine"),
    "SAW_C3.wav": lambda: tone(C3, 1.0, "saw"),
    "SQUARE_C3.wav": lambda: tone(C3, 1.0, "square"),
    "TRI_C3.wav": lambda: tone(C3, 1.0, "tri"),
    "SINE_C4.wav": lambda: tone(C3 * 2, 1.0, "sine"),
}


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "samples")
    outdir = os.path.abspath(outdir)
    os.makedirs(outdir, exist_ok=True)

    total = 0
    for name, fn in BANK.items():
        path = os.path.join(outdir, name)
        dur = write_wav(path, fn())
        size = os.path.getsize(path)
        total += size
        print(f"  {name:<14} {dur:5.2f}s  {size/1024:7.1f} KB")

    print(f"\n{len(BANK)} samples, {total/1024:.1f} KB total -> {outdir}")


if __name__ == "__main__":
    main()
