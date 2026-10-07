class_name PacmanSettings
## Loads pacman.cfg into typed section dictionaries.

const PATH := "res://03-pacman/pacman.cfg"


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("PacmanSettings: cannot load %s" % PATH)
		return {}
	return {
		"field": {
			"bg_color": _color(file, "field", "bg_color", Color.BLACK),
			"cell_size": file.get_value("field", "cell_size", 23.0),
		},
		"assets": {
			"layers_dir": file.get_value("assets", "layers_dir", ""),
			"maze_tiles": file.get_value("assets", "maze_tiles", ""),
			"ghost_door": file.get_value("assets", "ghost_door", ""),
			"layout": file.get_value("assets", "layout", ""),
		},
		"player": {
			"speed": file.get_value("player", "speed", 105.0),
			"death_time": file.get_value("player", "death_time", 1.3),
			"start_lives": int(file.get_value("player", "start_lives", 3)),
			"extra_life_score": int(file.get_value("player", "extra_life_score", 10000)),
		},
		"ghost": {
			"speed": file.get_value("ghost", "speed", 95.0),
			"fright_speed": file.get_value("ghost", "fright_speed", 62.0),
			"tunnel_speed": file.get_value("ghost", "tunnel_speed", 58.0),
			"eaten_speed": file.get_value("ghost", "eaten_speed", 210.0),
			"release_delays": _floats(file, "ghost", "release_delays", [0.0, 2.0, 5.0, 9.0]),
			"mode_durations": _floats(file, "ghost", "mode_durations",
					[7.0, 20.0, 7.0, 20.0, 5.0, 20.0, 5.0, 100000.0]),
			"fright_time": file.get_value("ghost", "fright_time", 7.0),
			"fright_time_min": file.get_value("ghost", "fright_time_min", 1.0),
			"fright_time_step": file.get_value("ghost", "fright_time_step", 0.8),
		},
		"scoring": {
			"pellet": int(file.get_value("scoring", "pellet", 10)),
			"power_pellet": int(file.get_value("scoring", "power_pellet", 50)),
			"ghosts": _ints(file, "scoring", "ghosts", [200, 400, 800, 1600]),
		},
		"fruit": {
			"lifetime": file.get_value("fruit", "lifetime", 9.5),
			"spawn_at": _ints(file, "fruit", "spawn_at", [70, 170]),
			"types": _strings(file, "fruit", "types", ["cherry", "strawberry", "orange", "apple"]),
		},
		"level": {
			"ghost_speed_step": file.get_value("level", "ghost_speed_step", 3.0),
			"level_cap": int(file.get_value("level", "level_cap", 8)),
		},
		"hud": {
			"font_size": int(file.get_value("hud", "font_size", 24)),
			"margin": file.get_value("hud", "margin", 12.0),
		},
	}


static func _color(file: ConfigFile, section: String, key: String,
		fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


static func _floats(file: ConfigFile, section: String, key: String, fallback: Array) -> Array:
	var raw: Variant = file.get_value(section, key, fallback)
	var out: Array = []
	if raw is Array:
		for v in raw:
			out.append(float(v))
	return out if not out.is_empty() else fallback


static func _ints(file: ConfigFile, section: String, key: String, fallback: Array) -> Array:
	var raw: Variant = file.get_value(section, key, fallback)
	var out: Array = []
	if raw is Array:
		for v in raw:
			out.append(int(v))
	return out if not out.is_empty() else fallback


static func _strings(file: ConfigFile, section: String, key: String, fallback: Array) -> Array:
	var raw: Variant = file.get_value(section, key, fallback)
	var out: Array = []
	if raw is Array:
		for v in raw:
			out.append(str(v))
	return out if not out.is_empty() else fallback
