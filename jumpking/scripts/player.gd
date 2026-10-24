extends CharacterBody2D

signal launched
signal landed(strength: float)

const JumpMath = preload("res://scripts/jump_math.gd")
const GRAVITY := 1150.0
const WALK_SPEED := 145.0
const JUMP_HORIZONTAL_SPEED := 195.0

var charge_time := 0.0
var charging := false
var facing := 1.0
var effect_time := 0.0
var launch_flash := 0.0
var landing_squash := 0.0
var impact_ring := 0.0
var trail_timer := 0.0
var was_on_floor := false
var particles: Array[Dictionary] = []

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 30)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	effect_time += delta
	launch_flash = move_toward(launch_flash, 0.0, delta * 2.5)
	landing_squash = move_toward(landing_squash, 0.0, delta * 2.0)
	impact_ring = move_toward(impact_ring, 0.0, delta * 2.2)
	update_particles(delta)
	var direction := Input.get_axis("move_left", "move_right")
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			charging = true
			charge_time = 0.0
		if charging:
			velocity.x = 0.0
			if direction != 0.0:
				facing = signf(direction)
			if Input.is_action_pressed("jump"):
				charge_time = minf(charge_time + delta, JumpMath.MAX_CHARGE)
			else:
				velocity.y = -JumpMath.launch_speed(charge_time)
				velocity.x = facing * JUMP_HORIZONTAL_SPEED
				launch_flash = 1.0
				spawn_particles(8, Color("ffd78a"), 1.0)
				launched.emit()
				charging = false
				charge_time = 0.0
		else:
			velocity.x = direction * WALK_SPEED
			if direction != 0.0:
				facing = signf(direction)
	else:
		velocity.y += GRAVITY * delta
		charging = false
		charge_time = 0.0

	var incoming_x := velocity.x
	var incoming_y := velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor and incoming_y > 180.0:
		landing_squash = minf(1.0, incoming_y / 750.0)
		impact_ring = 1.0
		spawn_particles(10, Color("a7d5cf"), 1.2)
		landed.emit(landing_squash)
	was_on_floor = is_on_floor()
	if not is_on_floor() and absf(velocity.y) > 80.0:
		trail_timer += delta
		if trail_timer >= 0.055:
			trail_timer = 0.0
			spawn_particles(1, Color("f7c76a"), 0.4)
	if is_on_wall() and not is_on_floor():
		for i in get_slide_collision_count():
			if absf(get_slide_collision(i).get_normal().x) > 0.6:
				velocity.x = -incoming_x * 0.35
				spawn_particles(6, Color("b2c7e5"), 0.8)
				break
	position.x = clampf(position.x, 12.0, 948.0)
	if position.x <= 12.0 or position.x >= 948.0:
		velocity.x = 0.0
	queue_redraw()

func spawn_particles(count: int, color: Color, force: float) -> void:
	for i in count:
		particles.append({
			"position": global_position + Vector2(randf_range(-8.0, 8.0), 13.0),
			"velocity": Vector2(randf_range(-100.0, 100.0), randf_range(-170.0, -45.0)) * force,
			"life": randf_range(0.3, 0.55),
			"radius": randf_range(1.5, 3.5),
			"color": color
		})
	while particles.size() > 60:
		particles.remove_at(0)

func update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle["life"] = float(particle["life"]) - delta
		if particle["life"] <= 0.0:
			particles.remove_at(i)
			continue
		particle["position"] = Vector2(particle["position"]) + Vector2(particle["velocity"]) * delta
		particle["velocity"] = Vector2(particle["velocity"]) + Vector2(0.0, 220.0) * delta
		particles[i] = particle

func _draw() -> void:
	for particle: Dictionary in particles:
		var particle_color: Color = particle["color"]
		particle_color.a = minf(1.0, float(particle["life"]) * 2.2)
		draw_circle(to_local(Vector2(particle["position"])), float(particle["radius"]), particle_color)
	var charge_ratio: float = charge_time / JumpMath.MAX_CHARGE
	var compression := 6.0 * charge_ratio
	if charging:
		var pulse := 0.5 + 0.5 * sin(effect_time * 12.0)
		draw_circle(Vector2.ZERO, 22.0 + pulse * 3.0, Color(1.0, 0.8, 0.35, 0.08 + charge_ratio * 0.16))
		draw_rect(Rect2(-19, -42, 38, 5), Color("344965"))
		draw_rect(Rect2(-18, -41, 36.0 * charge_ratio, 3), Color("ffd56d"))
	if launch_flash > 0.0:
		draw_circle(Vector2(0, 8), 24.0 + (1.0 - launch_flash) * 10.0, Color(1.0, 0.86, 0.52, launch_flash * 0.22))
	if impact_ring > 0.0:
		draw_arc(Vector2(0, 14), 18.0 + (1.0 - impact_ring) * 28.0, 0.0, TAU, 32, Color(0.65, 0.9, 0.9, impact_ring * 0.7), 2.0)
	var body_color := Color("f7c76a") if is_on_floor() else Color("ffdd8e")
	var half_width := 12.0 + landing_squash * 4.0
	var top := -15.0 + compression + landing_squash * 7.0 - launch_flash * 5.0
	draw_rect(Rect2(-half_width, top, half_width * 2.0, 15.0 - top), body_color)
	draw_rect(Rect2(-half_width, 8, half_width * 2.0, 7), Color("dc7b58"))
	draw_circle(Vector2(facing * 5.0, -5 + compression + landing_squash * 3.0), 2.0, Color("29314b"))
