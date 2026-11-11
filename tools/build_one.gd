extends "res://tools/build_scenes.gd"
## Пересобрать один-два базовых пропса из build_scenes.gd, не трогая остальное:
##   godot --headless --path . res://tools/build_one.tscn -- garden table
## Имя — без подчёркивания: «garden» вызовет _garden() и сохранит scenes/props/garden.tscn.


func _ready() -> void:
	# все готовые материалы — по именам файлов
	for f in DirAccess.get_files_at(MAT_DIR):
		if f.ends_with(".tres"):
			M[f.get_basename()] = load(MAT_DIR + f)
	for a in OS.get_cmdline_user_args():
		if has_method("_" + a):
			call("_" + a)
			print("собран: ", a)
		else:
			push_error("нет сборщика _" + a)
	get_tree().quit()
