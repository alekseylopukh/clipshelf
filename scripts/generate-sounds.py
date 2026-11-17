#!/usr/bin/env python3
# usage: scripts/generate-sounds.py   synthesizes App/Sounds/*.caf, Clipsy's own capture and paste sounds
import math
import os
import struct
import subprocess
import tempfile
import wave

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def render(duration, frequency, decay, peak, harmonic=0.0, attack=0.003):
    samples = []
    phase = 0.0
    for n in range(int(RATE * duration)):
        t = n / RATE
        phase += 2 * math.pi * frequency(t) / RATE
        envelope = min(1.0, t / attack) * math.exp(-t / decay)
        value = math.sin(phase) + harmonic * math.sin(2 * phase)
        samples.append(peak * envelope * value / (1 + harmonic))
    return samples


def write(name, samples):
    with tempfile.TemporaryDirectory() as scratch:
        wav = os.path.join(scratch, name + ".wav")
        with wave.open(wav, "wb") as file:
            file.setnchannels(1)
            file.setsampwidth(2)
            file.setframerate(RATE)
            file.writeframes(b"".join(struct.pack("<h", round(s * 32767)) for s in samples))
        caf = os.path.join(ROOT, "App", "Sounds", name + ".caf")
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", wav, caf], check=True)


write("CardCaptured", render(0.12, lambda t: 1568.0, decay=0.022, peak=0.3, harmonic=0.25))
write("CardPasted", render(0.22, lambda t: 520.0 + 360.0 * math.exp(-t / 0.03), decay=0.045, peak=0.4, attack=0.004))
