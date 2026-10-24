extends Node2D

const Player = preload("res://scripts/player.gd")
const JumpMath = preload("res://scripts/jump_math.gd")
const GameFont = preload("res://fonts/NotoSansKR.ttf")
const COURSE_TIERS := 5
const TIER_HEIGHT := 1680.0
# Alternating short taps, near-full jumps and needle landings.
const BASE_PLATFORMS := [
	Rect2(0, 500, 960, 40),
	Rect2(580, 400, 120, 18),
	Rect2(407, 275, 76, 18),
	Rect2(601, 195, 38, 18),
	Rect2(373, 35, 64, 18),
	Rect2(297, -30, 26, 18),
	Rect2(188, -115, 24, 18),
	Rect2(369, -260, 62, 18),
	Rect2(556, -350, 28, 18),
	Rect2(730, -445, 50, 18),
	Rect2(513, -575, 44, 18),
	Rect2(363, -655, 24, 18),
	Rect2(168, -775, 44, 18),
	Rect2(344, -870, 32, 18),
	Rect2(539, -1000, 42, 18),
	Rect2(709, -1080, 22, 18),
	Rect2(503, -1180, 64, 18)
]
static var PLATFORMS: Array[Rect2] = build_course()

static func build_course() -> Array[Rect2]:
	var course: Array[Rect2] = [BASE_PLATFORMS[0]]
	for tier in COURSE_TIERS:
		for ledge in range(1, BASE_PLATFORMS.size()):
			var original: Rect2 = BASE_PLATFORMS[ledge]
			var ledge_width := maxf(16.0, original.size.x - float(tier) * 5.0)
			var center_x := original.get_center().x
			if tier % 2 == 1:
				center_x = 960.0 - center_x
			course.append(Rect2(
				center_x - ledge_width * 0.5,
				original.position.y - float(tier) * TIER_HEIGHT,
				ledge_width,
				original.size.y
			))
	return course

var player: CharacterBody2D
var camera: Camera2D
var height_label: Label
var message_label: Label
var best_height := 0
var won := false
var shake_strength := 0.0
var shake_time := 0.0
var web_command_callback: JavaScriptObject
var web_state_timer := 0.0
var embedded_shell := false

func setup_web_controls() -> void:
	if not embedded_shell:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	web_command_callback = JavaScriptBridge.create_callback(_on_web_command)
	JavaScriptBridge.get_interface("window").minigameCommand = web_command_callback
	JavaScriptBridge.eval("window.parent.postMessage({type:'jumpking-ready'}, window.location.origin)")

func clear_controls() -> void:
	# Interrupted touches must cancel the charge rather than launch a jump.
	player.charging = false
	player.charge_time = 0.0
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)

func _on_web_command(args: Array) -> void:
	if args.is_empty():
		return
	var command = JSON.parse_string(str(args[0]))
	if not command is Dictionary:
		return
	match command.get("type", ""):
		"input":
			var action: String = command.get("action", "")
			if action not in ["move_left", "move_right", "jump"]:
				return
			if command.get("pressed", false) and not get_tree().paused:
				Input.action_press(action, clampf(float(command.get("strength", 1.0)), 0.0, 1.0))
			else:
				Input.action_release(action)
		"cancel":
			clear_controls()
		"pause":
			clear_controls()
			get_tree().paused = bool(command.get("paused", true))
		"restart":
			clear_controls()
			get_tree().paused = false
			get_tree().call_deferred("reload_current_scene")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		clear_controls()

func _ready() -> void:
	embedded_shell = OS.has_feature("web") and bool(JavaScriptBridge.eval("window.parent !== window"))
	for platform: Rect2 in PLATFORMS:
		var body := StaticBody2D.new()
		body.position = platform.position + platform.size * 0.5
		var shape := RectangleShape2D.new()
		shape.size = platform.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector2(460, 470)
	add_child(player)
	player.connect("launched", _on_player_launched)
	player.connect("landed", _on_player_landed)
	camera = Camera2D.new()
	camera.position = Vector2(0, -75)
	camera.limit_left = 0
	camera.limit_right = 960
	camera.limit_bottom = 540
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	player.add_child(camera)
	camera.make_current()
	get_viewport().size_changed.connect(update_camera_layout)
	update_camera_layout()
	make_hud()
	setup_web_controls()

func update_camera_layout() -> void:
	# Keep the whole course width visible; portrait screens reveal more sky.
	camera.zoom = Vector2.ONE * maxf(1.0, get_viewport_rect().size.x / 960.0)

func _process(delta: float) -> void:
	if embedded_shell:
		web_state_timer += delta
		if web_state_timer >= 0.05:
			web_state_timer = 0.0
			var state := JSON.stringify({"type": "jumpking-state", "height": best_height, "charge": player.charge_time / JumpMath.MAX_CHARGE, "charging": player.charging, "won": won})
			JavaScriptBridge.eval("window.parent.postMessage(%s, window.location.origin)" % state)
	if get_tree().paused:
		return
	shake_time += delta
	shake_strength = move_toward(shake_strength, 0.0, delta * 15.0)
	if camera:
		camera.offset = Vector2(sin(shake_time * 47.0), cos(shake_time * 39.0)) * shake_strength

func _on_player_launched() -> void:
	shake_strength = 2.0

func _on_player_landed(strength: float) -> void:
	shake_strength = 3.0 + strength * 5.0

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	height_label = Label.new()
	height_label.position = Vector2(24, 20)
	height_label.add_theme_font_size_override("font_size", 24)
	height_label.add_theme_font_override("font", GameFont)
	height_label.add_theme_color_override("font_color", Color("f7e8bb"))
	layer.add_child(height_label)

	message_label = Label.new()
	message_label.position = Vector2(24, 54)
	message_label.text = "화면 버튼으로 방향 정하기 · 점프를 누른 뒤 떼면 보는 방향으로 점프" if DisplayServer.is_touchscreen_available() else "A/D 방향 정하기 · 스페이스 충전 후 떼면 보는 방향으로 점프 · R 재시작"
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_font_override("font", GameFont)
	message_label.add_theme_color_override("font_color", Color("c5d4e8"))
	layer.add_child(message_label)
	# The web shell provides controls in CSS pixels outside the game viewport.
	if embedded_shell:
		height_label.hide()
		message_label.hide()
	else:
		add_touch_button(layer, "move_left", Vector2(30, 402), "left")
		add_touch_button(layer, "move_right", Vector2(170, 402), "right")
		add_touch_button(layer, "jump", Vector2(795, 402), "up")

func add_touch_button(layer: CanvasLayer, action_name: String, button_position: Vector2, direction: String) -> void:
	var button := TouchScreenButton.new()
	button.action = action_name
	button.position = button_position
	button.texture_normal = make_touch_texture(direction)
	button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	layer.add_child(button)

func make_touch_texture(direction: String) -> ImageTexture:
	var image := Image.create(108, 108, false, Image.FORMAT_RGBA8)
	var triangle := PackedVector2Array()
	match direction:
		"left":
			triangle = PackedVector2Array([Vector2(28, 54), Vector2(70, 25), Vector2(70, 83)])
		"right":
			triangle = PackedVector2Array([Vector2(80, 54), Vector2(38, 25), Vector2(38, 83)])
		_:
			triangle = PackedVector2Array([Vector2(54, 20), Vector2(24, 74), Vector2(84, 74)])
	for y in 108:
		for x in 108:
			var point := Vector2(x, y)
			if point.distance_to(Vector2(54, 54)) <= 51.0:
				image.set_pixel(x, y, Color(0.12, 0.20, 0.32, 0.78))
			if Geometry2D.is_point_in_polygon(point, triangle):
				image.set_pixel(x, y, Color("f7e8bb"))
	image.resize(132, 132, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	best_height = maxi(best_height, roundi(500.0 - player.position.y))
	height_label.text = "최고 높이  %d m" % best_height
	if not won and player.is_on_floor() and player.position.y < PLATFORMS[-1].position.y - 5.0:
		won = true
		message_label.text = "정상 도착! 다시 시작 버튼으로 재도전하세요." if DisplayServer.is_touchscreen_available() else "정상 도착! 축하합니다. R을 눌러 다시 도전하세요."
		message_label.add_theme_color_override("font_color", Color("ffd56d"))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		clear_controls()
		get_tree().reload_current_scene()
	elif embedded_shell and event.physical_keycode == KEY_ESCAPE:
		JavaScriptBridge.eval("window.parent.postMessage({type:'jumpking-menu'}, window.location.origin)")

func _exit_tree() -> void:
	if embedded_shell:
		JavaScriptBridge.get_interface("window").minigameCommand = null

func _draw() -> void:
	var world_top: float = PLATFORMS[-1].position.y - 425.0
	draw_rect(Rect2(0, world_top, 960, 540.0 - world_top), Color("14233b"))
	for i in ceili((540.0 - world_top) / 145.0):
		var y := world_top + i * 145.0
		draw_line(Vector2(0, y), Vector2(960, y), Color("23395a", 0.35), 1.0)
	for i in 180:
		var x := float((i * 271 + 53) % 960)
		var y := world_top + fposmod(float(i * 197 + 31), 540.0 - world_top)
		draw_circle(Vector2(x, y), 1.5, Color("b2c7e5", 0.6))
	for i in PLATFORMS.size():
		var platform: Rect2 = PLATFORMS[i]
		var shortcut_landing := i > 0 and (i - 1) % 16 == 5
		var body_color := Color("937144") if shortcut_landing else Color("44637e")
		var edge_color := Color("ffd56d") if shortcut_landing else Color("87b8b1")
		draw_rect(platform, body_color)
		draw_rect(Rect2(platform.position, Vector2(platform.size.x, 5)), edge_color)
		if shortcut_landing:
			var marker := platform.get_center() + Vector2(0, -23)
			draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -4), marker + Vector2(4, 0), marker + Vector2(0, 4), marker + Vector2(-4, 0)]), edge_color)
		if i == PLATFORMS.size() - 1:
			draw_rect(Rect2(platform.get_center().x - 12.5, platform.position.y - 34, 25, 34), Color("ffd56d"))
