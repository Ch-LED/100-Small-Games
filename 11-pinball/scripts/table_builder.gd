class_name PinballTableBuilder
extends RefCounted
## Turns PinballLayout data into nodes: the collision bodies the ball hits and
## the meshes you see, both from the same vertex list. Keeping them in one place
## is what stops "looks like it should hit" from drifting away from "does hit"
## (CONSTITUTION 五点五).

const WALL_COLOR := Color("533483")
const BUMPER_COLOR := Color("E94560")
const SLINGSHOT_COLOR := Color("FFB703")

## A bumper rings bright and high; a kickout thuds lower; a target is in between.
const BUMPER_TONE := 880.0
const SLINGSHOT_TONE := 466.0
const KICKOUT_TONE := 560.0
const TARGET_TONE := 740.0

const TARGET_COLOR := Color("FFD24A")
const KICKOUT_COLOR := Color("7BD1FF")
const SINK_COLOR := Color("141A2E")
const ROLLOVER_COLOR := Color("9AA7C7")

static var _wall_material: StandardMaterial3D


## Walls are built one box per polyline segment. A box per segment was chosen
## over a single extruded polygon because the drain is a real gap in the
## outline: a closed polygon has nowhere to put one, and an offset band around
## an open polyline self-intersects at every tight corner.
static func build_walls(body: StaticBody3D, mesh_parent: Node3D, settings: PinballSettings) -> void:
	var thickness: float = settings.table.wall_thickness
	var height: float = settings.table.wall_height
	for polyline in PinballLayout.wall_polylines():
		for i in range(polyline.size() - 1):
			_add_segment(body, mesh_parent, polyline[i], polyline[i + 1], thickness, height)


static func build_flippers(container: Node3D, scene: PackedScene, settings: PinballSettings) -> Array[PinballFlipper]:
	var flippers: Array[PinballFlipper] = []
	for mount in PinballLayout.flipper_mounts():
		var flipper: PinballFlipper = scene.instantiate()
		flipper.name = mount.name
		container.add_child(flipper)
		var pivot: Vector2 = mount.pivot
		flipper.position = Vector3(pivot.x, 0.0, pivot.y)
		flipper.configure(settings.flipper, mount)
		flippers.append(flipper)
	return flippers


static func build_bumpers(container: Node3D, scene: PackedScene, settings: PinballSettings) -> Array[PinballKicker]:
	var height: float = settings.table.wall_height
	var half := Vector3(0.0, height * 0.5, 0.0)
	var kickers: Array[PinballKicker] = []
	# Radii differ between the bumpers -- three big ones up the table, three
	# small on the right -- so the radius travels with the position.
	for spot in PinballLayout.bumper_spots():
		var radius: float = spot.radius
		var bumper: PinballKicker = scene.instantiate()
		container.add_child(bumper)
		bumper.position = Vector3(spot.pos.x, 0.0, spot.pos.y)
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		bumper.set_collision(shape, half)
		bumper.set_mesh(mesh, half)
		bumper.configure(int(settings.score.bumper), float(settings.score.bumper_kick),
				BUMPER_COLOR, BUMPER_TONE)
		kickers.append(bumper)
	return kickers


## Drop targets. The originals are not axis-aligned -- some are visibly skewed on
## the table -- so each one is an arbitrary quad, and both its collision shape
## and its mesh are extruded from those four corners rather than placed as a box.
static func build_targets(container: Node3D, scene: PackedScene, settings: PinballSettings) -> Array[PinballTarget]:
	var height: float = settings.table.wall_height
	var targets: Array[PinballTarget] = []
	for quad in PinballLayout.yellow_targets():
		var centre := Vector2.ZERO
		for p in quad:
			centre += p
		centre /= float(quad.size())
		var local := PackedVector2Array()
		for p in quad:
			local.append(p - centre)

		var target: PinballTarget = scene.instantiate()
		container.add_child(target)
		target.position = Vector3(centre.x, 0.0, centre.y)

		var points := PackedVector3Array()
		for p in local:
			points.append(Vector3(p.x, 0.0, p.y))
		for p in local:
			points.append(Vector3(p.x, height, p.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		target.set_geometry(shape, _prism_mesh(local, height), Vector3.ZERO)
		target.configure(int(settings.score.target), TARGET_TONE, TARGET_COLOR, height)
		targets.append(target)
	return targets


## Kickouts: the two short bars that throw the ball back out. Behaviourally they
## are the same object as a bumper -- hit it, it throws the ball -- so they reuse
## the kicker scene and only differ in shape and numbers.
static func build_kickouts(container: Node3D, scene: PackedScene, settings: PinballSettings) -> Array[PinballKicker]:
	var height: float = settings.table.wall_height
	var thickness: float = settings.table.wall_thickness
	var kickers: Array[PinballKicker] = []
	for segment in PinballLayout.kickers():
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var delta := b - a
		var mid := (a + b) * 0.5
		var size := Vector3(delta.length(), height, thickness)
		var placement := Transform3D(Basis(Vector3.UP, -atan2(delta.y, delta.x)),
				Vector3(0.0, height * 0.5, 0.0))

		var kicker: PinballKicker = scene.instantiate()
		container.add_child(kicker)
		kicker.position = Vector3(mid.x, 0.0, mid.y)
		var shape := BoxShape3D.new()
		shape.size = size
		var mesh := BoxMesh.new()
		mesh.size = size
		kicker.set_collision(shape, placement.origin)
		kicker.set_mesh(mesh, placement.origin)
		kicker.configure(int(settings.score.kicker), float(settings.score.kicker_kick),
				KICKOUT_COLOR, KICKOUT_TONE)
		kickers.append(kicker)
	return kickers


## Sinks and rollovers have no collision of their own -- the ball passes over
## them and the table decides what happened, because a fast ball steps clean over
## an Area between two physics ticks. They only get something to look at: a
## sunken disc for a sink, a small lit tile for a rollover.
static func build_sink_marks(parent: Node3D, settings: PinballSettings) -> void:
	for spot in PinballLayout.sink_spots():
		var disc := CylinderMesh.new()
		disc.top_radius = spot.radius
		disc.bottom_radius = spot.radius * 0.8
		disc.height = 0.06
		var node := MeshInstance3D.new()
		node.mesh = disc
		node.position = Vector3(spot.pos.x, 0.02, spot.pos.y)
		node.material_override = _shared_flat_material(SINK_COLOR, 0.0)
		parent.add_child(node)


static func build_rollover_marks(parent: Node3D, settings: PinballSettings) -> void:
	for quad in PinballLayout.rollovers():
		var centre := Vector2.ZERO
		for p in quad:
			centre += p
		centre /= float(quad.size())
		var local := PackedVector2Array()
		for p in quad:
			local.append(p - centre)
		var node := MeshInstance3D.new()
		node.mesh = _prism_mesh(local, 0.05)
		node.position = Vector3(centre.x, 0.01, centre.y)
		node.material_override = _shared_flat_material(ROLLOVER_COLOR, 0.6)
		parent.add_child(node)


static func _shared_flat_material(tint: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.7
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = glow > 0.0
	material.emission = tint
	material.emission_energy_multiplier = glow
	return material


static func _add_segment(body: StaticBody3D, mesh_parent: Node3D, a: Vector2, b: Vector2, thickness: float, height: float) -> void:
	var delta := b - a
	var run := delta.length()
	if run < 0.001:
		return
	var mid := (a + b) * 0.5
	# Longer than the run it covers, so neighbouring boxes overlap at the
	# corners rather than leaving a slot the ball can squeeze through.
	var size := Vector3(run + thickness, height, thickness)
	var placement := Transform3D(Basis(Vector3.UP, -atan2(delta.y, delta.x)),
			Vector3(mid.x, height * 0.5, mid.y))

	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = placement
	body.add_child(collider)

	var box := BoxMesh.new()
	box.size = size
	box.material = _shared_wall_material()
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.transform = placement
	mesh_parent.add_child(mesh)


## A triangular prism standing on the table plane. Written out rather than built
## from PrismMesh because a wedge here is an arbitrary triangle -- two feet on
## the funnel wall, one apex out in the field -- and PrismMesh only ever makes
## isosceles ones.
static func _prism_mesh(triangle: PackedVector2Array, height: float) -> ArrayMesh:
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for p in triangle:
		bottom.append(Vector3(p.x, 0.0, p.y))
		top.append(Vector3(p.x, height, p.y))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_triangle(tool, top[0], top[1], top[2], Vector3.UP)
	_add_triangle(tool, bottom[2], bottom[1], bottom[0], Vector3.DOWN)
	for i in 3:
		var j := (i + 1) % 3
		var edge := triangle[j] - triangle[i]
		var outward := Vector3(edge.y, 0.0, -edge.x).normalized()
		_add_triangle(tool, bottom[i], bottom[j], top[j], outward)
		_add_triangle(tool, bottom[i], top[j], top[i], outward)
	return tool.commit() as ArrayMesh


static func _add_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var corners: Array[Vector3] = [a, b, c]
	for corner in corners:
		tool.set_normal(normal)
		tool.add_vertex(corner)


static func _shared_wall_material() -> StandardMaterial3D:
	if _wall_material == null:
		_wall_material = StandardMaterial3D.new()
		_wall_material.albedo_color = WALL_COLOR
		_wall_material.roughness = 0.6
	return _wall_material
