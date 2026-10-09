class_name SpaceSettings
## Loads space-invaders.cfg into typed section dictionaries.

const PATH := "res://02-space-invaders/space-invaders.cfg"


static func load_all() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		push_error("SpaceSettings: cannot load %s" % PATH)
		return {}
	return {
		"scale": {
			"factor": float(file.get_value("scale", "factor", 4)),
		},
		"player": {
			"speed": file.get_value("player", "speed", 320.0),
			"bullet_speed": file.get_value("player", "bullet_speed", 900.0),
			"bottom_margin": file.get_value("player", "bottom_margin", 44.0),
			"lives": int(file.get_value("player", "lives", 3)),
			"invuln_time": file.get_value("player", "invuln_time", 1.5),
			"death_pause": file.get_value("player", "death_pause", 1.0),
			"fire_lock": file.get_value("player", "fire_lock", 0.5),
		},
		"enemy_grid": {
			"cols": int(file.get_value("enemy_grid", "cols", 11)),
			"col_gap": file.get_value("enemy_grid", "col_gap", 12.0),
			"row_gap": file.get_value("enemy_grid", "row_gap", 10.0),
			"step_x": file.get_value("enemy_grid", "step_x", 8.0),
			"top_margin": file.get_value("enemy_grid", "top_margin", 96.0),
		},
		"tick": {
			"base_slow": file.get_value("tick", "base_slow", 0.80),
			"base_fast": file.get_value("tick", "base_fast", 0.10),
			"fast_at_rows": int(file.get_value("tick", "fast_at_rows", 2)),
			"per_level_speedup": file.get_value("tick", "per_level_speedup", 0.92),
			"level_shift_rows": file.get_value("tick", "level_shift_rows", 1.0),
			"level_clear_rows": file.get_value("tick", "level_clear_rows", 2.0),
			"level_open_delay": file.get_value("tick", "level_open_delay", 0.08),
			"time_to_max": file.get_value("tick", "time_to_max", 45.0),
			"count_share": file.get_value("tick", "count_share", 0.35),
			"time_share": file.get_value("tick", "time_share", 0.65),
		},
		"enemy_fire": {
			"fire_interval": int(file.get_value("enemy_fire", "fire_interval", 3)),
			"fire_fail_chance": file.get_value("enemy_fire", "fire_fail_chance", 0.1),
			"energy_ratio": file.get_value("enemy_fire", "energy_ratio", 0.5),
			"energy_bullet_speed": file.get_value("enemy_fire", "energy_bullet_speed", 900.0),
			"dart_bullet_speed": file.get_value("enemy_fire", "dart_bullet_speed", 650.0),
		},
		"ufo": {
			"interval_min": file.get_value("ufo", "interval_min", 18.0),
			"interval_max": file.get_value("ufo", "interval_max", 30.0),
			"speed": file.get_value("ufo", "speed", 160.0),
			"y": file.get_value("ufo", "y", 90.0),
			"score_min": int(file.get_value("ufo", "score_min", 50)),
			"score_max": int(file.get_value("ufo", "score_max", 300)),
			"score_step": int(file.get_value("ufo", "score_step", 50)),
		},
		"shield": {
			"count": int(file.get_value("shield", "count", 4)),
			"tile_size": file.get_value("shield", "tile_size", 6.0),
			"tile_hp": int(file.get_value("shield", "tile_hp", 4)),
			"bottom_margin": file.get_value("shield", "bottom_margin", 210.0),
		},
		"bullet": {
			"min_width": file.get_value("bullet", "min_width", 16.0),
			"min_height": file.get_value("bullet", "min_height", 16.0),
		},
		"cheat": {
			"homing_rate": file.get_value("cheat", "homing_rate", 10.0),
		},
		"score": {
			"squid": int(file.get_value("score", "squid", 40)),
			"claude": int(file.get_value("score", "claude", 20)),
			"jelly": int(file.get_value("score", "jelly", 10)),
		},
		"hud": {
			"score_size": int(file.get_value("hud", "score_size", 24)),
			"margin": file.get_value("hud", "margin", 16.0),
		},
	}
