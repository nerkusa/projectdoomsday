class_name HexGrid
extends RefCounted
## Гексагональная сетка поверх локации (как в прототипе: гекс 0.72 м, «острый верх»).
## Проходимость считается сама: гекс занят, если в нём стоит любой объект
## со слоем столкновений «obstacles» (слой 1). Поставил избу в редакторе — сетка это увидит.

const HEX := 0.72
const SQ3 := 1.7320508
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

var free: Dictionary = {}
var bounds := Rect2(0, 0, 64, 64)
var _astar := AStar2D.new()
var _ids: Dictionary = {}
## Разрезанные связи между соседними свободными гексами: между их центрами тонкая
## стена, которую не задел пробник в центре гекса. Ключ — пара гексов.
var _cut: Dictionary = {}


func to_world(h: Vector2i) -> Vector3:
	return Vector3(HEX * SQ3 * (h.x + h.y / 2.0), 0.0, HEX * 1.5 * h.y)


func from_world(p: Vector3) -> Vector2i:
	var px := p.x / HEX
	var pz := p.z / HEX
	var q := SQ3 / 3.0 * px - pz / 3.0
	var r := 2.0 / 3.0 * pz
	var s := -q - r
	var rq := roundi(q)
	var rr := roundi(r)
	var rs := roundi(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(rq, rr)


func is_free(h: Vector2i) -> bool:
	return free.get(h, false)


func distance(a: Vector2i, b: Vector2i) -> int:
	return (absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2


func neighbors(h: Vector2i) -> Array:
	var out := []
	for d in DIRS:
		var n: Vector2i = h + d
		if is_free(n) and not _cut.has(_edge(h, n)):
			out.append(n)
	return out


## Строим карту проходимости по физике (вызывать после первого physics-кадра)
func build(space: PhysicsDirectSpaceState3D, rect: Rect2, mask := 1) -> void:
	bounds = rect
	free.clear()
	_cut.clear()
	_ids.clear()
	_astar.clear()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.2, 0.6)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = mask
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var r0 := from_world(Vector3(rect.position.x, 0, rect.position.y)).y - 1
	var r1 := from_world(Vector3(rect.end.x, 0, rect.end.y)).y + 1
	for r in range(r0, r1 + 1):
		var q0 := int(floor(rect.position.x / (HEX * SQ3) - r / 2.0)) - 1
		var q1 := int(ceil(rect.end.x / (HEX * SQ3) - r / 2.0)) + 1
		for qq in range(q0, q1 + 1):
			var h := Vector2i(qq, r)
			var w := to_world(h)
			if not rect.has_point(Vector2(w.x, w.z)):
				continue
			q.transform = Transform3D(Basis.IDENTITY, w + Vector3(0, 0.65, 0))
			var hit := space.intersect_shape(q, 1)
			free[h] = hit.is_empty()
	var i := 0
	for h in free:
		if free[h]:
			var w2 := to_world(h)
			_astar.add_point(i, Vector2(w2.x, w2.z))
			_ids[h] = i
			i += 1
	for h in _ids:
		for d in DIRS:
			var n: Vector2i = h + d
			if not _ids.has(n) or _astar.are_points_connected(_ids[h], _ids[n]) or _cut.has(_edge(h, n)):
				continue
			if _wall_between(space, to_world(h), to_world(n), mask):
				_cut[_edge(h, n)] = true
			else:
				_astar.connect_points(_ids[h], _ids[n])


func _edge(a: Vector2i, b: Vector2i) -> Vector4i:
	return Vector4i(a.x, a.y, b.x, b.y) if a < b else Vector4i(b.x, b.y, a.x, a.y)


## Стена между центрами соседних гексов: лучи на уровне колен и груди
func _wall_between(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, mask: int) -> bool:
	for y in [0.45, 1.0]:
		var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, y, 0), b + Vector3(0, y, 0), mask)
		q.hit_from_inside = true
		if not space.intersect_ray(q).is_empty():
			return true
	return false


## Путь для свободной ходьбы (вне боя). blocked — занятые гексы.
func explore_path(from: Vector2i, to: Vector2i, blocked := {}) -> Array:
	if not _ids.has(from) or not _ids.has(to):
		return []
	for h in blocked:
		if _ids.has(h) and h != from and h != to:
			_astar.set_point_disabled(_ids[h], true)
	var ids := _astar.get_id_path(_ids[from], _ids[to])
	for h in blocked:
		if _ids.has(h):
			_astar.set_point_disabled(_ids[h], false)
	var out := []
	for id in ids:
		var p := _astar.get_point_position(id)
		out.append(from_world(Vector3(p.x, 0, p.y)))
	if not out.is_empty():
		out.remove_at(0)
	return out


## Поиск в ширину (бой): dist — сколько шагов до гекса, par — откуда пришли
func bfs(from: Vector2i, blocked := {}, max_d := -1, max_n := 9000) -> Dictionary:
	var dist := {from: 0}
	var par := {}
	var queue := [from]
	var qi := 0
	while qi < queue.size() and dist.size() < max_n:
		var c: Vector2i = queue[qi]
		qi += 1
		var dc: int = dist[c]
		if max_d >= 0 and dc >= max_d:
			continue
		for n in neighbors(c):
			if blocked.has(n) or dist.has(n):
				continue
			dist[n] = dc + 1
			par[n] = c
			queue.append(n)
	return {"dist": dist, "par": par}


func path_to(b: Dictionary, to: Vector2i) -> Array:
	var p := []
	var c = to
	while c != null and b.par.has(c):
		p.push_front(c)
		c = b.par[c]
	return p


func nearest_free(p: Vector3, avoid := {}) -> Vector2i:
	var c := from_world(p)
	if is_free(c) and not avoid.has(c):
		return c
	var best = null
	var bd := 1e9
	for rad in range(1, 7):
		for dq in range(-rad, rad + 1):
			for dr in range(maxi(-rad, -dq - rad), mini(rad, -dq + rad) + 1):
				var h := Vector2i(c.x + dq, c.y + dr)
				if not is_free(h) or avoid.has(h):
					continue
				var w := to_world(h)
				var d := (w.x - p.x) ** 2 + (w.z - p.z) ** 2
				if d < bd:
					bd = d
					best = h
		if best != null:
			return best
	return c


## Видимость между точками (для прицеливания и «заметили ли тебя»)
func line_clear(a: Vector3, b: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 1.5, 0), b + Vector3(0, 1.5, 0), 1)
	return space.intersect_ray(q).is_empty()
