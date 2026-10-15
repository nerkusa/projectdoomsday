extends NyurbaDistrict
## Нью-Рба, Центр — верхушка города грехов: Дом правительства (президент Артур,
## советник Гарик, казначей Апович), казино «Северное сияние», гостиница «Алмаз»,
## казармы, арена, салон «Бархат», ювелирный; радиолотерея у «Первого алмаза».


func _ready() -> void:
	location_id = "nyurba_center"
	title = "Нью-Рба · Центр"
	links = {"ToProxod": ["nyurba", "FromCenter", "Проход"], "ToBlack": ["nyurba_black", "FromCenter", "Чёрный район"]}
	arrive_thought = "Центр. Фонари горят даже днём, у дверей — охрана, из казино доносится музыка. Здесь живут те, кто считает чужие деньги."
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"Monument":
			main.think("«Первому алмазу Нью-Рбы — от благодарных жителей». Стеклянный октаэдр на постаменте. Говорят, настоящий камень раньше лежал внутри. Теперь — стекло. Как и многое здесь.")
			return true
		"Lottery":
			main.think("«Радиолотерея „Алмаз“. Розыгрыш в 20:00 по городскому эфиру. Джекпот: 500 р.» Ниже мелко: «выигрыш выплачивается талонами банка».")
			return true
		"Roulette":
			main.think("Шарик прыгает по лункам, крупье не смотрит на стол. Кажется, он и так знает, где тот остановится.")
			return true
		"Slots":
			main.think("Однорукие бандиты собраны из шкафов старых ЭВМ. На экранах мигают вишенки, нарисованные от руки. Рычаг тугой, а выигрыш, говорят, бывает раз в год.")
			return true
		"Ring":
			main.think("Ринг из досок, канаты — из красной ткани. На полу тёмные пятна. Бои — по субботам, ставки принимает устроитель.")
			return true
		"Safe":
			_safe()
			return true
	return super.on_interact(it)


func _apply_story() -> void:
	if Game.flag("nr_apovich_arrested") or Game.flag("nr_coup"):
		_hide_ch("Apovich")
	if Game.flag("nr_coup"):
		_hide_ch("Artur")
	if Game.flag("act3"):
		_hide_ch("Buyer")
	var b := character("BooturC")
	if b:
		b.visible = Game.flag("bootur_rise") and not Game.flag("nr_resolved")
		b.process_mode = Node.PROCESS_MODE_INHERIT if b.visible else Node.PROCESS_MODE_DISABLED


## Сейф казначея: пока Аповича нет (ночью или он под замком) — Воровство; рядом охрана палат
func _safe() -> void:
	if Game.item_count("horizon_memo") > 0:
		main.think("Сейф пуст — бумаги у меня.")
		return
	var ap := character("Apovich")
	if ap and ap.visible and not Clock.is_night():
		main.think("Казначей сидит в двух шагах от сейфа и считает. Днём к нему не подобраться.")
		return
	if not Game.flag("nr_apovich_arrested") and not Game.skill_check("Воровство", "REF", "Воровство", 15, 2 if Game.hero.get("sneak", false) else 0):
		Game.change_rep(-5, "лез в сейф казначея")
		main.think("Замок щёлкнул не там. Охранник у двери обернулся: «Эй! А ну отошёл от сейфа!» Пришлось уходить.")
		return
	Game.add_item("horizon_memo")
	Game.grant_xp(120)
	main.think("Сейф поддался. Внутри — папка с треугольником в круге. Ориентировка на браслет… серия ЭЛ-1, владелец Эллэй. Мой браслет.")
	got_evidence()


func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"nr_arrest":
			Game.set_flag("nr_resolved")
			Game.set_flag("nr_apovich_arrested")
			main.dialog.closed.connect(func(): _hide_ch("Apovich"); _hide_ch("BooturC"), CONNECT_ONE_SHOT)
			Game.add_note("Нью-Рба: казначея Аповича взяли под замок. Сделку президент всё равно подписал — покупатель в «Алмазе».")
			return true
		"nr_deal":
			Game.set_flag("nr_resolved")
			Game.set_flag("nr_apovich_deal")
			return true
		"act2_end":
			main.dialog.closed.connect(func():
				var bu := character("Buyer")
				if bu:
					bu.start_pose = ""
					bu.pose = ""
					bu.move_along(Clock._route(self, bu.global_position, Vector3(2, 0, 40)), func(): _hide_ch("Buyer"), 2.6)
				await get_tree().create_timer(2.0, false).timeout
				act2_end(), CONNECT_ONE_SHOT)
			return true
	return super.on_dialog_action(a, sp)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Monument":
			return "Постамент со стеклянным «алмазом»."
		"Lottery":
			return "Экран радиолотереи на столбе."
		"Roulette":
			return "Рулетка под зелёным сукном."
		"Slots":
			return "Игровые автоматы из довоенных ЭВМ."
		"Ring":
			return "Дощатый ринг арены."
		"Safe":
			return "Тяжёлый сейф в кабинете казначея."
	return super.describe(it)
