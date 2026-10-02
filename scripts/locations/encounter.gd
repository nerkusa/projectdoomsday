extends Act1Location
## Случайная встреча в пути: одна поляна на все случаи. Кого поставить — берётся
## из data/world.json → encounters[Game.hero.flags["enc"]]: enemies (враги, к меткам E1..E5)
## и npcs (мирные, к меткам N1..N3, разговор — data/dialogs/enc_<шаблон>.json).
## Состояние поляны не хранится: каждая встреча — заново.

var enc_id := ""
var enc: Dictionary = {}


func _ready() -> void:
	location_id = "encounter"
	autosave_on_enter = false
	Game.world.erase("encounter")
	enc_id = str(Game.hero.flags.get("enc", "dogs"))
	enc = DB._load("res://data/world.json").get("encounters", {}).get(enc_id, {})
	title = str(enc.get("desc", "Тайга"))
	var chars := get_node("Characters")
	var i := 0
	for pair in enc.get("enemies", []):
		for k in int(pair[1]):
			i += 1
			_put(chars, str(pair[0]), "E%d" % i, true)
	i = 0
	for pair in enc.get("npcs", []):
		for k in int(pair[1]):
			i += 1
			_put(chars, str(pair[0]), "N%d" % i, false)
	var fire := get_node_or_null("Village/Campfire")
	if fire:
		fire.visible = enc.get("fire", false)
	super._ready()


func _put(parent: Node, tpl_id: String, mark: String, hostile_: bool) -> void:
	var m := get_node_or_null("Marks/" + mark) as Node3D
	var ch := Character.new()
	ch.name = "%s_%s" % [tpl_id, mark]
	ch.char_id = tpl_id
	ch.position = m.position if m else Vector3(28, 0, 18)
	ch.rotation.y = -PI / 2.0
	if hostile_:
		ch.hostile = true
		ch.aggro_radius = 12.0 if tpl_id == "chuchuna" else 9.0
		ch.squad = "enc"
	else:
		ch.dialog = "enc_" + tpl_id
		ch.armed = tpl_id == "jaeger"
	parent.add_child(ch)


func on_enter() -> void:
	super.on_enter()
	if not enc.get("enemies", []).is_empty():
		main.think("Они уже здесь. Не уйти — только драться или бежать к краю поляны.")


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win" and squad_cleared("enc"):
		main.think("Тихо. Можно обыскать и уходить.")
		main.hud.refresh_objective()


func objective() -> String:
	if not enc.get("enemies", []).is_empty() and not squad_cleared("enc"):
		return "Отбиться — или уйти краем поляны."
	return "Уйти краем поляны — дальше в путь."


func status_line() -> String:
	return "2062 · в пути · " + main.world_map.time_text().to_lower()
