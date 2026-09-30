extends Node
## Автозагрузка DB: читает все данные игры из папки data/.
## Оружие, предметы, персонажи, задания, диалоги — всё в JSON,
## их можно править в любом текстовом редакторе без программирования.

var weapons: Dictionary = {}
var items: Dictionary = {}
var characters: Dictionary = {}
var quests: Dictionary = {}
var intro: Dictionary = {}
## Что игрок видит, когда впервые замечает персонажа (как в первом Fallout)
var observations: Dictionary = {}
var _dialogs: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	weapons = _load("res://data/weapons.json")
	items = _load("res://data/items.json")
	characters = _load("res://data/characters.json")
	quests = _load("res://data/quests.json")
	intro = _load("res://data/intro.json")
	observations = _load("res://data/observations.json")
	_dialogs.clear()


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Нет файла данных: " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(txt)
	if err != OK:
		push_error("Ошибка в %s, строка %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	var d = _ints(json.data)
	return d if d is Dictionary else {}


## JSON читает все числа как дробные: 3 -> 3.0. Возвращаем целые.
func _ints(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _ints(v[k])
		return out
	if v is Array:
		var a := []
		for x in v:
			a.append(_ints(x))
		return a
	if v is float and is_equal_approx(v, round(v)):
		return int(v)
	return v


func dialog(id: String) -> Dictionary:
	if not _dialogs.has(id):
		_dialogs[id] = _load("res://data/dialogs/%s.json" % id)
	return _dialogs[id]


func weapon(key: String) -> Dictionary:
	return weapons.get(key, weapons.get("fists", {}))


func is_gun(key: String) -> bool:
	return weapons.has(key) and int(weapons[key].get("mag", 0)) > 0


## Цена в бартере; 0 — не меняется (сюжетные и памятные вещи)
func item_value(key: String) -> int:
	var d: Dictionary = weapons.get(key, items.get(key, {}))
	if d.get("quest", false):
		return 0
	return int(d.get("value", 0))


func item_name(key: String) -> String:
	if weapons.has(key):
		return weapons[key].name
	if items.has(key):
		return items[key].name
	return key
