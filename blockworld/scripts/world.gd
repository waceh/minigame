extends Node3D

const SIZE = 48
const CHUNK = 12
const SAVE_PATH = "user://island_v1.json"
const BLOCK_NAMES = ["잔디", "흙", "돌", "모래", "나무", "잎", "벽돌"]
const COLORS = [Color("79a94d"), Color("986d49"), Color("8b98a0"), Color("dfca8d"), Color("9d7448"), Color("488a4c"), Color("b66e59")]
const DIRS = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
const US = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.RIGHT, Vector3.LEFT, Vector3.RIGHT]
const VS = [Vector3.UP, Vector3.UP, Vector3.BACK, Vector3.FORWARD, Vector3.UP, Vector3.UP]
var save_path = SAVE_PATH
var blocks: Dictionary = {}
var edits: Dictionary = {}
var chunks: Dictionary = {}
var material: StandardMaterial3D
var player: CharacterBody3D
var camera: Camera3D
var hud: Control
var outline: MeshInstance3D
var selected = 0
var active = false
var target: Dictionary = {}
var spawn = Vector3.ZERO
var save_timer = -1.0
var message = ""
var message_time = 0.0
var breaking = 0
var placing = 0
var pointer_locked = false
var pointer_callback

func _ready():
	if OS.has_feature("web"):
		pointer_callback = JavaScriptBridge.create_callback(_on_pointer_lock)
		JavaScriptBridge.get_interface("window").blockIslandPointer = pointer_callback
	make_environment()
	make_material()
	generate_world()
	load_edits()
	for x in range(-2, 2):
		for z in range(-2, 2): rebuild_chunk(Vector2i(x, z))
	make_player()
	make_outline()
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/hud.gd").new()
	hud.world = self
	layer.add_child(hud)

func terrain_height(x: int, z: int) -> int:
	var distance = Vector2(x, z).length()
	return clampi(int(6 + sin(x * 0.19) * 1.8 + cos(z * 0.23) * 1.5 - maxf(0, distance - 14) * 0.55), 1, 10)

func generate_world():
	blocks.clear()
	for x in range(-24, 24):
		for z in range(-24, 24):
			var height = terrain_height(x, z)
			for y in range(height + 1):
				blocks[Vector3i(x, y, z)] = (3 if height <= 3 else 0) if y == height else (1 if y >= height - 2 else 2)
	for tree in [Vector2i(-10, -9), Vector2i(8, -8), Vector2i(14, 6), Vector2i(-12, 9), Vector2i(3, 12), Vector2i(-5, -16), Vector2i(17, -4), Vector2i(-17, -2)]:
		var base = terrain_height(tree.x, tree.y) + 1
		for y in range(base, base + 4): blocks[Vector3i(tree.x, y, tree.y)] = 4
		for x in range(-2, 3):
			for z in range(-2, 3):
				for y in range(3):
					if abs(x) + abs(z) + y < 5:
						var cell = Vector3i(tree.x + x, base + 3 + y, tree.y + z)
						if not blocks.has(cell): blocks[cell] = 5
	spawn = Vector3(0.5, terrain_height(0, 5) + 1.05, 5.5)

func make_material():
	var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 527
	for x in range(16):
		for y in range(16):
			var value = rng.randf_range(0.82, 1.0)
			if x == 0 or y == 0: value *= 0.88
			image.set_pixel(x, y, Color(value, value, value))
	material = StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0

func make_environment():
	var env = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var atmosphere = ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("5c9eca")
	atmosphere.sky_horizon_color = Color("d5e7df")
	atmosphere.ground_horizon_color = Color("d5e7df")
	atmosphere.ground_bottom_color = Color("759ba6")
	sky.sky_material = atmosphere
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d6e8f4")
	settings.ambient_light_energy = 0.38
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("fff1cd")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)
	var water = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(500, 500)
	water.mesh = plane
	water.position.y = 2.65
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color("409ba6")
	water_material.roughness = 0.28
	water.material_override = water_material
	add_child(water)
	# Floating voxel clouds, built as shared meshes instead of thousands of nodes.
	var cloud_material = StandardMaterial3D.new()
	cloud_material.albedo_color = Color("eef5ef")
	var mesh = BoxMesh.new()
	mesh.size = Vector3(8, 1.5, 4)
	for i in range(14):
		var cloud = MeshInstance3D.new()
		cloud.mesh = mesh
		cloud.material_override = cloud_material
		cloud.position = Vector3(sin(i * 5.3) * 65, 28 + i % 3 * 3, cos(i * 3.8) * 65)
		cloud.scale.x = 1 + (i % 3) * 0.4
		add_child(cloud)

func chunk_of(cell: Vector3i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.z) / CHUNK))

func rebuild_chunk(key: Vector2i):
	if chunks.has(key):
		remove_child(chunks[key])
		chunks[key].queue_free()
		chunks.erase(key)
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	for x in range(key.x * CHUNK, (key.x + 1) * CHUNK):
		for z in range(key.y * CHUNK, (key.y + 1) * CHUNK):
			for y in range(0, 25):
				var cell = Vector3i(x, y, z)
				if not blocks.has(cell): continue
				var kind: int = blocks[cell]
				for face in range(6):
					if blocks.has(cell + DIRS[face]): continue
					var center = Vector3(cell) + Vector3.ONE * 0.5 + Vector3(DIRS[face]) * 0.5
					var color: Color = COLORS[kind]
					if kind == 0 and face != 2: color = Color("8b7950") if face != 3 else COLORS[1]
					color = color * ([0.82, 0.74, 1.0, 0.58, 0.85, 0.78][face])
					color.a = 1.0
					var offset = vertices.size()
					for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
						vertices.append(center + US[face] * corner.x * 0.5 + VS[face] * corner.y * 0.5)
						normals.append(Vector3(DIRS[face]))
						colors.append(color)
						uvs.append((corner + Vector2.ONE) * 0.5)
					for index in [0, 1, 2, 0, 2, 3]: indices.append(offset + index)
	if vertices.is_empty(): return
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.create_trimesh_collision()
	chunks[key] = node

func make_player():
	player = load("res://scripts/player.gd").new()
	player.world = self
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.9
	player.add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 75
	camera.far = 240
	player.add_child(camera)
	player.camera = camera
	add_child(player)
	player.position = spawn
	player.rotation.y = 0.35
	camera.rotation.x = -0.16

func make_outline():
	outline = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	var line_material = StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color("fff4bf")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	for axis in range(3):
		for a in [0.0, 1.0]:
			for b in [0.0, 1.0]:
				var start = Vector3.ZERO
				start[(axis + 1) % 3] = a
				start[(axis + 2) % 3] = b
				var finish = start
				finish[axis] = 1
				mesh.surface_add_vertex((start - Vector3.ONE * 0.5) * 1.006)
				mesh.surface_add_vertex((finish - Vector3.ONE * 0.5) * 1.006)
	mesh.surface_end()
	outline.mesh = mesh
	outline.visible = false
	add_child(outline)

func _process(dt):
	if not is_instance_valid(player): return
	if active:
		var query = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 6.0)
		query.exclude = [player.get_rid()]
		target = get_world_3d().direct_space_state.intersect_ray(query)
		outline.visible = not target.is_empty()
		if outline.visible:
			outline.position = Vector3(hit_cell(false)) + Vector3.ONE * 0.5
	else: outline.visible = false
	if save_timer >= 0:
		save_timer -= dt
		if save_timer < 0: save_world()
	message_time = maxf(0, message_time - dt)

func hit_cell(adjacent: bool) -> Vector3i:
	var point: Vector3 = target.position + target.normal * (0.02 if adjacent else -0.02)
	return Vector3i(floori(point.x), floori(point.y), floori(point.z))

func can_place(cell: Vector3i) -> bool:
	if cell.x < -24 or cell.x >= 24 or cell.z < -24 or cell.z >= 24 or cell.y < 1 or cell.y > 24 or blocks.has(cell): return false
	var body = AABB(player.position + Vector3(-0.3, 0.03, -0.3), Vector3(0.6, 1.75, 0.6))
	return not body.intersects(AABB(Vector3(cell), Vector3.ONE))

func edit_target(place: bool):
	if not active or target.is_empty(): return
	var cell = hit_cell(place)
	if place:
		if not can_place(cell):
			show_message("여기에는 블록을 놓을 수 없어요")
			return
		set_block(cell, selected)
		placing += 1
	else:
		if cell.y <= 0:
			show_message("섬의 바닥은 부술 수 없어요")
			return
		set_block(cell, -1)
		breaking += 1

func set_block(cell: Vector3i, kind: int):
	if kind < 0: blocks.erase(cell)
	else: blocks[cell] = kind
	edits["%d,%d,%d" % [cell.x, cell.y, cell.z]] = kind
	var affected = {chunk_of(cell): true}
	for direction in DIRS: affected[chunk_of(cell + direction)] = true
	for key in affected: rebuild_chunk(key)
	save_timer = 0.8

func show_message(text: String):
	message = text
	message_time = 3.0

func save_world():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 1, "edits": edits}))
		show_message("월드 저장 완료")
	else: show_message("저장하지 못했어요. 브라우저 저장 공간을 확인하세요")

func load_edits():
	if not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or not data.get("edits") is Dictionary: return
	for key in data.edits:
		var parts = str(key).split(",")
		if parts.size() != 3: continue
		var cell = Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var kind = int(data.edits[key])
		if cell.x < -24 or cell.x >= 24 or cell.z < -24 or cell.z >= 24 or cell.y < 1 or cell.y > 24 or kind < -1 or kind > 6: continue
		edits[key] = kind
		if kind == -1: blocks.erase(cell)
		else: blocks[cell] = kind

func begin():
	active = true
	if not hud.mobile:
		if OS.has_feature("web"): JavaScriptBridge.eval("window.blockIslandSetCapture(true)")
		else: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.refresh_overlay()

func pause_game():
	active = false
	pointer_locked = false
	if OS.has_feature("web"): JavaScriptBridge.eval("window.blockIslandSetCapture(false)")
	else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.clear_touch()
	if not edits.is_empty(): save_world()
	hud.refresh_overlay()

func respawn():
	# Find a safe landing height even if the spawn column was edited.
	var top = terrain_height(0, 5)
	for y in range(25):
		if blocks.has(Vector3i(0, y, 5)): top = y
	player.position = Vector3(0.5, top + 1.05, 5.5)
	player.velocity = Vector3.ZERO
	show_message("섬의 시작 지점으로 돌아왔어요")

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and is_instance_valid(hud): pause_game()

func _on_pointer_lock(args: Array):
	pointer_locked = bool(args[0])
	if bool(args[1]):
		show_message("게임 화면을 클릭하면 마우스가 고정됩니다")
	elif not pointer_locked and active and not hud.mobile:
		pause_game()

func mouse_captured() -> bool:
	return pointer_locked or (not OS.has_feature("web") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
