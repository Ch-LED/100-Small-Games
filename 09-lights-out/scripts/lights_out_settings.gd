class_name LightsOutSettings
## Loads lights-out.cfg into typed section dictionaries.

const PATH := "res://09-lights-out/lights-out.cfg"

## Fixed logical field. Kept here so the HUD and the overlay agree without one
## reaching into the other for it.
const FIELD := Vector2(1280.0, 720.0)


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("LightsOutSettings: cannot load %s" % PATH)
		return {}
	return {
		"board": {
			"bg_color": _color(file, "board", "bg_color", Color("0A0E18")),
			"panel_color": _color(file, "board", "panel_color", Color("141B2B")),
			"off_color": _color(file, "board", "off_color", Color("2A3550")),
			"on_color": _color(file, "board", "on_color", Color("FFD24A")),
			"hint_color": _color(file, "board", "hint_color", Color("4BD3FF")),
			"cursor_color": _color(file, "board", "cursor_color", Color("F2F5F7")),
			"hint_border": int(file.get_value("board", "hint_border", 4)),
			"cell_size": file.get_value("board", "cell_size", 88.0),
			"gap": file.get_value("board", "gap", 12.0),
			"corner_radius": int(file.get_value("board", "corner_radius", 10)),
		},
		"play": {
			"start_presses": int(file.get_value("play", "start_presses", 3)),
			"presses_step": int(file.get_value("play", "presses_step", 1)),
			"presses_cap": int(file.get_value("play", "presses_cap", 12)),
			"solve_pause": file.get_value("play", "solve_pause", 1.2),
		},
		"audio": {
			"press_tones": _float_array(file, "audio", "press_tones",
					[392.00, 440.00, 493.88, 523.25, 587.33]),
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


static func _float_array(file: ConfigFile, section: String, key: String,
		fallback: Array[float]) -> Array[float]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[float] = []
	if raw is Array:
		for value in raw:
			out.append(float(value))
	return out if not out.is_empty() else fallback
