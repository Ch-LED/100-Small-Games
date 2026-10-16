class_name PipesModes
## The four ways to play, and their names.
##
## Kept out of both the root and the play scripts so neither has to reach into
## the other for it -- the root picks a screen, the play screen reads a verb,
## and both need to agree on what the numbers mean.

const LINK := 0
const TURN := 1
const SHIFT := 2
const SLIDE := 3
const COUNT := 4

const NAMES: Array[String] = ["LINK", "TURN", "SHIFT", "SLIDE"]
## One line beside each name on the menu: what you do with the mouse.
const BLURBS: Array[String] = [
	"drag dot to dot",
	"click to turn",
	"drag a row",
	"drag into the gap",
]


static func name_of(mode: int) -> String:
	if mode < 0 or mode >= COUNT:
		return "?"
	return NAMES[mode]


static func blurb_of(mode: int) -> String:
	if mode < 0 or mode >= COUNT:
		return ""
	return BLURBS[mode]


## Which of the shared verbs a mode uses. The three pipe modes all play on a
## PipesNet; LINK is the odd one out with a board of its own.
static func uses_net(mode: int) -> bool:
	return mode >= TURN and mode <= SLIDE


static func shuffle_for(mode: int) -> int:
	match mode:
		SHIFT:
			return PipesNetGenerator.Shuffle.SHIFT
		SLIDE:
			return PipesNetGenerator.Shuffle.SLIDE
		_:
			return PipesNetGenerator.Shuffle.TURN
