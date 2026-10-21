extends Node2D

const Player = preload("res://scripts/player.gd")
const GameFont = preload("res://fonts/NotoSansKR.ttf")
const PLATFORMS := [
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

var player: CharacterBody2D
var height_label: Label
var message_label: Label
var best_height := 0
var won := false

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
	var camera := Camera2D.new()
	camera.position = Vector2(0, -75)
	camera.limit_left = 0
	camera.limit_right = 960
	camera.limit_bottom = 540
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	player.add_child(camera)
	camera.make_current()
	make_hud()

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
	message_label.text = "A/D 이동 · 스페이스 충전 · 방향키 누른 채 떼어 점프 · 공중 조작 불가 · R 재시작"
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_font_override("font", GameFont)
	message_label.add_theme_color_override("font_color", Color("c5d4e8"))
	layer.add_child(message_label)

func _physics_process(_delta: float) -> void:
	best_height = maxi(best_height, roundi(500.0 - player.position.y))
	height_label.text = "최고 높이  %d m" % best_height
	if not won and player.is_on_floor() and player.position.y < PLATFORMS[-1].position.y - 5.0:
		won = true
		message_label.text = "정상 도착!  축하합니다. R을 눌러 다시 도전하세요."
		message_label.add_theme_color_override("font_color", Color("ffd56d"))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()

func _draw() -> void:
	draw_rect(Rect2(0, -1600, 960, 2140), Color("14233b"))
	for i in 16:
		var y := -1500.0 + i * 145.0
		draw_line(Vector2(0, y), Vector2(960, y), Color("23395a", 0.35), 1.0)
	for i in 36:
		var x := float((i * 271 + 53) % 960)
		var y := float((i * 197 + 31) % 1980) - 1480.0
		draw_circle(Vector2(x, y), 1.5, Color("b2c7e5", 0.6))
	for i in PLATFORMS.size():
		var platform: Rect2 = PLATFORMS[i]
		draw_rect(platform, Color("44637e"))
		draw_rect(Rect2(platform.position, Vector2(platform.size.x, 5)), Color("87b8b1"))
		if i == PLATFORMS.size() - 1:
			draw_rect(Rect2(platform.position.x + 52, platform.position.y - 34, 25, 34), Color("ffd56d"))
