extends Node
## Проверка: загружает все скрипты проекта и сообщает об ошибках.
## Запуск: godot --headless --path . res://tools/check.tscn

func _ready() -> void:
	var bad := 0
	for p in _files("res://scripts"):
		var s = load(p)
		if s == null or not (s as Script).can_instantiate():
			print("ОШИБКА: ", p)
			bad += 1
	print("Проверено, ошибок: ", bad)
	get_tree().quit(1 if bad else 0)


func _files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_files(dir + "/" + sub))
	return out
