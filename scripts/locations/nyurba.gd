extends NyurbaDistrict
## Нью-Рба, Проход — вход в город и низы: ворота с охраной, Алмазный банк, ломбард,
## бар «Забой», лавки в лабазах, склады. Бичи у бочек, «забойские» во дворе за баром.


func _ready() -> void:
	location_id = "nyurba"
	title = "Нью-Рба · Проход"
	links = {"ToCenter": ["nyurba_center", "FromProxod", "Центр"], "ToProm": ["nyurba_prom", "FromProxod", "Промрайон"]}
	arrive_thought = "Нью-Рба. Бетонная стена, автоматчики на вышках, над воротами — шпиль с часами. Город, где продаётся всё."
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"ToRoad":
			main.world_map.open(location_id)
			return true
		"Fountain":
			main.think("Фонтан сухой лет двадцать. На дне — окурки, битое стекло и одна монета: её никто не берёт — говорят, к удаче.")
			return true
		"InfoScreen":
			main.think("Экран у ворот: «Вход — 5 р. с носа. Оружие — в чехол. Алмазный банк: вклады под 3 % в месяц». Внизу бегущая строка: «Нью-Рба — город возможностей».")
			return true
	return super.on_interact(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Fountain":
			return "Каменная чаша с колонной посередине, воды нет."
		"InfoScreen":
			return "Уличный экран на столбе, янтарные буквы."
	return super.describe(it)
