class_name PixelFont
## Project-wide pixel font accessor. Shared infrastructure, not extracted
## from any single game.
## Font: "Press Start 2P" (SIL OFL 1.1), stored in the shared assets pool.
## Rendering is forced crisp (no antialiasing/hinting/subpixel); use font
## sizes that are multiples of BASE_SIZE for pixel-perfect glyphs.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const BASE_SIZE := 8

static var _font: FontFile


static func get_font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


## Applies the pixel font to a Label at `size` (snapped to a multiple of BASE_SIZE).
static func apply(label: Label, size: int) -> void:
	var snapped := maxi(BASE_SIZE, int(round(float(size) / BASE_SIZE)) * BASE_SIZE)
	label.add_theme_font_override("font", get_font())
	label.add_theme_font_size_override("font_size", snapped)
