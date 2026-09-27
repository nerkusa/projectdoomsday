"""Генератор текстур для построек в стиле референса «Нахарра»:
потемневшее бревно, ржавый профнастил, старые доски, камень фундамента.

Все текстуры бесшовные (шум строится через БПФ, он периодичен сам по себе),
к каждой пишется карта нормалей (*_n.png) по карте высот.

Запуск: python3 tools/gen_textures.py   (нужны numpy и Pillow)
Результат: assets/textures/*.png
"""
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
N = 512
rng = np.random.default_rng(2062)


def noise(scale_x: float, scale_y: float | None = None, n: int = N) -> np.ndarray:
	"""Бесшовный шум: белый шум, сглаженный гауссом в частотной области. 0..1"""
	if scale_y is None:
		scale_y = scale_x
	w = rng.standard_normal((n, n))
	fy = np.fft.fftfreq(n)[:, None]
	fx = np.fft.fftfreq(n)[None, :]
	g = np.exp(-((fx * scale_x) ** 2 + (fy * scale_y) ** 2) * 2 * np.pi ** 2)
	r = np.real(np.fft.ifft2(np.fft.fft2(w) * g))
	r -= r.min()
	return r / max(r.max(), 1e-9)


def fbm(base: float, octaves: int = 4, aspect: float = 1.0) -> np.ndarray:
	t = np.zeros((N, N))
	a = 1.0
	s = base
	tot = 0.0
	for _ in range(octaves):
		t += noise(s * aspect, s) * a
		tot += a
		a *= 0.5
		s /= 2.0
	return t / tot


def lerp(a, b, t):
	return a + (b - a) * t[..., None]


def col(h: str) -> np.ndarray:
	h = h.lstrip("#")
	return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def save(name: str, rgb: np.ndarray, height: np.ndarray, strength: float) -> None:
	os.makedirs(OUT, exist_ok=True)
	img = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
	Image.fromarray(img, "RGB").save(os.path.join(OUT, name + ".png"))
	# нормали по высотам (центральные разности с переносом через край — бесшовно)
	dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
	dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
	nz = np.ones_like(height)
	ln = np.sqrt(dx * dx + dy * dy + nz * nz)
	nrm = np.stack([-dx / ln, dy / ln, nz / ln], -1) * 0.5 + 0.5
	Image.fromarray((nrm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_n.png"))
	print("готово:", name)


def logs() -> None:
	"""Потемневшая древесина бревна: волокна вдоль U (горизонтально), трещины, серые пятна."""
	grain = fbm(0.8, 3, aspect=40.0)  # тянется вдоль X
	fine = noise(0.6, 0.6)
	blotch = fbm(60, 3)
	# редкие глубокие трещины вдоль волокон
	cr = fbm(1.2, 2, aspect=60.0)
	crack = np.clip((cr - 0.78) * 12, 0, 1)
	dark = col("2e2821")
	mid = col("5a4d3e")
	grey = col("7a7468")
	base = lerp(dark, mid, np.clip(grain * 1.4 - 0.2, 0, 1))
	base = lerp(base, grey, np.clip(blotch * 1.6 - 0.7, 0, 0.55))
	base *= (0.9 + fine[..., None] * 0.2)
	base = lerp(base, col("15120f"), crack * 0.85)
	h = grain * 0.6 + fine * 0.2 - crack * 0.8
	save("log_weathered", base, h, 3.0)


def metal_roof() -> None:
	"""Профнастил: волны вдоль V (скат), серый металл, ржавые подтёки сверху вниз."""
	x = np.linspace(0, 1, N, endpoint=False)[None, :] * np.ones((N, 1))
	waves = 8  # волн на тайл
	wave = 0.5 + 0.5 * np.sin(x * waves * 2 * np.pi)
	# ржавчина: пятна + вертикальные подтёки
	patch = fbm(40, 4)
	streak = fbm(40.0, 3, aspect=0.02)  # вытянуто по вертикали
	rust = np.clip((patch * 0.7 + streak * 0.5) - 0.45, 0, 1) * 2.2
	rust = np.clip(rust, 0, 1)
	metal = lerp(col("55575a"), col("7d7f80"), wave * 0.6 + noise(2)[...] * 0.4)
	rustc = lerp(col("5a2e17"), col("9a5226"), noise(3))
	rgb = lerp(metal, rustc, rust)
	# тёмные впадины волн
	rgb *= (0.72 + wave[..., None] * 0.35)
	# стыки листов каждые 0.5 тайла по V
	y = np.linspace(0, 1, N, endpoint=False)[:, None] * np.ones((1, N))
	seam = (np.abs(((y * 2) % 1.0) - 0.5) > 0.49).astype(float)
	rgb *= (1 - seam[..., None] * 0.45)
	h = wave * 1.0 - seam * 0.3 + rust * 0.1
	save("metal_roof", rgb, h, 5.0)


def planks() -> None:
	"""Старые доски: вертикальные, с щелями, разного тона."""
	x = np.linspace(0, 1, N, endpoint=False)[None, :] * np.ones((N, 1))
	boards = 6
	idx = np.floor(x * boards)
	tone = rng.uniform(0.75, 1.15, boards)[idx.astype(int)]
	gap = (np.abs((x * boards) % 1.0 - 0.5) > 0.47).astype(float)
	grain = fbm(32.0, 3, aspect=0.025)  # волокна по вертикали
	blotch = fbm(50, 3)
	base = lerp(col("3a3027"), col("6b5b48"), np.clip(grain * 1.3 - 0.15, 0, 1))
	base = lerp(base, col("7c776c"), np.clip(blotch * 1.5 - 0.7, 0, 0.5))
	base *= tone[..., None]
	base = lerp(base, col("120f0c"), gap)
	h = grain * 0.4 - gap * 1.0
	save("planks_old", base, h, 3.0)


def stone() -> None:
	"""Бутовый камень: ячейки Вороного (бесшовно — точки повторяются по краям)."""
	pts = rng.uniform(0, 1, (38, 2))
	yy, xx = np.mgrid[0:N, 0:N] / N
	d1 = np.full((N, N), 9.0)
	d2 = np.full((N, N), 9.0)
	cid = np.zeros((N, N), int)
	for i, (px, py) in enumerate(pts):
		for ox in (-1, 0, 1):
			for oy in (-1, 0, 1):
				d = np.hypot(xx - px - ox, (yy - py - oy) * 1.6)
				closer = d < d1
				d2 = np.where(closer, d1, np.minimum(d2, d))
				cid = np.where(closer, i, cid)
				d1 = np.where(closer, d, d1)
	edge = np.clip((d2 - d1) * 14, 0, 1)
	tone = rng.uniform(0.7, 1.2, len(pts))[cid]
	n = fbm(20, 4)
	base = lerp(col("3d3b37"), col("7a766c"), n) * tone[..., None]
	base = lerp(col("1a1917"), base, edge)
	h = edge * 0.8 + n * 0.3
	save("stone_wall", base, h, 4.0)


if __name__ == "__main__":
	logs()
	metal_roof()
	planks()
	stone()
