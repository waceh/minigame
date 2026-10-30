extends RefCounted

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.5, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, mat)

static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 12
	shape.rings = 6
	return mesh(parent, shape, pos, mat)

static func cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, mat: Material, segments: int = 12) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = segments
	return mesh(parent, shape, pos, mat)

static func ring(parent: Node3D, radius: float, thickness: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 64
	shape.ring_segments = 8
	return mesh(parent, shape, pos, mat)

# Faceted tapered armor: eight bevelled corners, deliberately broad shoulders.
static func armor(parent: Node3D, bottom: Vector2, top: Vector2, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for level in range(2):
		var size: Vector2 = bottom if level == 0 else top
		var x := size.x / 2
		var z := size.y / 2
		var bevel := minf(x, z) * 0.35
		for p in [Vector2(-x + bevel, -z), Vector2(x - bevel, -z), Vector2(x, -z + bevel), Vector2(x, z - bevel), Vector2(x - bevel, z), Vector2(-x + bevel, z), Vector2(-x, z - bevel), Vector2(-x, -z + bevel)]:
			points.append(Vector3(p.x, (level - 0.5) * height, p.y))
	for i in range(8):
		var j := (i + 1) % 8
		for index in [i, j + 8, j, i, i + 8, j + 8]:
			st.add_vertex(points[index])
		st.add_vertex(Vector3(0, -height / 2, 0))
		st.add_vertex(points[i])
		st.add_vertex(points[j])
		st.add_vertex(Vector3(0, height / 2, 0))
		st.add_vertex(points[j + 8])
		st.add_vertex(points[i + 8])
	st.generate_normals()
	return mesh(parent, st.commit(), pos, mat)
