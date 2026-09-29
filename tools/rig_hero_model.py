"""Герой из готовой 3D-модели (без скелета и текстур) + картинок-референсов.

  1. Модель масштабируется под рост манекена UAL и упрощается (~16 тыс. треугольников).
  2. Манекен ставится в позу модели (углы рук и ног подбираются по близости поверхностей),
     веса костей переносятся с манекена на модель по ближайшим точкам, модель «снимается»
     в исходную позу скелета — после этого её двигают все анимации UAL.
  3. Новая развёртка (xatlas) и запекание цвета проекцией:
     спереди — картинка в позе модели (front_ref), сзади и сбоку — лист персонажа
     (tools/ref/hero_ref.webp, A-поза: модель переставляется в неё по скелету).
  4. Пишет assets/models/hero_model.png и hero_model_mesh.bin
     (собрать: godot --headless --path . -s res://tools/build_hero_skin.gd -- hero_model)

Запуск: python3 tools/rig_hero_model.py tools/ref/hero_model.glb tools/ref/hero_front.webp
"""
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree
import fast_simplification
import xatlas

sys.path.insert(0, os.path.dirname(__file__))
import bake_hero_skin as B  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
SHEET = os.path.join(ROOT, "tools/ref/hero_ref.webp")
OUT_TEX = os.path.join(ROOT, "assets/models/hero_model.png")
OUT_MESH = os.path.join(ROOT, "assets/models/hero_model_mesh.bin")
TEX = 2048
TRIS = 16000
# поза листа персонажа (подобрана tools/bake_hero_skin.py по силуэту)
SHEET_THETA = np.radians(59)
SHEET_PHI = np.radians(8)


def load_model(path):
	m = B.GLB(path)
	pr = m.g["meshes"][0]["primitives"][0]
	P = m.acc(pr["attributes"]["POSITION"]).astype(np.float64)
	I = m.acc(pr["indices"]).reshape(-1, 3).astype(np.int64)
	return P, I


def skin_matrices(G, ib, names, chain, theta, phi):
	Gp = G.copy()
	for bone, ang in (("DEF-upper_arm.L", -theta), ("DEF-upper_arm.R", theta), ("DEF-thigh.L", phi), ("DEF-thigh.R", -phi)):
		k = names.index(bone)
		piv = G[k][:3, 3]
		t = np.eye(4)
		t[:3, 3] = piv
		ti = np.eye(4)
		ti[:3, 3] = -piv
		R = t @ B.rotz(ang) @ ti
		for c in chain(bone):
			Gp[c] = R @ G[c]
	return Gp @ ib


def apply_skin(S, J, W, P, inverse=False):
	"""Скиннинг точек P весами J/W матрицами S; inverse — обратно в позу покоя."""
	M = np.zeros((len(P), 4, 4))
	for k in range(4):
		M += W[:, k, None, None] * S[J[:, k]]
	if inverse:
		M = np.linalg.inv(M)
	Ph = np.c_[P, np.ones(len(P))]
	return np.einsum("nij,nj->ni", M, Ph)[:, :3], M[:, :3, :3]


def main():
	model_path, front_path = sys.argv[1], sys.argv[2]
	mesh, G, ib, names, chain = B.load_mannequin()
	top = B.pose(mesh, G, ib, names, chain, 0.0)[0][:, 1].max()
	P, I = load_model(model_path)
	# рост как у манекена, ноги на земле, по центру
	P = (P - [0, P[:, 1].min(), 0]) * (top / (P[:, 1].max() - P[:, 1].min()))
	hips = (P[:, 1] > 0.85) & (P[:, 1] < 1.05)
	P[:, 0] -= (P[hips, 0].min() + P[hips, 0].max()) / 2.0
	P[:, 2] -= (P[hips, 2].min() + P[hips, 2].max()) / 2.0
	Pm0 = B.pose(mesh, G, ib, names, chain, 0.0)[0]
	hm = (Pm0[:, 1] > 0.85) & (Pm0[:, 1] < 1.05)
	P[:, 2] += (Pm0[hm, 2].min() + Pm0[hm, 2].max()) / 2.0
	# упрощение
	red = 1.0 - TRIS / len(I)
	P, I = fast_simplification.simplify(P.astype(np.float32), I.astype(np.int32), target_reduction=red)
	P = P.astype(np.float64)
	I = I.astype(np.int64)
	print("модель: %d вершин, %d треугольников" % (len(P), len(I)))
	tree_model = cKDTree(P)
	# поза манекена под модель
	best = None
	for td in range(10, 70, 3):
		for pd in range(0, 14, 2):
			Pm, _ = B.pose(mesh, G, ib, names, chain, np.radians(td), np.radians(pd))
			d, _ = tree_model.query(Pm[::3])
			e = float(np.mean(d))
			if best is None or e < best[0]:
				best = (e, td, pd)
	print("поза модели: руки %d°, ноги %d° (ср. расстояние %.3f м)" % (best[1], best[2], best[0]))
	theta, phi = np.radians(best[1]), np.radians(best[2])
	Pm, _ = B.pose(mesh, G, ib, names, chain, theta, phi)
	# перенос весов: 6 ближайших точек манекена, обратно пропорционально расстоянию
	tree_m = cKDTree(Pm)
	d, idx = tree_m.query(P, k=6)
	wv = 1.0 / (d + 1e-4)
	nj = len(names)
	Wfull = np.zeros((len(P), nj))
	for k in range(6):
		src = idx[:, k]
		for c in range(4):
			np.add.at(Wfull, (np.arange(len(P)), mesh["J"][src, c]), wv[:, k] * mesh["W"][src, c])
	# сглаживание весов по соседям сетки — без рывков на сгибах
	nb = [[] for _ in range(len(P))]
	for a, b_, c in I:
		nb[a] += [b_, c]
		nb[b_] += [a, c]
		nb[c] += [a, b_]
	for _ in range(3):
		Wn = Wfull.copy()
		for v in range(len(P)):
			if nb[v]:
				Wn[v] = 0.5 * Wfull[v] + 0.5 * Wfull[nb[v]].mean(0)
		Wfull = Wn
	J = np.argsort(-Wfull, axis=1)[:, :4]
	W = np.take_along_axis(Wfull, J, 1)
	W /= W.sum(1, keepdims=True)
	# в позу покоя скелета
	S_model = skin_matrices(G, ib, names, chain, theta, phi)
	P_rest, _ = apply_skin(S_model, J, W, P, inverse=True)
	# нормали позы покоя
	def normals(V, F):
		n = np.zeros_like(V)
		fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
		for k in range(3):
			np.add.at(n, F[:, k], fn)
		return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-12)
	N_rest = normals(P_rest, I)
	# развёртка
	atlas = xatlas.Atlas()
	atlas.add_mesh(P_rest.astype(np.float32), I.astype(np.uint32))
	po = xatlas.PackOptions()
	po.resolution = TEX
	po.padding = 6
	atlas.generate(pack_options=po)
	vmap, faces, uvs = atlas[0]
	faces = faces.astype(np.int64)
	print("развёртка: %d вершин" % len(vmap))
	# позы для проекций
	S_sheet = skin_matrices(G, ib, names, chain, SHEET_THETA, SHEET_PHI)
	P_sheet, _ = apply_skin(S_sheet, J, W, P_rest)
	N_model = normals(P, I)
	N_sheet = normals(P_sheet, I)
	# тексели
	U = uvs[:, 0] * TEX
	V = uvs[:, 1] * TEX
	ti, bary, fidx = [], [], []
	for fi, f in enumerate(faces):
		X, Y = U[f], V[f]
		x0, x1 = int(max(0, np.floor(X.min()))), int(min(TEX - 1, np.ceil(X.max())))
		y0, y1 = int(max(0, np.floor(Y.min()))), int(min(TEX - 1, np.ceil(Y.max())))
		yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
		dd = (Y[1] - Y[2]) * (X[0] - X[2]) + (X[2] - X[1]) * (Y[0] - Y[2])
		if abs(dd) < 1e-12:
			continue
		l1 = ((Y[1] - Y[2]) * (xx - X[2]) + (X[2] - X[1]) * (yy - Y[2])) / dd
		l2 = ((Y[2] - Y[0]) * (xx - X[2]) + (X[0] - X[2]) * (yy - Y[2])) / dd
		l3 = 1 - l1 - l2
		ins = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
		if not ins.any():
			continue
		ti.append((yy[ins] - 0.5).astype(np.int64) * TEX + (xx[ins] - 0.5).astype(np.int64))
		bary.append(np.stack([l1[ins], l2[ins], l3[ins]], 1))
		fidx.append(np.full(ins.sum(), fi))
	ti = np.concatenate(ti)
	bary = np.concatenate(bary)
	fidx = np.concatenate(fidx)
	F = vmap[faces[fidx]]  # индексы исходных вершин для каждого текселя

	def interp(A):
		return np.einsum("nk,nkj->nj", bary, A[F])

	acc = np.zeros((len(ti), 3))
	wsum = np.zeros(len(ti))

	def project(img, mask, Pv, Nv, xy, dirv, cond, weight):
		H, Wd = img.shape[:2]
		xs, ys, zs = xy(Pv)
		zb = B.raster_depth(xs, ys, zs, I, Wd, H)
		tp = interp(Pv)
		tn = interp(Nv)
		tn /= np.linalg.norm(tn, axis=1, keepdims=True) + 1e-9
		px, py, pz = xy(tp)
		ix = np.clip(px.astype(int), 0, Wd - 1)
		iy = np.clip(py.astype(int), 0, H - 1)
		inside = (px >= 0) & (px < Wd) & (py >= 0) & (py < H)
		vis = inside & mask[iy, ix] & (zb[iy, ix] - pz < 0.03)
		w = (np.clip(tn @ dirv, 0, 1) ** 2 + 0.02) * vis * weight * cond(tn)
		imgf = img.astype(np.float64)
		x0 = np.clip(np.floor(px - 0.5).astype(int), 0, Wd - 2)
		y0 = np.clip(np.floor(py - 0.5).astype(int), 0, H - 2)
		fx = np.clip(px - 0.5 - x0, 0, 1)[:, None]
		fy = np.clip(py - 0.5 - y0, 0, 1)[:, None]
		col = (imgf[y0, x0] * (1 - fx) * (1 - fy) + imgf[y0, x0 + 1] * fx * (1 - fy)
			+ imgf[y0 + 1, x0] * (1 - fx) * fy + imgf[y0 + 1, x0 + 1] * fx * fy)
		return col, w

	# 1) спереди — картинка в позе модели
	fimg = np.asarray(Image.open(front_path).convert("RGB"))
	fmask = B.ref_masks(fimg)
	ys_, xs_ = np.nonzero(fmask)
	ftop, fbot = ys_.min(), ys_.max()
	fs = (fbot - ftop) / top
	rows = fmask[int(fbot - 0.15 * (fbot - ftop))]
	fcx = np.nonzero(rows)[0].mean()

	def xy_front(Q):
		return fcx + Q[:, 0] * fs, fbot - Q[:, 1] * fs, Q[:, 2]

	col, w = project(fimg, fmask, P, N_model, xy_front, np.array([0, 0, 1.0]), lambda n: 1.0, 1.0)
	acc += col * w[:, None]
	wsum += w
	print("вид спереди (картинка): %.0f%% текселей" % (100 * (w > 0).mean()))
	# 2) лист персонажа: сзади, левый бок, правый бок (зеркально), спереди — слабее
	simg = np.asarray(Image.open(SHEET).convert("RGB"))
	smask = B.ref_masks(simg)
	s = {v: (c["bottom"] - c["top"]) / top for v, c in B.VIEWS.items()}
	waist = (np.abs(P_sheet[:, 1] - 1.0) < 0.08) & (np.abs(P_sheet[:, 0]) < 0.25)
	s["zc"] = (P_sheet[waist, 2].min() + P_sheet[waist, 2].max()) / 2.0
	for v, dirv, cond, wt in (
			("back", np.array([0, 0, -1.0]), lambda n: 1.0, 1.0),
			("side", np.array([1.0, 0, 0]), lambda n: (n[:, 0] >= 0), 1.0),
			("front", np.array([0, 0, 1.0]), lambda n: 1.0, 0.25)):
		c = B.VIEWS[v]
		m2 = np.zeros_like(smask)
		m2[:, c["x"][0]:c["x"][1]] = smask[:, c["x"][0]:c["x"][1]]
		col, w = project(simg, m2, P_sheet, N_sheet, lambda Q, v=v: B.view_xy(v, Q, s), dirv, cond, wt)
		acc += col * w[:, None]
		wsum += w
		print("лист, %s: %.0f%% текселей" % (v, 100 * (w > 0).mean()))
	# правый бок: зеркало левого
	mir = np.array([-1.0, 1, 1])
	c = B.VIEWS["side"]
	m2 = np.zeros_like(smask)
	m2[:, c["x"][0]:c["x"][1]] = smask[:, c["x"][0]:c["x"][1]]
	col, w = project(simg, m2, P_sheet * mir, N_sheet * mir, lambda Q: B.view_xy("side", Q, s), np.array([1.0, 0, 0]),
		lambda n: (n[:, 0] >= 0), 1.0)
	acc += col * w[:, None]
	wsum += w
	print("лист, правый бок: %.0f%% текселей" % (100 * (w > 0).mean()))
	tex = np.zeros((TEX * TEX, 3))
	have = np.zeros(TEX * TEX, bool)
	ok = wsum > 0
	tex[ti[ok]] = acc[ok] / wsum[ok, None]
	have[ti[ok]] = True
	print("закрашено %.1f%% текселей развёртки" % (100.0 * ok.mean()))
	_, (iy, ix) = ndimage.distance_transform_edt(~have.reshape(TEX, TEX), return_indices=True)
	tex = tex.reshape(TEX, TEX, 3)[iy, ix]
	tex = (tex - 60.0) * 1.2 + 70.0
	Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8)).save(OUT_TEX)
	with open(OUT_MESH, "wb") as fo:
		fo.write(struct.pack("<II", len(vmap), len(faces)))
		fo.write(P_rest[vmap].astype("<f4").tobytes())
		fo.write(N_rest[vmap].astype("<f4").tobytes())
		fo.write(uvs.astype("<f4").tobytes())
		fo.write(J[vmap].astype("<i4").tobytes())
		fo.write(W[vmap].astype("<f4").tobytes())
		fo.write(faces.astype("<i4").tobytes())
	print("готово:", OUT_TEX, OUT_MESH)


if __name__ == "__main__":
	main()
