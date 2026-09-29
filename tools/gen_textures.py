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


def grass() -> None:
	"""Тёмная трава с бурыми проплешинами (для земли вокруг деревни)."""
	big = fbm(60, 4)
	mid = noise(6)
	blades = noise(0.7)
	g = lerp(col("2f3a22"), col("4a5230"), np.clip(mid * 1.2 - 0.1, 0, 1))
	g = lerp(g, col("5a4a32"), np.clip((big - 0.55) * 3.0, 0, 0.7))
	g *= (0.85 + blades[..., None] * 0.3)
	save("grass_dark", g, blades * 0.3 + mid * 0.3, 2.0)


def meadow() -> None:
	"""Выгоревший луг перед частоколом: сухая солома, бурые проплешины, тёмные сырые пятна."""
	big = fbm(50, 4)
	wet = fbm(35, 3)
	blades = noise(0.7)
	g = lerp(col("6a5e3a"), col("8a7a4c"), np.clip(big * 1.4 - 0.2, 0, 1))
	g = lerp(g, col("4a4a2c"), np.clip((wet - 0.55) * 3.0, 0, 0.8))
	g = lerp(g, col("5a4632"), np.clip((0.35 - big) * 3.0, 0, 0.6))
	g *= (0.85 + blades[..., None] * 0.3)
	save("meadow", g, blades * 0.3 + big * 0.2, 2.0)


def dirt() -> None:
	"""Утоптанная земля дорог с камешками и колеями."""
	big = fbm(40, 4)
	fine = noise(1.0)
	pebble = np.clip((noise(1.5) - 0.72) * 6, 0, 1)
	d = lerp(col("3e3226"), col("6a5640"), np.clip(big * 1.3 - 0.15, 0, 1))
	d *= (0.88 + fine[..., None] * 0.24)
	d = lerp(d, col("8a8070"), pebble * 0.7)
	save("dirt_road", d, big * 0.4 + pebble * 0.5 + fine * 0.2, 3.0)


def needles() -> None:
	"""Хвоя: тёмно-зелёная, пятнистая, с просветами."""
	clump = fbm(8, 4)
	fine = noise(0.6)
	n = lerp(col("15201a"), col("33462b"), np.clip(clump * 1.5 - 0.25, 0, 1))
	n *= (0.8 + fine[..., None] * 0.4)
	save("needles", n, clump * 0.6 + fine * 0.3, 4.0)


def bark() -> None:
	"""Кора хвойных: тёмная, с вертикальными бороздами."""
	groove = fbm(30, 3, aspect=0.03)
	fine = noise(0.8)
	b = lerp(col("1f1812"), col("4a3a2c"), np.clip(groove * 1.5 - 0.2, 0, 1))
	b *= (0.85 + fine[..., None] * 0.3)
	save("bark_dark", b, groove * 0.8 + fine * 0.2, 4.0)


def birch_bark() -> None:
	"""Берёзовая кора: белая, с чёрными поперечными чечевичками и серыми разводами."""
	base = fbm(20, 3)
	dash = fbm(1.0, 2, aspect=25.0)  # вытянутые поперёк ствола
	marks = np.clip((dash - 0.7) * 6, 0, 1)
	grey = np.clip((base - 0.6) * 2.5, 0, 0.6)
	b = lerp(col("d8d4c8"), col("a8a498"), grey)
	b = lerp(b, col("1c1a18"), marks * 0.9)
	save("birch_bark", b, base * 0.3 - marks * 0.5, 3.0)


def leaves() -> None:
	"""Листва: мелкие пятна света и тени."""
	clump = fbm(6, 4)
	fine = noise(0.6)
	l = lerp(col("2e4020"), col("6a7a38"), np.clip(clump * 1.5 - 0.2, 0, 1))
	l *= (0.8 + fine[..., None] * 0.4)
	save("leaves_tex", l, clump * 0.6 + fine * 0.3, 4.0)


def mud() -> None:
	"""Грязь: тёмная, сырая, с блестящими лужицами."""
	big = fbm(40, 4)
	fine = noise(1.0)
	m = lerp(col("2a221a"), col("4a3a2a"), np.clip(big * 1.3 - 0.1, 0, 1))
	m *= (0.9 + fine[..., None] * 0.2)
	save("mud", m, big * 0.5 + fine * 0.2, 3.0)


def rock() -> None:
	"""Валун: серый гранит в крапинку, пятна лишайника."""
	big = fbm(30, 4)
	speck = np.clip((noise(0.6) - 0.65) * 5, 0, 1)
	lichen = np.clip((fbm(25, 3) - 0.62) * 4, 0, 1)
	r = lerp(col("4a4844"), col("7a766e"), np.clip(big * 1.3 - 0.15, 0, 1))
	r = lerp(r, col("2a2826"), speck * 0.6)
	r = lerp(r, col("7a7a4a"), lichen * 0.7)
	save("rock", r, big * 0.7 + speck * 0.2, 4.0)


def _save_rgba(name: str, rgb: np.ndarray, alpha: np.ndarray, rough: np.ndarray, height: np.ndarray, strength: float) -> None:
	"""Текстура с прозрачностью + карта шероховатости (_r) + нормали (_n)."""
	os.makedirs(OUT, exist_ok=True)
	img = np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1)
	Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
	Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(os.path.join(OUT, name + "_r.png"))
	h, w = height.shape
	dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
	dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
	ln = np.sqrt(dx * dx + dy * dy + 1)
	nrm = np.stack([-dx / ln, dy / ln, 1 / ln], -1) * 0.5 + 0.5
	Image.fromarray((nrm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_n.png"))
	print("готово:", name)


def _blob_mask(w: int, h: int, fuzz: float, seed_scale: float) -> np.ndarray:
	"""Рваное пятно: эллипс, искажённый шумом, с широким мягким краем. 0..1"""
	yy, xx = np.mgrid[0:h, 0:w]
	u = (xx + 0.5) / w * 2 - 1
	v = (yy + 0.5) / h * 2 - 1
	r = np.sqrt(u * u + v * v)
	n = _noise_rect(w, h, seed_scale)
	n = (n - n.mean()) / max(n.std(), 1e-6) * 0.15
	fine = _noise_rect(w, h, seed_scale * 0.25)
	fine = (fine - fine.mean()) / max(fine.std(), 1e-6) * 0.05
	edge = 0.72 - r + n * fuzz + fine
	# к краям текстуры — гарантированно прозрачно
	border = np.clip(np.minimum(np.minimum(u + 1, 1 - u), np.minimum(v + 1, 1 - v)) * 6, 0, 1)
	t = np.clip(edge * 1.8, 0, 1)
	return t * t * (3 - 2 * t) * border


def _noise_rect(w: int, h: int, scale: float) -> np.ndarray:
	"""Шум нужного размера (кусок большого бесшовного шума)."""
	big = noise(scale, scale, n=max(w, h, 64))
	return big[:h, :w]


def swamp() -> None:
	"""Болотная заплата на луг: сырая бурая земля, мутная вода в окнах; края тают в луг."""
	w, h = 768, 256
	mask = _blob_mask(w, h, 1.8, 40)
	water = np.clip((_noise_rect(w, h, 14) - 0.52) * 4, 0, 1) * np.clip(mask * 1.5 - 0.3, 0, 1)
	grassy = np.clip((_noise_rect(w, h, 9) - 0.45) * 2.5, 0, 1)
	fine = _noise_rect(w, h, 0.8)
	c = lerp(col("463a28"), col("55502f"), grassy) * (0.9 + fine[..., None] * 0.2)
	c = lerp(c, col("22241a"), water * 0.9)
	alpha = np.clip(mask * 1.1, 0, 1) * 0.9
	rough = 0.95 - water * 0.35
	height = fine * 0.2 + grassy * 0.3 - water * 0.3
	_save_rgba("swamp", c, alpha, rough, height, 2.0)


def puddle() -> None:
	"""Лужа: мутная вода, сырая кайма растворяется в земле."""
	w = h = 256
	mask = _blob_mask(w, h, 1.4, 28)
	water = np.clip((mask - 0.55) * 2.5, 0, 1)
	fine = _noise_rect(w, h, 0.8)
	c = lerp(col("4c402a"), col("2a2a1a"), water) * (0.92 + fine[..., None] * 0.16)
	alpha = np.clip(mask * 1.1, 0, 1) * 0.85
	rough = 0.92 - water * 0.3
	_save_rgba("puddle", c, alpha, rough, fine * 0.2 - water * 0.2, 1.5)


def mud_patch() -> None:
	"""Сырое пятно земли: чуть темнее луга, матовое, край тает."""
	w = h = 256
	mask = _blob_mask(w, h, 1.6, 30)
	big = _noise_rect(w, h, 20)
	fine = _noise_rect(w, h, 0.8)
	c = lerp(col("4a3e2a"), col("5a4c34"), big) * (0.9 + fine[..., None] * 0.2)
	alpha = np.clip(mask * 1.1, 0, 1) * 0.55
	rough = 0.95 - np.clip(big - 0.6, 0, 1) * 0.3
	_save_rgba("mud_patch", c, alpha, rough, big * 0.3 + fine * 0.2, 2.0)


# ---------------- карточки листвы (ветки с прозрачным фоном) ----------------
def _card_save(name: str, img) -> None:
	"""Сохраняет RGBA-карточку: цвет под прозрачными пикселями дотягивается от краёв,
	чтобы на мипмапах не было тёмной каймы."""
	from PIL import ImageFilter
	os.makedirs(OUT, exist_ok=True)
	a = img.split()[3]
	rgb = img.convert("RGB")
	grown = rgb
	for _ in range(6):
		grown = grown.filter(ImageFilter.MaxFilter(5))
	base = Image.composite(rgb, grown, a.point(lambda v: 255 if v > 0 else 0))
	out = base.copy()
	out.putalpha(a)
	out.save(os.path.join(OUT, name + ".png"))
	print("готово:", name)


def _shade(rng, c1: str, c2: str, k: float | None = None):
	a = col(c1)
	b = col(c2)
	t = rng.random() if k is None else k
	c = a + (b - a) * t
	return tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,)


def spruce_branch() -> None:
	"""Еловая лапа: стебель слева направо, боковые веточки, густая хвоя; к концу сужается."""
	from PIL import ImageDraw
	rng = np.random.default_rng(7)
	S = 2
	W, H = 512 * S, 256 * S
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cy = H * 0.5

	def needles_along(x0, y0, x1, y1, nl, dens, tip_light):
		ln = max(1.0, np.hypot(x1 - x0, y1 - y0))
		ux, uy = (x1 - x0) / ln, (y1 - y0) / ln
		n = int(ln / dens)
		for i in range(n):
			t = i / max(1, n - 1)
			px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
			for side in (-1, 1):
				ang = np.deg2rad(rng.uniform(40, 70)) * side
				ca, sa = np.cos(ang), np.sin(ang)
				dx, dy = ux * ca - uy * sa, ux * sa + uy * ca
				l = nl * rng.uniform(0.75, 1.15) * (1.0 - 0.35 * t)
				c = _shade(rng, "1e3319", "3c5a2a", None)
				if t > 0.8 and tip_light:
					c = _shade(rng, "3f5f2c", "6a8a40", None)
				d.line([(px, py), (px + dx * l, py + dy * l)], fill=c, width=2 * S)

	# основной стебель чуть изогнут вниз к концу
	pts = [(8 * S + t * (W - 30 * S), cy + (t ** 2) * 18 * S) for t in np.linspace(0, 1, 40)]
	for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
		d.line([(x0, y0), (x1, y1)], fill=(70, 50, 32, 255), width=3 * S)
	# тёмная сердцевина лапы вдоль стебля
	core = [(x, y - 26 * S * (1 - x / W) - 4 * S) for x, y in pts] + [(x, y + 26 * S * (1 - x / W) + 4 * S) for x, y in pts[::-1]]
	d.polygon(core, fill=(28, 44, 24, 255))
	# боковые веточки
	for i, t in enumerate(np.linspace(0.05, 0.9, 22)):
		bx, by = pts[int(t * 39)]
		env = np.sin(np.pi * min(1.0, (t + 0.15))) * (1.0 - t * 0.55)
		for side in (-1, 1):
			ang = np.deg2rad(rng.uniform(35, 55)) * side
			l = (H * 0.40) * env * rng.uniform(0.75, 1.05)
			ex = bx + np.cos(ang) * l
			ey = by + np.sin(ang) * l
			# плотная масса хвои вокруг веточки — чтобы лапа не «таяла» вдали
			wx, wy = -np.sin(ang) * 11 * S, np.cos(ang) * 11 * S
			d.polygon([(bx - wx * 0.3, by - wy * 0.3), (ex - wx * 0.35, ey - wy * 0.35), (ex + (ex - bx) * 0.08, ey + (ey - by) * 0.08),
				(ex + wx * 0.35, ey + wy * 0.35), (bx + wx * 0.3, by + wy * 0.3)], fill=_shade(rng, "1a2c16", "243a1e"))
			d.line([(bx, by), (ex, ey)], fill=(78, 58, 36, 255), width=2 * S)
			needles_along(bx, by, ex, ey, 24 * S, 1.6 * S, True)
	needles_along(pts[0][0], pts[0][1], pts[-1][0], pts[-1][1], 26 * S, 1.5 * S, True)
	img = img.resize((W // S, H // S), Image.LANCZOS)
	_card_save("spruce_branch", img)


def pine_tuft() -> None:
	"""Сосновая «кисть»: длинная хвоя пучками веером от веточки."""
	from PIL import ImageDraw
	rng = np.random.default_rng(11)
	S = 2
	W = H = 256 * S
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	for tuft in range(6):
		ox = W * rng.uniform(0.3, 0.7)
		oy = H * rng.uniform(0.55, 0.85)
		base_ang = np.deg2rad(-90 + rng.uniform(-35, 35))
		fan = [(ox, oy)] + [(ox + np.cos(base_ang + np.deg2rad(a)) * 62 * S, oy + np.sin(base_ang + np.deg2rad(a)) * 62 * S) for a in range(-55, 56, 10)]
		d.polygon(fan, fill=_shade(rng, "22381b", "2c4521"))
		for _ in range(150):
			a = base_ang + np.deg2rad(rng.normal(0, 38))
			l = rng.uniform(55, 95) * S
			c = _shade(rng, "2a4420", "58763a")
			d.line([(ox, oy), (ox + np.cos(a) * l, oy + np.sin(a) * l)], fill=c, width=S + 1)
		d.line([(ox, oy), (ox + rng.uniform(-10, 10) * S, oy + 40 * S)], fill=(92, 62, 40, 255), width=4 * S)
	img = img.resize((W // S, H // S), Image.LANCZOS)
	_card_save("pine_tuft", img)


def birch_leaves() -> None:
	"""Ветка берёзы: тонкие прутья, мелкие листочки треугольником-сердечком."""
	from PIL import ImageDraw
	rng = np.random.default_rng(13)
	S = 2
	W = H = 512 * S
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cx, cy = W / 2, H / 2
	for twig in range(14):
		a = rng.uniform(0, 2 * np.pi)
		l = rng.uniform(0.25, 0.46) * W
		x0, y0 = cx + rng.normal(0, 20 * S), cy + rng.normal(0, 20 * S)
		x1, y1 = x0 + np.cos(a) * l, y0 + np.sin(a) * l
		d.line([(x0, y0), (x1, y1)], fill=(60, 45, 35, 255), width=2 * S)
		for k in range(int(l / (4 * S))):
			t = rng.uniform(0.15, 1.0)
			px, py = x0 + (x1 - x0) * t + rng.normal(0, 12 * S), y0 + (y1 - y0) * t + rng.normal(0, 12 * S)
			r = rng.uniform(9, 14) * S
			ang = rng.uniform(0, 2 * np.pi)
			pts = []
			for j in range(10):
				u = j / 10 * 2 * np.pi
				rr = r * (0.55 + 0.45 * abs(np.cos(u / 2)))
				pts.append((px + np.cos(u + ang) * rr, py + np.sin(u + ang) * rr * 0.7))
			d.polygon(pts, fill=_shade(rng, "4e6e2c", "8aa648"))
	img = img.resize((W // S, H // S), Image.LANCZOS)
	_card_save("birch_leaves", img)


if __name__ == "__main__":
	logs()
	metal_roof()
	planks()
	stone()
	grass()
	meadow()
	dirt()
	needles()
	bark()
	birch_bark()
	leaves()
	mud()
	rock()
	swamp()
	puddle()
	mud_patch()
