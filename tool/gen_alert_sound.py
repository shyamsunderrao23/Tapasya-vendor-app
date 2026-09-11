"""Generates a large, unique 'new job' alert chime (stdlib only, no deps).

A bright rising bell cascade that repeats twice with a final emphasis chord —
attention grabbing and pleasant, ideal as a new job request alert for vendors.
Outputs: assets/sounds/new_job_alert.wav  (16-bit mono, 44.1kHz)
"""
import math
import wave
import struct

SR = 44100


def bell(freq, dur, vol=0.5, decay=3.2):
    """A bell/marimba-like tone: fundamental + harmonics with exponential decay."""
    n = int(SR * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = math.exp(-decay * t)
        # subtle attack to avoid clicks
        atk = min(1.0, t / 0.006)
        s = (math.sin(2 * math.pi * freq * t)
             + 0.5 * math.sin(2 * math.pi * 2 * freq * t)
             + 0.25 * math.sin(2 * math.pi * 3 * freq * t))
        out[i] = vol * env * atk * (s / 1.75)
    return out


def add(buf, samples, start_sec):
    s = int(SR * start_sec)
    for i, v in enumerate(samples):
        idx = s + i
        if 0 <= idx < len(buf):
            buf[idx] += v


TOTAL = 2.9
master = [0.0] * int(SR * TOTAL)

# A major arpeggio: A5, C#6, E6, A6
notes = [880.00, 1108.73, 1318.51, 1760.00]


def cascade(start, vol):
    t = start
    for f in notes:
        add(master, bell(f, 0.55, vol), t)
        t += 0.11
    # emphasis chord at the top
    add(master, bell(880.00, 0.8, vol * 0.8), t + 0.04)
    add(master, bell(1318.51, 0.8, vol * 0.8), t + 0.04)
    add(master, bell(1760.00, 0.9, vol * 0.85), t + 0.04)
    return t


# First cascade, short gap, then a louder second cascade for a "large" alert feel
cascade(0.05, 0.50)
cascade(1.45, 0.58)

# Normalize / soft clip
peak = max((abs(x) for x in master), default=1.0) or 1.0
scale = 0.92 / peak

frames = bytearray()
for x in master:
    v = x * scale
    # soft clip
    if v > 1.0:
        v = 1.0
    elif v < -1.0:
        v = -1.0
    frames += struct.pack('<h', int(v * 32767))

with wave.open('assets/sounds/new_job_alert.wav', 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(bytes(frames))

print("Saved assets/sounds/new_job_alert.wav  duration=%.2fs samples=%d" % (TOTAL, len(master)))
