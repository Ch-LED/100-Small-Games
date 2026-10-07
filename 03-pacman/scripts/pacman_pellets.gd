class_name PacmanPellets
extends Node2D
## Draws every pellet in one pass. This node sits above the wall tiles in the
## maze scene, so pellets are never hidden by the wall art.
##
## The pellet data itself lives in PacmanMaze (it owns the layout); this node
## just renders whatever is still on the board.

var _maze: PacmanMaze
var _sprites: PacmanSprites
var _phase := 0


func setup(maze: PacmanMaze, sprites: PacmanSprites) -> void:
	_maze = maze
	_sprites = sprites
	_maze.pellets_changed.connect(queue_redraw)


## Power pellets blink; Game steps this on a slow clock.
func advance_animation() -> void:
	_phase += 1
	queue_redraw()


func _draw() -> void:
	if _maze == null or _sprites == null:
		return
	for row in PacmanGrid.ROWS:
		for col in PacmanGrid.COLS:
			var cell := Vector2i(col, row)
			var kind := _maze.pellet_at(cell)
			if kind == PacmanMaze.PELLET_NONE:
				continue
			var tag := "power" if kind == PacmanMaze.PELLET_POWER else "small"
			var texture := _sprites.texture("pellet", tag, _phase)
			draw_texture(texture, PacmanGrid.cell_center(cell) - texture.get_size() * 0.5)
