class_name TetrisTiles
extends RefCounted

## Builds the board's TileSet at runtime.
##
## There is no atlas image on disk. This project ships no external art, so the
## atlas is painted here pixel by pixel and wrapped in a TileSetAtlasSource.
## The TileMapLayer node itself -- the thing that actually draws -- is built in
## the scene; only its texture is code.

const TILE_PX := 32
const SOURCE_ID := 0

## Outer outline, painted in the block's dark shade so neighbouring blocks of
## the same colour still read as separate squares.
const BORDER := 1
## Top-left band, painted in the block's light tint. A flat square has no
## volume; this is what makes it look like a brick.
const HIGHLIGHT := 3

const SHADE_FACTOR := 0.45
const TINT_FACTOR := 0.5

## The atlas is one strip: seven solid blocks at columns 0..6, then the seven
## hollow landing-preview outlines at 7..13. Board, ghost and every preview
## slot share this one TileSet.
const GHOST_OFFSET := 7
## Outline thickness of a ghost tile, in pixels.
const GHOST_THICKNESS := 3
## The super cheat paints the whole active piece in one colour, so it needs its
## own block rather than one per kind.
const SUPER_OFFSET := 14


static func build(colors: Array[Color], super_color: Color) -> TileSet:
	var columns := colors.size() * 2 + 1
	var image := Image.create_empty(TILE_PX * columns, TILE_PX, false, Image.FORMAT_RGBA8)
	for index in colors.size():
		_paint_block(image, index * TILE_PX, colors[index])
		_paint_ghost(image, (index + GHOST_OFFSET) * TILE_PX, colors[index])
	_paint_block(image, SUPER_OFFSET * TILE_PX, super_color)

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	for index in columns:
		source.create_tile(Vector2i(index, 0))

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_PX, TILE_PX)
	tileset.add_source(source, SOURCE_ID)
	return tileset


## Atlas column for a solid tetromino block.
static func atlas_coords(kind: int) -> Vector2i:
	return Vector2i(kind, 0)


## Atlas column for the hollow outline the landing preview draws with. Same
## colour as the piece so a glance says which piece is about to land.
static func ghost_coords(kind: int) -> Vector2i:
	return Vector2i(kind + GHOST_OFFSET, 0)


## Atlas column for the block a zero-gravity piece is painted with.
static func super_coords() -> Vector2i:
	return Vector2i(SUPER_OFFSET, 0)


static func _paint_ghost(image: Image, x_offset: int, body: Color) -> void:
	var edge := Color(body.r, body.g, body.b, 1.0)
	var see_through := Color(0.0, 0.0, 0.0, 0.0)
	for y in TILE_PX:
		for x in TILE_PX:
			var on_edge := (
				x < GHOST_THICKNESS or y < GHOST_THICKNESS
				or x >= TILE_PX - GHOST_THICKNESS or y >= TILE_PX - GHOST_THICKNESS
			)
			image.set_pixel(x_offset + x, y, edge if on_edge else see_through)


static func _paint_block(image: Image, x_offset: int, body: Color) -> void:
	var shade := Color(body.r * SHADE_FACTOR, body.g * SHADE_FACTOR, body.b * SHADE_FACTOR)
	var tint := Color(
		minf(body.r * TINT_FACTOR + 0.5, 1.0),
		minf(body.g * TINT_FACTOR + 0.5, 1.0),
		minf(body.b * TINT_FACTOR + 0.5, 1.0)
	)
	for y in TILE_PX:
		for x in TILE_PX:
			var on_border := (
				x < BORDER or y < BORDER
				or x >= TILE_PX - BORDER or y >= TILE_PX - BORDER
			)
			var on_highlight := x < BORDER + HIGHLIGHT or y < BORDER + HIGHLIGHT
			var color := body
			if on_border:
				color = shade
			elif on_highlight:
				color = tint
			image.set_pixel(x_offset + x, y, color)
