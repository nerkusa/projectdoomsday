extends Node
## Проверка: загружает все скрипты проекта и сообщает об ошибках.
## Заодно проверяет диалоги на метагейминг: реплика, которая двигает задание,
## должна быть доступна только по пути, где проверено это задание (или сюжетный флаг).
## Иначе можно, например, сдать задание, которое ещё не взял.
## Запуск: godot --headless --path . res://tools/check.tscn

func _ready() -> void:
	var bad := 0
	for p in _files("res://scripts"):
		var s = load(p)
		if s == null or not (s as Script).can_instantiate():
			print("ОШИБКА: ", p)
			bad += 1
	bad += _check_dialogs()
	print("Проверено, ошибок: ", bad)
	get_tree().quit(1 if bad else 0)


func _files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_files(dir + "/" + sub))
	return out


# ---------------- диалоги: нет ли метагейминга ----------------
var _seen := {}
var _bad := []


func _check_dialogs() -> int:
	_bad = []
	var dir := "res://data/dialogs"
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + f))
		if typeof(d) != TYPE_DICTIONARY or not d.has("nodes"):
			continue
		var nodes: Dictionary = d.nodes
		# входы — узлы, в которые не ведёт ни одна реплика (их открывает скрипт)
		var targeted := {}
		for nid in nodes:
			for o in nodes[nid].get("options", []):
				if o.get("next") != null:
					targeted[str(o.next)] = true
				for k in ["success", "fail"]:
					if o.has(k):
						targeted[str(o[k])] = true
		_seen = {}
		for nid in nodes:
			if not targeted.has(nid) or nid == "start":
				_walk(f, nodes, str(nid), {})
	for b in _bad:
		print("МЕТАГЕЙМИНГ: ", b)
	return _bad.size()


const MONEY := ["rubles", "salt"]


func _takes_thing(d: Dictionary) -> bool:
	for k in d.get("take", {}):
		if not str(k) in MONEY:
			return true
	return false


## Что «знает» путь: задания, проверенные в условиях if
func _gate(g: Dictionary, c: Dictionary) -> Dictionary:
	var out := g.duplicate()
	if c.has("quest"):
		out[str(c.quest)] = true
	return out


func _walk(f: String, nodes: Dictionary, nid: String, g: Dictionary) -> void:
	var key := nid + "|" + ",".join(g.keys())
	if _seen.has(key) or not nodes.has(nid):
		return
	_seen[key] = true
	for o in nodes[nid].get("options", []):
		var c: Dictionary = o.get("if", {})
		var g2 := _gate(g, c)
		var outs := []
		for k in ["next", "success", "fail"]:
			if o.get(k) != null:
				outs.append(str(o[k]))
		# отдаёт вещь: вещь в условии или забирается репликой (деньги — это оплата, не сдача)
		var hand: bool = (c.has("item") and not str(c.item) in MONEY) or _takes_thing(o)
		_check_q(f, nid, str(o.get("text", "")), o.get("quest", {}), g2, hand)
		for t in outs:
			if nodes.has(t):
				_check_q(f, t, str(o.get("text", "")), nodes[t].get("quest", {}), g2, hand or _takes_thing(nodes[t]))
				_walk(f, nodes, t, g2)


## Метагейминг: отдаёшь вещь — и задание идёт дальше первого этапа,
## хотя на пути не проверено, что ты его вообще брал
func _check_q(f: String, nid: String, text: String, q, g: Dictionary, hand: bool) -> void:
	if typeof(q) != TYPE_DICTIONARY or not q.has("id") or not hand:
		return
	if int(q.get("stage", 0)) < 2 or g.has(str(q.id)):
		return
	var msg := "%s / %s: «%s» → %s этап %d — задание не проверено" % [f, nid, text.left(40), q.id, int(q.get("stage", 0))]
	if not msg in _bad:
		_bad.append(msg)
