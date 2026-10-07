class_name PacmanSprites
extends RefCounted
## Sprite lookup over a single aseprite sheet that stacks every layer.
##
## aseprite's JSON does not name the layer a tag belongs to, but frameTags are
## emitted in layer order (bottom-up), so TAG_LAYOUT below maps them back by
## walking the tag list in order and matching names. Missing tags (e.g. the
## death animation, until it is drawn) fall back to placeholder art.

const SHEET_PATH := "res://03-pacman/assets/sprites.png"
const JSON_PATH := "res://03-pacman/assets/sprites.json"

## Layer order as aseprite emits it, with the tags each layer is expected to
## carry. Tags that are absent are simply skipped — matching is by name and
## the cursor only ever moves forward, so duplicate names across layers
## ("up" exists for pacman and for ghost_eyes) resolve correctly.
const TAG_LAYOUT := [
	{"layer": "pacman", "tags": ["up", "down", "right", "death"]},
	{"layer": "ghost_body", "tags": ["walk"]},
	{"layer": "ghost_eyes", "tags": ["up", "right", "left", "down"]},
	{"layer": "ghost_fright", "tags": ["blue", "flash"]},
	{"layer": "pellet", "tags": ["small", "power"]},
	{"layer": "fruit", "tags": ["cherry", "strawberry", "orange", "apple"]},
]

const LAYER_COLORS := {
	"pacman": Color("FFE600"),
	"ghost_body": Color("FF2A2A"),
	"ghost_eyes": Color("F0F0FF"),
	"ghost_fright": Color("2121DE"),
	"pellet": Color("FFB897"),
	"fruit": Color("FF4B4B"),
}

const FRAME_SIZE := 16

var _sheet: Texture2D
var _rects: Dictionary = {}          # "<layer>_<tag>" -> Array[Rect2]
var _placeholders: Dictionary = {}   # layer -> Texture2D
var _missing: Dictionary = {}


func load_all() -> void:
	if not (ResourceLoader.exists(SHEET_PATH) and FileAccess.file_exists(JSON_PATH)):
		for entry in TAG_LAYOUT:
			_missing[entry["layer"]] = true
		return
	_sheet = load(SHEET_PATH)
	_parse()


func _parse() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	if raw is not Dictionary:
		push_error("PacmanSprites: cannot parse %s" % JSON_PATH)
		return
	var frames: Dictionary = raw.get("frames", {})
	# Frames are emitted in sheet order; index by iteration order.
	var cells: Array[Rect2] = []
	cells.resize(frames.size())
	var index := 0
	for key in frames:
		var f: Dictionary = frames[key]["frame"]
		cells[index] = Rect2(f["x"], f["y"], f["w"], f["h"])
		index += 1

	var tags: Array = raw.get("meta", {}).get("frameTags", [])
	var cursor := 0
	for entry in TAG_LAYOUT:
		for expected in entry["tags"]:
			var found := -1
			for i in range(cursor, tags.size()):
				if str(tags[i]["name"]) == expected:
					found = i
					break
			if found < 0:
				_missing[entry["layer"]] = true
				continue
			var rects: Array[Rect2] = []
			for i in range(int(tags[found]["from"]), int(tags[found]["to"]) + 1):
				if i < cells.size():
					rects.append(cells[i])
			_rects["%s_%s" % [entry["layer"], expected]] = rects
			cursor = found + 1


func has(layer: String, tag: String) -> bool:
	var frames: Array = _rects.get("%s_%s" % [layer, tag], [])
	return not frames.is_empty()


func frame_count(layer: String, tag: String) -> int:
	var frames: Array = _rects.get("%s_%s" % [layer, tag], [])
	return frames.size()


func texture(layer: String, tag: String, index := 0) -> Texture2D:
	var key := "%s_%s" % [layer, tag]
	var frames: Array = _rects.get(key, [])
	if not frames.is_empty():
		var atlas := AtlasTexture.new()
		atlas.atlas = _sheet
		atlas.region = frames[posmod(index, frames.size())]
		atlas.filter_clip = true
		return atlas
	return _placeholder(layer)


## Stand-in art (a tinted 16x16 block) for any frame that has not been drawn.
func _placeholder(layer: String) -> Texture2D:
	if _placeholders.has(layer):
		return _placeholders[layer]
	var image := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	var tint: Color = LAYER_COLORS.get(layer, Color.MAGENTA)
	image.fill(tint)
	for i in FRAME_SIZE:
		image.set_pixel(i, 0, tint.darkened(0.5))
		image.set_pixel(i, FRAME_SIZE - 1, tint.darkened(0.5))
		image.set_pixel(0, i, tint.darkened(0.5))
		image.set_pixel(FRAME_SIZE - 1, i, tint.darkened(0.5))
	var texture := ImageTexture.create_from_image(image)
	_placeholders[layer] = texture
	return texture


## Layers with at least one tag still missing — surfaced at startup so it is
## obvious which art is standing in.
func missing_layers() -> Array:
	return _missing.keys()
