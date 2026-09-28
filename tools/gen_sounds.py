"""Процедурные звуки пролога: выстрелы вдали и рядом, шорох в кустах,
удар монтировкой, щелчок разъёма и писк компьютера.
Запуск: python3 tools/gen_sounds.py  (нужен numpy)"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(2062)


def save(name, x):
	x = np.asarray(x, dtype=np.float64)
	x = x / max(1e-6, np.abs(x).max()) * 0.9
	os.makedirs(OUT, exist_ok=True)
	with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes((x * 32767).astype(np.int16).tobytes())
	print("готово:", name)


def t(sec):
	return np.arange(int(SR * sec)) / SR


def lowpass(x, k):
	"""Простой фильтр: скользящее среднее k отсчётов, дважды."""
	if k <= 1:
		return x
	ker = np.ones(k) / k
	return np.convolve(np.convolve(x, ker, "same"), ker, "same")


def reverb(x, delays=(0.07, 0.13, 0.21, 0.34), decay=0.45):
	y = np.concatenate([x, np.zeros(int(SR * 0.9))])
	for i, d in enumerate(delays):
		n = int(SR * d)
		y[n:n + len(x)] += x * decay ** (i + 1)
	return y


def shot(dist_k, seed, length=0.9):
	r = np.random.default_rng(seed)
	tt = t(length)
	crack = r.normal(0, 1, len(tt)) * np.exp(-tt * (60 - dist_k * 35))
	boom = np.sin(2 * np.pi * (70 + 30 * r.random()) * tt) * np.exp(-tt * 9)
	x = lowpass(crack, 1 + int(dist_k * 14)) * (1.0 - dist_k * 0.5) + boom * (0.6 + dist_k * 0.6)
	return reverb(x, decay=0.35 + dist_k * 0.25)


for i in range(3):
	save("shot_far_%d" % (i + 1), shot(0.85, 10 + i))
save("shot_near", shot(0.1, 99, 0.6))

# шорох: полосовой шум с неровной громкостью (кто-то идёт по траве)
tt = t(1.4)
n = rng.normal(0, 1, len(tt))
band = lowpass(n, 3) - lowpass(n, 18)
env = np.clip(np.sin(tt * 2 * np.pi * 2.3) * 0.5 + 0.5, 0, 1) ** 2 * np.exp(-((tt - 0.7) ** 2) / 0.25)
save("rustle", band * env)

# удар монтировкой: глухой низкий удар + металлический звон
tt = t(0.7)
thud = np.sin(2 * np.pi * 85 * tt) * np.exp(-tt * 22) + lowpass(rng.normal(0, 1, len(tt)), 6) * np.exp(-tt * 40)
ring = (np.sin(2 * np.pi * 1320 * tt) + 0.6 * np.sin(2 * np.pi * 2130 * tt)) * np.exp(-tt * 9) * 0.25
save("hit_blunt", thud + ring)

# щелчок разъёма
tt = t(0.25)
click = rng.normal(0, 1, len(tt)) * np.exp(-tt * 300) + np.sin(2 * np.pi * 2400 * tt) * np.exp(-tt * 120) * 0.5
save("plug", click)

# писк компьютера: два коротких тона
tt = t(0.32)
tone = np.where(tt < 0.12, np.sin(2 * np.pi * 1040 * tt), 0) + np.where(tt > 0.16, np.sin(2 * np.pi * 1560 * tt), 0)
tone *= np.clip(np.minimum(tt * 400, 1), 0, 1)
save("beep", tone * 0.6)

# крик вдали (гласная «а» с дрожанием) — для сцены в деревне
tt = t(1.1)
f0 = 330 + 40 * np.sin(tt * 30) - 90 * tt
ph = 2 * np.pi * np.cumsum(f0) / SR
voice = sum(np.sin(ph * k) / k for k in range(1, 7))
voice *= np.clip(tt * 12, 0, 1) * np.exp(-tt * 2.2)
save("scream_far", reverb(lowpass(voice, 4), decay=0.4))
