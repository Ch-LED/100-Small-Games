class_name PongGame
extends Control
## Pong controller. Structure lives in pingpong.tscn (see CONSTITUTION 5.5);
## this script only loads the config, positions the field and runs the match.

const ZONE_DEPTH := 40.0
const WALL_THICKNESS := 4.0

@onready var _background: ColorRect = $Background
@onready var _paddle_left: PongPaddle = %PaddleLeft
@onready var _paddle_right: PongPaddle = %PaddleRight
@onready var _wall_top: Area2D = %WallTop
@onready var _wall_bottom: Area2D = %WallBottom
@onready var _zone_left: Area2D = %ZoneLeft
@onready var _zone_right: Area2D = %ZoneRight
@onready var _ball: PongBall = %Ball
@onready var _line: ColorRect = $CenterLine
@onready var _scoreboard: Label = $Scoreboard
@onready var _ai: PongAi = $Ai

var _cfg := {}
var _score := 0
var _serve_wait := 0.0
var _waiting_for_serve := false


func _ready() -> void:
	_cfg = PongSettings.load_all()
	_background.color = _cfg.field.bg_color

	_paddle_left.setup("left", _cfg.paddle)
	_paddle_right.setup("right", _cfg.paddle)
	_ball.setup(_cfg.ball)
	_ball.scored.connect(_on_scored)
	_ai.setup(_ball, _paddle_left, _cfg.ai)

	_scoreboard.add_theme_font_size_override("font_size", int(_cfg.scoreboard.font_size))
	_scoreboard.add_theme_color_override("font_color", Color(1, 1, 1, _cfg.scoreboard.alpha))

	resized.connect(_layout)
	await get_tree().process_frame
	_layout()
	_begin_serve()


func _process(delta: float) -> void:
	if not _waiting_for_serve:
		return
	_serve_wait -= delta
	if _serve_wait <= 0.0:
		_waiting_for_serve = false
		_ball.launch_random()


func _physics_process(_delta: float) -> void:
	_paddle_right.set_target(_player_dir())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameRouter.back_to_hub()


## Player intent is the fallthrough of the wasd and arrow actions (DECISION_LOG 010).
func _player_dir() -> int:
	var up := _action("wasd_up") or _action("arrow_up")
	var down := _action("wasd_down") or _action("arrow_down")
	return (1 if down else 0) - (1 if up else 0)


func _action(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _layout() -> void:
	var field := size
	if field.x <= 0.0 or field.y <= 0.0:
		return

	var line_color: Color = _cfg.center_line.color
	_line.color = Color(line_color.r, line_color.g, line_color.b, _cfg.center_line.alpha)
	var line_w: float = _cfg.center_line.width
	_line.position = Vector2((field.x - line_w) * 0.5, 0.0)
	_line.size = Vector2(line_w, field.y)

	var pw: float = _cfg.paddle.width
	var ph: float = _cfg.paddle.height
	var edge: float = _cfg.paddle.edge_distance
	var inset := edge + pw * 0.5
	_paddle_left.position = Vector2(inset, field.y * 0.5)
	_paddle_right.position = Vector2(field.x - inset, field.y * 0.5)
	_paddle_left.refresh_bounds(ph * 0.5, field.y - ph * 0.5)
	_paddle_right.refresh_bounds(ph * 0.5, field.y - ph * 0.5)

	_set_strip(_wall_top, Vector2(field.x, WALL_THICKNESS), Vector2(field.x * 0.5, -WALL_THICKNESS * 0.5))
	_set_strip(_wall_bottom, Vector2(field.x, WALL_THICKNESS), Vector2(field.x * 0.5, field.y + WALL_THICKNESS * 0.5))
	_set_strip(_zone_left, Vector2(ZONE_DEPTH, field.y), Vector2(-ZONE_DEPTH * 0.5, field.y * 0.5))
	_set_strip(_zone_right, Vector2(ZONE_DEPTH, field.y), Vector2(field.x + ZONE_DEPTH * 0.5, field.y * 0.5))


## The barriers are plain Area2Ds; only their shape and centre are data-driven.
func _set_strip(area: Area2D, shape_size: Vector2, center: Vector2) -> void:
	area.position = center
	var collision := area.get_node("Collision") as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	shape.size = shape_size


func _begin_serve() -> void:
	_ball.set_center(size * 0.5)
	_waiting_for_serve = true
	_serve_wait = _cfg.ball.serve_pause


func _on_scored(side: String) -> void:
	_score += 1 if side == "left" else -1
	_scoreboard.text = str(_score)
	_begin_serve()
