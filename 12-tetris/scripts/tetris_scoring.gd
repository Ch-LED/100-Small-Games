class_name TetrisScoring
extends RefCounted

## Guideline scoring, level and gravity.
##
## Everything here is the specification's. If a number looks arbitrary it came
## from the guideline, and it should be checked there before anyone changes it
## -- the point of this game is that it follows the standard.
##
## Pure logic, no scene tree, so the whole table can be asserted directly.

## What kind of spin the lock was. The play session decides this, because half
## the test ("the last action was a rotation") is about its own history rather
## than about the board.
enum Spin { NONE, FULL, MINI }

## Rows per level. The guideline counts total cleared lines, not lines since
## the last level up.
const LINES_PER_LEVEL := 10

## Indexed by rows cleared.
const LINE_SCORES := [0, 100, 300, 500, 800]
## T-spins, indexed by rows cleared. A T can clear at most three.
const TSPIN_SCORES := [400, 800, 1200, 1600]
## Mini T-spins, indexed by rows cleared. They top out at two.
const TSPIN_MINI_SCORES := [100, 200, 400]

const COMBO_POINTS := 50
const BACK_TO_BACK_MULTIPLIER := 1.5

const SOFT_DROP_POINTS := 1
const HARD_DROP_POINTS := 2

var score: int = 0
var lines_total: int = 0
var level: int = 1
## -1 means no streak is running. The first clear takes it to 0, which pays
## nothing -- only the second clear in a row starts earning combo points.
var combo: int = -1
var back_to_back: bool = false

var _level_cap: int


func _init(level_cap: int = 20) -> void:
	_level_cap = level_cap


## Prices one locked piece, folds it into the running totals, and returns what
## it was worth.
func register(lines: int, spin: Spin) -> int:
	var cleared := lines > 0
	var gained := base_points(lines, spin) * level
	if cleared and back_to_back and is_difficult(lines, spin):
		gained = int(roundf(gained * BACK_TO_BACK_MULTIPLIER))
	if cleared:
		combo += 1
		if combo > 0:
			gained += COMBO_POINTS * combo * level
	else:
		combo = -1
	if cleared:
		back_to_back = is_difficult(lines, spin)
	lines_total += lines
	level = mini(1 + lines_total / LINES_PER_LEVEL, _level_cap)
	score += gained
	return gained


func base_points(lines: int, spin: Spin) -> int:
	match spin:
		Spin.FULL:
			return TSPIN_SCORES[mini(lines, TSPIN_SCORES.size() - 1)]
		Spin.MINI:
			return TSPIN_MINI_SCORES[mini(lines, TSPIN_MINI_SCORES.size() - 1)]
		_:
			return LINE_SCORES[mini(lines, LINE_SCORES.size() - 1)]


## A "difficult" clear is a Tetris or any T-spin that cleared rows. These are
## what a back-to-back chain is made of, and an ordinary clear breaks it.
func is_difficult(lines: int, spin: Spin) -> bool:
	if spin != Spin.NONE:
		return true
	return lines == 4


## A short label for what a lock just did, for the HUD. Empty when it cleared
## nothing and was not a spin. T-spins are the one thing a player cannot check
## from the score alone -- the number jumps, but nothing says why -- so naming
## it is the difference between "I think that worked" and knowing.
static func describe(lines: int, spin: Spin) -> String:
	var names := ["SINGLE", "DOUBLE", "TRIPLE", "TETRIS"]
	if spin != Spin.NONE:
		var prefix := "T-SPIN" if spin == Spin.FULL else "MINI T-SPIN"
		if lines == 0:
			return prefix
		return "%s %s" % [prefix, names[mini(lines, 3) - 1]]
	if lines > 0:
		return names[mini(lines, 4) - 1]
	return ""


func add_soft_drop(rows: int) -> void:
	score += rows * SOFT_DROP_POINTS


func add_hard_drop(rows: int) -> void:
	score += rows * HARD_DROP_POINTS


## Seconds per row at `for_level`: the guideline's curve, flattened at
## `capped_at`.
static func gravity_interval(for_level: int, capped_at: int) -> float:
	var level := mini(maxi(for_level, 1), capped_at)
	var base := 0.8 - float(level - 1) * 0.007
	return pow(base, level - 1)
