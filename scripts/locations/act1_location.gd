class_name Act1Location
extends Location
## Общее для локаций первого акта: выходы на карту мира, еда для платы и подарков,
## первая мысль при входе, задачи из журнала.

## Мысль при первом входе (ключ узла в thoughts.json)
var arrive_thought := ""


func _ready() -> void:
	Game.hero_changed.connect(_on_hero_changed)


func _exit_tree() -> void:
	if Game.hero_changed.is_connected(_on_hero_changed):
		Game.hero_changed.disconnect(_on_hero_changed)


func _on_hero_changed() -> void:
	pass


func status_line() -> String:
	return "2062 · конец лета · за чертой"


func on_enter() -> void:
	if not Game.flag("seen_" + location_id):
		Game.set_flag("seen_" + location_id)
		if arrive_thought != "":
			await get_tree().create_timer(0.8, false).timeout
			main.say("thoughts", arrive_thought)
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
	return true


## Задача на экране: первая незакрытая из заданий этой локации, потом общие
func objective() -> String:
	return ""
