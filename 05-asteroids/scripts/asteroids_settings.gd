class_name AsteroidsSettings
## Loads asteroids.cfg into typed section dictionaries.

const PATH := "res://05-asteroids/asteroids.cfg"

## Index into the per-size arrays (radius / score / speed / spin).
const LARGE := 0
const MEDIUM := 1
const SMALL := 2


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("AsteroidsSettings: cannot load %s" % PATH)
		return {}
	return {
		"field": {
			"bg_color": _color(file, "field", "bg_color", Color("0B0F1A")),
			"star_color": _color(file, "field", "star_color", Color("2E4166")),
			"star_count": int(file.get_value("field", "star_count", 90)),
			"star_min": file.get_value("field", "star_min", 1.0),
			"star_max": file.get_value("field", "star_max", 2.2),
			"ship_color": _color(file, "field", "ship_color", Color("E8F1FF")),
			"invuln_color": _color(file, "field", "invuln_color", Color("57D97B")),
			"thrust_color": _color(file, "field", "thrust_color", Color("FFB84D")),
			"rock_color": _color(file, "field", "rock_color", Color("8FA6C8")),
			"saucer_color": _color(file, "field", "saucer_color", Color("FF6B8A")),
			"bullet_color": _color(file, "field", "bullet_color", Color("FFF3B0")),
		},
		"ship": {
			"rotate_speed": file.get_value("ship", "rotate_speed", 250.0),
			"thrust_accel": file.get_value("ship", "thrust_accel", 380.0),
			"drag": file.get_value("ship", "drag", 0.45),
			"max_speed": file.get_value("ship", "max_speed", 430.0),
			"radius": file.get_value("ship", "radius", 14.0),
			"lives": int(file.get_value("ship", "lives", 3)),
			"fire_cooldown": file.get_value("ship", "fire_cooldown", 0.16),
			"max_bullets": int(file.get_value("ship", "max_bullets", 4)),
			"invuln_time": file.get_value("ship", "invuln_time", 2.2),
			"death_pause": file.get_value("ship", "death_pause", 1.6),
			"safe_spawn_radius": file.get_value("ship", "safe_spawn_radius", 130.0),
		},
		"bullet": {
			"speed": file.get_value("bullet", "speed", 680.0),
			"lifetime": file.get_value("bullet", "lifetime", 1.05),
			"radius": file.get_value("bullet", "radius", 3.0),
			"length": file.get_value("bullet", "length", 11.0),
		},
		"rock": {
			"radius": _float_array(file, "rock", "radius", [46.0, 26.0, 14.0]),
			"score": _int_array(file, "rock", "score", [20, 50, 100]),
			"speed_min": _float_array(file, "rock", "speed_min", [46.0, 72.0, 104.0]),
			"speed_max": _float_array(file, "rock", "speed_max", [88.0, 132.0, 186.0]),
			"spin_min": _float_array(file, "rock", "spin_min", [-70.0, -115.0, -165.0]),
			"spin_max": _float_array(file, "rock", "spin_max", [70.0, 115.0, 165.0]),
			"level_speedup": file.get_value("rock", "level_speedup", 1.06),
			"level_speedup_cap": int(file.get_value("rock", "level_speedup_cap", 8)),
			"vertices_min": int(file.get_value("rock", "vertices_min", 9)),
			"vertices_max": int(file.get_value("rock", "vertices_max", 13)),
			"jaggedness": file.get_value("rock", "jaggedness", 0.34),
		},
		"wave": {
			"start_count": int(file.get_value("wave", "start_count", 4)),
			"count_step": int(file.get_value("wave", "count_step", 2)),
			"count_cap": int(file.get_value("wave", "count_cap", 11)),
		},
		"saucer": {
			"first_delay": file.get_value("saucer", "first_delay", 9.0),
			"interval_min": file.get_value("saucer", "interval_min", 16.0),
			"interval_max": file.get_value("saucer", "interval_max", 28.0),
			"speed": file.get_value("saucer", "speed", 150.0),
			"radius": file.get_value("saucer", "radius", 16.0),
			"score": int(file.get_value("saucer", "score", 200)),
			"fire_interval": file.get_value("saucer", "fire_interval", 1.35),
			"aim_chance": file.get_value("saucer", "aim_chance", 0.55),
			"bullet_speed": file.get_value("saucer", "bullet_speed", 420.0),
			"y_min": file.get_value("saucer", "y_min", 90.0),
			"y_max": file.get_value("saucer", "y_max", 300.0),
		},
		"beat": {
			"slow": file.get_value("beat", "slow", 1.05),
			"fast": file.get_value("beat", "fast", 0.26),
		},
		"fx": {
			"shards": int(file.get_value("fx", "shards", 9)),
			"length": file.get_value("fx", "length", 11.0),
			"duration": file.get_value("fx", "duration", 0.45),
			"spread": file.get_value("fx", "spread", 140.0),
			"size_scale": _float_array(file, "fx", "size_scale", [1.35, 1.15, 1.0]),
			"ship_scale": file.get_value("fx", "ship_scale", 1.5),
			"ship_duration": file.get_value("fx", "ship_duration", 0.8),
		},
		"score": {
			"extra_life": int(file.get_value("score", "extra_life", 10000)),
		},
		"hud": {
			"font_size": int(file.get_value("hud", "font_size", 16)),
			"margin": file.get_value("hud", "margin", 20.0),
			"lives_icon_scale": file.get_value("hud", "lives_icon_scale", 0.72),
		},
	}


static func _color(file: ConfigFile, section: String, key: String,
		fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


static func _float_array(file: ConfigFile, section: String, key: String,
		fallback: Array) -> Array:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array = []
	if raw is Array:
		for v in raw:
			out.append(float(v))
	return out if not out.is_empty() else fallback


static func _int_array(file: ConfigFile, section: String, key: String,
		fallback: Array) -> Array:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array = []
	if raw is Array:
		for v in raw:
			out.append(int(v))
	return out if not out.is_empty() else fallback
