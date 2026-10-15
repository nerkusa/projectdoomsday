extends NyurbaDistrict
## Нью-Рба, коллектор под Проходом: люк во дворе бара «Забой» — вниз; на том конце —
## скобы в Чёрный район. Здесь живут бичи; в насосной — слесарь водоканала.


func _ready() -> void:
	location_id = "nyurba_sewer"
	title = "Нью-Рба · коллектор"
	links = {"UpProxod": ["nyurba", "FromSewer", "Наверх, в Проход"], "UpBlack": ["nyurba_black", "FromSewer", "Наверх, в Чёрный район"]}
	arrive_thought = "Коллектор. Темно, капает, по дну течёт что-то чёрное. Где-то впереди — огонь и голоса."
	super._ready()


func status_line() -> String:
	return "2062 · Нью-Рба · под землёй"


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"Valve":
			main.think("Вентиль прикипел намертво. На нём краской: «НЕ КРУТИТЬ! — Водоканал». Кто-то дописал: «а то что?»")
			return true
		"Pumps":
			main.think("Насосы «Ливны», довоенные. Один разобран на запчасти, второй ещё гудел бы — будь ток.")
			return true
	return super.on_interact(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Valve":
			return "Красный вентиль задвижки."
		"Pumps":
			return "Два насоса на бетонных тумбах."
	return super.describe(it)
