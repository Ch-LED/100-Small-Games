class_name Game2048Settings
## Loads twenty48.cfg into typed section dictionaries.

const PATH := "res://08-twenty48/twenty48.cfg"

## Fixed logical field. Kept here so the HUD and the overlay agree without one
## reaching into the other for it.
const FIELD := Vector2(1280.0, 720.0)


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("Game2048Settings: cannot load %s" % PATH)
		return {}
	return {
		"board": {
			"bg_color": _color(file, "board", "bg_color", Color("FAF8EF")),
			"panel_color": _color(file, "board", "panel_color", Color("BBADA0")),
			"empty_color": _color(file, "board", "empty_color", Color("CDC1B4")),
			"spawn_four_chance": file.get_value("board", "spawn_four_chance", 0.1),
			"tile_size": file.get_value("board", "tile_size", 130.0),
			"gap": file.get_value("board", "gap", 14.0),
			"corner_radius": int(file.get_value("board", "corner_radius", 8)),
			"font_sizes": _int_array(file, "board", "font_sizes", [40, 32, 24, 16]),
		},
		"tiles": {
			"values": _int_array(file, "tiles", "values", _default_values()),
			"colors": _colors(file, "tiles", "colors", _default_colors()),
			"dark_text_color": _color(file, "tiles", "dark_text_color", Color("776E65")),
			"light_text_color": _color(file, "tiles", "light_text_color", Color("F9F6F2")),
			"dark_text_upto": int(file.get_value("tiles", "dark_text_upto", 4)),
		},
		"audio": {
			"merge_tones": _float_array(file, "audio", "merge_tones",
					[220.00, 233.08, 246.94, 261.63, 277.18, 293.66, 311.13]),
		},
		"hud": {
			"font_size": int(file.get_value("hud", "font_size", 16)),
			"margin": file.get_value("hud", "margin", 24.0),
		},
	}


static func _default_values() -> Array[int]:
	return [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]


static func _default_colors() -> Array[Color]:
	return [
		Color("EEE4DA"), Color("EDE0C8"), Color("F2B179"), Color("F59563"),
		Color("F67C5F"), Color("F65E3B"), Color("EDCF72"), Color("EDCC61"),
		Color("EDC850"), Color("EDC53F"), Color("EDC22E"), Color("3C3A32"),
	]


static func _color(file: ConfigFile, section: String, key: String,
		fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


## Typed results, so they can be assigned straight into typed fields downstream.
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
