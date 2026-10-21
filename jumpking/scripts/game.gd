extends Node2D

const Player = preload("res://scripts/player.gd")
const GameFont = preload("res://fonts/NotoSansKR.ttf")
const COURSE_TIERS := 5
const TIER_HEIGHT := 1680.0
const BASE_PLATFORMS := [
	Rect2(0, 500, 960, 40),
	Rect2(580, 400, 140, 18),
	Rect2(390, 295, 115, 18),
	Rect2(615, 190, 110, 18),
	Rect2(425, 85, 105, 18),
	Rect2(235, -20, 110, 18),
	Rect2(440, -125, 105, 18),
	Rect2(650, -230, 105, 18),
	Rect2(465, -335, 95, 18),
	Rect2(260, -440, 95, 18),
	Rect2(450, -545, 95, 18),
	Rect2(640, -650, 95, 18),
	Rect2(450, -755, 100, 18),
	Rect2(250, -860, 95, 18),
	Rect2(450, -965, 100, 18),
	Rect2(650, -1070, 95, 18),
	Rect2(450, -1175, 100, 18)
]
static var PLATFORMS: Array[Rect2] = build_course()

static func build_course() -> Array[Rect2]:
	var course: Array[Rect2] = [BASE_PLATFORMS[0]]
	for tier in COURSE_TIERS:
		for ledge in range(1, BASE_PLATFORMS.size()):
			var original: Rect2 = BASE_PLATFORMS[ledge]
			var progress := tier * (BASE_PLATFORMS.size() - 1) + ledge - 1
			var difficulty := float(progress) / float(COURSE_TIERS * (BASE_PLATFORMS.size() - 1) - 1)
			var ledge_width: float = original.size.x + lerpf(28.0, -40.0, difficulty)
			course.append(Rect2(
				original.position.x + (original.size.x - ledge_width) * 0.5,
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

func _ready() -> void:
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
	make_hud()

func _process(delta: float) -> void:
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
	best_height = maxi(best_height, roundi(500.0 - player.position.y))
	height_label.text = "최고 높이  %d m" % best_height
	if not won and player.is_on_floor() and player.position.y < PLATFORMS[-1].position.y - 5.0:
		won = true
		message_label.text = "정상 도착! 다시 시작 버튼으로 재도전하세요." if DisplayServer.is_touchscreen_available() else "정상 도착! 축하합니다. R을 눌러 다시 도전하세요."
		message_label.add_theme_color_override("font_color", Color("ffd56d"))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()

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
		draw_rect(platform, Color("44637e"))
		draw_rect(Rect2(platform.position, Vector2(platform.size.x, 5)), Color("87b8b1"))
		if i == PLATFORMS.size() - 1:
			draw_rect(Rect2(platform.get_center().x - 12.5, platform.position.y - 34, 25, 34), Color("ffd56d"))
