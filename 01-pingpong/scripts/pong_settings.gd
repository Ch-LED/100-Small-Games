class_name PongSettings
## Loads pingpong.cfg into typed section dictionaries.
## Call load_all() once; each returned section holds parsed floats and Colors.

const PATH := "res://01-pingpong/pingpong.cfg"


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("PongSettings: cannot load %s" % PATH)
		return {}

	var cfg := {}
	cfg["field"] = {"bg_color": _color(file, "field", "bg_color", Color(0.89, 0.9, 0.91))}

	cfg["center_line"] = {
		"color": _color(file, "center_line", "color"),
		"alpha": file.get_value("center_line", "alpha", 0.45),
		"width": file.get_value("center_line", "width", 8.0),
	}

	cfg["ball"] = {
		"radius": file.get_value("ball", "radius", 11.0),
		"speed": file.get_value("ball", "speed", 520.0),
		"color": _color(file, "ball", "color", Color(1.0, 0.55, 0.35)),
		"color_alpha": file.get_value("ball", "color_alpha", 1.0),
		"speed_boost_per_hit": file.get_value("ball", "speed_boost_per_hit", 0.05),
		"serve_pause": file.get_value("ball", "serve_pause", 2.0),
		"serve_min_deg": file.get_value("ball", "serve_min_deg", 12.0),
		"serve_max_deg": file.get_value("ball", "serve_max_deg", 32.0),
		"reflect_curve": file.get_value("ball", "reflect_curve", 0.55),
		"random_deflect_deg": file.get_value("ball", "random_deflect_deg", 4.0),
		"min_dir_x": file.get_value("ball", "min_dir_x", 0.30),
	}

	cfg["paddle"] = {
		"width": file.get_value("paddle", "width", 16.0),
		"height": file.get_value("paddle", "height", 120.0),
		"edge_distance": file.get_value("paddle", "edge_distance", 36.0),
		"max_speed": file.get_value("paddle", "max_speed", 900.0),
		"left_color": _color(file, "paddle", "left_color", Color(0.18, 0.42, 0.84)),
		"right_color": _color(file, "paddle", "right_color", Color(0.88, 0.26, 0.23)),
	}

	cfg["ai"] = {
		"cooldown_enabled": file.get_value("ai", "cooldown_enabled", true),
		"reaction_min": file.get_value("ai", "reaction_min", 0.08),
		"reaction_max": file.get_value("ai", "reaction_max", 0.12),
		"dead_zone": file.get_value("ai", "dead_zone", 6.0),
	}

	cfg["scoreboard"] = {
		"font_size": file.get_value("scoreboard", "font_size", 300.0),
		"alpha": file.get_value("scoreboard", "alpha", 0.38),
	}

	return cfg


static func _color(file: ConfigFile, section: String, key: String, fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
