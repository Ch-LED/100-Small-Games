class_name SpaceSprites
extends RefCounted
## Slices the aseprite sheet by tag (meta.frameTags) and trims every frame to
## its opaque bounds, so sprites and collision shapes use the real art size
## instead of the raw 16x8 cell. Trim is computed once from the texture image.

const SHEET_PATH := "res://02-space-invaders/assets/sprites.png"
const JSON_PATH := "res://02-space-invaders/assets/sprites.json"
const RAW_CELL := Vector2(16.0, 8.0)

var _sheet: Texture2D
var _cells: Array[Rect2] = []
var _content: Array[Rect2] = []
var _tags: Dictionary = {}


func _init() -> void:
	_sheet = load(SHEET_PATH)
	_parse()


func _parse() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	if raw is not Dictionary:
		push_error("SpaceSprites: cannot parse %s" % JSON_PATH)
		return

	var frames: Dictionary = raw.get("frames", {})
	_cells.resize(frames.size())
	_content.resize(frames.size())
	# Index by iteration order: aseprite emits frames in sheet order, and the
	# key format changes with export options ("sprites 0.aseprite" vs
	# "sprites #jelly 0.aseprite"), so never parse the key.
	var index := 0
	var image: Image = null
	for key in frames:
		var entry: Dictionary = frames[key]
		var f: Dictionary = entry["frame"]
		_cells[index] = Rect2(f["x"], f["y"], f["w"], f["h"])
		if bool(entry.get("trimmed", false)):
			# Export already cropped to the opaque bounds — trust it.
			_content[index] = _cells[index]
		else:
			if image == null:
				image = _read_image()
			_content[index] = _trim(image, _cells[index])
		index += 1

	for tag in raw.get("meta", {}).get("frameTags", []):
		var indices: Array[int] = []
		for i in range(int(tag["from"]), int(tag["to"]) + 1):
			indices.append(i)
		_tags[str(tag["name"])] = indices


func _read_image() -> Image:
	if _sheet == null:
		return null
	var image := _sheet.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	return image


## Opaque bounding box of one cell, in sheet coordinates. Falls back to the
## whole cell when the image is unavailable or the cell is empty.
func _trim(image: Image, cell: Rect2) -> Rect2:
	if image == null:
		return cell
	var min_x := int(cell.size.x)
	var min_y := int(cell.size.y)
	var max_x := -1
	var max_y := -1
	for y in int(cell.size.y):
		for x in int(cell.size.x):
			if image.get_pixel(int(cell.position.x) + x, int(cell.position.y) + y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return cell
	return Rect2(
			cell.position + Vector2(float(min_x), float(min_y)),
			Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1)))


func has_tag(tag: String) -> bool:
	return _tags.has(tag)


func frame_count(tag: String) -> int:
	var indices: Array = _tags.get(tag, [])
	return indices.size()


## Trimmed region of a frame, in sheet coordinates.
func content_rect(tag: String, index: int) -> Rect2:
	var indices: Array = _tags.get(tag, [])
	if indices.is_empty():
		return Rect2()
	return _content[indices[posmod(index, indices.size())]]


## Trimmed, upscaled pixel size of a frame — use for collision shapes.
func content_size(tag: String, index: int, factor: float) -> Vector2:
	return content_rect(tag, index).size * factor


## Raw cell size, upscaled — use for grid spacing so the formation stays even.
func cell_size(factor: float) -> Vector2:
	return RAW_CELL * factor


func make_atlas(tag: String, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = content_rect(tag, index)
	atlas.filter_clip = true
	return atlas


func make_sprite(tag: String, index: int, factor: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = make_atlas(tag, index)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(factor, factor)
	sprite.centered = true
	return sprite
