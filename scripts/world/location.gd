class_name Location
extends Node3D
## Корневой скрипт любой локации.
## В сцене локации должны быть узлы:
##   Characters — персонажи (Character)
##   Items      — предметы (Interactable)
##   Spawns     — точки появления (Marker3D), главная — "Start"
## Сюжет конкретной локации пишется в наследнике (см. nakharro.gd).

@export var location_id := "location"
@export var title := "Локация"
## Границы карты в метрах (X, Z, ширина, глубина)
@export var map_rect := Rect2(0, 0, 64, 64)
## Центр карты для камеры в начале
@export var camera_start := Vector3(32, 0, 32)

var grid := HexGrid.new()
var main: Node = null


## Вызывается из main.gd после загрузки
func setup(m: Node) -> void:
	main = m
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.build(get_world_3d().direct_space_state, map_rect, 1)
	_scatter_loot()
	_apply_world_state()


func spawn_point(n := "Start") -> Vector3:
	var s := get_node_or_null("Spawns/" + n)
	if s is Node3D:
		return (s as Node3D).global_position
	return camera_start


func characters() -> Array:
	var out := []
	var c := get_node_or_null("Characters")
	if c:
		for x in c.get_children():
			if x is Character:
				out.append(x)
	return out


func character(n: String) -> Character:
	return get_node_or_null("Characters/" + n) as Character


func items() -> Array:
	var out := []
	var c := get_node_or_null("Items")
	if c:
		for x in c.get_children():
			if x is Interactable:
				out.append(x)
	return out


func item(n: String) -> Interactable:
	return get_node_or_null("Items/" + n) as Interactable


func ws() -> Dictionary:
	return Game.wstate(location_id)


func _apply_world_state() -> void:
	var st := ws()
	for it in items():
		if st.picked.has(it.uid()):
			it.set_active(false)
	for ch in characters():
		if st.dead.has(ch.uid()):
			ch.pose = "dead"
			ch.start_dead = true
			ch.set_held("")
		elif st.misc.has("gone_" + ch.uid()):
			ch.visible = false
		elif st.misc.has("calm_" + ch.uid()):
			# с ним договорились миром
			ch.hostile = false
			ch.aggro_radius = 0.0
	if main and main.get("social"):
		main.social.apply_hostile(self)
	on_world_state_applied()


# ---------- вещи, разбросанные по месту ----------
## Сколько и что валяется: переопредели scatter_table() / scatter_count() в наследнике.
## Пусто — ничего не разбрасывать (дома, подвалы, бункер).
func scatter_table() -> Array:
	return []


func scatter_count() -> int:
	return clampi(int(map_rect.get_area() / 420.0), 3, 12)


const ITEM_SCENES := {"canned": "item_canned", "rusks": "item_rusks", "dried_fish": "item_dried_fish", "herbs": "item_herbs",
	"matches": "item_matches", "rope": "item_rope", "flask": "item_flask", "blanket": "item_blanket", "compass": "item_compass",
	"screwdriver": "item_screwdriver", "hairpin": "item_hairpin", "bandage": "bandage"}


## Раскидать вещи по местам, куда можно дойти от входа. Места и вещи одни и те же
## при каждом входе (зерно — от id места), подобранное запоминается как обычно.
func _scatter_loot() -> void:
	var table := scatter_table()
	if table.is_empty() or not has_node("Items"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(location_id + str(Game.hero.flags.get("enc_seed", 0) if location_id == "encounter" else 0))
	var start := grid.from_world(spawn_point("Start"))
	if not grid.is_free(start):
		start = grid.nearest_free(spawn_point("Start"))
	var reach: Dictionary = grid.bfs(start, {}, -1, 80000)
	var cells: Array = reach.get("dist", {}).keys()
	if cells.size() < 20:
		return
	var taken := []
	for it in get_node("Items").get_children():
		if it is Node3D:
			taken.append((it as Node3D).global_position)
	var n := scatter_count()
	var placed := 0
	for t in n * 12:
		if placed >= n:
			break
		var h: Vector2i = cells[rng.randi() % cells.size()]
		var p := grid.to_world(h) + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		if not map_rect.grow(-3.0).has_point(Vector2(p.x, p.z)) or p.distance_to(spawn_point("Start")) < 4.0:
			continue
		var close := false
		for q in taken:
			if (q as Vector3).distance_to(p) < 5.0:
				close = true
				break
		if close:
			continue
		var e: Array = table[rng.randi() % table.size()]
		var id: String = e[0]
		var ps: PackedScene = load("res://scenes/props/%s.tscn" % ITEM_SCENES.get(id, "junk"))
		var it: Interactable = ps.instantiate()
		it.name = "Loot%d" % placed
		it.kind = "item"
		it.item_id = id
		it.count = rng.randi_range(int(e[1]), int(e[2])) if e.size() > 2 else 1
		it.label = DB.item_name(id) if not ITEM_SCENES.has(id) else ""
		it.position = p
		it.rotation.y = rng.randf() * TAU
		get_node("Items").add_child(it)
		taken.append(p)
		placed += 1


# ---------- крючки для сюжета (переопредели в наследнике) ----------
func on_world_state_applied() -> void:
	pass


func on_enter() -> void:
	pass


func on_hero_moved(_pos: Vector3) -> void:
	pass


## Вернуть true, если действие обработано здесь
func on_dialog_action(_action: String, _speaker: Character) -> bool:
	return false


## Вернуть true, если клик по предмету обработан здесь (иначе — обычный подбор)
func on_interact(_it: Interactable) -> bool:
	return false


## Чужая ли вещь: взять её — воровство (подсветка красным, «· чужое» в подсказке)
func is_theft(_it: Interactable) -> bool:
	return false


## На каком расстоянии мирные жители замечают воровство (0 — тут не следят)
func theft_watch_radius() -> float:
	return 0.0


## Можно ли уйти на карту мира кликом у края локации
func can_leave_edge() -> bool:
	return true


## Подсказка, когда у края уйти нельзя («» — молча идём к краю)
func edge_tip() -> String:
	return ""


## Можно ли поднять предмет прямо сейчас
func can_pick(_it: Interactable) -> bool:
	return true


func on_picked(_it: Interactable) -> void:
	pass


func on_looted(_ch: Character) -> void:
	pass


func on_combat_round(_round: int) -> void:
	pass


func on_fighter_down(_f: Fighter) -> void:
	pass


func on_combat_end(_result: String, _kind: String) -> void:
	pass


## Условие для вариантов диалога {"cond": "..."}
func dialog_cond(_id: String) -> bool:
	return true
