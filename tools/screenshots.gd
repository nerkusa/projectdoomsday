extends Node
## Снимки экрана для проверки интерфейса (нужен рендер, не --headless).
## Запуск: godot --path . res://tools/screenshots.tscn -- <папка>

var main: Node
var out := "user://shots/"


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + n + ".png")
	print("снимок: ", n)


func frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	await shot("01_menu")
	main._on_menu("new")
	await frames(3)
	Game.hero.name = "Эрхаан"
	main.sheet.open()
	await frames(3)
	await shot("02_sheet")
	main.sheet.close()
	await frames(3)
	main.slides._next()
	await wait(1.5)
	await shot("03_intro")
	while main.slides.visible:
		main.slides._next()
		main.slides._next()
		await frames(1)
	while main.location == null or main._loading:
		await wait(0.1)
	await wait(1.0)
	main.dialog.close()
	await wait(0.8)
	await shot("04_village")
	main.talk_to(main.location.character("Ded"))
	await wait(3.0)
	await shot("05_dialog")
	main.dialog.close()
	main.zoom = 26.0
	await wait(1.0)
	await shot("06_village_wide")
	main.zoom = 15.0
	Game.add_item("knife")
	Game.add_item("pistol")
	Game.add_item("ammo9", 16)
	Game.add_item("bandage", 2)
	Game.set_flag("kpk")
	Game.hero.flags["modules"] = {"carrier": true, "inventory": true, "map": true, "radio": true}
	main.kpk.open("inv")
	main.kpk._sel = "pistol"
	main.kpk.render()
	await wait(0.4)
	await shot("07_kpk_inv")
	main.kpk.open("map")
	await wait(0.4)
	await shot("08_kpk_map")
	main.kpk.open("stat")
	await wait(0.4)
	await shot("09_kpk_stat")
	main.kpk.close()
	# бой с псом
	var wolf: Character = main.location.character("Wolf")
	main.player.global_position = wolf.global_position + Vector3(-4, 0, 3)
	main.cam_target = main.player.global_position
	Game.hero.hands = ["pistol", "knife"]
	main.player.set_held("pistol")
	await wait(1.5)
	while main.combat.on and not main.combat.my_turn():
		await wait(0.2)
	main.combat.hover(wolf, null)
	await wait(0.5)
	await shot("10_combat")
	# налёт
	main.combat.on = false
	main.overlay.visible = false
	Game.set_flag("phase", "raid")
	Game.set_flag("fire_seen")
	main.location._apply_phase()
	main.player.global_position = Vector3(34, 0, 34)
	main.cam_target = main.player.global_position
	main.zoom = 20.0
	await wait(2.0)
	main.dialog.close()
	await wait(0.5)
	await shot("11_raid")
	get_tree().quit()
