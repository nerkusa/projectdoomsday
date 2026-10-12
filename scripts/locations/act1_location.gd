class_name Act1Location
extends Location
## Общее для локаций первого акта: выходы на карту мира, еда для платы и подарков,
## первая мысль при входе, задачи из журнала.

## Мысль при первом входе (ключ узла в thoughts.json)
var arrive_thought := ""
## Сохраняться ли при входе (на случайной поляне — нет: там всё одноразовое)
var autosave_on_enter := true


func _ready() -> void:
	Game.hero_changed.connect(_on_hero_changed)


func _exit_tree() -> void:
	if Game.hero_changed.is_connected(_on_hero_changed):
		Game.hero_changed.disconnect(_on_hero_changed)


func _on_hero_changed() -> void:
	pass


## Что валяется по месту: [id, мин, макс]. Большие открытые места — посёлки, лагерь,
## заимка, руины, встречи в пути; дома и подвалы (маленькие) — без разброса.
func scatter_table() -> Array:
	if map_rect.get_area() < 1500.0:
		return []
	var common := [["rusks", 1, 2], ["dried_fish", 1, 1], ["canned", 1, 1], ["matches", 1, 1], ["bandage", 1, 1],
		["scrap_iron", 1, 2], ["rope", 1, 1], ["firewood", 1, 2], ["candle", 1, 1]]
	if location_id.begins_with("sungar"):
		return common + [["rubles", 2, 6], ["ammo9", 2, 5], ["copper_wire", 1, 2], ["tea", 1, 1], ["beer", 1, 1],
			["t_coin", 1, 1], ["t_button", 1, 1], ["t_postcard", 1, 1], ["salt", 1, 1], ["antirad", 1, 1]]
	if location_id == "encounter":
		return common + [["ammo762", 2, 4], ["ammo9", 2, 4], ["herbs", 1, 2], ["mushroom", 1, 2], ["berries", 1, 2],
			["t_badge", 1, 1], ["t_lighter", 1, 1], ["flask", 1, 1], ["rubles", 1, 4], ["antirad", 1, 1], ["bone_charm", 1, 1]]
	return common + [["herbs", 1, 2], ["mushroom", 1, 2], ["berries", 1, 2], ["ammo762", 1, 3], ["t_beads", 1, 1],
		["t_whistle", 1, 1], ["salt", 1, 1], ["rubles", 1, 3]]


func status_line() -> String:
	return "2062 · конец лета · за чертой"


func on_enter() -> void:
	if not Game.flag("seen_" + location_id):
		Game.set_flag("seen_" + location_id)
		if arrive_thought != "":
			await get_tree().create_timer(0.8, false).timeout
			main.say("thoughts", arrive_thought)
	if autosave_on_enter:
		main.autosave()


## Выходы: всё, что зовётся *Exit, открывает карту мира
func on_interact(it: Interactable) -> bool:
	if String(it.name).ends_with("Exit"):
		main.world_map.open(location_id)
		return true
	return false


func item_actions(it: Interactable) -> Array:
	if String(it.name).ends_with("Exit"):
		return [["Уйти (карта мира)", "use"]]
	return []


## Еда, которую можно отдать: сухари, рыба, консервы, грибы, ягоды…
func food_items() -> Array:
	var out := []
	for k in Game.hero.items:
		var d: Dictionary = DB.items.get(k, {})
		if d.get("travel", "") == "food" or k in ["mushroom", "berries"]:
			for i in int(Game.hero.items[k]):
				out.append(k)
	return out


## Плата и подарки едой — общие для всех локаций акта
func on_dialog_action(a: String, _sp: Character) -> bool:
	match a:
		"pay_food":
			give_food(2)
			return true
		"give_food3":
			give_food(3)
			return true
	return false


func food_count() -> int:
	return food_items().size()


## Отдать n штук еды (сначала самую дешёвую)
func give_food(n: int) -> void:
	var f := food_items()
	f.sort_custom(func(a, b): return DB.item_value(a) < DB.item_value(b))
	for i in mini(n, f.size()):
		Game.remove_item(f[i])
		Game.log_line("Отдано: " + DB.item_name(f[i]))


func dialog_cond(id: String) -> bool:
	match id:
		"has_food2":
			return food_count() >= 2
		"has_food3":
			return food_count() >= 3
		"has_herbs3":
			return Game.item_count("herbs") >= 3
		"has_salt2":
			return Game.item_count("salt") >= 2
	# rub_N — есть ли N рублей
	if id.begins_with("rub_"):
		return Game.item_count("rubles") >= int(id.substr(4))
	return true


## Задача на экране: первая незакрытая из заданий этой локации, потом общие
func objective() -> String:
	return ""


## Все ли враги отряда мертвы или сбежали
func squad_cleared(squad: String) -> bool:
	for ch in characters():
		if ch.squad == squad and ch.pose != "dead" and ch.visible and not ws().misc.has("gone_" + ch.uid()):
			return false
	return true
