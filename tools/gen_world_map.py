"""Генератор карты мира: assets/textures/world_map.jpg по data/world.json.

Реки, переправы, тракты, места и места взрывов берутся из world.json — картинка
и логика игры (через реки не пройти, только по переправам) совпадают.
Картинка вдвое крупнее координат world.json (SC) — чётко видно при приближении.

Как устроено:
  рельеф (шум + отмывка светом с северо-запада, горизонтали) → вода одной маской
  (реки с меняющейся шириной, неровные озёра-алаасы, старицы, ручьи) → по
  расстоянию до воды: глубина, отмели, песчаный берег, прибрежный лес → тайга
  мягкими массивами, болота штриховкой как на топокарте, гари и воронки
  ударов → значки (карьеры, развалины, тракт, мосты, паромы) сглаженным слоем →
  фильтр «экран КПК»: янтарная градиентная карта, вода бирюзовая.
Заодно пишет assets/textures/world_biome.png — маленькую карту местности
для случайных встреч (красный — поле, зелёный — лес, синий — болото).

Запуск: python3 tools/gen_world_map.py  (~2 мин)
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W_JSON = json.load(open(os.path.join(ROOT, "data", "world.json")))
SC = 2
W0, H0 = W_JSON["size"]
W, H = W0 * SC, H0 * SC
rng = np.random.default_rng(2062)
N = W_JSON["nodes"]
BLASTS = W_JSON.get("blasts", [])
RIVERS = W_JSON["rivers"]


def P(q):
    """Точка world.json → пиксель картинки."""
    return (q[0] * SC, q[1] * SC)


def fbm(scale, octaves=5, seed=0):
    """Фрактальный шум 0..1 (scale — в координатах world.json)."""
    scale *= SC
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


def noise(blur):
    a = np.asarray(Image.fromarray((rng.random((H, W)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)),
                   np.float32) / 255.0
    return (a - a.min()) / (a.max() - a.min() + 1e-6)


YY, XX = np.ogrid[:H, :W]


def dist(cx, cy):
    """Расстояние (в координатах world.json) от точки world.json."""
    return np.sqrt((XX - cx * SC) ** 2 + (YY - cy * SC) ** 2) / SC


def blob(cx, cy, r, soft=0.35):
    return np.clip((1.0 - dist(cx, cy) / r) / soft, 0, 1)


def smooth(a):
    a = np.clip(a, 0, 1)
    return a * a * (3 - 2 * a)


def mix(a, b, t):
    return a * (1 - t[..., None]) + np.asarray(b, np.float32) * t[..., None]


def chaikin(pts, n=3):
    pts = [tuple(q) for q in pts]
    for _ in range(n):
        if len(pts) < 3:
            break
        pts = [pts[0]] + [(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                          for a, b in zip(pts, pts[1:]) for t in (0.25, 0.75)] + [pts[-1]]
    return pts


def near_any(x, y, rr):
    for n in N.values():
        if math.hypot(n["pos"][0] - x, n["pos"][1] - y) < rr:
            return True
    for bl in BLASTS:
        if math.hypot(bl["pos"][0] - x, bl["pos"][1] - y) < bl["r"] * 1.2:
            return True
    return False


def river_dist(x, y):
    """(расстояние до ближайшей реки минус её полуширина, точка, направление течения)."""
    best = (1e9, None, None)
    for rv in RIVERS:
        pts = rv["pts"]
        for a, b in zip(pts, pts[1:]):
            ax, ay, bx, by = a[0], a[1], b[0], b[1]
            dx, dy = bx - ax, by - ay
            L2 = dx * dx + dy * dy + 1e-9
            t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / L2))
            px, py = ax + dx * t, ay + dy * t
            d = math.hypot(x - px, y - py) - rv["width"] / 2
            if d < best[0]:
                L = math.sqrt(L2)
                best = (d, (px, py), (dx / L, dy / L))
    return best


# ================= рельеф =================
height = fbm(520, 7, 1) * 0.6 + fbm(140, 5, 2) * 0.3 + fbm(40, 4, 3) * 0.1
gy, gx = np.gradient(height)
shade = np.clip(0.5 + (-gx - gy) * 80.0 * SC, 0, 1)
valley = np.clip((np.asarray(Image.fromarray((height * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(60 * SC)),
                             np.float32) / 255.0 - height) * 6, 0, 1)  # низины темнее
moist = fbm(300, 4, 4)

# ================= зоны =================
swamp = np.zeros((H, W), np.float32)
dead = np.zeros((H, W), np.float32)
field = np.zeros((H, W), np.float32)
wob = fbm(90, 4, 5)
for z in W_JSON.get("zones", []):
    b = np.clip(blob(z["pos"][0], z["pos"][1], z["r"] * 1.3, 0.6) * (0.55 + 0.9 * wob), 0, 1)
    tgt = {"swamp": swamp, "dead": dead, "field": field}.get(z["type"], field)
    np.maximum(tgt, b, out=tgt)

burn = np.zeros((H, W), np.float32)
streak = np.zeros((H, W), np.float32)
rng_rad = fbm(12, 2, 21)
for bl in BLASTS:
    cx, cy = bl["pos"]
    r = bl["r"]
    dd = dist(cx, cy)
    k = 1.0 if bl["type"] == "strike" else 0.6
    np.maximum(burn, np.clip(1.2 - dd / (r * 1.5), 0, 1) * k, out=burn)
    if bl["type"] == "strike":
        # поваленный лес — лучи от эпицентра, рваные
        ang = np.arctan2(YY - cy * SC, XX - cx * SC)
        tab = rng.random(900)
        idx = ((ang + math.pi) / math.tau * 900).astype(np.int32) % 900
        rays = tab[idx] * (0.6 + 0.8 * rng_rad)
        ring = np.clip((dd - r * 0.35) / (r * 0.2), 0, 1) * np.clip((r * 1.7 - dd) / (r * 0.6), 0, 1)
        np.maximum(streak, ring * np.clip((rays - 0.8) * 3, 0, 1), out=streak)
np.maximum(dead, burn, out=dead)
del rng_rad

# ================= вода: одна маска =================
wimg = Image.new("L", (W, H), 0)
wdr = ImageDraw.Draw(wimg)
shallow_img = Image.new("L", (W, H), 0)  # броды и мели
sdr = ImageDraw.Draw(shallow_img)

# реки: густые круги вдоль русла, ширина плавно гуляет (±15% — как в игре)
for rv in RIVERS:
    pts = rv["pts"]
    s_acc = 0.0
    ph = rng.uniform(0, 100)
    for a, b in zip(pts, pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(L * SC / 2))
        for i in range(n):
            t = i / n
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            s = s_acc + L * t
            k = 1.0 + 0.1 * math.sin(s / 37 + ph) + 0.05 * math.sin(s / 11 + ph * 2)
            rr = rv["width"] * k / 2 * SC
            X, Y = x * SC, y * SC
            wdr.ellipse([X - rr, Y - rr, X + rr, Y + rr], fill=255)
        s_acc += L
rwater = np.asarray(wimg, np.uint8) > 127
d_riv = ndimage.distance_transform_edt(~rwater).astype(np.float32) / SC
del rwater


def lake_poly(cx, cy, r0, ex=1.0, rot=0.0, seed=0):
    rr = np.random.default_rng(seed)
    ph = rr.uniform(0, math.tau, 6)
    amp = [0, 0, 0.16, 0.1, 0.06, 0.05]
    pts = []
    for i in range(72):
        th = i / 72 * math.tau
        r = r0 * (1 + sum(amp[k] * math.sin(k * th + ph[k]) for k in range(2, 6)))
        x, y = math.cos(th) * r * ex, math.sin(th) * r
        pts.append(((cx + x * math.cos(rot) - y * math.sin(rot)) * SC, (cy + x * math.sin(rot) + y * math.cos(rot)) * SC))
    return pts


# озеро у Нюрбы
wdr.polygon(lake_poly(1158, 612, 33, 0.85, 0.3, 7), fill=255)

# алаасы — группами, больше в болотах и на полянах
lakes = 0
for _ in range(400):
    x, y = rng.uniform(50, W0 - 50), rng.uniform(50, H0 - 50)
    s_ = swamp[int(y * SC), int(x * SC)] + field[int(y * SC), int(x * SC)] * 0.5 + moist[int(y * SC), int(x * SC)] * 0.3
    if rng.random() > 0.12 + s_ * 0.8 or near_any(x, y, 40) or river_dist(x, y)[0] < 25:
        continue
    for j in range(int(rng.integers(1, 5))):
        lx, ly = x + rng.normal(0, 14), y + rng.normal(0, 10)
        if near_any(lx, ly, 30) or river_dist(lx, ly)[0] < 20:
            continue
        r0 = float(np.clip(rng.lognormal(1.6, 0.45), 2.5, 16))
        wdr.polygon(lake_poly(lx, ly, r0, rng.uniform(0.6, 1.5), rng.uniform(0, math.pi), int(rng.integers(1 << 30))), fill=255)
        lakes += 1

# старицы — подковы у излучин рек
for rv in RIVERS:
    pts = rv["pts"]
    for i in range(6, len(pts) - 6, 9):
        if rng.random() > 0.55:
            continue
        a, b = pts[i - 1], pts[i + 1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) + 1e-9
        side = 1 if rng.random() < 0.5 else -1
        nx, ny = -dy / L * side, dx / L * side
        R = rng.uniform(12, 24)
        off = rv["width"] / 2 + R + rng.uniform(8, 20)
        cx, cy = pts[i][0] + nx * off, pts[i][1] + ny * off
        base = math.atan2(-ny, -nx) + math.pi  # горбом от реки
        arc = []
        for k in range(26):
            th = base - 1.9 + 3.8 * k / 25
            arc.append((cx + math.cos(th) * R, cy + math.sin(th) * R * 0.75))
        if any(river_dist(q[0], q[1])[0] < 6 for q in arc) or any(near_any(q[0], q[1], 30) for q in arc[::5]):
            continue
        w = rng.uniform(2.5, 4.5) * SC
        wdr.line([P(q) for q in arc], fill=255, width=int(w), joint="curve")

# ручьи — петляют к ближайшей реке, к устью шире
creeks = 0
for _ in range(220):
    x, y = rng.uniform(40, W0 - 40), rng.uniform(40, H0 - 40)
    d0, tgt_, _ = river_dist(x, y)
    if not (60 < d0 < 260) or near_any(x, y, 50):
        continue
    hd = math.atan2(tgt_[1] - y, tgt_[0] - x) + rng.uniform(-0.8, 0.8)
    line = [(x, y)]
    for step in range(220):
        d, tp, _ = river_dist(x, y) if step % 4 == 0 else (d, tp, None)
        if d < 0:
            break
        want = math.atan2(tp[1] - y, tp[0] - x)
        diff = (want - hd + math.pi) % math.tau - math.pi
        hd += diff * 0.12 + rng.normal(0, 0.35)
        x += math.cos(hd) * 3.0
        y += math.sin(hd) * 3.0
        line.append((x, y))
    if len(line) < 12 or river_dist(x, y)[0] > 2:
        continue
    line = chaikin(line, 2)
    for k in range(len(line) - 1):
        w = (1.0 + 1.6 * k / len(line)) * SC
        A, B = P(line[k]), P(line[k + 1])
        wdr.line([A, B], fill=255, width=max(2, int(round(w))))
        wdr.ellipse([B[0] - w / 2, B[1] - w / 2, B[0] + w / 2, B[1] + w / 2], fill=255)
    creeks += 1
    if creeks >= 38:
        break
print("озёр:", lakes, "ручьёв:", creeks)

# броды и паромы: мели поперёк реки
for c in W_JSON.get("crossings", []):
    if c["type"] in ("ford", "ferry"):
        _, tp, fl = river_dist(*c["pos"])
        x, y = P(c["pos"])
        sdr.ellipse([x - 14 * SC, y - 14 * SC, x + 14 * SC, y + 14 * SC], fill=255 if c["type"] == "ford" else 120)

water = np.asarray(wimg, np.uint8) > 127
d_out = ndimage.distance_transform_edt(~water).astype(np.float32) / SC  # до воды, в ед. world.json
d_in = ndimage.distance_transform_edt(water).astype(np.float32) / SC  # от берега вглубь
shallow = np.asarray(shallow_img.filter(ImageFilter.GaussianBlur(6 * SC)), np.float32) / 255.0
del wimg, shallow_img

# ================= земля =================
ground_lo = np.array([96, 82, 52], np.float32)  # сырая низина
ground_hi = np.array([150, 130, 86], np.float32)  # сухие гривы
m = smooth((height - 0.3) * 1.8) * (1 - 0.5 * moist)
img = mix(np.broadcast_to(ground_lo, (H, W, 3)).astype(np.float32), ground_hi, m)
img = mix(img, (110, 112, 70), smooth((moist - 0.45) * 2.2) * 0.5)  # травы
img = mix(img, (168, 150, 100), field * 0.55)  # поля и луга — светлые
# песчаный берег и мокрая кромка
sand = smooth(1.0 - d_riv / 3.0) * (d_riv > 0) * 0.6 + smooth(1.0 - d_out / 1.2) * (d_out > 0) * 0.25
img = mix(img, (150, 136, 100), sand)
mud = smooth(1.0 - np.abs(d_riv - 5.0) / 3.0) * (d_riv > 0)
img *= (1 - 0.1 * mud)[..., None]

# ================= тайга =================
forest_d = smooth((fbm(260, 6, 6) - 0.2) * 2.2)
riparian = smooth(1.0 - np.abs(d_riv - 16.0) / 12.0) * (0.6 + 0.4 * wob)  # лес по берегам рек
forest_d = np.maximum(forest_d, riparian * 0.7)
forest_d *= (1 - 0.92 * dead) * (1 - 0.8 * field) * (1 - 0.5 * smooth((height - 0.72) * 4)) * smooth((d_out - 1.5) / 2.5)
clump = fbm(9, 3, 30)
fine = noise(0.9 * SC)
tree = smooth((forest_d + (clump - 0.5) * 0.6 + (fine - 0.5) * 0.25 - 0.45) * 3.2)
crown = 0.7 + 0.45 * clump + 0.25 * (fine - 0.5)
tree_col = np.array([48, 66, 42], np.float32) * crown[..., None]
img = mix(img, (0, 0, 0), tree * 0.0) * (1 - tree[..., None] * 0.9) + tree_col * tree[..., None] * 0.9
# тень крон на юго-восток: лес «стоит» над землёй
tsh = np.roll(np.roll(tree, 2 * SC, 0), 2 * SC, 1)
img *= (1 - 0.3 * np.clip(tsh - tree, 0, 1))[..., None]
del clump, fine, crown, tree_col, tsh

# болото: сизый налёт и мочажины
img = mix(img, (92, 100, 88), swamp * 0.45)
pond = smooth((fbm(16, 3, 8) - 0.6) * 5) * swamp
img = mix(img, (66, 84, 82), pond * 0.8)
# гари и мёртвый лес: серо-бурые, к центру темнее, лучи поваленного леса
img = mix(img, (120, 106, 86), dead * 0.5)
img *= (1 - 0.35 * burn ** 2)[..., None]
img *= (1 - 0.45 * streak)[..., None]

# известняковые выходы
lime = np.zeros((H, W), np.float32)
for (x, y, r) in [(1560, 420, 140), (1730, 470, 120), (2190, 600, 150), (2330, 650, 110), (1840, 610, 90)]:
    np.maximum(lime, blob(x, y, r, 0.7), out=lime)
lime = smooth((fbm(30, 4, 9) - 0.55) * 5) * lime
img = mix(img, (184, 176, 156), lime * 0.6)

# свет: отмывка рельефа, низины, горизонтали
img *= (0.72 + 0.56 * shade)[..., None]
img *= (1 - 0.25 * valley)[..., None]
lev = height * 14.0
iso = np.abs(lev - np.round(lev))
gm = np.sqrt(gx ** 2 + gy ** 2) * 14.0 + 1e-4
cline = np.clip(1.0 - iso / (gm * 1.2), 0, 1) * smooth((height - 0.45) * 3) * (1 - tree * 0.6)
img *= (1 - 0.12 * cline)[..., None]
img *= (0.97 + 0.06 * noise(0.8))[..., None]
del lev, iso, gm, cline, gx, gy, valley, lime, pond

# ================= вода: цвет по глубине =================
depth = smooth(d_in / 9.0) * (1 - shallow * 0.8)
wcol = mix(np.broadcast_to(np.array([88, 120, 112], np.float32), (H, W, 3)).astype(np.float32), (26, 46, 54), depth)
flow = fbm(6, 3, 40)
wcol *= (0.94 + 0.12 * flow)[..., None]
wedge = smooth(1.0 - d_in / 1.2) * water  # светлая кромка у берега
wcol = mix(wcol, (140, 160, 140), wedge * 0.5)
wsoft = np.asarray(Image.fromarray(water.astype(np.uint8) * 255).filter(ImageFilter.GaussianBlur(0.8 * SC)), np.float32) / 255.0
img = mix(img, (0, 0, 0), wsoft * 0) * (1 - wsoft[..., None]) + wcol * wsoft[..., None]
del wcol, flow, wedge, depth

# ================= значки: сглаженный слой =================
base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
del img
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(ov)

# болота штриховкой (как на топокарте)
hs = np.random.default_rng(77)
for _ in range(26000):
    x, y = hs.uniform(0, W), hs.uniform(0, H)
    sv = swamp[int(y), int(x)]
    if sv < 0.45 or hs.random() > sv or water[int(y), int(x)]:
        continue
    L = hs.uniform(4, 9) * SC
    od.line([(x - L / 2, y), (x + L / 2, y)], fill=(40, 58, 60, 150), width=SC)
    if hs.random() < 0.4:
        od.line([(x - L / 4, y + 3 * SC), (x + L / 4, y + 3 * SC)], fill=(40, 58, 60, 130), width=SC)


def crater(cx, cy, r):
    cx, cy, r = cx * SC, cy * SC, r * SC
    for i in range(12, 0, -1):
        rr = r * i / 12.0
        c = int(60 + i * 8)
        od.ellipse([cx - rr, cy - rr * 0.92, cx + rr, cy + rr * 0.92], fill=(c, int(c * 0.88), int(c * 0.72), 255),
                   outline=(c - 22, int((c - 22) * 0.86), int((c - 22) * 0.7), 255), width=SC)
    od.ellipse([cx - r * 0.18, cy - r * 0.16, cx + r * 0.18, cy + r * 0.16], fill=(40, 60, 64, 255))


crater(N["mir"]["pos"][0] + 14, N["mir"]["pos"][1] - 6, 46)
crater(N["nyurba"]["pos"][0] + 120, N["nyurba"]["pos"][1] - 70, 34)
crater(1500, 1450, 26)
crater(560, 260, 22)


def ruins(cx, cy, rad, n, seed):
    rr = np.random.default_rng(seed)
    base_a = rr.uniform(0, math.pi)
    ca, sa = math.cos(base_a), math.sin(base_a)
    for _ in range(n):
        u, v = rr.integers(-4, 5), rr.integers(-3, 4)
        x = cx + (u * ca - v * sa) * rad / 4.5 + rr.normal(0, 1.0)
        y = cy + (u * sa + v * ca) * rad / 4.5 + rr.normal(0, 1.0)
        if water[int(y * SC) % H, int(x * SC) % W]:
            continue
        s = rr.uniform(1.4, 2.8) * SC
        t = rr.uniform(0.5, 0.9)
        X, Y = x * SC, y * SC
        c = int(rr.uniform(66, 100))
        quad = [(-s, -s * t), (s, -s * t), (s, s * t), (-s, s * t)]
        od.polygon([(X + px * ca - py * sa, Y + px * sa + py * ca) for px, py in quad],
                   fill=(c, int(c * 0.9), int(c * 0.78), 220), outline=(40, 34, 26, 200))


for i, (nid, n) in enumerate(N.items()):
    if water[int(n["pos"][1] * SC), int(n["pos"][0] * SC)]:
        continue
    big = nid in ("mirny", "vilyuysk", "yakutsk", "nyurba", "gorny", "sungar")
    ruins(n["pos"][0], n["pos"][1], 40 if big else 22, 34 if big else 12, 100 + i)
for i, (x, y) in enumerate([(1350, 1250), (2250, 1000), (900, 520), (2700, 450), (1700, 1200), (2900, 1550)]):
    if not near_any(x, y, 60) and river_dist(x, y)[0] > 30:
        ruins(x, y, 18, 9, 300 + i)

# тракт: колея по суше (воду не пересекает — там мосты и паромы)
for p in W_JSON.get("paths", []):
    if p.get("type") == "road":
        pts = [P(q) for q in chaikin(p["pts"])]
        od.line(pts, fill=(132, 114, 82, 170), width=5 * SC, joint="curve")
        od.line(pts, fill=(96, 80, 58, 220), width=2 * SC, joint="curve")
# на воде колею не видно
wa = np.asarray(ov, np.uint8).copy()
wa[..., 3] = (wa[..., 3] * (1 - wsoft)).astype(np.uint8)
ov = Image.fromarray(wa)
del wa
od = ImageDraw.Draw(ov)


def blast(bl):
    cx, cy = bl["pos"]
    r = bl["r"]
    X, Y = cx * SC, cy * SC
    if bl["type"] == "strike":
        cr = r * 0.28 * SC
        for i in range(14, 0, -1):
            rr = cr * (0.4 + 0.06 * i)
            c = int(48 + i * 7)
            od.ellipse([X - rr, Y - rr * 0.94, X + rr, Y + rr * 0.94], fill=(c, int(c * 0.86), int(c * 0.7), 255))
        od.ellipse([X - cr * 1.25, Y - cr * 1.2, X + cr * 1.25, Y + cr * 1.2], outline=(168, 150, 116, 220), width=3 * SC)
        od.ellipse([X - cr * 0.45, Y - cr * 0.42, X + cr * 0.45, Y + cr * 0.42], fill=(34, 30, 26, 255))
    else:
        for i in range(9, 0, -1):
            rr = r * 0.45 * SC * i / 9.0
            c = int(58 + i * 9)
            od.ellipse([X - rr * 1.1, Y - rr * 0.8, X + rr * 1.1, Y + rr * 0.8], fill=(c, int(c * 0.9), int(c * 0.76), 255))
        for k in range(9):
            a = rng.uniform(0, math.tau)
            p = [(X, Y)]
            for s in range(5):
                a += rng.uniform(-0.5, 0.5)
                p.append((p[-1][0] + math.cos(a) * r * 0.22 * SC, p[-1][1] + math.sin(a) * r * 0.22 * SC))
            od.line(p, fill=(44, 38, 30, 230), width=SC)
    # опасная зона: красный пунктир и знак радиации
    R = r * 1.55 * SC
    for k in range(0, 48, 2):
        od.arc([X - R, Y - R, X + R, Y + R], k * 7.5, k * 7.5 + 5, fill=(200, 60, 36, 255), width=4 * SC)
    tx, ty, tr = X + R * 0.72, Y - R * 0.72, 18 * SC
    od.ellipse([tx - tr * 1.25, ty - tr * 1.25, tx + tr * 1.25, ty + tr * 1.25], fill=(230, 200, 60, 255), outline=(30, 24, 16, 255), width=SC)
    for k in range(3):
        a0 = -90 + k * 120 - 30
        od.pieslice([tx - tr, ty - tr, tx + tr, ty + tr], a0, a0 + 60, fill=(30, 24, 16, 255))
    od.ellipse([tx - tr * 0.3, ty - tr * 0.3, tx + tr * 0.3, ty + tr * 0.3], fill=(230, 200, 60, 255))
    od.ellipse([tx - tr * 0.18, ty - tr * 0.18, tx + tr * 0.18, ty + tr * 0.18], fill=(30, 24, 16, 255))


for bl in BLASTS:
    blast(bl)

ov = ov.filter(ImageFilter.GaussianBlur(0.5 * SC))  # без «пиксельных» краёв
base = Image.alpha_composite(base.convert("RGBA"), ov)
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(ov)
# переправы поперёк течения: мост и плотина — настил, паром — канат и причалы
for c in W_JSON.get("crossings", []):
    _, tp, fl = river_dist(*c["pos"])
    rw = next((rv["width"] for rv in RIVERS if river_dist(*c["pos"])[0] < 1e8), 30)
    x, y = P(c["pos"])
    ux, uy = -fl[1], fl[0]  # поперёк реки
    half = (river_dist(*c["pos"])[0] * -1 + 14) * SC if river_dist(*c["pos"])[0] < 0 else 26 * SC
    half = max(half, 22 * SC)
    a = (x - ux * half, y - uy * half)
    b = (x + ux * half, y + uy * half)
    if c["type"] in ("bridge", "dam"):
        wdt = (14 if c["type"] == "dam" else 8) * SC
        od.line([a, b], fill=(30, 26, 22, 255), width=wdt + 3 * SC)
        od.line([a, b], fill=(150, 140, 120, 255), width=wdt)
        for t in np.linspace(0.15, 0.85, 6):
            px, py = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            od.line([(px - fl[0] * wdt * 0.5, py - fl[1] * wdt * 0.5), (px + fl[0] * wdt * 0.5, py + fl[1] * wdt * 0.5)],
                    fill=(90, 82, 70, 255), width=SC)
    else:
        n = 14
        for k in range(n):
            if k % 2 == 0:
                p0 = (a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
                p1 = (a[0] + (b[0] - a[0]) * (k + 1) / n, a[1] + (b[1] - a[1]) * (k + 1) / n)
                od.line([p0, p1], fill=(220, 210, 180, 230), width=2 * SC)
        for q in (a, b):
            s = 4 * SC
            od.rectangle([q[0] - s, q[1] - s, q[0] + s, q[1] + s], fill=(110, 90, 60, 255), outline=(30, 24, 16, 255))
        if c["type"] == "ferry":
            mx, my = x + ux * half * 0.3, y + uy * half * 0.3
            s = 6 * SC
            od.polygon([(mx - fl[0] * s - ux * s * 0.6, my - fl[1] * s - uy * s * 0.6), (mx + fl[0] * s - ux * s * 0.6, my + fl[1] * s - uy * s * 0.6),
                        (mx + fl[0] * s + ux * s * 0.6, my + fl[1] * s + uy * s * 0.6), (mx - fl[0] * s + ux * s * 0.6, my - fl[1] * s + uy * s * 0.6)],
                       fill=(120, 100, 70, 255), outline=(30, 24, 16, 255))

ov = ov.filter(ImageFilter.GaussianBlur(0.4 * SC))
cross_a = np.asarray(ov, np.float32)[..., 3] / 255.0  # где настил — уже не вода
base = Image.alpha_composite(base, ov).convert("RGB")
del ov

# ================= карта местности для встреч =================
bio = np.zeros((H0 // 4, W0 // 4, 3), np.uint8)
sm = lambda a: np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).resize((W0 // 4, H0 // 4), Image.BILINEAR)) / 255.0
fs, ff, fw = sm(forest_d), sm(field), sm(swamp)
bio[..., 1] = 255
bio[(fw > 0.35)] = (0, 0, 255)
bio[(fw <= 0.35) & ((ff > 0.4) | (fs < 0.25))] = (255, 0, 0)
Image.fromarray(bio).save(os.path.join(ROOT, "assets", "textures", "world_biome.png"))
del forest_d, field, swamp, dead, burn, streak, tree, riparian, sand, mud

# ================= сетка, виньетка, рамка =================
arr = np.asarray(base, np.float32)
del base
gridm = ((XX % (200 * SC) < SC) | (YY % (200 * SC) < SC)).astype(np.float32)
arr *= (1 - 0.12 * gridm)[..., None]
vig = np.clip(1.0 - (((XX - W / 2) / (W / 2)) ** 2 + ((YY - H / 2) / (H / 2)) ** 2) * 0.22, 0.6, 1)
arr *= vig[..., None]
edge = np.minimum(np.minimum(XX, W - 1 - XX), np.minimum(YY, H - 1 - YY)).astype(np.float32) / SC
torn = edge + (fbm(14, 2, 11) - 0.5) * 18
frame = np.clip((26 - torn) / 10, 0, 1)
paper = np.array([96, 70, 40], np.float32) * (0.8 + 0.4 * fbm(10, 2, 12))[..., None]
arr = arr * (1 - frame[..., None]) + paper * frame[..., None]
arr *= (0.55 + 0.45 * np.clip((torn - 26) / 14, 0, 1))[..., None]
del paper, frame, torn, edge

# ================= фильтр «экран КПК» =================
a = np.clip(arr, 0, 255) / 255.0
del arr
lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
lo, hi = np.percentile(lum[::8, ::8], [0.5, 99.8])
lum = np.clip((lum - lo) / (hi - lo), 0, 1) * 0.82 + 0.1


def gmap(t, stops):
    xs = [s[0] for s in stops]
    return np.stack([np.interp(t, xs, [s[1][k] for s in stops]) for k in range(3)], -1).astype(np.float32)


amb = gmap(lum, [(0.0, (0.07, 0.03, 0.01)), (0.25, (0.30, 0.14, 0.04)), (0.5, (0.66, 0.38, 0.12)),
                 (0.75, (0.93, 0.66, 0.28)), (1.0, (1.0, 0.92, 0.68))])
wat = gmap(lum, [(0.0, (0.01, 0.06, 0.08)), (0.3, (0.05, 0.22, 0.26)), (0.6, (0.16, 0.45, 0.48)), (1.0, (0.62, 0.88, 0.82))])
red = ((a[..., 0] - a[..., 1]) > 0.25)[..., None]  # красные пометки взрывов остаются красными
amb = np.where(red, a * 0.6 + amb * 0.4, amb)
wm = (np.asarray(Image.fromarray((water * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0 * SC)), np.float32) / 255.0 * (1 - cross_a))[..., None]
out = Image.fromarray(np.clip((amb * (1 - wm) + wat * wm) * 255.0, 0, 255).astype(np.uint8))
out = out.filter(ImageFilter.UnsharpMask(radius=1.5, percent=50, threshold=2))
out.save(os.path.join(ROOT, "assets", "textures", "world_map.jpg"), quality=90)
print("карта:", W, "x", H)
