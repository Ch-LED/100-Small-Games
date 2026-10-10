class_name MarbleRace
extends Node3D
## Phase 0 sandbox: the ball and camera on hand-placed geometry, so the drive
## feel can be measured and played before any track generation exists.
## Phase 1 swaps the hand-placed geometry for TrackBuilder output; the ball,
## camera and this controller survive.

@onready var _ball: MarbleBall = $Ball
@onready var _camera_rig: MarbleCameraRig = $CameraRig

var _cfg: Dictionary = {}


func _ready() -> void:
	_cfg = RaceSettings.load_all()
	if _cfg.is_empty():
		return
	_camera_rig.configure(_cfg, _ball)
	_ball.configure(_cfg)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	_ball.steering_basis = _camera_rig.get_steering_basis()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Sandbox-only: there is no menu to go back to yet. Phase 3 replaces
		# this with the pause menu (spec 11).
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
