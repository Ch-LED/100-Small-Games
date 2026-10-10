class_name MarbleCameraRig
extends Node3D
## Third-person follow camera driven by the mouse (technical spec 6).

var _cfg: Dictionary = {}
var _target: Node3D = null
var _yaw := 0.0
var _pitch := 0.0


func configure(settings: Dictionary, target: Node3D) -> void:
	_cfg = settings.camera
	_target = target
	_pitch = deg_to_rad(float(_cfg.pitch_max) * 0.35)


## Steering resolves in a yaw-only basis so that where the camera happens to be
## pitched never changes which way the ball goes (spec 6).
func get_steering_basis() -> Basis:
	return Basis(Vector3.UP, _yaw)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or _cfg.is_empty():
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var sensitivity: float = _cfg.mouse_sensitivity
	_yaw -= motion.relative.x * sensitivity
	_pitch += motion.relative.y * sensitivity
	_pitch = clampf(_pitch,
			deg_to_rad(float(_cfg.pitch_min)),
			deg_to_rad(float(_cfg.pitch_max)))


func _physics_process(delta: float) -> void:
	if _target == null or _cfg.is_empty():
		return
	var distance: float = _cfg.distance
	var focus := _target.global_position + Vector3(0.0, float(_cfg.look_height), 0.0)
	var offset := Basis(Vector3.UP, _yaw) * Vector3(
			0.0, sin(_pitch) * distance, cos(_pitch) * distance)
	var desired := focus + Vector3(0.0, float(_cfg.height), 0.0) + offset
	var weight := 1.0 - exp(-float(_cfg.follow_damp) * delta)
	global_position = global_position.lerp(desired, weight)
	if global_position.distance_squared_to(focus) > 0.0001:
		look_at(focus, Vector3.UP)
