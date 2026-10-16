extends MirnyDistrict
## Мирный · центр — ничейная земля. Посреди города мёртвый карьер трубки «Мир», вокруг —
## промзона ГОК «Мир» (цеха, котельная, склады) и барахолка, где торгуют все со всеми.
## По углам — улицы в районы фракций, у каждой свой кордон. Тракт: запад — к Нью-Рбе,
## восток — к ГЭС. Серпантин с северной бровки — на дно карьера.


func _ready() -> void:
	location_id = "mirny"
	title = "Мирный · центр"
	links = {"ToKimberlit": ["mirny_kimberlit", "FromCenter", "Район «Кимберлита»"],
		"ToRepublic": ["mirny_republic", "FromCenter", "Совет и йегеря"],
		"ToWorkers": ["mirny_workers", "FromCenter", "Рабочий посёлок"],
		"ToRaiders": ["mirny_raiders", "FromCenter", "Квартал рейдеров"]}
	arrive_thought = "Мирный. Посреди города — воронка карьера, такая, что дна не видно. Вокруг ржавая промзона, а на каждом углу — флаги четырёх цветов и кто-то с ружьём."
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"WestRoad", "EastRoad":
			main.world_map.open(location_id)
			return true
		"ToQuarry":
			main.load_location("mirny_quarry", "FromTop")
			return true
		"GokSign":
			main.think("«ГОК „Мир“. Промзона. Вход по пропускам». Пропуска давно никто не проверяет — промзона ничья, как и карьер.")
			return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"ToQuarry":
			return [["Спуститься в карьер", "use"]]
		"WestRoad", "EastRoad":
			return [["Уйти (карта мира)", "use"]]
		"GokSign":
			return [["Прочитать", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"ToQuarry":
			return "Серпантин уходит вниз, в карьер. Ограждение здесь разобрано."
		"WestRoad":
			return "Тракт обратно на запад — к Нью-Рбе."
		"EastRoad":
			return "Дорога на восток — к плотине Вилюйской ГЭС."
		"GokSign":
			return "Ржавая вывеска на воротах промзоны."
	return super.describe(it)
