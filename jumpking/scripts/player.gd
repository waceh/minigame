extends CharacterBody2D

const JumpMath = preload("res://scripts/jump_math.gd")
const GRAVITY := 1150.0
const WALK_SPEED := 145.0
const JUMP_HORIZONTAL_SPEED := 195.0

var charge_time := 0.0
var charging := false
var facing := 1.0

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 30)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			charging = true
			charge_time = 0.0
		if charging:
			velocity.x = 0.0
			if direction != 0.0:
				facing = direction
			if Input.is_action_pressed("jump"):
				charge_time = minf(charge_time + delta, JumpMath.MAX_CHARGE)
			else:
				velocity.y = -JumpMath.launch_speed(charge_time)
				velocity.x = direction * JUMP_HORIZONTAL_SPEED
				charging = false
				charge_time = 0.0
		else:
			velocity.x = direction * WALK_SPEED
			if direction != 0.0:
				facing = direction
	else:
		velocity.y += GRAVITY * delta
		charging = false
		charge_time = 0.0

	var incoming_x := velocity.x
	move_and_slide()
	if is_on_wall() and not is_on_floor():
		for i in get_slide_collision_count():
			if absf(get_slide_collision(i).get_normal().x) > 0.6:
				velocity.x = -incoming_x * 0.35
				break
	position.x = clampf(position.x, 12.0, 948.0)
	if position.x <= 12.0 or position.x >= 948.0:
		velocity.x = 0.0
	queue_redraw()

func _draw() -> void:
	var compression := 6.0 * charge_time / JumpMath.MAX_CHARGE
	var body_color := Color("f7c76a") if is_on_floor() else Color("ffdd8e")
	draw_rect(Rect2(-12, -15 + compression, 24, 30 - compression), body_color)
	draw_rect(Rect2(-12, 8, 24, 7), Color("dc7b58"))
	draw_circle(Vector2(facing * 5.0, -5 + compression), 2.0, Color("29314b"))
