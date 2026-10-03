extends Location
## Бункер под базой на Сытыгане — второй уровень. Спуск — по верёвке через вентшахту.
## Генератор (Механика) включает свет и электрозамок архива. Без тока дверь можно
## поддеть отвёрткой (Воровство). В архиве — копия «списка Б» и ведомость на Эллэя.


func _ready() -> void:
	location_id = "ruin_bunker"
	title = "Бункер под Сытыганом"
	# открытая дверь архива не должна мешать сетке ходов
	if Game.flag("archive_open"):
		var d := get_node_or_null("Village/ArchiveDoor")
		if d:
			d.free()


func on_world_state_applied() -> void:
	_apply_power()


func _apply_power() -> void:
	var on := Game.flag("bunker_power")
	for l in get_node("Village/MainLights").get_children():
		l.visible = on
	for l in get_node("Village/Emergency").get_children():
		(l as OmniLight3D).light_energy = 0.4 if on else 0.9


func on_enter() -> void:
	_apply_power()
	if not Game.flag("bunker_seen"):
		Game.set_flag("bunker_seen")
		main.think("Красные лампы. Значит, где-то ещё есть ток — аварийный. Пахнет пылью, машинным маслом и чем-то сладким. Мертвечиной.")


func status_line() -> String:
	return "2062 · бункер · " + ("свет есть" if Game.flag("bunker_power") else "аварийный свет")


func _open_door() -> void:
	Game.set_flag("archive_open")
	var d := get_node_or_null("Village/ArchiveDoor")
	if d:
		d.queue_free()
	main.sfx("plug", -4.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.build(get_world_3d().direct_space_state, map_rect, 1)


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"UpRope":
			main.load_location("ruin", "Shaft")
			return true
		"Generator":
			if Game.flag("bunker_power"):
				main.think("Генератор ровно гудит. Сколько ему лет — пятьдесят? Делали же…")
			elif Game.skill_check("Механика", "INT", "Механика", 12) or Game.flag("gen_try"):
				Game.set_flag("bunker_power")
				_apply_power()
				Game.grant_xp(50)
				main.think("Продул фильтр, подкачал топливо, дёрнул пускач. Чихнул… и загудел. Под потолком загораются лампы — одна за другой.")
			else:
				Game.set_flag("gen_try")
				main.think("Не схватывает. Топливо есть, искры нет. Ещё раз — и, может, пойдёт.")
			return true
		"DoorLock":
			if Game.flag("archive_open"):
				main.think("Дверь открыта.")
			elif Game.flag("bunker_power") and Game.item_count("keycard") > 0:
				Game.log_line("Ключ-карта: доступ разрешён.", "", "hit")
				main.think("Замок пискнул, лампочка — зелёная. «Архив. Уровень два».")
				_open_door()
			elif Game.flag("bunker_power"):
				main.think("Замок ожил: мигает красным, ждёт карту. Карты нет. Может, у кого-то из своих была?")
			elif Game.item_count("screwdriver") > 0:
				if Game.skill_check("Воровство", "REF", "Воровство", 13) or Game.flag("pry_try"):
					main.think("Поддел отвёрткой ригель — замок без тока, держит только пружина. Щёлк.")
					_open_door()
				else:
					Game.set_flag("pry_try")
					main.think("Отвёртка соскальзывает. Ещё раз, аккуратнее.")
			else:
				main.think("Электрозамок. Без тока — мёртвый. Включить генератор? Или поддеть чем-то тонким.")
			return true
		"Lockers":
			if Game.flag("lockers_open"):
				main.think("Пустые шкафчики. Таблички с фамилиями: Петров, Ким, Сидорова…")
			else:
				Game.set_flag("lockers_open")
				main.loot_win.open("Шкафчики охраны", [{"id": "cas_ether", "n": 1, "name": DB.item_name("cas_ether")},
					{"id": "ammo9", "n": 6, "name": DB.item_name("ammo9")}, {"id": "t_harmonica", "n": 1, "name": DB.item_name("t_harmonica")}], func(e):
					Game.add_item(e.id, int(e.get("n", 1)))
					return true)
			return true
		"Files":
			if not Game.flag("archive_open"):
				main.think("Шкаф с делами — за стеклом двери архива. Сначала открыть дверь.")
				return true
			if Game.flag("list_b_found"):
				main.think("Остальное — пустые папки. Самое важное вывезли. Это — забыли.")
			else:
				Game.set_flag("list_b_found")
				Game.add_item("list_b")
				Game.set_quest("who", maxi(5, Game.quest_stage("who")))
				Game.grant_xp(120)
				main.say("thoughts", "bunker_list")
			return true
		"Registry":
			if not Game.flag("archive_open"):
				main.think("Ведомость висит на стене архива. Дверь заперта.")
				return true
			if not Game.flag("registry_read"):
				Game.set_flag("registry_read")
				Game.add_note("Ведомость ООО «Системный анализ „Горизонт“» на 12.12.2012, отдел цифровых моделей: «Николаев Эллэй Н. — статус: БЕГЛЕЦ. При обнаружении — изъять носитель (браслет Э-1)». Браслет Э-1 — тот, что у меня на руке.")
				Game.grant_xp(60)
			main.say("thoughts", "bunker_registry")
			return true
	return false


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win" and not Game.flag("squat_clear"):
		var left := false
		for ch in characters():
			if ch.squad == "squat" and ch.pose != "dead" and ch.visible:
				left = true
		if not left:
			Game.set_flag("squat_clear")
			main.think("Копатели. Залезли раньше меня — и тоже не открыли архив.")


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"UpRope":
			return [["Подняться по верёвке", "use"]]
		"Generator":
			return [["Запустить генератор", "use"]]
		"DoorLock":
			if Game.flag("bunker_power"):
				return [["Приложить ключ-карту", "use"]]
			return [["Поддеть замок отвёрткой", "use"]]
		"Lockers":
			return [["Открыть шкафчики", "use"]]
		"Files", "Registry":
			return [["Читать", "use"]]
	return []


func describe(it: Interactable) -> String:
	match String(it.name):
		"Generator":
			return "Дизель-генератор с табличкой «Мин. обороны». Топливный бак на треть полон."
		"DoorLock":
			return "Дверь архива с электрозамком. " + ("Мигает красным." if Game.flag("bunker_power") else "Мёртвый — тока нет.")
		"Lockers":
			return "Ряд железных шкафчиков, на дверцах — фамилии."
		"Files":
			return "Стеллаж с папками. На корешках — коды поселений."
		"Registry":
			return "Толстая ведомость в клеёнчатой обложке."
		"UpRope":
			return "Моя верёвка — свисает из шахты."
	return ""


func objective() -> String:
	if not Game.flag("archive_open"):
		return "Попасть в архив: включить генератор или поддеть замок."
	if not Game.flag("list_b_found"):
		return "Осмотреть архив."
	return ""
