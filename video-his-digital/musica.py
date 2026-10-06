"""Banda sonora sintetizada para el video (sin derechos de terceros).

Tensión (0–24.5 s) → latidos y monitor (24.5–27.6 s) → impacto + revelación
de marca → ritmo positivo para la solución, beneficios y llamada a la acción.
Uso: python3 musica.py  →  musica.wav
"""
import wave
import numpy as np

SR = 44100
DUR = 51.0
N = int(SR * DUR)
t = np.arange(N) / SR
L = np.zeros(N)
R = np.zeros(N)
rng = np.random.default_rng(7)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n, a, d):
    """Envolvente ataque/decaimiento exponencial de n muestras."""
    e = np.exp(-np.arange(n) / (d * SR))
    k = max(1, int(a * SR))
    e[:k] *= np.linspace(0, 1, k)
    return e


def add(sig, at, gain=1.0, pan=0.0):
    i = int(at * SR)
    if i >= N:
        return
    sig = sig[: N - i] * gain
    L[i : i + len(sig)] += sig * (1 - pan) / 2 * 2 ** 0.5
    R[i : i + len(sig)] += sig * (1 + pan) / 2 * 2 ** 0.5


def tone(f, dur, a=0.005, d=0.3, kind="sine"):
    n = int(dur * SR)
    x = np.arange(n) / SR
    ph = 2 * np.pi * f * x
    if kind == "saw":
        w = sum(np.sin(ph * k) / k for k in range(1, 9))
    elif kind == "tri":
        w = np.sin(ph) + np.sin(3 * ph) / 9 - np.sin(5 * ph) / 25
    else:
        w = np.sin(ph)
    return w * env(n, a, d)


def lowpass(x, k):
    return np.convolve(x, np.ones(k) / k, mode="same")


# --- 1) Dron de tensión (La menor grave) que crece hasta el giro ---
drama = (t < 24.6)
swell = np.clip(t / 24.5, 0, 1) ** 1.5
drone = (np.sin(2 * np.pi * 55 * t) + 0.6 * np.sin(2 * np.pi * 82.41 * t + 0.4 * np.sin(2 * np.pi * 0.2 * t))
         + 0.25 * np.sin(2 * np.pi * 110.3 * t) + 0.18 * np.sin(2 * np.pi * 130.8 * t))
drone *= (0.10 + 0.16 * swell) * drama * np.clip((24.6 - t) / 0.15, 0, 1)
L += drone
R += drone * 0.96

# Tic-tac del reloj en la escena 1
for k in range(12):
    click = rng.standard_normal(int(0.02 * SR)) * env(int(0.02 * SR), 0.0005, 0.004)
    add(click, 0.3 + k * 0.5, 0.35 if k % 2 else 0.5, pan=-0.3 if k % 2 else 0.3)

# Pulsos graves cada vez más rápidos (escenas 2–4)
tp = 6.0
while tp < 24.3:
    add(tone(48, 0.5, 0.004, 0.18), tp, 0.55)
    tp += max(0.42, 1.0 - (tp - 6) * 0.033)

# Golpes en los momentos clave (estampa "OLVIDADO", caída de la meta, temblor)
for at, g in [(14.5, 0.9), (16.0, 0.6), (20.1, 0.5), (22.3, 0.7)]:
    add(tone(41, 1.2, 0.002, 0.45, "saw") + rng.standard_normal(int(1.2 * SR)) * env(int(1.2 * SR), 0.001, 0.08) * 0.6, at, g * 0.5)

# Barrido de ruido (riser) antes del corte a negro
n = int(2.4 * SR)
riser = lowpass(rng.standard_normal(n), 6) * np.linspace(0, 1, n) ** 2
add(riser, 22.1, 0.35)

# Transiciones "whoosh" entre escenas
for at in [6.0, 12.0, 18.0, 38.5]:
    n = int(0.6 * SR)
    w = lowpass(rng.standard_normal(n), 4) * np.sin(np.linspace(0, np.pi, n)) ** 2
    add(w, at - 0.3, 0.22)

# --- 2) Monitor cardíaco sincronizado con la línea ECG ---
for at in [25.3, 26.15]:
    add(tone(988, 0.16, 0.003, 0.08), at, 0.28)
    add(tone(55, 0.35, 0.002, 0.12), at, 0.6)

# --- 3) Impacto + revelación de marca (27.6 s) ---
n = int(3.5 * SR)
braam = (tone(36.7, 3.5, 0.003, 1.3, "saw") * 0.9 + rng.standard_normal(n) * env(n, 0.001, 0.25) * 0.5)
add(lowpass(braam, 3), 27.6, 0.55)
for m, g in [(72, .12), (76, .10), (79, .10), (84, .08)]:  # brillo en Do mayor
    add(tone(hz(m), 3.0, 0.02, 1.4, "tri"), 27.62, g)

# --- 4) Ritmo positivo 112 bpm (30.5 s → final) ---
BPM = 112
beat = 60 / BPM
start = 30.5
prog = [(48, [60, 64, 67]), (43, [59, 62, 67]), (45, [60, 64, 69]), (41, [60, 65, 69])]  # C G Am F
b = 0
while start + b * beat < DUR - 1.0:
    at = start + b * beat
    bar = (b // 4) % 4
    bass, chord = prog[bar]
    # bombo
    n = int(0.35 * SR)
    x = np.arange(n) / SR
    kick = np.sin(2 * np.pi * (45 + 90 * np.exp(-x * 30)) * x) * env(n, 0.001, 0.12)
    add(kick, at, 0.75)
    # charles a contratiempo
    hn = int(0.06 * SR)
    hat = np.diff(rng.standard_normal(hn + 1)) * env(hn, 0.0005, 0.015)
    add(hat, at + beat / 2, 0.16, pan=0.35)
    # palmada en 2 y 4
    if b % 2 == 1:
        cn = int(0.18 * SR)
        add(lowpass(rng.standard_normal(cn), 2) * env(cn, 0.001, 0.05), at, 0.22, pan=-0.2)
    # bajo
    add(tone(hz(bass - 12), beat * 0.9, 0.005, 0.25, "tri"), at, 0.32)
    # colchón de acordes al inicio de cada compás
    if b % 4 == 0:
        for m in chord:
            add(tone(hz(m), beat * 4, 0.25, 2.2, "tri"), at, 0.06, pan=-0.4)
            add(tone(hz(m) * 1.003, beat * 4, 0.25, 2.2, "tri"), at, 0.06, pan=0.4)
    # arpegio "pluck"
    arp = chord + [chord[1] + 12]
    for s in range(2):
        m = arp[(b * 2 + s) % 4] + 12
        add(tone(hz(m), 0.3, 0.002, 0.12, "tri"), at + s * beat / 2, 0.07, pan=0.25 if s else -0.25)
    b += 1

# Acento final al entrar la llamada a la acción
add(tone(hz(48), 2.5, 0.003, 0.9, "saw") * 0.5, 44.5, 0.3)
for m in [72, 76, 79, 84]:
    add(tone(hz(m), 3.5, 0.01, 1.6, "tri"), 44.52, 0.07)

# Fundido final, normalización y escritura
fade = np.clip((DUR - t) / 2.0, 0, 1)
fadein = np.clip(t / 0.3, 0, 1)
L *= fade * fadein
R *= fade * fadein
peak = max(np.abs(L).max(), np.abs(R).max())
L, R = L / peak * 0.89, R / peak * 0.89
data = (np.stack([L, R], axis=1) * 32767).astype(np.int16)
with wave.open("musica.wav", "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data.tobytes())
print("musica.wav listo")
