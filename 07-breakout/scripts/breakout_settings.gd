class_name BreakoutSettings
## Loads breakout.cfg into typed section dictionaries.

const PATH := "res://07-breakout/breakout.cfg"


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("BreakoutSettings: cannot load %s" % PATH)
		return {}
	return {
		"field": {
			"bg_color": _color(file, "field", "bg_color", Color("0E1116")),
			"wall_color": _color(file, "field", "wall_color", Color("2C3946")),
			"ball_color": _color(file, "field", "ball_color", Color("F2F5F7")),
			"paddle_color": _color(file, "field", "paddle_color", Color("5AD1E6")),
			"margin_x": file.get_value("field", "margin_x", 40.0),
			"wall_top": file.get_value("field", "wall_top", 40.0),
			"wall_thickness": file.get_value("field", "wall_thickness", 40.0),
			"cols": int(file.get_value("field", "cols", 14)),
			"brick_height": file.get_value("field", "brick_height", 26.0),
			"brick_gap": file.get_value("field", "brick_gap", 6.0),
			"brick_top": file.get_value("field", "brick_top", 80.0),
			"brick_colors": _colors(file, "field", "brick_colors", _default_colors()),
			"brick_scores": _int_array(file, "field", "brick_scores", _default_scores()),
			"row_tones": _float_array(file, "field", "row_tones", _default_tones()),
		},
		"ball": {
			"radius": file.get_value("ball", "radius", 9.0),
			"speed": file.get_value("ball", "speed", 430.0),
			"max_speed": file.get_value("ball", "max_speed", 760.0),
			"speed_boost_per_hit": file.get_value("ball", "speed_boost_per_hit", 0.012),
			"min_angle_from_horizontal_deg": file.get_value(
					"ball", "min_angle_from_horizontal_deg", 22.0),
			"paddle_curve": file.get_value("ball", "paddle_curve", 0.9),
			"random_deflect_deg": file.get_value("ball", "random_deflect_deg", 2.0),
			"launch_min_deg": file.get_value("ball", "launch_min_deg", 58.0),
			"launch_max_deg": file.get_value("ball", "launch_max_deg", 80.0),
			"attach_offset": file.get_value("ball", "attach_offset", 24.0),
			"max_bounces": int(file.get_value("ball", "max_bounces", 8)),
		},
		"paddle": {
			"width": file.get_value("paddle", "width", 140.0),
			"height": file.get_value("paddle", "height", 18.0),
			"bottom_margin": file.get_value("paddle", "bottom_margin", 64.0),
			"max_speed": file.get_value("paddle", "max_speed", 900.0),
			"cheat_width_scale": file.get_value("paddle", "cheat_width_scale", 1.8),
		},
		"play": {
			"lives": int(file.get_value("play", "lives", 3)),
			"life_pause": file.get_value("play", "life_pause", 0.8),
			"level_pause": file.get_value("play", "level_pause", 1.2),
			"speed_step": file.get_value("play", "speed_step", 1.08),
			"level_speedup_cap": int(file.get_value("play", "level_speedup_cap", 8)),
		},
		"hud": {
			"font_size": int(file.get_value("hud", "font_size", 16)),
			"margin": file.get_value("hud", "margin", 24.0),
		},
	}


static func _default_colors() -> Array[Color]:
	return [
		Color("E74C3C"), Color("E67E22"), Color("F1C40F"), Color("2ECC71"),
		Color("1ABC9C"), Color("3498DB"), Color("9B59B6"), Color("95A5A6"),
	]


static func _default_scores() -> Array[int]:
	return [7, 7, 5, 5, 3, 3, 1, 1]


static func _default_tones() -> Array[float]:
	return [1046.50, 880.00, 783.99, 659.25, 523.25, 440.00, 349.23, 261.63]


static func _color(file: ConfigFile, section: String, key: String,
		fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


## Typed results, so they can be assigned straight into `Array[Color]` fields.
static func _colors(file: ConfigFile, section: String, key: String,
		fallback: Array[Color]) -> Array[Color]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[Color] = []
	if raw is Array:
		for value in raw:
			if value is String and Color.html_is_valid(value):
				out.append(Color.html(value))
	return out if not out.is_empty() else fallback


static func _float_array(file: ConfigFile, section: String, key: String,
		fallback: Array[float]) -> Array[float]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[float] = []
	if raw is Array:
		for value in raw:
			out.append(float(value))
	return out if not out.is_empty() else fallback


static func _int_array(file: ConfigFile, section: String, key: String,
		fallback: Array[int]) -> Array[int]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[int] = []
	if raw is Array:
		for value in raw:
			out.append(int(value))
	return out if not out.is_empty() else fallback
