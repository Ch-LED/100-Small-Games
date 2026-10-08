class_name SnakeSettings
## Loads snake.cfg into typed section dictionaries.

const PATH := "res://04-snake/snake.cfg"

const DEFAULT_START_DIR := "right"


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("SnakeSettings: cannot load %s" % PATH)
		return {}
	return {
		"field": {
			"bg_color": _color(file, "field", "bg_color", Color("101826")),
			"board_color": _color(file, "field", "board_color", Color("16202E")),
			"grid_color": _color(file, "field", "grid_color", Color("22304A")),
			"border_color": _color(file, "field", "border_color", Color("3B5A7A")),
			"border_color_cheat": _color(file, "field", "border_color_cheat", Color("2B3B52")),
			"border_width": file.get_value("field", "border_width", 4.0),
		},
		"board": {
			"cell_size": file.get_value("board", "cell_size", 40.0),
			"cols": int(file.get_value("board", "cols", 30)),
			"rows": int(file.get_value("board", "rows", 15)),
		},
		"snake": {
			"start_length": int(file.get_value("snake", "start_length", 3)),
			"start_dir": str(file.get_value("snake", "start_dir", DEFAULT_START_DIR)),
			"base_interval": file.get_value("snake", "base_interval", 0.16),
			"interval_step": file.get_value("snake", "interval_step", 0.012),
			"min_interval": file.get_value("snake", "min_interval", 0.06),
			"growth_per_food": int(file.get_value("snake", "growth_per_food", 1)),
			"body_color": _color(file, "snake", "body_color", Color("57D97B")),
			"head_color": _color(file, "snake", "head_color", Color("C8F56A")),
			"dead_color": _color(file, "snake", "dead_color", Color("E0433A")),
			"segment_inset": file.get_value("snake", "segment_inset", 3.0),
			"wrap_edges": bool(file.get_value("snake", "wrap_edges", false)),
		},
		"food": {
			"color": _color(file, "food", "color", Color("FF5C5C")),
			"pulse_speed": file.get_value("food", "pulse_speed", 5.0),
			"pulse_min": file.get_value("food", "pulse_min", 0.75),
			"score": int(file.get_value("food", "score", 10)),
		},
		"level": {
			"foods_per_level": int(file.get_value("level", "foods_per_level", 5)),
			"level_cap": int(file.get_value("level", "level_cap", 10)),
		},
		"hud": {
			"font_size": int(file.get_value("hud", "font_size", 16)),
			"margin": file.get_value("hud", "margin", 24.0),
		},
	}


static func _color(file: ConfigFile, section: String, key: String,
		fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
