class_name RaceTrackPath
extends Path3D
## Sweeps a slab cross-section along the curve to make the road surface and
## its collision. The curve itself lives in resources/tracks/ so it stays
## editable in the 3D viewport; this node only fills the geometry in.

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _shape: CollisionShape3D = $Body/Shape

## Cross-section corners, in the curve's local frame: X is lateral, Y is up.
## Four of them, so the road is a solid slab rather than a surface — a
## zero-thickness shell is something a fast ball slides straight through.
const PROFILE: Array[Vector3] = [
	Vector3(-1.0, 0.0, 0.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(1.0, -1.0, 0.0),
	Vector3(-1.0, -1.0, 0.0),
]

var _half_width := 3.0
var _thickness := 0.6
var _samples := 48
var _color := Color("2A3346")


func configure(settings: Dictionary) -> void:
	_half_width = settings.track.half_width
	_thickness = settings.track.thickness
	_samples = settings.track.samples
	_color = settings.track.color
	_build()


func start_point() -> Vector3:
	return to_global(curve.sample_baked(0.0)) if curve != null else global_position


## Lowest baked point of the road, so the ball can be judged fallen relative to
## where the road actually goes rather than against a fixed height.
func lowest_point() -> float:
	if curve == null:
		return global_position.y
	var length := curve.get_baked_length()
	var lowest := INF
	for i in 64:
		lowest = minf(lowest, to_global(curve.sample_baked(length * float(i) / 63.0)).y)
	return lowest


## The curve frame nearest a world point, with the curve's tilt applied. Its Y
## is the road's up — which the ball rolls about, and which the camera will
## clamp its pitch against once the track banks.
##
## get_closest_offset is unambiguous only while the road never passes near
## itself; a track that crosses or loops back will need something better.
func frame_near(point: Vector3) -> Transform3D:
	if curve == null:
		return global_transform
	var offset := curve.get_closest_offset(to_local(point))
	return global_transform * curve.sample_baked_with_rotation(offset, false, true)


func _build() -> void:
	if curve == null:
		push_error("RaceTrackPath: no curve assigned")
		return
	var rings := _sample_rings()
	if rings.size() < 2:
		push_error("RaceTrackPath: curve produced fewer than two rings")
		return
	var triangles := _triangles(rings)
	_mesh_instance.mesh = _mesh_from(triangles)
	_mesh_instance.material_override = _road_material()
	_shape.shape = _shape_from(triangles)


func _sample_rings() -> Array:
	var length := curve.get_baked_length()
	var rings: Array = []
	for i in _samples + 1:
		rings.append(_ring(curve.sample_baked_with_rotation(
				length * float(i) / float(_samples))))
	return rings


func _ring(frame: Transform3D) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for corner in PROFILE:
		ring.append(frame * Vector3(
				corner.x * _half_width, corner.y * _thickness, corner.z))
	return ring


func _triangles(rings: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in rings.size() - 1:
		_append_band(out, rings[i], rings[i + 1])
	_append_cap(out, rings[0], true)
	_append_cap(out, rings[rings.size() - 1], false)
	return out


static func _append_band(out: PackedVector3Array, near: PackedVector3Array,
		far: PackedVector3Array) -> void:
	for edge in near.size():
		var next := (edge + 1) % near.size()
		_append_quad(out, near[edge], near[next], far[next], far[edge])


static func _append_cap(out: PackedVector3Array, ring: PackedVector3Array,
		flip: bool) -> void:
	if flip:
		_append_quad(out, ring[3], ring[2], ring[1], ring[0])
	else:
		_append_quad(out, ring[0], ring[1], ring[2], ring[3])


## Wound so the road's normals face outward. This is not cosmetic: a
## ConcavePolygonShape3D only collides along its face normals
## (backface_collision defaults to false), so a road wound the other way is a
## road the ball falls straight through.
static func _append_quad(out: PackedVector3Array, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3) -> void:
	out.append(a)
	out.append(c)
	out.append(b)
	out.append(a)
	out.append(d)
	out.append(c)


static func _mesh_from(triangles: PackedVector3Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in triangles:
		surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


static func _shape_from(triangles: PackedVector3Array) -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(triangles)
	return shape


func _road_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _color
	material.roughness = 0.85
	return material
