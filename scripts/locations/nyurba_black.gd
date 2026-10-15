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


func describe(it: Interactable) -> String:
	if String(it.name) == "Hatch":
		return "Открытый люк. Снизу тянет сыростью и дымом."
	return super.describe(it)
