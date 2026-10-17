class_name SokobanView
extends Control

## The board, drawn in one pass: walls, floor, goals, boxes, player.
##
## The view owns no rules -- it reads the level and paints it. One `_draw`
## covers the whole board, which is what lets a 10x6 level cost the same as a
## 5x5 one (spec 3.1).

var _settings: SokobanSettings
var _level: SokobanLevel
## The `]` cheat: the player walks over boxes.
var _ghost := false


func setup(settings: SokobanSettings) -> void:
	_settings = settings
	queue_redraw()


func board_size() -> Vector2:
	if _settings == null or _level == null:
		return Vector2.ZERO
	return Vector2(_level.cols * _settings.cell_size, _level.rows * _settings.cell_size)


func refresh(level: SokobanLevel, ghost: bool) -> void:
	_level = level
	_ghost = ghost
	if level != null:
		custom_minimum_size = Vector2(level.cols * _settings.cell_size,
				level.rows * _settings.cell_size)
		size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	if _settings == null or _level == null:
		return
	var cell := _settings.cell_size
	for index in _level.cell_count():
		_draw_cell(index, cell)
	for index in _level.cell_count():
		if _level.has_box(index):
			_draw_box(index, cell)
	if _level.player >= 0:
		_draw_player(cell)


func _draw_cell(index: int, cell: float) -> void:
	var corner := Vector2(_level.col_of(index) * cell, _level.row_of(index) * cell)
	var rect := Rect2(corner, Vector2(cell, cell))
	if _level.is_wall(index):
		draw_rect(rect, _settings.wall_color, true)
		draw_line(corner, corner + Vector2(cell, 0.0), _settings.wall_edge, 2.0)
		draw_line(corner, corner + Vector2(0.0, cell), _settings.wall_edge, 2.0)
		return
	draw_rect(rect, _settings.floor_color, true)
	if _level.is_goal(index):
		draw_arc(corner + Vector2(cell, cell) * 0.5, cell * 0.22, 0.0, TAU, 24,
				_settings.goal_color, 2.0, true)


func _draw_box(index: int, cell: float) -> void:
	var on_goal := _level.is_goal(index)
	var corner := Vector2(_level.col_of(index) * cell, _level.row_of(index) * cell)
	var inset := cell * 0.12
	var rect := Rect2(corner + Vector2(inset, inset), Vector2(cell - inset * 2.0,
			cell - inset * 2.0))
	draw_rect(rect, _settings.box_done_color if on_goal else _settings.box_color, true)
	var edge := _settings.box_done_edge if on_goal else _settings.box_edge
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), edge, 2.0)
	draw_line(rect.position, rect.position + Vector2(0.0, rect.size.y), edge, 2.0)


func _draw_player(cell: float) -> void:
	var centre := Vector2(_level.col_of(_level.player) * cell + cell * 0.5,
			_level.row_of(_level.player) * cell + cell * 0.5)
	var ink := _settings.super_color if _ghost else _settings.player_color
	draw_circle(centre, cell * 0.30, ink)
	draw_arc(centre, cell * 0.30, 0.0, TAU, 24,
			_settings.player_edge if not _ghost else ink.lightened(0.4), 2.0, true)
