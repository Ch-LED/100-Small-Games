class_name PacmanDebug
extends Node2D
## Toggleable overlay (P) that visualises how the ghosts decide where to go:
## each ghost's *target cell* is boxed in its own colour, its currently chosen
## direction gets a small arrow, and its state is labelled.
##
## Strictly read-only — it only reads ghost state, never changes it, so what
## you see is exactly what the AI is doing.

var enabled := false
var ghosts: Array[PacmanGhost] = []

const LABEL_SIZE := 10


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var cell := PacmanGrid.CELL
	for ghost in ghosts:
		if not is_instance_valid(ghost):
			continue
		_draw_target(ghost, cell)
		_draw_heading(ghost)
		_draw_state(ghost)


## The cell the ghost is steering toward, boxed in the ghost's colour.
func _draw_target(ghost: PacmanGhost, cell: float) -> void:
	var target: Vector2i = ghost.target_cell
	if not PacmanGrid.in_bounds(target):
		return
	var rect := Rect2(PacmanGrid.ORIGIN + Vector2(target) * cell, Vector2(cell, cell))
	draw_rect(rect, ghost.tint, false, 2.0)
	var inner := rect.grow(-4.0)
	draw_rect(inner, Color(ghost.tint.r, ghost.tint.g, ghost.tint.b, 0.25), true)


## An arrow at the junction showing which way the ghost committed.
func _draw_heading(ghost: PacmanGhost) -> void:
	var dir: Vector2i = ghost.dir
	if dir == PacmanGrid.DIR_NONE:
		return
	var at := PacmanGrid.cell_center(ghost.cell()) + Vector2(dir) * PacmanGrid.CELL * 0.30
	var tip := at + Vector2(dir) * PacmanGrid.CELL * 0.30
	var side := Vector2(-dir.y, dir.x) * PacmanGrid.CELL * 0.14
	draw_line(at, tip, ghost.tint, 2.0)
	draw_line(tip, tip - Vector2(dir) * PacmanGrid.CELL * 0.14 + side, ghost.tint, 2.0)
	draw_line(tip, tip - Vector2(dir) * PacmanGrid.CELL * 0.14 - side, ghost.tint, 2.0)


func _draw_state(ghost: PacmanGhost) -> void:
	var label := ghost.debug_state_name()
	if label.is_empty():
		return
	var font := PixelFont.get_font()
	var at := PacmanGrid.cell_center(ghost.cell()) + Vector2(-10.0, -PacmanGrid.CELL * 0.9)
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, ghost.tint)
