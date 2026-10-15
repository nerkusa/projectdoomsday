extends NyurbaDistrict
## Нью-Рба, Промрайон — цеха огранки и напыления, приёмка сырья под охраной, склад
## продукции, заводская столовая. Здесь хозяин — промышленник Кеша; здесь видно, что
## алмазный порошок в цех приходит «не тот».


func _ready() -> void:
	location_id = "nyurba_prom"
	title = "Нью-Рба · Промрайон"
	links = {"ToProxod": ["nyurba", "FromProm", "Проход"], "ToBlack": ["nyurba_black", "FromProm", "Чёрный район"]}
	arrive_thought = "Промрайон. Гудят станки, из труб валит дым, пахнет горелым металлом. Город держится на этих цехах."
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"Cutters":
			if Game.flag("nr_kesha_pal"):
				main.think("Резцы «с алмазным напылением». Провёл ногтем — напыление сыплется, как сахар. Кеша прав: это паль.")
			else:
				main.think("Ящик резцов с клеймом «НР — алмазное напыление». Блестят. Один, правда, уже со сколом.")
			return true
		"Cart":
			main.think("Вагонетка с породой. Камни серые, пустые — из таких алмазов не выйдет.")
			return true
	return super.on_interact(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Cutters":
			return "Ящик с готовыми резцами на верстаке."
		"Cart":
			return "Ржавая вагонетка на узкоколейке."
	return super.describe(it)
