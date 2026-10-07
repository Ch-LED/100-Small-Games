class_name SpaceField
## Fixed logical playfield size. canvas_items stretch maps it to the window,
## so gameplay layout stays deterministic regardless of window size/aspect.
const SIZE := Vector2(1280.0, 720.0)

## Side masks were dropped, so the play band is the full screen again. Keep the
## constant around (set > 0 to re-narrow, masks build themselves) since the
## gameplay bounds all read PLAY_RECT.
const SIDE_RATIO := 0.0
const PLAY_RECT := Rect2(
		SIZE.x * SIDE_RATIO,
		0.0,
		SIZE.x * (1.0 - 2.0 * SIDE_RATIO),
		SIZE.y)
