extends NyurbaDistrict
## Нью-Рба, Чёрный район — дно: лачуги, барахолка, ночлежка, рюмочная «24 часа».
## Здесь пропивает себя Боотур; здесь ходят сборщики долгов казначея. Люк — в коллектор.


func _ready() -> void:
	location_id = "nyurba_black"
	title = "Нью-Рба · Чёрный район"
	links = {"ToProm": ["nyurba_prom", "FromBlack", "Промрайон"], "ToCenter": ["nyurba_center", "FromBlack", "Центр"],
		"Hatch": ["nyurba_sewer", "FromBlack", "Люк в коллектор"]}
	arrive_thought = "Чёрный район. Лачуги из всего подряд, дым от бочек, на стенах — «долги платят все». Сюда падают из Прохода."
	super._ready()


func _apply_story() -> void:
	var b := character("Bootur")
	if b == null:
		return
	if Game.flag("bootur_dead"):
		b.pose = "dead"
	elif Game.flag("bootur_rise"):
		_hide_ch("Bootur")


func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"bootur_kill":
			var b := character("Bootur")
			main.dialog.close()
			if b:
				b.pose = "dead"
				ws().dead[b.uid()] = true
			Game.set_flag("bootur_dead")
			Game.set_quest("act2", 4)
			Game.change_rep(-4, "убил безоружного Боотура")
			main.sfx("hit_blunt", -2.0)
			main.think("Один удар. Боотур даже не поднял рук. Наливайка Зоя смотрит на меня молча. Нахарро от этого не ожило.")
			return true
		"bootur_spare":
			Game.set_flag("bootur_spared")
			Game.set_quest("act2", 4)
			return true
		"bootur_rise":
			Game.set_flag("bootur_rise")
			Game.set_quest("act2", 4)
			Game.add_note("Боотур протрезвел и пойдёт со мной к Аповичу — скажет при свидетелях, как его купили.")
			main.dialog.closed.connect(func():
				var b := character("Bootur")
				if b:
					b.start_pose = ""
					b.pose = ""
					b.move_along(Clock._route(self, b.global_position, Vector3(44, 0, NR_EXIT_S)), func(): _hide_ch("Bootur"), 3.0)
				main.think("Боотур идёт к Центру, ни разу не оглянувшись на стойку. Ждёт меня у Дома правительства."), CONNECT_ONE_SHOT)
			return true
	return super.on_dialog_action(a, sp)


const NR_EXIT_S := 82.0


func describe(it: Interactable) -> String:
	if String(it.name) == "Hatch":
		return "Открытый люк. Снизу тянет сыростью и дымом."
	return super.describe(it)
