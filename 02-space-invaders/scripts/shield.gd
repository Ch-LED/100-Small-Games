class_name InvaderShield
extends Node2D
## A fort built from 6x6 tiles, 8 wide x 6 tall. Row 0 uses the triangle tag
## at both ends for a rounded crown; the bottom two rows leave a doorway.
##   . T S S S S T .
##   S S S S S S S S
##   S S S S S S S S
##   S S S S S S S S
##   S S . . . . S S
##   S . . . . . . S
## Left-side triangles are mirrored horizontally.

const LAYOUT: Array[String] = [
	"TSST",
	"SVVS",
	"S..S",
]
const SYMBOL_SQUARE := "S"
const SYMBOL_CROWN := "T"
const SYMBOL_DOOR := "V"
const SYMBOL_EMPTY := "."

var _tiles: Array[FortTile] = []


func build(tile_size: float, factor: float, hp: int, sprites: SpaceSprites) -> void:
	var width := LAYOUT[0].length()
	for row in LAYOUT.size():
		var line: String = LAYOUT[row]
		if line.length() != width:
			push_error("InvaderShield: LAYOUT row %d has %d cells, expected %d" %
					[row, line.length(), width])
			continue
		for col in line.length():
			var symbol := line[col]
			if symbol == SYMBOL_EMPTY:
				continue
			var is_left := col < width / 2
			var tile := FortTile.new()
			var tag := FortTile.TAG_SQUARE if symbol == SYMBOL_SQUARE else FortTile.TAG_TRIANGLE
			tile.setup(tag, hp, sprites, factor)
			if symbol == SYMBOL_CROWN:
				# Crown corners taper the top inwards: source triangle is
				# "top-left filled", so flip vertically and mirror the left one.
				tile.set_flip(is_left, true)
			elif symbol == SYMBOL_DOOR:
				# Doorway edges taper outwards towards the opening: keep the
				# source orientation and mirror the right-hand one.
				tile.set_flip(not is_left, false)
			tile.position = Vector2(
					(float(col) + 0.5) * tile_size * factor,
					(float(row) + 0.5) * tile_size * factor)
			add_child(tile)
			_tiles.append(tile)


func tiles() -> Array[FortTile]:
	var alive: Array[FortTile] = []
	for tile in _tiles:
		if is_instance_valid(tile):
			alive.append(tile)
	return alive


func pixel_size(tile_size: float, factor: float) -> Vector2:
	return Vector2(LAYOUT[0].length(), LAYOUT.size()) * tile_size * factor
