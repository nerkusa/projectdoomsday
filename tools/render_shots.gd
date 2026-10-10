extends Node
## Скриншоты для проверки (нужен рендер, не --headless):
##   xvfb-run -a -s "-screen 0 1600x900x24" $G --rendering-driver opengl3 --resolution 1600x900 --path . \
##     res://tools/render_shots.tscn -- "кадр;кадр;…" /путь/префикс     → префикс_0.png, _1.png…
## Кадр: loc|x|z|zoom|час|флаги — флаги через запятую, «квест=этап» ставит этап.
##       encounter|x|z|zoom|час|enc_id|ориентиры(plane,heli,…)
##       MAP — карта мира с тропами;  WAIT|часов|через_сколько_сек — экран ожидания.
var main: Node

func _ready() -> void:
	Clock.running = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.new_hero()
	for f in ["sg_entered", "sg_permit", "seen_kresty", "seen_sungar", "bunker_seen"]:
		Game.set_flag(f)
	main.menu.visible = false
	get_tree().paused = false
	var shots: Array = OS.get_cmdline_user_args()[0].split(";")
	var out: String = OS.get_cmdline_user_args()[1]
	var i := 0
	for s in shots:
		var p: Array = s.split("|")
		if p[0] == "MAP":
			for id in ["kresty", "camp", "zaimka", "convoy", "ruin"]:
				WorldMap.reveal(id)
			Game.set_flag("visited_kresty")
			main.world_map.open("kresty")
			for k in 40:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
			main.world_map.visible = false
			i += 1
			continue
		if p[0] == "WAIT":
			main.wait_hours(float(p[1]), "")
			await get_tree().create_timer(float(p[2])).timeout
			get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
			while main.wait_scr.visible:
				await get_tree().process_frame
			i += 1
			continue
		if p[0] == "encounter":
			Game.hero.flags["enc"] = p[5] if p.size() > 5 else "trader"
			Game.hero.flags["enc_biome"] = "field"
			Game.hero.flags["enc_mode"] = "peace"
			Game.hero.flags["enc_force_landmarks"] = Array(p[6].split(",")) if p.size() > 6 else []
		elif p.size() > 5 and p[5] != "":
			for f in str(p[5]).split(","):
				if f.contains("="):
					var kv: PackedStringArray = f.split("=")
					Game.set_quest(kv[0], int(kv[1]))
				else:
					Game.set_flag(f)
		if main.location == null or main.location.location_id != p[0] or p[0] == "encounter":
			main.load_location(p[0])
			while main._loading:
				await get_tree().process_frame
			for k in 10:
				await get_tree().process_frame
		main.menu.visible = false
		main.dialog.close()
		Game.hero.flags["clock"] = float(p[4]) if p.size() > 4 else 12.0
		if main.location.has_method("on_world_state_applied"):
			main.location.on_world_state_applied()
		Clock.apply_light(main.location)
		Clock.update_schedules(true)
		var pos := Vector3(float(p[1]), 0, float(p[2]))
		main.player.global_position = pos
		main.cam_target = pos
		main.zoom = float(p[3])
		main.camera.size = main.zoom
		if main.location.has_method("_show") and main.location.has_method("room_at"):
			main.location._show(main.location.room_at(pos))
		for k in 50:
			await get_tree().process_frame
		main.dialog.close()
		main.hud.visible = false
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
		main.hud.visible = true
		i += 1
	get_tree().quit()
