class_name Audio
extends RefCounted
## Громкость: шины Master («Общая»), SFX («Эффекты» — выстрелы, удары, щелчки)
## и Ambient («Окружение» — дождь, ветер, гром). Уровни 0..100 хранятся
## в Game.settings (vol_master, vol_sfx, vol_ambient), применяются при старте
## и сразу при изменении ползунка в меню.

const BUSES := [["vol_master", "Master", "Общая громкость"], ["vol_sfx", "SFX", "Эффекты"], ["vol_ambient", "Ambient", "Окружение и погода"]]


static func ensure_buses() -> void:
	for b in BUSES:
		if b[1] == "Master":
			continue
		if AudioServer.get_bus_index(b[1]) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b[1])
			AudioServer.set_bus_send(i, "Master")


static func level(id: String) -> int:
	return int(Game.settings.get(id, 80))


static func set_level(id: String, v: int) -> void:
	Game.settings[id] = clampi(v, 0, 100)
	apply()


static func apply() -> void:
	ensure_buses()
	for b in BUSES:
		var i := AudioServer.get_bus_index(b[1])
		var v := level(b[0])
		AudioServer.set_bus_mute(i, v <= 0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v / 100.0, 0.001)))
