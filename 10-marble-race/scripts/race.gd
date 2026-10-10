class_name MarbleRace
extends Node3D
## Phase 1: the ball and camera on a road swept from resources/tracks.
## Phase 2 adds the timed restart and the HUD; phase 3 the menu and the save.

@onready var _ball: MarbleBall = $Ball
@onready var _camera_rig: MarbleCameraRig = $CameraRig
@onready var _track: RaceTrackPath = $Track

var _cfg: Dictionary = {}
var _fall_y := -1000.0


func _ready() -> void:
	_cfg = RaceSettings.load_all()
	if _cfg.is_empty():
		return
	_track.configure(_cfg)
	_camera_rig.configure(_cfg, _ball)
	_ball.configure(_cfg)
	_fall_y = _track.lowest_point() - float(_cfg.play.fall_margin)
	_respawn()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	var road := _track.frame_near(_ball.global_position)
	_ball.surface_normal = road.basis.y
	_ball.steering_basis = _camera_rig.get_steering_basis()
	if _ball.global_position.y < _fall_y:
		_respawn()


## Phase 2 replaces this with the timed restart. For now it exists so the road
## can actually be driven without falling forever.
func _respawn() -> void:
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.global_position = _track.start_point() \
			+ Vector3(0.0, float(_cfg.ball.radius) + 0.6, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Sandbox-only: there is no menu to go back to yet. Phase 3 replaces
		# this with the pause menu (spec 11).
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
