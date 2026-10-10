class_name RaceTrackPath
extends Path3D
## Sweeps a slab cross-section along the curve to make the road surface and
## its collision. The curve itself lives in resources/tracks/ so it stays
## editable in the 3D viewport; this node only fills the geometry in.

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _shape: CollisionShape3D = $Body/Shape

## Half the distance the bank's curvature is measured over, in metres. A
## Catmull-Rom curve through sparse waypoints has curvature that swings hard
## from point to point, and a bank that tracks it exactly twists the road
## ring to ring — a washboard at speed. Averaging over 2 * BANK_STEP of road
## is what turns that into a ramp the ball can actually feel as a corner.
const BANK_STEP := 8.0

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
var _samples := 160
var _road_color := Color("2A3346")
var _bank_max := 12.0
var _full_bank_radius := 40.0
var _bank_deadband := 1.5
var _start_t := 0.02
var _finish_t := 0.97
var _marker_span := 0.012
var _start_color := Color("4BD3FF")
var _finish_color := Color("FFD24A")


func configure(settings: Dictionary) -> void:
	_half_width = settings.track.half_width
	_thickness = settings.track.thickness
	_samples = settings.track.samples
	_road_color = settings.track.color
	_bank_max = settings.track.bank_max
	_full_bank_radius = settings.track.full_bank_radius
	_bank_deadband = settings.track.bank_deadband
	_start_t = settings.track.start_t
	_finish_t = settings.track.finish_t
	_marker_span = settings.track.marker_span
	_start_color = settings.track.start_color
	_finish_color = settings.track.finish_color
	_build()


func start_point() -> Vector3:
	return to_global(curve.sample_baked(0.0)) if curve != null else global_position


## How far along the road a point is, 0 at the start and 1 at the end. This is
## the whole of the finish line: no trigger volume, just where the ball is.
func progress_at(point: Vector3) -> float:
	if curve == null:
		return 0.0
	return curve.get_closest_offset(to_local(point)) / curve.get_baked_length()


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
## is the road's up — which the ball rolls about, and which the camera clamps
## its pitch against once the track banks.
##
## get_closest_offset is unambiguous only while the road never passes near
## itself; a track that crosses or loops back will need something better.
func frame_near(point: Vector3) -> Transform3D:
	if curve == null:
		return global_transform
	var length := curve.get_baked_length()
	var offset := curve.get_closest_offset(to_local(point))
	var local := curve.sample_baked_with_rotation(offset, false, true)
	return global_transform * _banked(local, offset, length)


func _build() -> void:
	if curve == null:
		push_error("RaceTrackPath: no curve assigned")
		return
	var rings := _sample_rings()
	if rings.size() < 2:
		push_error("RaceTrackPath: curve produced fewer than two rings")
		return
	_mesh_instance.mesh = _mesh_from(rings)
	_mesh_instance.material_override = _road_material()
	# The collision is taken from the mesh rather than swept a second time, so
	# the road the ball rolls on and the road it is drawn against cannot drift.
	_shape.shape = _shape_from(_mesh_instance.mesh.get_faces())


func _sample_rings() -> Array:
	var length := curve.get_baked_length()
	var rings: Array = []
	for i in _samples + 1:
		var offset := length * float(i) / float(_samples)
		rings.append(_ring(_banked(curve.sample_baked_with_rotation(offset, false, true),
				offset, length)))
	return rings


## A corkscrew section is authored as curve tilt (see the curve generator), and
## the bank below is added on top of it: tilt says "the road rolls about its
## own axis", bank says "the corner leans", and a track may want either.
##
## Bank is derived from the road's own curvature rather than authored per
## control point. Curve3D interpolates tilt linearly between points, so with a
## turn occupying one whole segment the only thing point data can express is a
## step at each end of it — and a step in bank at 20 m/s is a jolt. Deriving it
## lets the bank ramp itself in and out with the turn, and works for any track
## without the curve having to carry anything extra.
func _banked(frame: Transform3D, offset: float, length: float) -> Transform3D:
	var bank := _bank_at(offset, length, frame)
	if is_zero_approx(bank):
		return frame
	var rolled := frame
	rolled.basis = frame.basis.rotated(frame.basis.z, deg_to_rad(bank))
	return rolled


## Signed curvature from the change in heading, then a bank that reaches
## bank_max at full_bank_radius and eases off as the turn widens.
##
## The sign is measured, not derived: the first build banked every corner
## outward, which is precisely the direction that throws the ball off. Checked
## by confirming the road's inner edge ends up the lower one.
func _bank_at(offset: float, length: float, frame: Transform3D) -> float:
	var before := curve.sample_baked(maxf(offset - BANK_STEP, 0.0))
	var here := curve.sample_baked(offset)
	var after := curve.sample_baked(minf(offset + BANK_STEP, length))
	var incoming := (here - before).normalized()
	var outgoing := (after - here).normalized()
	# Heading change spans 2 * BANK_STEP, not BANK_STEP. Dividing by the wrong
	# one doubled every curvature, so full_bank_radius bit at twice the radius
	# it claims to.
	var signed_curvature := (outgoing - incoming).dot(frame.basis.x) / (2.0 * BANK_STEP)
	if absf(signed_curvature) < 0.000001:
		return 0.0
	var strength := clampf(_full_bank_radius * absf(signed_curvature), 0.0, 1.0)
	var bank := -_bank_max * strength * signf(signed_curvature)
	# Nearly straight road has nearly no curvature left, and the sign of what
	# remains is noise. A degree of bank flickering about does nothing except
	# twist the surface, so anything under the deadband is snapped away.
	return 0.0 if absf(bank) < _bank_deadband else bank


func _ring(frame: Transform3D) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for corner in PROFILE:
		ring.append(frame * Vector3(
				corner.x * _half_width, corner.y * _thickness, corner.z))
	return ring


## Start and finish are painted into the road's own vertex colours rather than
## built as separate meshes or trigger volumes: a band of rings takes the
## marker colour, everything else the road colour, and nothing new has to be
## kept in step with the sweep.
func _ring_color(index: int) -> Color:
	var along := float(index) / float(_samples)
	if absf(along - _start_t) < _marker_span:
		return _start_color
	if absf(along - _finish_t) < _marker_span:
		return _finish_color
	return _road_color


func _mesh_from(rings: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size() - 1:
		# One colour per band, taken from the ring it starts at, so the marker's
		# edges land exactly on ring boundaries instead of fading between them.
		_emit_band(surface, rings[i], rings[i + 1], _ring_color(i))
	_emit_cap(surface, rings[0], true, _ring_color(0))
	_emit_cap(surface, rings[rings.size() - 1], false, _ring_color(rings.size() - 1))
	surface.generate_normals()
	return surface.commit()


static func _emit_band(surface: SurfaceTool, near: PackedVector3Array,
		far: PackedVector3Array, color: Color) -> void:
	for edge in near.size():
		var next := (edge + 1) % near.size()
		_emit_quad(surface, near[edge], near[next], far[next], far[edge], color)


static func _emit_cap(surface: SurfaceTool, ring: PackedVector3Array,
		flip: bool, color: Color) -> void:
	if flip:
		_emit_quad(surface, ring[3], ring[2], ring[1], ring[0], color)
	else:
		_emit_quad(surface, ring[0], ring[1], ring[2], ring[3], color)


## Wound so the road's normals face outward. This is not cosmetic: a
## ConcavePolygonShape3D only collides along its face normals
## (backface_collision defaults to false), so a road wound the other way is a
## road the ball falls straight through.
static func _emit_quad(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, color: Color) -> void:
	for vertex in [a, c, b, a, d, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)


static func _shape_from(faces: PackedVector3Array) -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


func _road_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	return material
