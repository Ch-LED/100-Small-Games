class_name SimonSettings
## Loads simon.cfg into typed section dictionaries.

const PATH := "res://06-simon/simon.cfg"


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("SimonSettings: cannot load %s" % PATH)
		return {}
	return {
		"field": {
			"bg_color": _color(file, "field", "bg_color", Color("0C1014")),
			"hub_color": _color(file, "field", "hub_color", Color("1A2028")),
			"pad_colors": _colors(file, "field", "pad_colors", _default_pads()),
			"dim_amount": file.get_value("field", "dim_amount", 0.62),
			"outer_radius": file.get_value("field", "outer_radius", 236.0),
			"inner_radius": file.get_value("field", "inner_radius", 96.0),
			"gap_deg": file.get_value("field", "gap_deg", 5.0),
			"segments": int(file.get_value("field", "segments", 20)),
		},
		"play": {
			"base_step": file.get_value("play", "base_step", 0.62),
			"step_decay": file.get_value("play", "step_decay", 0.018),
			"min_step": file.get_value("play", "min_step", 0.24),
			"flash_ratio": file.get_value("play", "flash_ratio", 0.62),
			"start_length": int(file.get_value("play", "start_length", 1)),
			"fail_pause": file.get_value("play", "fail_pause", 0.9),
			"auto_step": file.get_value("play", "auto_step", 0.35),
			"input_flash": file.get_value("play", "input_flash", 0.18),
			"round_pause": file.get_value("play", "round_pause", 0.9),
		},
		"overlay": {
			"dot_size": file.get_value("overlay", "dot_size", 14.0),
			"dot_gap": file.get_value("overlay", "dot_gap", 8.0),
			"dot_y_margin": file.get_value("overlay", "dot_y_margin", 64.0),
			"state_font_size": int(file.get_value("overlay", "state_font_size", 10)),
			"state_x": file.get_value("overlay", "state_x", 10.0),
			"state_y": file.get_value("overlay", "state_y", 72.0),
		},
		"hud": {
			"font_size": int(file.get_value("hud", "font_size", 16)),
			"margin": file.get_value("hud", "margin", 24.0),
		},
	}


static func _default_pads() -> Array[Color]:
	return [Color("2ECC71"), Color("E74C3C"), Color("F1C40F"), Color("3498DB")]


static func _color(file: ConfigFile, section: String, key: String,
		fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


## Reads a list of hex colours, one entry per pad. The result is typed, so it can
## be assigned straight into an `Array[Color]` field downstream.
static func _colors(file: ConfigFile, section: String, key: String,
		fallback: Array[Color]) -> Array[Color]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[Color] = []
	if raw is Array:
		for value in raw:
			if value is String and Color.html_is_valid(value):
				out.append(Color.html(value))
	return out if not out.is_empty() else fallback
