extends Node3D
const V = preload("res://scripts/visuals.gd")
const MOVES = {
	"punch": {"duration": 0.32, "active": 0.11, "damage": 7.0, "range": 2.0, "stun": 0.25},
	"kick": {"duration": 0.53, "active": 0.23, "damage": 12.0, "range": 2.65, "stun": 0.36},
	"launch": {"duration": 0.67, "active": 0.29, "damage": 14.0, "range": 2.05, "stun": 0.65},
	"heavy": {"duration": 0.82, "active": 0.37, "damage": 20.0, "range": 2.8, "stun": 0.55}
}
var hp := 100.0
var wins := 0
var face := 1.0
var move := ""
var move_time := 0.0
var did_hit := false
var stun := 0.0
var guard := false
var velocity_y := 0.0
var combo := 0
var combo_timer := 0.0
var moving := false
var animation_time := 0.0
var tint := Color("58d9cf")
var index := 0
var rig: Node3D
var sprite: Sprite3D
var segments: Dictionary = {}
var joints: Dictionary = {}
var trail_points: Array[Vector3] = []
var visual_frame := 0

func setup(number: int) -> void:
	index = number
	tint = Color("6de0c3") if index == 0 else Color("ff846e")
	rig = Node3D.new()
	add_child(rig)
	sprite = Sprite3D.new()
	sprite.texture = preload("res://assets/fighters.png")
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.pixel_size = 3.4 / (sprite.texture.get_height() / 4.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.35
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The sprite pivots at its feet, so depth movement stays attached to the ground.
	sprite.offset = Vector2(0, sprite.texture.get_height() / 4.0 * 0.42)
	rig.add_child(sprite)
	pose(0)

func reset_at(pos: Vector3) -> void:
	position = pos
	hp = 100
	move = ""
	move_time = 0
	stun = 0
	guard = false
	velocity_y = 0
	combo = 0
	combo_timer = 0
	did_hit = false
	trail_points.clear()

func attack(kind: String) -> bool:
	if move != "" or stun > 0 or position.y > 0.05 or hp <= 0:
		return false
	move = kind
	move_time = 0
	did_hit = false
	guard = false
	return true

func step(dt: float) -> void:
	stun = maxf(0, stun - dt)
	combo_timer -= dt
	if combo_timer <= 0:
		combo = 0
	if move != "":
		move_time += dt
		if move_time >= MOVES[move].duration:
			move = ""
	if position.y > 0 or velocity_y > 0:
		velocity_y -= 16 * dt
		position.y = maxf(0, position.y + velocity_y * dt)
		if position.y == 0:
			velocity_y = 0

func resolve_hit(other) -> Dictionary:
	if move == "" or did_hit or move_time < MOVES[move].active:
		return {}
	did_hit = true
	var data: Dictionary = MOVES[move]
	if absf(position.x - other.position.x) > data.range or absf(position.z - other.position.z) > 0.65 or other.position.y > 2.6:
		return {}
	var blocked: bool = other.guard and other.position.y == 0 and other.stun == 0
	var air: bool = other.position.y > 0.1
	var damage: float = 0 if blocked else roundf(data.damage * (0.65 if air else 1.0))
	other.hp = maxf(0, other.hp - damage)
	other.stun = 0.14 if blocked else data.stun
	other.position.x = clampf(other.position.x + face * (0.12 if blocked else 0.27), -5.8, 5.8)
	if not blocked:
		combo += 1
		combo_timer = 1.3
		if move == "launch" and not air:
			other.velocity_y = 6.5
		elif air:
			other.velocity_y = maxf(other.velocity_y, 2.7)
	return {"blocked": blocked, "damage": damage, "combo": combo, "position": other.position + Vector3(0, 1.7, 0)}

func pose(dt: float) -> void:
	animation_time += dt
	visual_frame = 0
	if hp <= 0:
		visual_frame = 7
	elif stun > 0 and not guard:
		visual_frame = 6
	elif guard:
		visual_frame = 5
	elif move != "":
		var data: Dictionary = MOVES[move]
		if move_time >= data.active * 0.35 and move_time <= data.duration - 0.07:
			visual_frame = {"punch": 2, "kick": 3, "launch": 4, "heavy": 3}[move]
	elif moving:
		visual_frame = 1 if int(animation_time * 8) % 2 == 0 else 0
	sprite.frame = index * 8 + visual_frame
	sprite.flip_h = face < 0
	var bounce := absf(sin(animation_time * (10 if moving else 3))) * (0.04 if moving else 0.015)
	rig.position.y = bounce if hp > 0 and position.y == 0 else 0
	var extension := 1.0
	if move != "":
		extension += sin(clampf(move_time / MOVES[move].duration, 0, 1) * PI) * 0.04
	sprite.scale = Vector3(extension, 1.0 - (0.025 if guard else 0.0), 1)
	sprite.modulate = Color(1.3, 1.15, 1.0) if stun > 0 and fmod(animation_time, 0.12) < 0.06 else Color.WHITE
