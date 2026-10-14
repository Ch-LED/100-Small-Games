class_name TetrisDebug
extends Node2D

## The P overlay: the grid, the spawn line, the box around the active piece
## with its centre marked, and a line of numbers.
##
## It draws what is already true and cannot change a rule. Reading the run's
## internals is the whole job of an introspection layer, so it does that rather
## than being handed a copy of everything.
##
## The landing preview is also on P, but the field draws that as tiles: a hollow
## outline is a shape, and shapes belong in the atlas.

const GRID_COLOR := Color("22304A")
const EDGE_COLOR := Color("FFE94A")
const SPAWN_COLOR := Color("E94560")
const TEXT_COLOR := Color("4BD3FF")
const TEXT_SIZE := 12
const CENTRE_ARM := 6.0

var _settings: TetrisSettings
var _play: TetrisPlay
var _shown: bool = false


func setup(settings: TetrisSettings) -> void:
	_settings = settings


## Redraws whether or not it is turning the overlay on: the canvas caches
## drawing commands, so switching it off has to repaint as well.
func set_shown(shown: bool) -> void:
	_shown = shown
	queue_redraw()


func update_from(play: TetrisPlay) -> void:
	_play = play
	if _shown:
		queue_redraw()


func _draw() -> void:
	if not _shown or _settings == null or _play == null:
		return
	var cell := float(_settings.cell_size)
	var width := float(TetrisBoard.WIDTH) * cell
	var height := float(TetrisBoard.VISIBLE_ROWS) * cell

	for column in range(TetrisBoard.WIDTH + 1):
		draw_line(Vector2(column * cell, 0.0), Vector2(column * cell, height), GRID_COLOR)
	for row in range(TetrisBoard.VISIBLE_ROWS + 1):
		draw_line(Vector2(0.0, row * cell), Vector2(width, row * cell), GRID_COLOR)

	# The first visible row. A piece above it is still in the buffer that the
	# kicks push into, which is why it is worth being able to see.
	draw_line(Vector2(0.0, 0.0), Vector2(width, 0.0), SPAWN_COLOR, 2.0)

	_draw_piece(cell)
	_draw_readout(cell, height)


## The active piece's bounding box and its centre. T-spin detection looks at
## the four corners of exactly this box, so seeing it is how anyone can tell
## why a spin did or did not count.
func _draw_piece(cell: float) -> void:
	var origin := _play.piece_origin()
	var rotation := _play.piece_rotation()
	var size: int = Tetromino.BOX_SIZE[_play.piece_kind()]
	var top_left := Vector2(float(origin.x) * cell, float(origin.y - TetrisBoard.SPAWN_ROWS) * cell)
	var box := Rect2(top_left, Vector2(size, size) * cell)
	draw_rect(box, EDGE_COLOR, false, 2.0)

	var centre := box.position + Vector2(size, size) * cell * 0.5
	draw_line(centre - Vector2(CENTRE_ARM, 0.0), centre + Vector2(CENTRE_ARM, 0.0), EDGE_COLOR, 2.0)
	draw_line(centre - Vector2(0.0, CENTRE_ARM), centre + Vector2(0.0, CENTRE_ARM), EDGE_COLOR, 2.0)

	for cell_position in _play.active_cells():
		if cell_position.y < TetrisBoard.SPAWN_ROWS:
			continue
		var corner := Vector2(
			float(cell_position.x) * cell,
			float(cell_position.y - TetrisBoard.SPAWN_ROWS) * cell
		)
		draw_rect(Rect2(corner, Vector2(cell, cell)), EDGE_COLOR, false, 1.0)


func _draw_readout(cell: float, height: float) -> void:
	var font := PixelFont.get_font()
	var lines := [
		"PIECE %s  ROT %d" % [Tetromino.KIND_LETTERS[_play.piece_kind()], _play.piece_rotation()],
		"GRAVITY %.3f s/row" % _play.gravity_interval(),
		"LOCK %.2f s   RESETS %d" % [_play.lock_timer(), _play.lock_resets()],
		"BAG %s" % _bag_text(),
	]
	for index in lines.size():
		draw_string(
			font,
			Vector2(cell * 0.4, height + float(TEXT_SIZE) * 1.4 * float(index + 1)),
			lines[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			TEXT_SIZE,
			TEXT_COLOR
		)


func _bag_text() -> String:
	var letters := ""
	for kind in _play.bag_remaining():
		letters += Tetromino.KIND_LETTERS[kind]
	return letters if not letters.is_empty() else "-"
