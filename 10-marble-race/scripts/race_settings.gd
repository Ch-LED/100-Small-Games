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
			"friction": file.get_value("ball", "friction", 1.2),
			"bounce": file.get_value("ball", "bounce", 0.15),
			"linear_damp": file.get_value("ball", "linear_damp", 0.14),
			"angular_damp": file.get_value("ball", "angular_damp", 0.42),
			"linear_damp_active": file.get_value("ball", "linear_damp_active", 0.03),
			"angular_damp_active": file.get_value("ball", "angular_damp_active", 0.09),
			"brake_torque": file.get_value("ball", "brake_torque", 3.4),
			"brake_min_spin": file.get_value("ball", "brake_min_spin", 0.5),
			"spin_torque": file.get_value("ball", "spin_torque", 5.0),
			"turn_boost": file.get_value("ball", "turn_boost", 1.0),
			"min_turn_speed": file.get_value("ball", "min_turn_speed", 1.0),
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
			"restart_delay": file.get_value("play", "restart_delay", 1.1),
			"finish_pause": file.get_value("play", "finish_pause", 2.2),
		},
		"track": {
			"half_width": file.get_value("track", "half_width", 3.0),
			"thickness": file.get_value("track", "thickness", 0.6),
			"samples": int(file.get_value("track", "samples", 160)),
			"color": _color(file, "track", "color", Color("2A3346")),
			"wall_color": _color(file, "track", "wall_color", Color("46608C")),
			"wall_thickness": file.get_value("track", "wall_thickness", 0.35),
			"wall_ramp": file.get_value("track", "wall_ramp", 5.0),
			"debug_color": _color(file, "track", "debug_color", Color("FFE94A")),
			"bank_max": file.get_value("track", "bank_max", 12.0),
			"full_bank_radius": file.get_value("track", "full_bank_radius", 40.0),
			"bank_deadband": file.get_value("track", "bank_deadband", 1.5),
			"start_t": file.get_value("track", "start_t", 0.02),
			"finish_t": file.get_value("track", "finish_t", 0.97),
			"marker_span": file.get_value("track", "marker_span", 0.012),
			"start_color": _color(file, "track", "start_color", Color("4BD3FF")),
			"finish_color": _color(file, "track", "finish_color", Color("FFD24A")),
		},
		"cheat": {
			"edge_field_depth": file.get_value("cheat", "edge_field_depth", 1.4),
			"edge_field_strength": file.get_value("cheat", "edge_field_strength", 280.0),
			"flight_thrust": file.get_value("cheat", "flight_thrust", 350.0),
			"flight_linear_damp": file.get_value("cheat", "flight_linear_damp", 7.0),
			"flight_angular_damp": file.get_value("cheat", "flight_angular_damp", 16.0),
			"flight_max_speed": file.get_value("cheat", "flight_max_speed", 70.0),
			"flight_brake_bleed": file.get_value("cheat", "flight_brake_bleed", 3.0),
		},
		"hud": {
			"font_size": int(file.get_value("hud", "font_size", 16)),
			"margin": file.get_value("hud", "margin", 28.0),
			"time_color": _color(file, "hud", "time_color", Color("F2F5F7")),
			"message_color": _color(file, "hud", "message_color", Color("9FB0C8")),
		},
	}


static func _color(file: ConfigFile, section: String, key: String,
		fallback: Color = Color.WHITE) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
