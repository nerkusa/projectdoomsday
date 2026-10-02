extends Act1Location
## Лагерь оборванцев у старой лесопилки: беженцы после налётов.
## На въезде Дуолан требует плату (еда / запугать / уговорить / драка).
## Вожак Хабырыыс видел тех же солдат и «проводника». Здесь же Нюргун —
## сын рыбака из Крестов, раненая Туйаара и меняла Кылаа.

const THUG_R := 6.0


func _ready() -> void:
	location_id = "camp"
	title = "Лагерь оборванцев"
	arrive_thought = "camp_arrive"
	super._ready()


func on_hero_moved(pos: Vector3) -> void:
	if Game.flag("camp_passed") or main.combat.on or main.ui_blocked():
		return
	var t := character("Thug")
	if t == null or not t.visible or t.pose == "dead":
		return
	var d := pos.distance_to(t.global_position)
	# первый раз окликает издалека; дальше линии, где он стоит, не пускает
	var first := not Game.flag("camp_stopped") and d < THUG_R
	# поляна лагеря вся восточнее Дуолана — мимо него, лесом, тоже не обойти
	var past := pos.x > t.global_position.x - 0.8
	if first or past:
		Game.set_flag("camp_stopped")
		main.player.stop()
		if past:
			main.player.global_position = Vector3(t.global_position.x - 2.2, 0, t.global_position.z)
		main.talk_to(t)


func on_dialog_action(a: String, sp: Character) -> bool:
	if a == "fight":
		# саму драку начинает main; здесь только помним, что она была
		Game.set_flag("camp_thug_fought")
		return false
	return super.on_dialog_action(a, sp)


func on_combat_end(res: String, kind: String) -> void:
	# реванш с Дуоланом на кулаках
	if kind == "spar" and Game.quest_stage("rematch") == 1:
		await get_tree().create_timer(0.6, false).timeout
		main.talk_to(character("Thug"), "rematch_won" if res == "win" else "rematch_lost")
		return
	if res != "win" or Game.flag("camp_passed"):
		return
	var t := character("Thug")
	if t and (t.pose == "dead" or ws().misc.has("gone_" + t.uid()) or not t.visible):
		Game.set_flag("camp_passed")
		Game.change_rep(-4, "побил людей в лагере беженцев")
		main.think("Беженцы смотрят молча. Кто-то прячет детей в палатку.")


func on_interact(it: Interactable) -> bool:
	if String(it.name) == "Stash":
		if Game.flag("camp_stash"):
			main.think("Пусто.")
		elif Game.flag("stash_told") or Game.skill_check("Внимательность", "PRC", "Внимательность", 12):
			Game.set_flag("camp_stash")
			main.loot_win.open("Тайник под брёвнами", [{"id": "ammo9", "n": 4, "name": DB.item_name("ammo9")},
				{"id": "canned", "n": 1, "name": DB.item_name("canned")}], func(e):
				Game.add_item(e.id, int(e.get("n", 1)))
				if not Game.flag("stash_told"):
					Game.change_rep(-2, "взял из чужого тайника", false)
				return true)
		else:
			main.think("Брёвна как брёвна. Хотя одно лежит как-то не так…")
		return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	if String(it.name) == "Stash":
		return [["Пошарить под брёвнами", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Stash":
			return "Штабель старых брёвен у лесопилки."
		"WestExit":
			return "Тропа обратно на большую дорогу — к Крестам."
	return ""


func objective() -> String:
	if not Game.flag("camp_passed"):
		return "Пройти в лагерь: на въезде стоит Дуолан."
	if not Game.flag("camp_boss_told"):
		return "Поговорить с Хабырыысом у костра — что они видели."
	if Game.quest_stage("kr_nets") in [1, 2]:
		return "Найти в лагере того, кто таскает рыбу у Тэрэнтэя."
	return ""
