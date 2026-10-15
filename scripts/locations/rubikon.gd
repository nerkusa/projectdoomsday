extends Act1Location
## Рубикон — мёртвый Вилюйск (Акт IV). Проспект кишит мутантами: вурды стаей, рогачи,
## топтун у кратера, ушаны. Обойти можно северной тропой — если браслет расшифрован
## (на нём карта старых ходов), но на тропе сидит чучуна. По улицам бродит Харат —
## чёрный конь: близко не подходить. Если ток ушёл рабочим или совету — с героем ополченцы.

## Сколько урона за раунд даёт ополченец
const ALLY_DMG := Vector2i(2, 5)
## Харат: скорость шага и радиус, на котором он замечает героя
const HARAT_SPEED := 2.2
const HARAT_SEE := 6.0
const HARAT_PATH := [Vector3(12, 0, 38), Vector3(92, 0, 38), Vector3(95, 0, 62), Vector3(56, 0, 67), Vector3(5, 0, 62), Vector3(5, 0, 40)]

var _harat: Node3D
var _hi := 0
var _harat_cd := 0.0
var _step := 0.0


func _ready() -> void:
	location_id = "rubikon"
	title = "Рубикон"
	arrive_thought = "Вилюйск. Стекло вместо земли, остовы пятиэтажек, кости у дороги. И тишина — только где-то в домах что-то шуршит."
	super._ready()
	_harat = get_node_or_null("Village/Harat") as Node3D


func status_line() -> String:
	return "2062 · Рубикон"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("act4") == 0:
		Game.set_quest("act4", 1)
		if DB.intro.has("act4_rubicon"):
			main.slides.play(DB.intro["act4_rubicon"])
	var own := str(Game.flag_value("ges_owner", ""))
	var allies := own == "workers" or own == "republic"
	for i in 3:
		var a := character("Ally%d" % i)
		if a and not allies:
			_hide(a)
	main.hud.refresh_objective()


func _hide(ch: Character) -> void:
	ch.stop()
	ch.visible = false
	ch.process_mode = Node.PROCESS_MODE_DISABLED


func objective() -> String:
	if Game.quest_stage("act4") == 1:
		if Game.flag("bracelet_decoded"):
			return "Пройти Рубикон: проспектом через мутантов — или северной тропой (на браслете карта ходов)."
		return "Пройти Рубикон насквозь, на восток. Проспект кишит мутантами."
	if Game.flag("rubicon_passed"):
		return "Дальше по тракту — Горный (карта мира)."
	return ""


## Харат бродит по кругу; заметив героя, бьёт копытом и уходит дальше
func _process(delta: float) -> void:
	if _harat == null or not _harat.visible or main == null or main.combat.on:
		return
	var tgt: Vector3 = HARAT_PATH[_hi]
	var d := tgt - _harat.position
	d.y = 0.0
	if d.length() < 0.5:
		_hi = (_hi + 1) % HARAT_PATH.size()
	else:
		var dir := d.normalized()
		_harat.position += dir * HARAT_SPEED * delta
		_harat.rotation.y = atan2(dir.x, dir.z)
		_step += delta * 4.0
		for i in 4:
			var leg := _harat.get_node_or_null("Leg%d" % i) as Node3D
			if leg:
				leg.rotation.x = sin(_step + (PI if i in [1, 2] else 0.0)) * 0.45
	_harat_cd = maxf(0.0, _harat_cd - delta)
	if _harat_cd > 0.0 or main.player == null:
		return
	var hp: Vector3 = main.player.global_position
	if Vector2(hp.x - _harat.position.x, hp.z - _harat.position.z).length() < HARAT_SEE:
		_harat_cd = 25.0
		if Game.hero.get("sneak", false) and Game.skill_check("Скрытность", "REF", "Скрытность", 12):
			main.think("Харат прошёл в трёх шагах. Не повернул головы — только глаза-угли мигнули. Не дышать.")
			return
		var dmg := randi_range(5, 9)
		Game.set_hero_hp(maxi(1, Game.hero_hp() - dmg))
		main.hud.refresh()
		main.sfx("shot_near", 0.0, 0.5)
		Game.log_line("Харат! −%d ХП" % dmg, "", "miss")
		main.think("Чёрный конь. Удар — и я в пепле, а он уже уходит, будто меня и не было. Харат. Про него в Мирном шёпотом говорили.")


func on_combat_round(_r: int) -> void:
	for i in 3:
		var a := character("Ally%d" % i)
		if a == null or not a.visible or a.pose == "dead":
			continue
		var es: Array = main.combat.enemies()
		if es.is_empty():
			return
		var t = es[randi() % es.size()]
		main.combat.ally_hit(t, randi_range(ALLY_DMG.x, ALLY_DMG.y), a.display_name)


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"WestExit":
			main.world_map.open(location_id)
			return true
		"EastExit":
			_pass()
			main.world_map.open(location_id)
			return true
		"TrailIn":
			if not Game.flag("bracelet_decoded"):
				main.think("В чаще — то ли тропа, то ли звериный лаз. Куда ведёт — не знаю. Без карты туда соваться — смерть.")
				return true
			main.think("Браслет показывает старые ходы: тропа огибает город по северу. Тихо. Почти.")
			main.player.global_position = spawn_point("Trail")
			return true
		"TrailOut":
			_pass()
			main.think("Тропа вывела на тракт за городом. Рубикон позади.")
			main.world_map.open(location_id)
			return true
	return super.on_interact(it)


## Рубикон пройден: открывается дорога на Горный и Якутск
func _pass() -> void:
	if Game.flag("rubicon_passed"):
		return
	Game.set_flag("rubicon_passed")
	Game.set_quest("act4", 2)
	Game.grant_xp(250)
	Game.add_note("Рубикон пройден. Мёртвый Вилюйск — «черновики» «Горизонта»: мутанты не сами пришли с севера. Дальше — Горный и ГРЭС-2.")
	main.hud.refresh_objective()


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"TrailIn":
			return [["Свернуть на тропу", "use"]]
		"TrailOut":
			return [["Выйти на тракт", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"TrailIn":
			return "Узкий лаз в чащу на север."
		"TrailOut":
			return "Тропа выходит к тракту."
		"WestExit":
			return "Дорога назад, к ГЭС."
		"EastExit":
			return "Тракт уходит на восток."
	return ""
