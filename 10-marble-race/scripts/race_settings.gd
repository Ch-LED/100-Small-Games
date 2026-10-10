class_name RaceSettings
## Loads marble-race.cfg into typed section dictionaries.


const PATH := "res://10-marble-race/marble-race.cfg"


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("RaceSettings: cannot load %s" % PATH)
		return {}
	return {
		"ball": {
			"radius": file.get_value("ball", "radius", 0.5),
			"mass": file.get_value("ball", "mass", 1.0),
			"gravity_scale": file.get_value("ball", "gravity_scale", 1.0),
			"friction": file.get_value("ball", "friction", 3.0),
			"bounce": file.get_value("ball", "bounce", 0.15),
			"linear_damp": file.get_value("ball", "linear_damp", 1.0),
			"angular_damp": file.get_value("ball", "angular_damp", 3.0),
			"linear_damp_active": file.get_value("ball", "linear_damp_active", 0.05),
			"angular_damp_active": file.get_value("ball", "angular_damp_active", 0.15),
			"spin_torque": file.get_value("ball", "spin_torque", 5.0),
			"turn_boost": file.get_value("ball", "turn_boost", 1.0),
			"min_turn_speed": file.get_value("ball", "min_turn_speed", 1.0),
			"ground_glue": bool(file.get_value("ball", "ground_glue", true)),
			"ground_glue_distance": file.get_value("ball", "ground_glue_distance", 1.2),
			"max_speed": file.get_value("ball", "max_speed", 34.0),
		},
		"camera": {
			"distance": file.get_value("camera", "distance", 7.0),
			"height": file.get_value("camera", "height", 2.5),
			"look_height": file.get_value("camera", "look_height", 0.6),
			"follow_damp": file.get_value("camera", "follow_damp", 8.0),
			"pitch_min": file.get_value("camera", "pitch_min", 5.0),
			"pitch_max": file.get_value("camera", "pitch_max", 75.0),
			"mouse_sensitivity": file.get_value("camera", "mouse_sensitivity", 0.0022),
			"align_distance": file.get_value("camera", "align_distance", 8.0),
			"align_damp": file.get_value("camera", "align_damp", 3.0),
		},
		"play": {
			"fall_margin": file.get_value("play", "fall_margin", 8.0),
		},
		"track": {
			"half_width": file.get_value("track", "half_width", 3.0),
			"thickness": file.get_value("track", "thickness", 0.6),
			"samples": int(file.get_value("track", "samples", 48)),
			"color": _color(file, "track", "color", Color("2A3346")),
			"bank_max": file.get_value("track", "bank_max", 12.0),
			"full_bank_radius": file.get_value("track", "full_bank_radius", 40.0),
			"bank_deadband": file.get_value("track", "bank_deadband", 1.5),
		},
	}


static func _color(file: ConfigFile, section: String, key: String,
		fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
