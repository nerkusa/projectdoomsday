extends Node
## Скриншоты интерфейса: разговор с дедом, КПК (вещи, «Дело»), реплики над головой.
## Запуск (нужен рендер): godot --path . res://tools/ui_shots.tscn -- /путь/префикс
func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func shot(main: Node, out: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)


func _ready() -> void:
	Clock.running = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(3)
	Game.new_hero()
	main.menu.visible = false
	get_tree().paused = false
	main.load_location("nakharro", "Start")
	while main._loading:
		await frames(2)
	var out: String = OS.get_cmdline_user_args()[0]
	await get_tree().create_timer(1.5).timeout
	await shot(main, out + "_hud.png")
	main.talk_to(main.location.character("Ded"))
	await frames(4)
	main.dialog._finish_typing()
	await shot(main, out + "_dialog.png")
	main.dialog.close()
	Game.add_item("medkit")
	main.kpk.open("inv")
	await shot(main, out + "_kpk.png")
	main.kpk.open("stat")
	await shot(main, out + "_stat.png")
	main.kpk.open("cas")
	await shot(main, out + "_cas.png")
	main.kpk.open("ether")
	await shot(main, out + "_ether.png")
	get_tree().quit()
