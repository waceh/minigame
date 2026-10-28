extends Node3D

const Track = preload("res://scripts/track.gd")
const FONT = preload("res://font.ttf")
const SpeedLinesScript = preload("res://scripts/speed_lines.gd")
const JoystickScript = preload("res://scripts/joystick.gd")
const TILE_SIZE := 4.0
const SHIP_HEIGHT := 0.55
const JUMP_HEIGHT_MULTIPLIER := sqrt(3.0)
const FAST_SPEED := 40.0
const MAX_ACCEL_SPEED := 60.0
const LANE_X := [-8.0, -4.0, 0.0, 4.0, 8.0]

var track = Track.new()
var level := 0
var mode := "title"
var player_x := 0.0
var player_z := -5.0
var player_y := SHIP_HEIGHT
var vertical_speed := 0.0
var speed := 16.0
var boost_time := 0.0
var fuel := 100.0
var oxygen := 100.0
var elapsed := 0.0
var last_pad := ""
var message := ""
var touch_steer := 0.0
var touch_fast := false
var touch_brake := false
var touch_jump := false
var stars: Array[MeshInstance3D] = []

var course_root: Node3D
var ship: Node3D
var camera: Camera3D
var hud: CanvasLayer
var status_label: Label
var help_label: Label
var title_label: Label
var fuel_bar: ProgressBar
var oxygen_bar: ProgressBar
var speed_lines
var engine_trails: Array[MeshInstance3D] = []
var joystick
var action_buttons: Dictionary = {}
var action_touches: Dictionary = {}
var mouse_actions: Dictionary = {}

func _ready() -> void:
	Input.emulate_mouse_from_touch = false
	_configure_mobile_view()
	get_window().size_changed.connect(_configure_mobile_view)
	_create_world()
	_create_ship()
	_create_hud()
	_build_course()
	_update_display()

func _configure_mobile_view() -> void:
	if DisplayServer.is_touchscreen_available():
		var portrait := get_window().size.x < get_window().size.y
		get_window().content_scale_size = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)

func _create_world() -> void:
	course_root = Node3D.new()
	add_child(course_root)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.current = true
	add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("070e28")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("596ca2")
	env.ambient_light_energy = 0.6
	ambient.environment = env
	add_child(ambient)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261027
	for i in range(100):
		var star := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.035, 0.11)
		mesh.height = mesh.radius * 2.0
		star.mesh = mesh
		star.material_override = _material(Color("a7dfff"), true)
		star.position = Vector3(rng.randf_range(-100, 100), rng.randf_range(-25, 60), rng.randf_range(-170, 40))
		add_child(star)
		stars.append(star)

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.2
	mat.roughness = 0.36
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	return mat

func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color, glow)
	node.position = position
	parent.add_child(node)
	return node

func _road_batch(transforms: Array[Transform3D], color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.85, 0.42, 3.85)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	node.material_override = _material(color)
	course_root.add_child(node)

func _create_ship() -> void:
	ship = Node3D.new()
	add_child(ship)
	_box(ship, Vector3(1.6, 0.35, 2.3), Vector3(0, 0, 0), Color("d7e7f5"))
	_box(ship, Vector3(0.65, 0.33, 0.9), Vector3(0, 0.31, -0.2), Color("4ac9eb"), true)
	_box(ship, Vector3(2.5, 0.12, 0.65), Vector3(0, -0.08, 0.4), Color("fb646d"))
	for side in [-1, 1]:
		_box(ship, Vector3(0.38, 0.18, 0.38), Vector3(side * 0.55, -0.23, 1.08), Color("ffb650"), true)
		var trail := _box(ship, Vector3(0.17, 0.12, 4.0), Vector3(side * 0.55, -0.23, 3.15), Color("76eaff"), true)
		trail.visible = false
		engine_trails.append(trail)
	ship.position = Vector3(player_x, player_y, player_z)

func _build_course() -> void:
	for child in course_root.get_children():
		child.queue_free()
	var light_roads: Array[Transform3D] = []
	var dark_roads: Array[Transform3D] = []
	for row in range(track.length(level)):
		for lane in range(5):
			var kind: int = track.tile_at(level, row, lane)
			if kind == Track.Tile.GAP:
				continue
			var x: float = LANE_X[lane]
			var z := -(float(row) + 0.5) * TILE_SIZE
			if kind == Track.Tile.ROAD:
				var road_transform := Transform3D(Basis.IDENTITY, Vector3(x, -0.24, z))
				if (row + lane) % 2 == 0:
					light_roads.append(road_transform)
				else:
					dark_roads.append(road_transform)
				continue
			var shade := Color("364e90") if (row + lane) % 2 == 0 else Color("2d437e")
			if kind == Track.Tile.FUEL:
				shade = Color("37bfff")
			elif kind == Track.Tile.OXYGEN:
				shade = Color("54ecae")
			elif kind == Track.Tile.HAZARD:
				shade = Color("e15a70")
			elif kind == Track.Tile.BOOST:
				shade = Color("edba58")
			_box(course_root, Vector3(3.85, 0.42, 3.85), Vector3(x, -0.24, z), shade, kind != Track.Tile.ROAD)
			if kind == Track.Tile.HAZARD:
				_box(course_root, Vector3(1.2, 1.25, 1.25), Vector3(x, 0.62, z), Color("ff4f69"), true)
			elif kind in [Track.Tile.FUEL, Track.Tile.OXYGEN, Track.Tile.BOOST]:
				_box(course_root, Vector3(2.4, 0.07, 2.4), Vector3(x, 0.025, z), Color("d6faff"), true)
				if kind == Track.Tile.BOOST:
					_box(course_root, Vector3(3.5, 0.12, 0.38), Vector3(x, 0.12, z + 1.0), Color("fff7ad"), true)
					_box(course_root, Vector3(3.5, 0.12, 0.38), Vector3(x, 0.12, z - 1.0), Color("fff7ad"), true)
	_road_batch(light_roads, Color("364e90"))
	_road_batch(dark_roads, Color("2d437e"))
	for row in range(Track.LAUNCH_ROWS[level] + 2, Track.SKY_GAP_ENDS[level] + 1, 3):
		for side in [-1, 1]:
			_box(course_root, Vector3(0.2, 2.2, 0.2), Vector3(side * 10.1, 0.3, -(float(row) + 0.5) * TILE_SIZE), Color("7feaff"), true)
	for lane in range(5):
		_box(course_root, Vector3(3.8, 0.1, 0.45), Vector3(LANE_X[lane], 0.05, -track.length(level) * TILE_SIZE + 1), Color("ffe281"), true)
	var finish_z := -track.length(level) * TILE_SIZE + 2.0
	for side in [-1, 1]:
		_box(course_root, Vector3(0.8, 5.0, 0.8), Vector3(side * 10.0, 2.5, finish_z), Color("8be9ff"), true)
	_box(course_root, Vector3(21, 0.8, 0.8), Vector3(0, 5, finish_z), Color("8be9ff"), true)

func _label(parent: Node, text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _create_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	ui.theme = theme
	hud.add_child(ui)
	speed_lines = SpeedLinesScript.new()
	speed_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(speed_lines)
	var top := HBoxContainer.new()
	top.position = Vector2(24, 20)
	top.size = Vector2(1230, 46)
	ui.add_child(top)
	status_label = _label(top, "", 22, Color("e8f4ff"))
	var meter_panel := VBoxContainer.new()
	meter_panel.position = Vector2(24, 73)
	meter_panel.size = Vector2(220, 75)
	ui.add_child(meter_panel)
	_label(meter_panel, "FUEL", 14, Color("77daff"))
	fuel_bar = ProgressBar.new()
	fuel_bar.max_value = 100
	fuel_bar.show_percentage = false
	meter_panel.add_child(fuel_bar)
	_label(meter_panel, "OXYGEN", 14, Color("80f4c1"))
	oxygen_bar = ProgressBar.new()
	oxygen_bar.max_value = 100
	oxygen_bar.show_percentage = false
	meter_panel.add_child(oxygen_bar)
	title_label = _label(ui, "", 44, Color("ffffff"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.anchor_left = 0.03
	title_label.anchor_right = 0.97
	title_label.anchor_top = 0.32
	title_label.anchor_bottom = 0.32
	title_label.offset_bottom = 70
	help_label = _label(ui, "", 23, Color("d5e7ff"))
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.anchor_left = 0.03
	help_label.anchor_right = 0.97
	help_label.anchor_top = 0.42
	help_label.anchor_bottom = 0.42
	help_label.offset_bottom = 140
	joystick = JoystickScript.new()
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 20
	joystick.offset_right = 210
	joystick.offset_top = -200
	joystick.offset_bottom = -10
	joystick.changed.connect(func(value: float): touch_steer = value)
	ui.add_child(joystick)
	var buttons := HBoxContainer.new()
	buttons.anchor_left = 0.46
	buttons.anchor_right = 1.0
	buttons.anchor_top = 1.0
	buttons.anchor_bottom = 1.0
	buttons.offset_left = 0
	buttons.offset_right = -20
	buttons.offset_top = -145
	buttons.offset_bottom = -30
	buttons.add_theme_constant_override("separation", 14)
	ui.add_child(buttons)
	for spec in [["감속", "brake"], ["가속", "fast"], ["점프", "jump"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(100, 110)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 23)
		buttons.add_child(button)
		action_buttons[spec[1]] = button
		button.button_down.connect(_touch_down.bind(spec[1]))
		button.button_up.connect(_touch_up.bind(spec[1]))
		button.mouse_exited.connect(_touch_up.bind(spec[1]))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_set_action_touch(event.index, _action_at(event.position))
		elif action_touches.has(event.index):
			_set_action_touch(event.index, "")
	elif event is InputEventScreenDrag and action_touches.has(event.index):
		_set_action_touch(event.index, _action_at(event.position))

func _action_at(position: Vector2) -> String:
	for action in action_buttons:
		var button: Button = action_buttons[action]
		if button.get_global_rect().has_point(position):
			return action
	return ""

func _set_action_touch(index: int, action: String) -> void:
	if action.is_empty():
		action_touches.erase(index)
	else:
		if mode != "playing":
			if mode == "complete":
				level = 0
			_start()
		action_touches[index] = action
	_refresh_actions()

func _refresh_actions() -> void:
	var held: Array = action_touches.values()
	touch_fast = mouse_actions.has("fast") or held.has("fast")
	touch_brake = mouse_actions.has("brake") or held.has("brake")
	touch_jump = mouse_actions.has("jump") or held.has("jump")

func _touch_down(action: String) -> void:
	if mode != "playing":
		if mode == "complete":
			level = 0
		_start()
	mouse_actions[action] = true
	_refresh_actions()

func _touch_up(action: String) -> void:
	mouse_actions.erase(action)
	_refresh_actions()

func _start() -> void:
	mode = "playing"
	player_x = 0
	player_z = -5
	player_y = SHIP_HEIGHT
	vertical_speed = 0
	speed = 16
	boost_time = 0
	fuel = 100
	oxygen = 100
	elapsed = 0
	last_pad = ""
	message = ""
	touch_steer = 0.0
	action_touches.clear()
	mouse_actions.clear()
	_refresh_actions()
	_build_course()
	_update_display()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_SPACE] and mode != "playing":
		if mode == "complete":
			level = 0
		_start()
	elif event.keycode == KEY_R:
		if mode == "complete":
			level = 0
		_start()
	elif event.keycode == KEY_ESCAPE and mode == "playing":
		mode = "paused"
	elif event.keycode == KEY_ESCAPE and mode == "paused":
		mode = "playing"

func _physics_process(delta: float) -> void:
	if mode != "playing":
		_update_camera(delta)
		return
	var dt := minf(delta, 0.05)
	elapsed += dt
	boost_time = maxf(0.0, boost_time - dt)
	var key_steer := float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	var steer := clampf(key_steer + touch_steer, -1.0, 1.0)
	player_x = clampf(player_x + steer * 9.5 * dt, -10.8, 10.8)
	var accelerating := Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or touch_fast
	var braking := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or touch_brake
	var target_speed := 66.0 if boost_time > 0.0 else (MAX_ACCEL_SPEED if accelerating else (9.0 if braking else 16.0))
	var speed_change := 18.0
	if accelerating and boost_time <= 0.0:
		if speed < FAST_SPEED:
			target_speed = FAST_SPEED
		elif speed <= MAX_ACCEL_SPEED:
			speed_change = 5.0
	speed = move_toward(speed, target_speed, speed_change * dt)
	var lane := clampi(int(round(player_x / TILE_SIZE)) + 2, 0, 4)
	var row := int(floor(-player_z / TILE_SIZE))
	var tile: int = track.tile_at(level, row, lane)
	var grounded := player_y >= SHIP_HEIGHT - 0.05 and player_y <= SHIP_HEIGHT + 0.02 and vertical_speed <= 0 and tile != Track.Tile.GAP
	var previous_y := player_y
	if grounded:
		player_y = SHIP_HEIGHT
		vertical_speed = 0
		if Input.is_key_pressed(KEY_SPACE) or touch_jump:
			vertical_speed = 10.0
	if not grounded:
		vertical_speed -= Track.GRAVITY[level] * dt
		player_y += vertical_speed * dt
	player_z -= speed * dt
	row = int(floor(-player_z / TILE_SIZE))
	lane = clampi(int(round(player_x / TILE_SIZE)) + 2, 0, 4)
	tile = track.tile_at(level, row, lane)
	if tile != Track.Tile.GAP and previous_y >= SHIP_HEIGHT and player_y <= SHIP_HEIGHT and vertical_speed <= 0:
		player_y = SHIP_HEIGHT
		vertical_speed = 0
	if absf(player_x) > 10.2 or player_y < -4.0:
		_fail("길 밖으로 떨어졌습니다")
	elif tile == Track.Tile.HAZARD and player_y < 1.7:
		_fail("장애물에 부딪혔습니다")
	elif tile != Track.Tile.GAP and player_y < 0.9:
		var pad_key := str(row) + ":" + str(lane)
		if last_pad != pad_key:
			last_pad = pad_key
			match tile:
				Track.Tile.FUEL: fuel = minf(100, fuel + 60)
				Track.Tile.OXYGEN: oxygen = minf(100, oxygen + 38)
				Track.Tile.BOOST:
					boost_time = 4.5
					speed = 66.0
					vertical_speed = 22.0 * JUMP_HEIGHT_MULTIPLIER
					player_y = maxf(player_y, SHIP_HEIGHT + 0.04)
	fuel = maxf(0, fuel - dt * (3.0 + maxf(0, speed - 16) * 0.08))
	oxygen = maxf(0, oxygen - dt * 3.8)
	if fuel <= 0:
		_fail("연료가 떨어졌습니다")
	elif oxygen <= 0:
		_fail("산소가 떨어졌습니다")
	elif -player_z >= track.length(level) * TILE_SIZE - 3:
		if level == track.level_count() - 1:
			mode = "complete"
			message = "모든 코스를 완주했습니다!"
		else:
			level += 1
			mode = "clear"
			message = "코스 통과! 다음 코스로 이동합니다"
	ship.position = Vector3(player_x, player_y, player_z)
	ship.rotation.z = lerpf(ship.rotation.z, -steer * 0.16, dt * 8)
	for trail in engine_trails:
		trail.visible = boost_time > 0.0
	speed_lines.intensity = clampf((speed - 21.0) / 45.0, 0.0, 1.0)
	speed_lines.motion += dt * speed * 4.0
	speed_lines.queue_redraw()
	_update_camera(dt)
	_update_display()

func _update_camera(dt: float) -> void:
	var desired := Vector3(player_x * 0.45, maxf(5.0, player_y + (5.0 if boost_time > 0.0 else 4.3)), player_z + (15.0 if boost_time > 0.0 else 12.0))
	camera.position = camera.position.lerp(desired, minf(1.0, dt * 5))
	camera.fov = lerpf(camera.fov, 96.0 if boost_time > 0.0 else 72.0, minf(1.0, dt * 3.5))
	camera.look_at(Vector3(player_x * 0.45, 0, player_z - 17), Vector3.UP)
	for star in stars:
		if star.global_position.z > camera.position.z + 35:
			star.global_position.z -= 210

func _fail(reason: String) -> void:
	if mode == "playing":
		mode = "failed"
		message = reason

func _update_display() -> void:
	status_label.text = "SKYROAD  /  %d·%d  %s    속도 %02d    %d%%" % [level + 1, track.level_count(), Track.NAMES[level], int(speed * 10), int(clampf(-player_z / (track.length(level) * TILE_SIZE) * 100, 0, 100))]
	fuel_bar.value = fuel
	oxygen_bar.value = oxygen
	match mode:
		"title":
			title_label.text = "SKYROAD"
			help_label.text = "우주 도로를 달려 결승점까지!\n← → 이동 · ↑ ↓ 속도 · SPACE 점프\nENTER 또는 화면 버튼으로 시작"
		"playing":
			title_label.text = "HYPER JUMP" if boost_time > 0.0 and player_y < 3.0 else ""
			help_label.text = ""
		"paused":
			title_label.text = "일시정지"
			help_label.text = "ESC로 계속 · R로 다시 시작"
		"failed":
			title_label.text = "도전 실패"
			help_label.text = message + "\nENTER / SPACE / R로 다시 시작"
		"clear":
			title_label.text = "코스 통과!"
			help_label.text = "ENTER / SPACE로 다음 코스 시작"
		"complete":
			title_label.text = "모든 코스 완주!"
			help_label.text = "R로 다시 도전"
