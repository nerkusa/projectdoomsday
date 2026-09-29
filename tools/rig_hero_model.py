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
import json
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
HAND_LEN = 0.233  # запястье → кончики пальцев у манекена
OUT_RIG = os.path.join(ROOT, "assets/models/hero_model_rig.json")
GLOVE_LUM = 68.0
# поза листа персонажа (подобрана tools/bake_hero_skin.py по силуэту)
SHEET_THETA = np.radians(59)
SHEET_PHI = np.radians(8)


def short_arms(G, names, chain, k):
	"""Скелет с укороченными руками: локальные смещения предплечья и кисти умножаются на k.
	То же делает в игре scripts/world/arm_length.gd."""
	G = G.copy()
	for side in ("L", "R"):
		sh = G[names.index("DEF-upper_arm." + side)][:3, 3].copy()
		el = G[names.index("DEF-forearm." + side)][:3, 3].copy()
		wr = G[names.index("DEF-hand." + side)][:3, 3].copy()
		d_el = (el - sh) * (k - 1)
		d_wr = d_el + (wr - el) * (k - 1)
		for c in chain("DEF-forearm." + side):
			G[c][:3, 3] += d_el
		for c in chain("DEF-hand." + side):
			G[c][:3, 3] += d_wr - d_el
	return G


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
	# руки модели короче рук скелета — вытягиваем их вдоль оси руки (плавно от плеча),
	# иначе запястье модели не совпадёт с запястьем скелета и кисть «оторвётся»
	tree_model = cKDTree(P)
	# картинка спереди (в позе модели) — для цвета и для поиска перчаток
	fimg = np.asarray(Image.open(front_path).convert("RGB"))
	fmask = B.ref_masks(fimg)
	ys_, xs_ = np.nonzero(fmask)
	ftop, fbot = ys_.min(), ys_.max()
	fs = (fbot - ftop) / top
	rows = fmask[int(fbot - 0.15 * (fbot - ftop))]
	fcx = np.nonzero(rows)[0].mean()

	def xy_front(Q):
		return fcx + Q[:, 0] * fs, fbot - Q[:, 1] * fs, Q[:, 2]

	vx, vy, _ = xy_front(P)
	fi = np.clip(vx.astype(int), 0, fimg.shape[1] - 1)
	fj = np.clip(vy.astype(int), 0, fimg.shape[0] - 1)
	lum = fimg[fj, fi].astype(np.float64) @ np.array([0.3, 0.59, 0.11])
	# перенос весов по частям тела: сначала каждая точка модели относится к руке, ноге или
	# туловищу (по расстоянию до костей с учётом толщины части), потом берёт веса только
	# у точек манекена той же части — иначе низ куртки у кисти получал бы веса руки
	S_fit = skin_matrices(G, ib, names, chain, theta, phi)
	jp = np.array([(S_fit[k] @ np.r_[G[k][:3, 3], 1])[:3] for k in range(len(names))])
	def J_(n):
		return jp[names.index(n)]
	groups = {
		"armL": ([("DEF-upper_arm.L", "DEF-forearm.L"), ("DEF-forearm.L", "DEF-hand.L"), ("DEF-hand.L", "DEF-f_middle.03.L")], set(chain("DEF-upper_arm.L"))),
		"armR": ([("DEF-upper_arm.R", "DEF-forearm.R"), ("DEF-forearm.R", "DEF-hand.R"), ("DEF-hand.R", "DEF-f_middle.03.R")], set(chain("DEF-upper_arm.R"))),
		"legL": ([("DEF-thigh.L", "DEF-shin.L"), ("DEF-shin.L", "DEF-foot.L"), ("DEF-foot.L", "DEF-toe.L")], set(chain("DEF-thigh.L"))),
		"legR": ([("DEF-thigh.R", "DEF-shin.R"), ("DEF-shin.R", "DEF-foot.R"), ("DEF-foot.R", "DEF-toe.R")], set(chain("DEF-thigh.R"))),
	}
	torso_segs = [("DEF-hips", "DEF-spine.001"), ("DEF-spine.001", "DEF-spine.002"), ("DEF-spine.002", "DEF-spine.003"),
		("DEF-spine.003", "DEF-neck"), ("DEF-neck", "DEF-head"), ("DEF-shoulder.L", "DEF-upper_arm.L"), ("DEF-shoulder.R", "DEF-upper_arm.R")]
	limb_bones = set().union(*[g[1] for g in groups.values()])
	groups["torso"] = (torso_segs, set(range(len(names))) - limb_bones)

	def seg_dist(X, segs):
		best = np.full(len(X), np.inf)
		for a, b_ in segs:
			A, Bp = J_(a), J_(b_)
			if a == "DEF-neck" and b_ == "DEF-head":
				Bp = J_("DEF-head") + np.array([0, 0.22, 0])
			ab = Bp - A
			t = np.clip(((X - A) @ ab) / max(ab @ ab, 1e-9), 0, 1)
			best = np.minimum(best, np.linalg.norm(X - (A + np.outer(t, ab)), axis=1))
		return best

	mdom_j = mesh["J"][np.arange(len(mesh["J"])), np.argmax(mesh["W"], axis=1)]
	gnames = list(groups.keys())
	m_group = np.zeros(len(Pm), int)
	for gi, g in enumerate(gnames):
		m_group[np.isin(mdom_j, list(groups[g][1]))] = gi
	radius = {}
	for gi, g in enumerate(gnames):
		radius[g] = np.percentile(seg_dist(Pm[m_group == gi], groups[g][0]), 90)
	score = np.stack([seg_dist(P, groups[g][0]) / radius[g] for g in gnames], 1)
	p_group = np.argmin(score, 1)
	print("части тела:", {g: int((p_group == gi).sum()) for gi, g in enumerate(gnames)})
	# длина руки модели (плечо → кончики пальцев) против скелета: скелет героя укорачиваем
	# (предплечье и кисть сдвигаются к плечу), модель не тянем. Кисть манекена той же длины.
	tip_m = G[names.index("DEF-hand.L")][0, 3] - G[names.index("DEF-upper_arm.L")][0, 3] + HAND_LEN
	ks = []
	for side in ("L", "R"):
		sh = jp[names.index("DEF-upper_arm." + side)]
		hd = jp[names.index("DEF-hand." + side)]
		d = (hd - sh) / np.linalg.norm(hd - sh)
		tip = ((P[p_group == gnames.index("arm" + side)] - sh) @ d).max()
		ks.append((tip - HAND_LEN) / (tip_m - HAND_LEN))
	arm_k = float(np.clip(np.mean(ks), 0.6, 1.1))
	print("рука модели к руке скелета: %.3f (L %.3f, R %.3f)" % (arm_k, ks[0], ks[1]))
	G_std = G
	G = short_arms(G, names, chain, arm_k)
	Pm, _ = B.pose(mesh, G, ib, names, chain, theta, phi)
	json.dump({"arm_k": arm_k}, open(OUT_RIG, "w"))
	nj = len(names)
	Wfull = np.zeros((len(P), nj))
	for gi, g in enumerate(gnames):
		pm_idx = np.nonzero(m_group == gi)[0]
		pv = np.nonzero(p_group == gi)[0]
		if len(pv) == 0:
			continue
		tr = cKDTree(Pm[pm_idx])
		d, idx = tr.query(P[pv], k=6)
		wv = 1.0 / (d + 1e-4)
		for k in range(6):
			src = pm_idx[idx[:, k]]
			for c in range(4):
				np.add.at(Wfull, (pv, mesh["J"][src, c]), wv[:, k] * mesh["W"][src, c])
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
	# цвет рукавов берём с картинки по исходной (не растянутой) модели
	P_pose0 = P.copy()
	P_rest0 = P_rest.copy()
	# кисти — как у манекена (и у всех остальных): сгенерированные пальцы модели плохо гнутся
	# и оружие в них сидит криво. Кисти модели убираем, ставим кисти манекена чуть крупнее
	# (перчатка толще руки манекена), с его весами.
	hand_bones = np.array([("hand" in n or "f_" in n or "thumb" in n) for n in names])
	# у модели кисть — всё, что дальше запястья вдоль руки (в позе покоя руки вдоль ±X)
	# сравниваем в Т-позе укороченного скелета: запястья там, где кисти манекена
	S_T = skin_matrices(G, ib, names, chain, 0.0, 0.0)
	P_T, _ = apply_skin(S_T, J, W, P_rest)
	wl = G[names.index("DEF-hand.L")][:3, 3]
	wr = G[names.index("DEF-hand.R")][:3, 3]
	# рукав оставляем чуть длиннее запястья — он прикрывает тонкое запястье манекена
	is_hand = (P_T[:, 0] > wl[0] + 0.035) | (P_T[:, 0] < wr[0] - 0.035)
	keep = ~(is_hand[I].any(1))
	# цвет перчатки — с картинки, по вырезанным тёмным точкам кистей модели
	gl = np.nonzero(is_hand & (lum < GLOVE_LUM))[0]
	gx, gy, _ = xy_front(P_pose0[gl])
	glove_col = np.median(fimg[np.clip(gy.astype(int), 0, fimg.shape[0] - 1), np.clip(gx.astype(int), 0, fimg.shape[1] - 1)].astype(np.float64), axis=0) if len(gl) else np.array([55.0, 48, 42])
	print("цвет перчатки:", glove_col.round())
	I = I[keep]
	mdom = np.argmax(mesh["W"], axis=1)
	mJd = mesh["J"][np.arange(len(mdom)), mdom]
	mhand = hand_bones[mJd]
	mfaces = mesh["I"][mhand[mesh["I"]].all(1)]
	used = np.unique(mfaces)
	remap = -np.ones(len(mesh["P"]), np.int64)
	remap[used] = np.arange(len(used)) + len(P_rest)
	hp = mesh["P"][used].copy()
	for side in ("L", "R"):
		wrist = G_std[names.index("DEF-hand." + side)][:3, 3]
		sel = (mesh["J"][used] == names.index("DEF-hand." + side)).any(1) | np.array(
			[names[j].endswith("." + side) for j in mJd[used]])
		hp[sel] = wrist + (hp[sel] - wrist) * 1.1
	n_model = len(P_rest)
	P_rest = np.vstack([P_rest, hp])
	P_pose0 = np.vstack([P_pose0, np.zeros_like(hp)])
	P_rest0 = np.vstack([P_rest0, hp])
	hand_v = np.r_[np.zeros(n_model, bool), np.ones(len(hp), bool)]
	J = np.vstack([J, mesh["J"][used]])
	W = np.vstack([W, mesh["W"][used]])
	I = np.vstack([I, remap[mfaces]])
	# убрать вершины, на которые больше не ссылается ни одна грань
	alive = np.unique(I)
	nid = -np.ones(len(P_rest), np.int64)
	nid[alive] = np.arange(len(alive))
	P_rest, J, W, I = P_rest[alive], J[alive], W[alive], nid[I]
	P_pose0, P_rest0, hand_v = P_pose0[alive], P_rest0[alive], hand_v[alive]
	P, _ = apply_skin(S_model, J, W, P_rest)
	# для проекций: рукава — как на картинке (без растяжения), кисти — на своём месте
	P_proj = np.where(hand_v[:, None], P, P_pose0)
	print("кисти заменены: -%d граней модели, +%d граней кистей манекена" % ((~keep).sum(), len(mfaces)))
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
	P_sheet, _ = apply_skin(S_sheet, J, W, P_rest0)
	N_model = normals(P_proj, I)
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

	col, w = project(fimg, fmask, P_proj, N_model, xy_front, np.array([0, 0, 1.0]), lambda n: 1.0, 1.0)
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
	on_hand = hand_v[F].any(1)
	acc[on_hand] = glove_col * (0.9 + 0.2 * np.random.default_rng(1).random((on_hand.sum(), 1)))
	wsum[on_hand] = 1.0
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
