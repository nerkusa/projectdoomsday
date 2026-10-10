"""Генератор карты мира: assets/textures/world_map.jpg по data/world.json.

Реки, переправы, тракты и места берутся из world.json — картинка и логика игры
(через реки не пройти, только по переправам) совпадают. Стиль — как прежняя
рисованная карта: охристая земля, тёмная тайга пятнами, сопки с тенью,
белые известняки, болота, кимберлитовые карьеры, рамка-пергамент.

Запуск: python3 tools/gen_world_map.py
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W_JSON = json.load(open(os.path.join(ROOT, "data", "world.json")))
W, H = W_JSON["size"]
rng = np.random.default_rng(2062)


def fbm(scale, octaves=5, seed=0):
    """Фрактальный шум 0..1: сумма сглаженных случайных сеток."""
    r = np.random.default_rng(seed)
    out = np.zeros((H, W), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        f = 2 ** o
        gh, gw = max(2, int(H / scale * f) + 2), max(2, int(W / scale * f) + 2)
        g = r.random((gh, gw)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
        im = im.filter(ImageFilter.GaussianBlur(max(1.0, scale / f / 5.0)))
        out += np.asarray(im, np.float32) / 255.0 * amp
        tot += amp
        amp *= 0.5
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)


def blob(cx, cy, r, soft=0.35):
    yy, xx = np.ogrid[:H, :W]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    return np.clip((1.0 - d) / soft, 0, 1)


def smooth(a):
    return a * a * (3 - 2 * a)


# ---------- рельеф и земля ----------
height = fbm(520, 6, 1) * 0.7 + fbm(140, 4, 2) * 0.3
gy, gx = np.gradient(height)
shade = np.clip(0.5 + (-gx - gy) * 70.0, 0, 1)  # свет с северо-запада
moist = fbm(300, 4, 3)
ochre = np.array([132, 110, 64], np.float32)
olive = np.array([88, 92, 54], np.float32)
dry = np.array([150, 128, 80], np.float32)
m = smooth(np.clip((moist - 0.35) * 2.0, 0, 1))[..., None]
img = ochre * (1 - m) + olive * m
d = smooth(np.clip((height - 0.62) * 3.0, 0, 1))[..., None]
img = img * (1 - d * 0.5) + dry * d * 0.5
img *= (0.8 + 0.4 * shade)[..., None]
grain = np.asarray(Image.fromarray((rng.random((H, W)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.0)), np.float32) / 255.0
img *= (0.93 + 0.14 * grain)[..., None]

# ---------- зоны: болота, мёртвые пятна, поля ----------
swamp = np.zeros((H, W), np.float32)
dead = np.zeros((H, W), np.float32)
field = np.zeros((H, W), np.float32)
wob = fbm(90, 3, 5)
for z in W_JSON.get("zones", []):
    b = blob(z["pos"][0], z["pos"][1], z["r"] * 1.3, 0.6) * (0.55 + 0.9 * wob)
    {"swamp": swamp, "dead": dead, "field": field}.get(z["type"], field)[:] = np.maximum(
        {"swamp": swamp, "dead": dead, "field": field}.get(z["type"], field), np.clip(b, 0, 1))

# ---------- тайга: пятна леса из «крон» ----------
forest_d = smooth(np.clip((fbm(260, 5, 6) - 0.22) * 2.2, 0, 1))
forest_d *= (1 - 0.85 * dead) * (1 - 0.75 * field) * (1 - 0.5 * smooth(np.clip((height - 0.7) * 4, 0, 1)))
speck = np.asarray(Image.fromarray((rng.random((H, W)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1)),
                   np.float32) / 255.0
speck = (speck - speck.min()) / (speck.max() - speck.min())
tree = np.clip((speck - (1.0 - forest_d * 0.88)) * 7.0, 0, 1)
crowns = np.asarray(Image.fromarray((rng.random((H, W)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.4)), np.float32) / 255.0
crowns = (crowns - crowns.min()) / (crowns.max() - crowns.min())
tree_col = np.array([30, 48, 30], np.float32) * (0.75 + 0.3 * fbm(40, 2, 7) + 0.5 * (crowns - 0.5))[..., None]
img = img * (1 - tree[..., None] * 0.92) + tree_col * tree[..., None] * 0.92
# тень от крон (смещение вниз-вправо)
sh = np.roll(np.roll(tree, 2, 0), 2, 1)
img *= (1 - 0.25 * np.clip(sh - tree, 0, 1))[..., None]

# болото: серо-синие разводы и мелкие озерца
pond = np.clip((fbm(26, 3, 8) - 0.62) * 6, 0, 1) * swamp
img = img * (1 - swamp[..., None] * 0.5) + np.array([78, 88, 82], np.float32) * swamp[..., None] * 0.5
img = img * (1 - pond[..., None]) + np.array([52, 72, 78], np.float32) * pond[..., None]
# мёртвые пятна: серо-бурые, без леса
img = img * (1 - dead[..., None] * 0.45) + np.array([118, 104, 84], np.float32) * dead[..., None] * 0.45

# белые известняковые выходы (как к востоку от Нюрбы и у Вилюйска на снимке)
lime = np.zeros((H, W), np.float32)
for (x, y, r) in [(1560, 420, 140), (1730, 470, 120), (2190, 600, 150), (2330, 650, 110), (1840, 610, 90)]:
    lime = np.maximum(lime, blob(x, y, r, 0.7))
lime = np.clip((fbm(30, 3, 9) - 0.55) * 5, 0, 1) * lime
img = img * (1 - lime[..., None]) + np.array([214, 206, 186], np.float32) * lime[..., None]

im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
dr = ImageDraw.Draw(im)

# ---------- кимберлитовые карьеры ----------
def crater(cx, cy, r):
    for i in range(7, 0, -1):
        rr = r * i / 7.0
        c = int(70 + i * 12)
        dr.ellipse([cx - rr, cy - rr * 0.92, cx + rr, cy + rr * 0.92], fill=(c, int(c * 0.88), int(c * 0.72)),
                   outline=(c - 28, int((c - 28) * 0.86), int((c - 28) * 0.7)), width=3)
    dr.ellipse([cx - r * 0.18, cy - r * 0.16, cx + r * 0.18, cy + r * 0.16], fill=(40, 60, 64))


N = W_JSON["nodes"]
crater(N["mir"]["pos"][0] + 14, N["mir"]["pos"][1] - 6, 46)
crater(N["nyurba"]["pos"][0] + 120, N["nyurba"]["pos"][1] - 70, 34)
crater(1500, 1450, 26)
crater(560, 260, 22)

# озеро у Нюрбы
lx, ly = 1158, 612
dr.ellipse([lx - 30, ly - 36, lx + 30, ly + 36], fill=(46, 70, 76), outline=(150, 132, 96), width=5)

# ---------- тракт и тропы (слабые колеи, сами линии рисует игра) ----------
for p in W_JSON.get("paths", []):
    pts = [tuple(q) for q in p["pts"]]
    if p.get("type") == "road":
        dr.line(pts, fill=(146, 124, 86), width=7, joint="curve")
        dr.line(pts, fill=(120, 100, 70), width=3, joint="curve")

# ---------- реки: берег, вода, стрежень ----------
riv = Image.new("RGBA", (W, H), (0, 0, 0, 0))
rd = ImageDraw.Draw(riv)
wn = fbm(200, 3, 13)
for layer in range(3):
    for r in W_JSON["rivers"]:
        pts = r["pts"]
        for a, b in zip(pts, pts[1:]):
            k = 0.75 + 0.55 * wn[min(H - 1, max(0, int(a[1]))), min(W - 1, max(0, int(a[0])))]
            w = r["width"] * k
            if layer == 0:
                rd.line([tuple(a), tuple(b)], fill=(140, 126, 92, 255), width=int(w + 10))
                rd.ellipse([a[0] - (w + 10) / 2, a[1] - (w + 10) / 2, a[0] + (w + 10) / 2, a[1] + (w + 10) / 2], fill=(140, 126, 92, 255))
            elif layer == 1:
                rd.line([tuple(a), tuple(b)], fill=(32, 52, 56, 255), width=int(w))
                rd.ellipse([a[0] - w / 2, a[1] - w / 2, a[0] + w / 2, a[1] + w / 2], fill=(32, 52, 56, 255))
            else:
                rd.line([tuple(a), tuple(b)], fill=(48, 74, 76, 255), width=max(2, int(w * 0.3)))
riv = riv.filter(ImageFilter.GaussianBlur(1.6))
im.paste(riv, (0, 0), riv)
dr = ImageDraw.Draw(im)

# переправы: мост/плотина — тёмная перемычка, паром/брод — светлые отмели
for c in W_JSON.get("crossings", []):
    x, y = c["pos"]
    if c["type"] in ("bridge", "dam"):
        dr.rectangle([x - 10, y - 26, x + 10, y + 26], fill=(92, 84, 74), outline=(40, 34, 28), width=3)
    else:
        dr.ellipse([x - 16, y - 12, x + 16, y + 12], fill=(170, 150, 104))

# ---------- виньетка и рамка-пергамент ----------
arr = np.asarray(im, np.float32)
yy, xx = np.mgrid[:H, :W]
vig = np.clip(1.0 - (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) * 0.22, 0.6, 1)
arr *= vig[..., None]
edge = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy)).astype(np.float32)
torn = edge + (fbm(14, 2, 11) - 0.5) * 18
frame = np.clip((26 - torn) / 10, 0, 1)
paper = np.array([96, 70, 40], np.float32) * (0.8 + 0.4 * fbm(10, 2, 12))[..., None]
arr = arr * (1 - frame[..., None]) + paper * frame[..., None]
burn = np.clip((torn - 26) / 14, 0, 1)
arr *= (0.55 + 0.45 * burn)[..., None]
out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
out.save(os.path.join(ROOT, "assets", "textures", "world_map.jpg"), quality=90)
print("карта:", W, "x", H)
