class_name PieceBag
extends RefCounted

## 7-bag randomiser: the seven kinds are shuffled into a bag and dealt in that
## order, then a fresh bag is shuffled.
##
## This is NOT uniform random, and the difference is visible: no run of the
## same kind can exceed two, so "it keeps taking turns" is the standard
## behaving correctly, not a bug to go and smooth out.

var _rng := RandomNumberGenerator.new()
var _queue: Array[int] = []
## A fixed deal order, used by the tutorial. While one is set the bag is not
## consulted at all: a lesson that waited on the bag would sometimes never deal
## the piece it is teaching.
var _sequence: Array[int] = []
var _cursor: int = 0


## A seed of 0 means "pick one", which is what play wants. Tests pass a seed.
func _init(random_seed: int = 0) -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed


## Deal this order instead of a bag, cycling if it runs out. The cycle is
## deliberate: a lesson should not end because the script ran dry.
func set_sequence(sequence: Array) -> void:
	_sequence.clear()
	for kind in sequence:
		_sequence.append(int(kind))
	_cursor = 0


func next() -> int:
	if not _sequence.is_empty():
		var kind: int = _sequence[_cursor % _sequence.size()]
		_cursor += 1
		return kind
	if _queue.is_empty():
		_shuffle_into_queue()
	return _queue.pop_front()


## The kind that will be dealt `index` deals from now (0 = the next one).
func peek(index: int) -> int:
	if not _sequence.is_empty():
		return _sequence[(_cursor + index) % _sequence.size()]
	while _queue.size() <= index:
		_shuffle_into_queue()
	return _queue[index]


## What is left of the current bags, for the debug overlay. Never read by play.
func remaining() -> Array[int]:
	if not _sequence.is_empty():
		var rest: Array[int] = []
		for index in _sequence.size():
			rest.append(_sequence[(_cursor + index) % _sequence.size()])
		return rest
	return _queue.duplicate()


func _shuffle_into_queue() -> void:
	var bag: Array[int] = []
	for kind in Tetromino.KIND_COUNT:
		bag.append(kind)
	for index in range(bag.size() - 1, 0, -1):
		var swap_with := _rng.randi_range(0, index)
		var held := bag[index]
		bag[index] = bag[swap_with]
		bag[swap_with] = held
	_queue.append_array(bag)
