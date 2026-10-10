class_name RaceTrackPath
extends Path3D
## Sweeps a slab cross-section along the curve to make the road surface and
## its collision, plus a barrier on either edge wherever a wall spans it. The
## curve itself lives in resources/tracks/ so it stays editable in the 3D
## viewport; this node only fills the geometry in.

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _shape: CollisionShape3D = $Body/Shape
@onready var _debug: MeshInstance3D = $Debug

## Barriers rising out of the road's edges. Level data rather than tuning, so
## it is edited here and saved with the level rather than kept in the cfg.
@export var walls: Array[TrackWall] = []

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
var _wall_color := Color("46608C")
var _wall_thickness := 0.35
## Metres of road a wall takes to rise out of the surface and to sink back
## into it. A wall that simply starts is a wall the ball can catch an edge on.
var _wall_ramp := 5.0
var _debug_color := Color("FFE94A")
var _bank_max := 12.0
var _full_bank_radius := 100.0
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
	_wall_color = settings.track.wall_color
	_wall_thickness = settings.track.wall_thickness
	_wall_ramp = settings.track.wall_ramp
	_debug_color = settings.track.debug_color
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
## itself; a track that crosses, loops back, or forks will need something
## better.
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
	if _samples < 1:
		push_error("RaceTrackPath: samples must be at least 1")
		return
	var length := curve.get_baked_length()
	var slabs: Array = []
	var lefts: Array = []
	var rights: Array = []
	for i in _samples + 1:
		var offset := length * float(i) / float(_samples)
		var along := float(i) / float(_samples)
		var frame := _banked(curve.sample_baked_with_rotation(offset, false, true),
				offset, length)
		slabs.append(_slab_ring(frame))
		lefts.append(_wall_ring(frame, -1, along, length))
		rights.append(_wall_ring(frame, 1, along, length))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit_slab(surface, slabs)
	_sweep(surface, lefts, _wall_color)
	_sweep(surface, rights, _wall_color)
	var first: PackedVector3Array = slabs[0]
	var last: PackedVector3Array = slabs[slabs.size() - 1]
	_emit_cap(surface, first, true, _ring_color(0))
	_emit_cap(surface, last, false, _ring_color(_samples))
	_mesh_instance.mesh = surface.commit()
	_mesh_instance.material_override = _road_material()
	# Only the walls collide. The road has none: the ball is held up by
	# _ride_road() in ball.gd, and a creased road surface underneath it would
	# only be a second floor for it to catch on.
	var faces := _wall_faces(lefts) + _wall_faces(rights)
	_shape.shape = _shape_from(faces)
	# The overlay is built from those same faces, so P shows what the ball can
	# actually hit rather than a redrawing of it.
	_debug.mesh = _wireframe(faces)
	_debug.material_override = _debug_material()
	_debug.visible = false


## Toggling visibility rather than rebuilding: a MeshInstance's visible flag is
## the one switch that cannot be left showing a stale frame.
func toggle_debug() -> void:
	_debug.visible = not _debug.visible


## Every collision triangle's three edges, lifted a hair along the triangle's
## own normal so the wire does not z-fight the surface it is drawn on.
static func _wireframe(faces: PackedVector3Array) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var lift := (b - a).cross(c - a).normalized() * 0.02
		_edge(mesh, a + lift, b + lift)
		_edge(mesh, b + lift, c + lift)
		_edge(mesh, c + lift, a + lift)
	mesh.surface_end()
	return mesh


static func _edge(mesh: ImmediateMesh, from: Vector3, to: Vector3) -> void:
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)


func _debug_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _debug_color
	return material


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


func _slab_ring(frame: Transform3D) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for corner in PROFILE:
		ring.append(frame * Vector3(
				corner.x * _half_width, corner.y * _thickness, corner.z))
	return ring


## The wall's cross-section at one point, in world units. Every corner is
## scaled out of the road's edge by how present the wall is there, so an absent
## wall collapses to a point ON the surface and a wall rises out of the road
## rather than appearing beside it with a free edge for the ball to catch.
func _wall_ring(frame: Transform3D, side: int, along: float, length: float) -> PackedVector3Array:
	var span := _wall_at(side, along, length)
	var present: float = span["present"]
	var base := Vector3(float(side) * _half_width, 0.0, 0.0)
	var corners := [
		base,
		base + Vector3(0.0, span["height"], 0.0),
		base + Vector3(float(side) * _wall_thickness, span["height"], 0.0),
		base + Vector3(float(side) * _wall_thickness, 0.0, 0.0),
	]
	# Mirrored so both walls wind the same way and their faces come out facing
	# the road rather than away from it.
	if side < 0:
		corners.reverse()
	var ring := PackedVector3Array()
	for corner in corners:
		ring.append(frame * (base + (corner - base) * present))
	return ring


## How much wall stands at this point on this side: which of the spans covers
## it, how tall that span is, and how far up its own ramp it is. Spans are
## taken one at a time rather than combined, so a wall can never be half of two
## overlapping ones.
func _wall_at(side: int, along: float, length: float) -> Dictionary:
	var ramp := _wall_ramp / maxf(length, 1.0)
	var result := {"present": 0.0, "height": 0.0}
	for wall in walls:
		if wall == null or wall.side != side:
			continue
		if along < wall.from_t or along > wall.to_t:
			continue
		var rising := clampf((along - wall.from_t) / ramp, 0.0, 1.0)
		var falling := clampf((wall.to_t - along) / ramp, 0.0, 1.0)
		var present := minf(rising, falling)
		if present > float(result["present"]):
			result = {"present": present, "height": wall.height}
	return result


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


func _emit_slab(surface: SurfaceTool, rings: Array) -> void:
	for i in rings.size() - 1:
		# One colour per band, taken from the ring it starts at, so the marker's
		# edges land exactly on ring boundaries instead of fading between them.
		var near: PackedVector3Array = rings[i]
		var far: PackedVector3Array = rings[i + 1]
		_emit_band(surface, near, far, _ring_color(i))


func _sweep(surface: SurfaceTool, rings: Array, color: Color) -> void:
	for i in rings.size() - 1:
		var near: PackedVector3Array = rings[i]
		var far: PackedVector3Array = rings[i + 1]
		# Where the wall is absent, its cross-section has collapsed to a single
		# point and the band is a run of zero-area triangles. They cost nothing
		# to look at, but they would go into the collision shape as well, and a
		# concave mesh full of degenerate faces is not something to hand to the
		# physics engine — it hung the scene outright the first time.
		if _collapsed(near) and _collapsed(far):
			continue
		_emit_band(surface, near, far, color)


## The walls' triangles on their own, matching the winding _emit_quad uses.
## Kept separate from the mesh so the road can be drawn without being collided
## with.
func _wall_faces(rings: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in rings.size() - 1:
		var near: PackedVector3Array = rings[i]
		var far: PackedVector3Array = rings[i + 1]
		if _collapsed(near) and _collapsed(far):
			continue
		for edge in near.size():
			var next := (edge + 1) % near.size()
			out.append_array(PackedVector3Array([
					near[edge], far[next], near[next],
					near[edge], far[edge], far[next]]))
	return out


static func _collapsed(ring: PackedVector3Array) -> bool:
	for point in ring:
		if point.distance_squared_to(ring[0]) > 0.000001:
			return false
	return true


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
	# One normal for the whole quad, from its two triangles. Per-triangle
	# normals make the road show its triangulation, because a swept quad is
	# never quite planar and its two halves then tilt differently.
	var first := (c - a).cross(b - a)
	var second := (d - a).cross(c - a)
	var normal := first + second
	if normal.length_squared() < 0.000000001:
		return
	normal = -normal.normalized()
	_emit_face(surface, a, c, b, normal, color)
	_emit_face(surface, a, d, c, normal, color)


## Normals are per quad, computed here rather than by
## SurfaceTool.generate_normals(). That one averages across every vertex it
## shares, so the 90-degree edge where a wall meets the road comes out shaded
## as a rounded join: the wall's dark side bleeds onto the road and the road's
## lit side bleeds onto the wall, leaving broad patches that match neither
## surface. The geometry is faceted, so the shading has to be too — but at the
## quad, not the triangle, or the road ribbons show their triangulation.
static func _emit_face(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, normal: Vector3, color: Color) -> void:
	for vertex in [a, b, c]:
		surface.set_normal(normal)
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
