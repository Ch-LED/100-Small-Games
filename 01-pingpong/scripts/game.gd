class_name PongGame
extends Control
## Pong controller: builds the static field (background, center line,
## scoreboard) and the Area2D entities from pingpong.cfg, then runs the match.

const ZONE_DEPTH := 40.0
const WALL_THICKNESS := 4.0

var _cfg := {}
var _ball: PongBall
var _paddle_left: PongPaddle
var _paddle_right: PongPaddle
var _ai: PongAi
var _line: ColorRect
var _scoreboard: Label
var _score := 0
var _serve_wait := 0.0
var _waiting_for_serve := false
var _walls: Array = []
var _zones: Array = []


func _ready() -> void:
	_cfg = PongSettings.load_all()
	_build_field()
	_build_entities()
	_build_scoreboard()
	resized.connect(_layout)
	await get_tree().process_frame
	_layout()
	_begin_serve()


func _process(delta: float) -> void:
	if _waiting_for_serve:
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


func _build_field() -> void:
	var background := ColorRect.new()
	background.color = _cfg.field.bg_color
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_line = ColorRect.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)


## Siblings are named and created before the ball so that the ball's @onready
## references (see ball.gd) resolve when it enters the tree.
func _build_entities() -> void:
	_paddle_left = PongPaddle.new()
	_paddle_left.setup("left", _cfg.paddle)
	_paddle_left.name = "PaddleLeft"
	add_child(_paddle_left)

	_paddle_right = PongPaddle.new()
	_paddle_right.setup("right", _cfg.paddle)
	_paddle_right.name = "PaddleRight"
	add_child(_paddle_right)

	_walls.append(_make_area_strip("WallTop"))
	_walls.append(_make_area_strip("WallBottom"))
	_zones.append(_make_area_strip("ZoneLeft"))
	_zones.append(_make_area_strip("ZoneRight"))

	_ball = PongBall.new()
	_ball.setup(_cfg.ball)
	_ball.scored.connect(_on_scored)
	add_child(_ball)

	_ai = PongAi.new()
	_ai.setup(_ball, _paddle_left, _cfg.ai)
	add_child(_ai)


## A thin rectangle Area2D that the ball senses. Returns [area, shape].
func _make_area_strip(node_name: String) -> Array:
	var area := Area2D.new()
	area.name = node_name
	area.monitoring = false
	area.monitorable = true
	var shape := RectangleShape2D.new()
	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	return [area, shape]


func _build_scoreboard() -> void:
	_scoreboard = Label.new()
	_scoreboard.text = "0"
	_scoreboard.add_theme_font_size_override("font_size", int(_cfg.scoreboard.font_size))
	_scoreboard.add_theme_color_override("font_color", Color(1, 1, 1, _cfg.scoreboard.alpha))
	_scoreboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scoreboard.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scoreboard)


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

	_layout_strips(field)


func _layout_strips(field: Vector2) -> void:
	_set_strip(_walls[0], Vector2(field.x, WALL_THICKNESS), Vector2(field.x * 0.5, -WALL_THICKNESS * 0.5))
	_set_strip(_walls[1], Vector2(field.x, WALL_THICKNESS), Vector2(field.x * 0.5, field.y + WALL_THICKNESS * 0.5))
	_set_strip(_zones[0], Vector2(ZONE_DEPTH, field.y), Vector2(-ZONE_DEPTH * 0.5, field.y * 0.5))
	_set_strip(_zones[1], Vector2(ZONE_DEPTH, field.y), Vector2(field.x + ZONE_DEPTH * 0.5, field.y * 0.5))


func _set_strip(strip: Array, shape_size: Vector2, center: Vector2) -> void:
	var area = strip[0]
	var shape = strip[1]
	area.position = center
	shape.size = shape_size


func _begin_serve() -> void:
	_ball.set_center(size * 0.5)
	_waiting_for_serve = true
	_serve_wait = _cfg.ball.serve_pause


func _on_scored(side: String) -> void:
	_score += 1 if side == "left" else -1
	_scoreboard.text = str(_score)
	_begin_serve()
