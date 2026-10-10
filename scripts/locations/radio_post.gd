extends Act1Location
## Пост связи наёмников на сопке — источник сигнала из модуля «Связь».
## Дорогу находит кассета «Эфир». Охрана: двое с ружьями и радист.
## Рация в кунге (с «Эфиром») — перехват: Кирк отчитывается «Первому» и получает выговор.
## Журнал радиста — позывные и расписание сеансов. С мачты видно округу.


func _ready() -> void:
	location_id = "radio_post"
	title = "Пост связи"
	arrive_thought = ""
	super._ready()


func on_enter() -> void:
	super.on_enter()
	if not Game.flag("post_seen"):
		Game.set_flag("post_seen")
		main.think("Мачта над сопкой — красно-белая, с тарелками. Внизу кунг на колёсах, гудит генератор. Вот откуда шёл сигнал. И охрана — двое с ружьями.")


func status_line() -> String:
	return "2062 · конец лета · пост связи"


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win" and squad_cleared("post") and not Game.flag("post_clear"):
		Game.set_flag("post_clear")
		main.think("Тихо. Только генератор тарахтит да рация шипит в кунге.")


func _ether() -> bool:
	return Game.cas_has_tag("ether") or Game.item_count("cas_ether") > 0


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"RadioSet":
			if not squad_cleared("post"):
				main.think("К рации не подойти — охрана смотрит.")
			elif Game.flag("kirk_heard"):
				main.think("Рация шипит. Сеанс кончился. Следующий — в шесть утра, но меня тут уже не будет.")
			elif not _ether():
				main.think("Шипит на десятке частот сразу. Без «Эфира» не разобрать, где чья.")
			else:
				Game.set_flag("kirk_heard")
				Game.grant_xp(100)
				Game.add_note("Перехват на посту связи: «Север-два» — это Кирк. Он доложил «Первому»: Нахарро зачищен, носитель (браслет) не найден. «Первый» назвал его племянником и пригрозил заменой. Они ищут браслет — тот, что у меня.")
				main.think("Вставил «Эфир» — кассета щёлкнула и сама поймала частоту.\n«— Север-два — Первому. Объект зачищен. Носитель… не обнаружен.\n— Ты сжёг деревню и не нашёл браслет?\n— Проводник клянётся, старик носил его на руке…\n— Найди, Кирк. Или я найду тебе замену. Даже если ты мой племянник.»\nШип. Браслет. Они ищут браслет.")
			return true
		"Logbook":
			if not squad_cleared("post"):
				main.think("Журнал лежит на столе — прямо перед радистом.")
			elif not Game.flag("post_log"):
				Game.set_flag("post_log")
				Game.grant_xp(40)
				Game.add_note("Журнал радиста поста связи: «Север-2 (К.) — группа зачистки. Первый — Центр. Ретранслятор „Сытыган“ — списан. Сеансы с Центром: 06:00 ежедневно. Проводник — на связь только через Сунгар».")
				main.think("Журнал в клеёнке. Позывные, время сеансов… «Проводник — на связь только через Сунгар». Опять Сунгар.")
			else:
				main.think("Позывные и сеансы — всё уже переписал.")
			return true
		"MastClimb":
			if not squad_cleared("post"):
				main.think("Лезть на мачту под ружьями — нет уж.")
			else:
				var seen := []
				for id in ["convoy", "ruin", "zaimka"]:
					if not main.world_map.known(id):
						WorldMap.reveal(id)
						seen.append(str(main.world_map.nodes()[id].get("name", id)))
				if not Game.flag("mast_climbed"):
					Game.set_flag("mast_climbed")
					Game.grant_xp(20)
				main.think("Залез до середины — дальше ступени срезаны. Ветер, тайга до горизонта, река блестит." +
					((" Видно: " + ", ".join(seen) + ".") if not seen.is_empty() else ""))
			return true
		"AmmoCrate":
			if Game.flag("post_crate"):
				main.think("Пусто.")
			else:
				Game.set_flag("post_crate")
				main.loot_win.open("Ящик охраны", [{"id": "ammo9", "n": 8, "name": DB.item_name("ammo9")},
					{"id": "medkit", "n": 1, "name": DB.item_name("medkit")}, {"id": "canned", "n": 2, "name": DB.item_name("canned")}], func(e):
					Game.add_item(e.id, int(e.get("n", 1)))
					return true)
			return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"RadioSet":
			return [["Слушать эфир" + ("" if _ether() else " (нужна кассета «Эфир»)"), "use"]]
		"Logbook":
			return [["Читать журнал", "use"]]
		"MastClimb":
			return [["Залезть на мачту", "use"]]
		"AmmoCrate":
			return [["Открыть", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"RadioSet":
			return "Армейская рация в кунге: шкалы светятся зелёным, наушники на крючке."
		"Logbook":
			return "Журнал радиста в клеёнчатой обложке."
		"MastClimb":
			return "Скобы-ступени на ноге мачты."
		"AmmoCrate":
			return "Зелёный ящик с трафаретом."
		"WestExit":
			return "Тропа вниз с сопки."
	return ""


func objective() -> String:
	if not squad_cleared("post"):
		return "Пост охраняют. Снять охрану или подкрасться."
	if not Game.flag("kirk_heard"):
		return "Послушать рацию в кунге (кассета «Эфир»)."
	return ""
