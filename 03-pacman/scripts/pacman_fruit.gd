class_name PacmanFruit
extends Area2D
## Bonus fruit: appears above the ghost house at a pellet threshold, sits for
## `lifetime` seconds, then vanishes.

signal collected(kind: String, score: int)

## Score per fruit kind, following the arcade progression.
const SCORES := {
	"cherry": 100, "strawberry": 300, "orange": 500, "apple": 700,
}

@onready var _collision: CollisionShape2D = $Collision
@onready var _sprite: Sprite2D = $Sprite

var kind := "cherry"

var _timer := 0.0
var _lifetime := 9.5
var _taken := false


func setup(fruit_kind: String, sprites: PacmanSprites, cell: Vector2i,
		lifetime: float) -> void:
	kind = fruit_kind
	_lifetime = lifetime

	collision_layer = PacmanLayers.FRUIT
	collision_mask = 0
	monitoring = false
	monitorable = true

	var shape := CircleShape2D.new()
	shape.radius = PacmanGrid.CELL * 0.4
	_collision.shape = shape
	_sprite.texture = sprites.texture("fruit", kind, 0)

	position = PacmanGrid.cell_center(cell)


func _process(delta: float) -> void:
	if _taken:
		return
	_timer += delta
	if _timer >= _lifetime:
		queue_free()


func score() -> int:
	return int(SCORES.get(kind, 100))


## Called by Pac-Man's pellet handler when it enters this cell.
func collect() -> void:
	if _taken:
		return
	_taken = true
	collected.emit(kind, score())
	queue_free()
