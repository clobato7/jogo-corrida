"""Gera os efeitos sonoros do jogo em assets/sfx/.

Os sons são sintetizados (sem arquivos de terceiros). Para trocar algum por um som
próprio, basta substituir o .wav com o mesmo nome.

Uso: python tools/gen_sfx.py
"""
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, release=0.05):
    """Envelope simples: sobe rápido, mantém e desce no fim."""
    e = np.ones(n)
    a, r = int(attack * RATE), int(release * RATE)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x, cutoff):
    b, a = butter(2, cutoff / (RATE / 2), "low")
    return lfilter(b, a, x)


def bandpass(x, lo, hi):
    b, a = butter(2, [lo / (RATE / 2), hi / (RATE / 2)], "band")
    return lfilter(b, a, x)


def save(name, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", RATE, (x * 32767).astype(np.int16))


def engine():
    # Loop de 1 s com número inteiro de ciclos, para emendar sem estalo.
    tt = t(1.0)
    f = 60.0
    x = sum((1.0 / k) * np.sin(2 * np.pi * f * k * tt) for k in range(1, 9))
    x += 0.4 * np.sin(2 * np.pi * 30 * tt)  # ronco grave
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * 15 * tt) ** 2  # pulsação dos pistões
    x = np.tanh(1.5 * x)
    return x


def hit():
    tt = t(0.3)
    thud = np.sin(2 * np.pi * (90 - 50 * tt / 0.3) * tt) * np.exp(-tt * 18)
    crunch = lowpass(rng.standard_normal(len(tt)), 2500) * np.exp(-tt * 30)
    return thud + 0.6 * crunch


def beep(freq, seconds):
    tt = t(seconds)
    x = np.sin(2 * np.pi * freq * tt) + 0.3 * np.sin(2 * np.pi * freq * 2 * tt)
    return x * env(len(tt), 0.005, seconds * 0.4)


def notes(seq, note_len, tail=0.3):
    """Sequência de notas (Hz) com um sininho suave."""
    total = t(note_len * len(seq) + tail)
    out = np.zeros(len(total))
    for i, f in enumerate(seq):
        tt = t(note_len + tail)
        n = np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2 * tt) + 0.15 * np.sin(2 * np.pi * f * 3 * tt)
        n *= np.exp(-tt * 5) * env(len(tt), 0.005, 0.05)
        start = int(i * note_len * RATE)
        out[start:start + len(n)] += n[: len(out) - start]
    return out


def pop():
    tt = t(0.35)
    bang = lowpass(rng.standard_normal(len(tt)), 3000) * np.exp(-tt * 25)
    crackle = bandpass(rng.standard_normal(len(tt)), 3000, 8000) * (rng.random(len(tt)) > 0.97) * np.exp(-tt * 6)
    return bang + 0.8 * crackle


def ambient():
    # 8 s de vento suave com alguns passarinhos, emendável em loop.
    seconds = 8.0
    n = int(seconds * RATE)
    noise = rng.standard_normal(n + RATE)
    wind = lowpass(noise, 500)[RATE:]
    tt = t(seconds)
    wind *= 0.6 + 0.4 * np.sin(2 * np.pi * tt / seconds) ** 2  # sobe e desce uma vez por loop
    x = wind / np.max(np.abs(wind)) * 0.5
    for start in (0.8, 1.05, 3.6, 5.2, 5.4, 6.7):
        ct = t(0.12)
        chirp = np.sin(2 * np.pi * (3200 + 1800 * np.sin(np.pi * ct / 0.12)) * ct) * np.sin(np.pi * ct / 0.12)
        i = int(start * RATE)
        x[i:i + len(ct)] += 0.25 * chirp
    # Cruza o fim com o começo para o loop não estalar.
    fade = int(0.5 * RATE)
    ramp = np.linspace(0, 1, fade)
    x[:fade] = x[:fade] * ramp + x[-fade:] * (1 - ramp)
    return x[:-fade]


if __name__ == "__main__":
    save("engine", engine(), 0.7)
    save("hit", hit())
    save("beep", beep(660, 0.2))
    save("go", beep(990, 0.5))
    save("lap", notes([784, 1047], 0.12))           # sol, dó
    save("win", notes([523, 659, 784, 1047], 0.16, 0.6))  # dó, mi, sol, dó
    save("pop", pop(), 0.6)
    save("ambient", ambient(), 0.6)
    print("Sons gerados em", OUT)
