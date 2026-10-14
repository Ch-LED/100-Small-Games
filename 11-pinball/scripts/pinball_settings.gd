class_name PinballSettings
extends RefCounted
## Every tunable number for 11-pinball, read from the game's own .cfg.
##
## WARNING: the table below is written by hand, one key at a time. A key added
## to the .cfg without being added here is NOT an error -- the fallback value
## is used silently and the game runs on numbers nobody chose. Add cfg keys and
## read-table rows together, always.

const CONFIG_PATH := "res://11-pinball/pinball.cfg"

var table: Dictionary = {}
var ball: Dictionary = {}
var flipper: Dictionary = {}
var plunger: Dictionary = {}
var camera: Dictionary = {}
var hud: Dictionary = {}
var score: Dictionary = {}
var rules: Dictionary = {}
var cheat: Dictionary = {}
var super_cheat: Dictionary = {}


static func load_default() -> PinballSettings:
	var settings := PinballSettings.new()
	settings.read_config(CONFIG_PATH)
	return settings


## A missing or unreadable file is not fatal: every value falls back, and the
## game runs on the fallbacks rather than refusing to start.
func read_config(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		push_warning("pinball: cannot read %s; every value falls back" % path)
	table = {
		"tilt_deg": float(file.get_value("table", "tilt_deg", 16.0)),
		"wall_height": float(file.get_value("table", "wall_height", 2.5)),
		"wall_thickness": float(file.get_value("table", "wall_thickness", 0.1)),
	}
	ball = {
		"mass": float(file.get_value("ball", "mass", 1.0)),
		"gravity_scale": float(file.get_value("ball", "gravity_scale", 2.0)),
		"friction": float(file.get_value("ball", "friction", 0.10)),
		"bounce": float(file.get_value("ball", "bounce", 0.35)),
		"linear_damp": float(file.get_value("ball", "linear_damp", 0.0)),
		"angular_damp": float(file.get_value("ball", "angular_damp", 0.02)),
		"max_speed": float(file.get_value("ball", "max_speed", 64.0)),
	}
	flipper = {
		"radius": float(file.get_value("flipper", "radius", 0.35)),
		"flip_angular_speed": float(file.get_value("flipper", "flip_angular_speed", 14.0)),
		"return_angular_speed": float(file.get_value("flipper", "return_angular_speed", 18.0)),
		"restitution": float(file.get_value("flipper", "restitution", 0.45)),
		"contact_slack": float(file.get_value("flipper", "contact_slack", 1.15)),
	}
	plunger = {
		"charge_time": float(file.get_value("plunger", "charge_time", 1.1)),
		"launch_min_speed": float(file.get_value("plunger", "launch_min_speed", 10.0)),
		"launch_max_speed": float(file.get_value("plunger", "launch_max_speed", 42.0)),
	}
	camera = {
		"height": float(file.get_value("camera", "height", 28.0)),
		"pull_back": float(file.get_value("camera", "pull_back", 8.0)),
		"look_forward": float(file.get_value("camera", "look_forward", 0.0)),
		"fov": float(file.get_value("camera", "fov", 51.0)),
	}
	hud = {
		"font_size": int(file.get_value("hud", "font_size", 18)),
	}
	score = {
		"bumper": int(file.get_value("score", "bumper", 100)),
		"bumper_kick": float(file.get_value("score", "bumper_kick", 13.0)),
		"target": int(file.get_value("score", "target", 25)),
		"rollover": int(file.get_value("score", "rollover", 10)),
		"kicker": int(file.get_value("score", "kicker", 150)),
		"kicker_kick": float(file.get_value("score", "kicker_kick", 20.0)),
		"sink": int(file.get_value("score", "sink", 500)),
		"sink_hold": float(file.get_value("score", "sink_hold", 0.35)),
		"sink_eject": float(file.get_value("score", "sink_eject", 18.0)),
	}
	rules = {
		"starting_balls": int(file.get_value("rules", "starting_balls", 3)),
	}
	cheat = {
		"flipper_length_scale": float(file.get_value("cheat", "flipper_length_scale", 1.6)),
	}
	super_cheat = {
		"rescue_speed": float(file.get_value("super_cheat", "rescue_speed", 38.0)),
	}
