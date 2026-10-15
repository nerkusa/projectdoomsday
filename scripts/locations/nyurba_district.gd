class_name NyurbaDistrict
extends Act1Location
## Общее для районов Нью-Рбы: переходы между районами по улицам (To* → другая локация).
## С карты мира попадаешь только в Проход (через ворота).

## имя выхода → [локация, точка появления, подпись]
var links := {}


func status_line() -> String:
	return "2062 · Нью-Рба"


func on_interact(it: Interactable) -> bool:
	var n := String(it.name)
	if links.has(n):
		if not ResourceLoader.exists("res://scenes/locations/%s.tscn" % str(links[n][0])):
			main.think("Туда пока не пройти: улицу перегородили.")
			return true
		main.load_location(str(links[n][0]), str(links[n][1]))
		return true
	if it.has_meta("junk"):
		_rummage(it)
		return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if links.has(n):
		return [["Перейти: " + str(links[n][2]), "use"]]
	if it.has_meta("junk"):
		return [["Порыться", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	var n := String(it.name)
	if links.has(n):
		return "Улица ведёт дальше — %s." % str(links[n][2]).to_lower()
	if it.has_meta("junk"):
		return str(JUNK_DESC.get(str(it.get_meta("junk")), "Гора мусора. Кто знает, что в ней."))
	return ""


# ---------------- мусор: порыться можно раз в сутки ----------------
const JUNK_DESC := {
	"nr_junk_bags": "Чёрные мешки, лопнувшие по швам. Воняет.",
	"nr_junk_scrap": "Ржавое железо: листы, трубы, обрезки арматуры.",
	"nr_junk_furniture": "Сломанные стулья, комод без ящиков, диван с вылезшими пружинами.",
	"nr_junk_tires": "Покрышки стопкой. В них любят прятать заначки.",
	"nr_dumpster": "Железный бак на колёсиках, крышка откинута.",
}
## Что попадается: [предмет, шанс, сколько]
const JUNK_LOOT := {
	"nr_junk_bags": [["rusks", 0.25, 1], ["t_button", 0.2, 1], ["t_postcard", 0.15, 1], ["candle", 0.15, 1], ["rubles", 0.2, 2], ["matches", 0.15, 1]],
	"nr_junk_scrap": [["scrap_iron", 0.6, 2], ["copper_wire", 0.3, 1], ["spring", 0.1, 1], ["screwdriver", 0.05, 1]],
	"nr_junk_furniture": [["firewood", 0.5, 2], ["t_comb", 0.15, 1], ["t_photo", 0.15, 1], ["rubles", 0.25, 3], ["t_coin", 0.15, 1]],
	"nr_junk_tires": [["ammo9", 0.2, 3], ["rubles", 0.3, 4], ["t_lighter", 0.15, 1], ["flask", 0.1, 1]],
	"nr_dumpster": [["rusks", 0.2, 1], ["dried_fish", 0.15, 1], ["beer", 0.15, 1], ["bandage", 0.15, 1], ["rope", 0.1, 1], ["rubles", 0.2, 2]],
}
const JUNK_EMPTY := ["Тряпьё, битое стекло, очистки. Ничего.", "Только крысы разбежались. Пусто.",
	"Кто-то уже всё перерыл до меня.", "Ржавые банки и мокрая бумага. Не повезло."]


func _rummage(it: Interactable) -> void:
	var key := "junk_" + location_id + "_" + String(it.name)
	if int(ws().misc.get(key, -1)) == Clock.day():
		main.think("Здесь я сегодня уже рылся. Завтра натащат нового.")
		return
	ws().misc[key] = Clock.day()
	main.sfx("rustle", -4.0)
	var kind := str(it.get_meta("junk"))
	var found := []
	var bonus := 0.05 * maxi(0, int(Game.effective_skills().get("Внимательность", 0)))
	for e in JUNK_LOOT.get(kind, JUNK_LOOT["nr_junk_bags"]):
		if randf() < float(e[1]) + bonus:
			found.append({"id": str(e[0]), "n": randi_range(1, int(e[2])), "name": DB.item_name(str(e[0]))})
	if found.is_empty():
		main.think(JUNK_EMPTY[randi() % JUNK_EMPTY.size()])
		return
	main.loot_win.open(it.title(), found, func(e):
		Game.add_item(e.id, int(e.get("n", 1)))
		return true)
