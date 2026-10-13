extends Node
## Скриншоты для проверки (нужен рендер, не --headless):
##   xvfb-run -a -s "-screen 0 1600x900x24" $G --rendering-driver opengl3 --resolution 1600x900 --path . \
##     res://tools/render_shots.tscn -- "кадр;кадр;…" /путь/префикс     → префикс_0.png, _1.png…
## Кадр: loc|x|z|zoom|час|флаги — флаги через запятую, «квест=этап» ставит этап, «weather=rain» — погоду.
##       encounter|x|z|zoom|час|enc_id|ориентиры(plane,heli,…)
##       MAP — карта мира с тропами (MAP|all — все места);  WAIT|часов|через_сколько_сек — экран ожидания.
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
			var ids: Array = ["kresty", "camp", "zaimka", "convoy", "ruin"]
			if p.size() > 1 and p[1] == "all":
				ids = main.world_map.nodes().keys()
			if p.size() > 1 and p[1] == "fresh":
				# начало игры: туман, известны только Нахарро и Кресты; пройдена дорога от Нахарро
				ids = []
				Game.world.erase("_fog")
				var wm0: WorldMap = main.world_map
				var a: Vector2 = wm0.node_pos("nakharro")
				var b: Vector2 = wm0.node_pos("kresty")
				main.world_map.open("nakharro")
				for k in 12:
					wm0.explore(a.lerp(b, k / 22.0))
				main.world_map._build_fog()
			for id in ids:
				WorldMap.reveal(id)
			Game.set_flag("visited_kresty")
			if p.size() <= 1 or p[1] != "fresh":
				main.world_map.open("kresty")
			if p.size() > 2:
				main.world_map.set_zoom(float(p[2]))
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
			# каждый кадр — новая встреча (зерно местности иначе сохраняется)
			Game.hero.flags["enc_seed"] = randi()
			Game.world.erase("encounter")
		var talk := ""
		var pick := ""
		Game.hero.sneak = false
		if p.size() > 5 and p[5] != "" and p[0] != "encounter":
			for f in str(p[5]).split(","):
				if f == "sneak":
					Game.hero.sneak = true
				elif f.begins_with("talk="):
					talk = f.trim_prefix("talk=")
				elif f.begins_with("opt="):
					pick = f.trim_prefix("opt=")
				elif f.begins_with("int="):
					Game.hero.stats["INT"] = int(f.trim_prefix("int="))
				elif f.begins_with("rad="):
					Game.hero["rad"] = float(f.trim_prefix("rad="))
				elif f.begins_with("weather="):
					Weather.frozen = true
					Weather.set_kind(f.trim_prefix("weather="), 999.0)
				elif f.contains("="):
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
		if talk == "SHEET":
			# кадр с листом героя (как при создании)
			Game.hero.locked = false
			main.sheet.open()
			main.sheet.pick(str(main.sheet.presets()[0].id))
			await get_tree().process_frame
		elif talk != "":
			# кадр с диалогом: говорим с человеком и, если надо, выбираем ответ
			main.talk_to(main.location.character(talk))
			for k in 5:
				await get_tree().process_frame
			main.dialog._finish_typing()
			if pick != "":
				for k2 in main.dialog._visible_opts.size():
					if pick in str(main.dialog._visible_opts[k2].get("text", "")):
						main.dialog._choose(k2)
						break
				for k in 5:
					await get_tree().process_frame
				main.dialog._finish_typing()
			await get_tree().process_frame
		else:
			main._check_aggro()
			main.hud.visible = false
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
		main.hud.visible = true
		main.dialog.close()
		i += 1
	get_tree().quit()
