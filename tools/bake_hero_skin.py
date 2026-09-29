"""Запекание текстуры героя с референса (вид спереди / сзади / сбоку) на манекен UAL.

Что делает:
  1. Читает манекен (assets/models/AnimationLibrary_Godot_Standard.glb), ставит его
     в A-позу, как на референсе (угол рук подбирается по силуэту).
  2. Делает новую развёртку xatlas (у манекена своей годной развёртки нет).
  3. Для каждого текселя берёт цвет из того вида, куда смотрит поверхность, с проверкой
     заслонения (буфер глубины каждого вида), смешивает виды по нормали.
  4. Пишет assets/models/hero_skin.png и assets/models/hero_skin_mesh.bin
     (вершины, нормали, UV, кости, веса, индексы) — их собирает tools/build_hero_skin.gd.

Запуск: python3 tools/bake_hero_skin.py tools/ref/hero_ref.webp
  потом: godot --headless --path . -s res://tools/build_hero_skin.gd
Нужны numpy, pillow, scipy, xatlas.
"""
import json
import struct
import sys
import os

import numpy as np
from PIL import Image
from scipy import ndimage
import xatlas

ROOT = os.path.join(os.path.dirname(__file__), "..")
MODEL = os.path.join(ROOT, "assets/models/AnimationLibrary_Godot_Standard.glb")
OUT_TEX = os.path.join(ROOT, "assets/models/hero_skin.png")
OUT_MESH = os.path.join(ROOT, "assets/models/hero_skin_mesh.bin")
TEX = 2048

# Разметка референса: фигура, её центр по X (между ботинками / по торсу), макушка и подошва.
# side — персонаж смотрит вправо, видна его ЛЕВАЯ сторона.
VIEWS = {
	"front": {"x": (15, 472), "cx": 230.0, "top": 47, "bottom": 856},
	"back": {"x": (476, 770), "cx": 580.0, "top": 51, "bottom": 854},
	"side": {"x": (776, 990), "cx": 868.0, "top": 50, "bottom": 860},
}

CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


# ---------------- glb ----------------
class GLB:
	def __init__(self, path):
		f = open(path, "rb").read()
		n = struct.unpack("<I", f[12:16])[0]
		self.g = json.loads(f[20:20 + n])
		off = 20 + n
		bl = struct.unpack("<I", f[off:off + 4])[0]
		self.bin = f[off + 8:off + 8 + bl]

	def acc(self, i):
		a = self.g["accessors"][i]
		bv = self.g["bufferViews"][a["bufferView"]]
		dt = CT[a["componentType"]]
		n = NC[a["type"]]
		start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
		stride = bv.get("byteStride", 0)
		isz = np.dtype(dt).itemsize * n
		if stride and stride != isz:
			raw = np.frombuffer(self.bin, np.uint8, stride * a["count"], start).reshape(a["count"], stride)[:, :isz]
			arr = np.frombuffer(raw.tobytes(), dt).reshape(a["count"], n)
		else:
			arr = np.frombuffer(self.bin, dt, a["count"] * n, start).reshape(a["count"], n)
		if a.get("normalized"):
			arr = arr.astype(np.float32) / np.iinfo(dt).max
		return arr.copy()


def quat_mat(q):
	x, y, z, w = q
	return np.array([
		[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
		[2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
		[2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def node_local(n):
	m = np.eye(4)
	if "matrix" in n:
		return np.array(n["matrix"]).reshape(4, 4).T
	r = quat_mat(n.get("rotation", [0, 0, 0, 1]))
	s = np.array(n.get("scale", [1, 1, 1]))
	m[:3, :3] = r * s
	m[:3, 3] = n.get("translation", [0, 0, 0])
	return m


def load_mannequin():
	m = GLB(MODEL)
	g = m.g
	nodes = g["nodes"]
	parent = {}
	for i, n in enumerate(nodes):
		for c in n.get("children", []):
			parent[c] = i
	glob = {}

	def gm(i):
		if i not in glob:
			glob[i] = (gm(parent[i]) if i in parent else np.eye(4)) @ node_local(nodes[i])
		return glob[i]

	skin = g["skins"][0]
	joints = skin["joints"]
	ib = m.acc(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
	G = np.array([gm(j) for j in joints])
	names = [nodes[j]["name"] for j in joints]
	# цепочки рук: сустав и все его потомки
	def chain(root_name):
		ri = joints[names.index(root_name)]
		out = []
		for k, j in enumerate(joints):
			p = j
			while p is not None:
				if p == ri:
					out.append(k)
					break
				p = parent.get(p)
		return out

	P, N, J, W, I = [], [], [], [], []
	base = 0
	for p in g["meshes"][0]["primitives"]:
		a = p["attributes"]
		pos = m.acc(a["POSITION"]).astype(np.float64)
		P.append(pos)
		N.append(m.acc(a["NORMAL"]).astype(np.float64))
		J.append(m.acc(a["JOINTS_0"]).astype(np.int32))
		W.append(m.acc(a["WEIGHTS_0"]).astype(np.float64))
		I.append(m.acc(p["indices"]).reshape(-1, 3).astype(np.int64) + base)
		base += len(pos)
	mesh = {"P": np.vstack(P), "N": np.vstack(N), "J": np.vstack(J), "W": np.vstack(W), "I": np.vstack(I)}
	mesh["W"] /= mesh["W"].sum(1, keepdims=True)
	return mesh, G, ib, names, chain


def rotz(a):
	c, s = np.cos(a), np.sin(a)
	m = np.eye(4)
	m[:2, :2] = [[c, -s], [s, c]]
	return m


def pose(mesh, G, ib, names, chain, theta, phi=0.0):
	"""A-поза: руки опущены на theta (рад) от горизонтали, ноги разведены на phi."""
	Gp = G.copy()
	for bone, ang in (("DEF-upper_arm.L", -theta), ("DEF-upper_arm.R", theta), ("DEF-thigh.L", phi), ("DEF-thigh.R", -phi)):
		k = names.index(bone)
		piv = G[k][:3, 3]
		t = np.eye(4)
		t[:3, 3] = piv
		ti = np.eye(4)
		ti[:3, 3] = -piv
		R = t @ rotz(ang) @ ti
		for c in chain(bone):
			Gp[c] = R @ G[c]
	S = Gp @ ib  # матрицы скиннинга
	P = mesh["P"]
	N = mesh["N"]
	Ph = np.c_[P, np.ones(len(P))]
	out = np.zeros_like(P)
	nout = np.zeros_like(N)
	for k in range(4):
		M = S[mesh["J"][:, k]]
		w = mesh["W"][:, k:k + 1]
		out += w * np.einsum("nij,nj->ni", M, Ph)[:, :3]
		nout += w * np.einsum("nij,nj->ni", M[:, :3, :3], N)
	nout /= np.linalg.norm(nout, axis=1, keepdims=True) + 1e-9
	return out, nout


# ---------------- референс ----------------
def ref_masks(img):
	a = img.astype(np.float64)
	# фон — тёмный градиент: оцениваем его по колонкам у левого края
	bg = np.median(a[:, :8], axis=1, keepdims=True)
	d = np.abs(a - bg).sum(-1)
	m = d > 14
	m = ndimage.binary_closing(m, iterations=3)
	m = ndimage.binary_fill_holes(m)
	m = ndimage.binary_opening(m, iterations=1)
	return m


def view_xy(v, pts, s):
	"""Точки модели (метры) -> пиксели референса и глубина (больше — ближе к зрителю)."""
	c = VIEWS[v]
	x, y, z = pts[:, 0], pts[:, 1], pts[:, 2]
	py = c["bottom"] - y * s[v]
	if v == "front":
		return c["cx"] + x * s[v], py, z
	if v == "back":
		return c["cx"] - x * s[v], py, -z
	# сбоку: персонаж смотрит вправо (+Z модели — вправо), к зрителю — его левый бок (+X)
	return c["cx"] + (z - s["zc"]) * s[v], py, x


def raster_depth(xs, ys, zs, tris, w, h):
	"""Z-буфер вида: для каждого пикселя — глубина ближайшей грани (−inf, если пусто)."""
	zb = np.full((h, w), -np.inf)
	for t in tris:
		X, Y, Z = xs[t], ys[t], zs[t]
		x0, x1 = int(max(0, np.floor(X.min()))), int(min(w - 1, np.ceil(X.max())))
		y0, y1 = int(max(0, np.floor(Y.min()))), int(min(h - 1, np.ceil(Y.max())))
		if x1 < x0 or y1 < y0:
			continue
		yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
		d = (Y[1] - Y[2]) * (X[0] - X[2]) + (X[2] - X[1]) * (Y[0] - Y[2])
		if abs(d) < 1e-9:
			continue
		l1 = ((Y[1] - Y[2]) * (xx - X[2]) + (X[2] - X[1]) * (yy - Y[2])) / d
		l2 = ((Y[2] - Y[0]) * (xx - X[2]) + (X[0] - X[2]) * (yy - Y[2])) / d
		l3 = 1 - l1 - l2
		ins = (l1 >= -1e-6) & (l2 >= -1e-6) & (l3 >= -1e-6)
		if not ins.any():
			continue
		zz = l1 * Z[0] + l2 * Z[1] + l3 * Z[2]
		sub = zb[y0:y1 + 1, x0:x1 + 1]
		upd = ins & (zz > sub)
		sub[upd] = zz[upd]
	return zb


def main():
	ref_path = sys.argv[1]
	img = np.asarray(Image.open(ref_path).convert("RGB"))
	H, Wd = img.shape[:2]
	mask = ref_masks(img)
	mesh, G, ib, names, chain = load_mannequin()
	tris = mesh["I"]
	P0, _ = pose(mesh, G, ib, names, chain, 0.0)
	top = P0[:, 1].max()
	s = {v: (c["bottom"] - c["top"]) / top for v, c in VIEWS.items()}
	waist = (np.abs(P0[:, 1] - 1.0) < 0.08) & (np.abs(P0[:, 0]) < 0.25)
	s["zc"] = (P0[waist, 2].min() + P0[waist, 2].max()) / 2.0
	# угол рук и разворот ног — по совпадению силуэта спереди
	c = VIEWS["front"]
	fm = mask[:, c["x"][0]:c["x"][1]]

	def iou(theta, phi):
		P, _ = pose(mesh, G, ib, names, chain, theta, phi)
		xs, ys, zs = view_xy("front", P, s)
		zb = raster_depth(xs - c["x"][0], ys, zs, tris, fm.shape[1], H)
		sil = zb > -np.inf
		return (sil & fm).sum() / max(1, (sil | fm).sum())

	theta, phi = np.radians(58), 0.0
	best = iou(theta, phi)
	for step in (np.radians(4), np.radians(2), np.radians(1)):
		changed = True
		while changed:
			changed = False
			for dt, dp in ((step, 0), (-step, 0), (0, step), (0, -step)):
				v = iou(theta + dt, phi + dp)
				if v > best + 1e-4:
					best, theta, phi, changed = v, theta + dt, phi + dp, True
	print("руки %.0f°, ноги %.0f°: совпадение силуэта %.3f" % (np.degrees(theta), np.degrees(phi), best))
	P, Nn = pose(mesh, G, ib, names, chain, theta, phi)
	bake(img, mask, mesh, P, Nn, s)


def bake(img, mask, mesh, P, Nn, s):
	H, Wd = img.shape[:2]
	tris = mesh["I"]
	# развёртка по исходной (T-) позе
	atlas = xatlas.Atlas()
	atlas.add_mesh(mesh["P"].astype(np.float32), tris.astype(np.uint32))
	po = xatlas.PackOptions()
	po.resolution = TEX
	po.padding = 6
	atlas.generate(pack_options=po)
	vmap, faces, uvs = atlas[0]
	print("развёртка: %d вершин, %d граней" % (len(vmap), len(faces)))
	Pp = P[vmap]
	Np = Nn[vmap]
	# тексели каждой грани: позиция и нормаль в позе референса
	tex_idx, tex_pos, tex_nrm = [], [], []
	U = uvs[:, 0] * TEX
	V = uvs[:, 1] * TEX
	for f in faces:
		X, Y = U[f], V[f]
		x0, x1 = int(max(0, np.floor(X.min()))), int(min(TEX - 1, np.ceil(X.max())))
		y0, y1 = int(max(0, np.floor(Y.min()))), int(min(TEX - 1, np.ceil(Y.max())))
		yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
		d = (Y[1] - Y[2]) * (X[0] - X[2]) + (X[2] - X[1]) * (Y[0] - Y[2])
		if abs(d) < 1e-12:
			continue
		l1 = ((Y[1] - Y[2]) * (xx - X[2]) + (X[2] - X[1]) * (yy - Y[2])) / d
		l2 = ((Y[2] - Y[0]) * (xx - X[2]) + (X[0] - X[2]) * (yy - Y[2])) / d
		l3 = 1 - l1 - l2
		ins = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
		if not ins.any():
			continue
		L = np.stack([l1[ins], l2[ins], l3[ins]], 1)
		tex_idx.append((yy[ins] - 0.5).astype(np.int64) * TEX + (xx[ins] - 0.5).astype(np.int64))
		tex_pos.append(L @ Pp[f])
		tex_nrm.append(L @ Np[f])
	ti = np.concatenate(tex_idx)
	tp = np.concatenate(tex_pos)
	tn = np.concatenate(tex_nrm)
	tn /= np.linalg.norm(tn, axis=1, keepdims=True) + 1e-9
	print("текселей:", len(ti))
	imgf = img.astype(np.float64)
	acc = np.zeros((len(ti), 3))
	wsum = np.zeros(len(ti))
	for v, dirv in (("front", np.array([0, 0, 1.0])), ("back", np.array([0, 0, -1.0])), ("side", np.array([1.0, 0, 0])), ("side_r", None)):
		vv = "side" if v == "side_r" else v
		pts, nrm = tp, tn
		if v == "side_r":
			# правый бок не виден — берём левый зеркально
			pts = tp * np.array([-1, 1, 1])
			nrm = tn * np.array([-1, 1, 1])
			dirv = np.array([1.0, 0, 0])
		c = VIEWS[vv]
		xs, ys, zs = view_xy(vv, P, s)
		zb = raster_depth(xs, ys, zs, tris, Wd, H)
		px, py, pz = view_xy(vv, pts, s)
		ix = np.clip(px.astype(int), 0, Wd - 1)
		iy = np.clip(py.astype(int), 0, H - 1)
		inside = (px >= c["x"][0]) & (px < c["x"][1]) & (py >= 0) & (py < H)
		vis = inside & mask[iy, ix] & (zb[iy, ix] - pz < 0.035)
		cosv = np.clip(nrm @ dirv, 0, 1)
		w = (cosv ** 2 + 0.02) * vis
		if v == "side_r":
			w *= (tn[:, 0] < 0)
		elif v == "side":
			w *= (tn[:, 0] >= 0)
		# билинейная выборка
		x0 = np.clip(np.floor(px - 0.5).astype(int), 0, Wd - 2)
		y0 = np.clip(np.floor(py - 0.5).astype(int), 0, H - 2)
		fx = np.clip(px - 0.5 - x0, 0, 1)[:, None]
		fy = np.clip(py - 0.5 - y0, 0, 1)[:, None]
		col = (imgf[y0, x0] * (1 - fx) * (1 - fy) + imgf[y0, x0 + 1] * fx * (1 - fy)
			+ imgf[y0 + 1, x0] * (1 - fx) * fy + imgf[y0 + 1, x0 + 1] * fx * fy)
		acc += col * w[:, None]
		wsum += w
		print("вид %s: видно %.0f%% текселей" % (v, 100.0 * (w > 0).mean()))
	tex = np.zeros((TEX * TEX, 3))
	have = np.zeros(TEX * TEX, bool)
	ok = wsum > 0
	tex[ti[ok]] = acc[ok] / wsum[ok, None]
	have[ti[ok]] = True
	print("закрашено %.1f%% текселей развёртки" % (100.0 * ok.mean()))
	# дыры и поля вокруг островов — ближайшим закрашенным
	have2 = have.reshape(TEX, TEX)
	_, (iy, ix) = ndimage.distance_transform_edt(~have2, return_indices=True)
	tex = tex.reshape(TEX, TEX, 3)[iy, ix]
	# референс снят в полумраке — чуть светлее и контрастнее, чтобы одежда читалась с игровой камеры
	tex = (tex - 60.0) * 1.25 + 72.0
	Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8)).save(OUT_TEX)
	# сетка с новой развёрткой (исходная поза, кости и веса как в glb)
	with open(OUT_MESH, "wb") as fo:
		fo.write(struct.pack("<II", len(vmap), len(faces)))
		fo.write(mesh["P"][vmap].astype("<f4").tobytes())
		fo.write(mesh["N"][vmap].astype("<f4").tobytes())
		fo.write(uvs.astype("<f4").tobytes())
		fo.write(mesh["J"][vmap].astype("<i4").tobytes())
		fo.write(mesh["W"][vmap].astype("<f4").tobytes())
		fo.write(faces.astype("<i4").tobytes())
	print("готово:", OUT_TEX, OUT_MESH)


if __name__ == "__main__":
	main()
