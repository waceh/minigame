extends CharacterBody3D

var world: Node3D
var camera: Camera3D
var move_touch = -1
var look_touch = -1
var move_origin = Vector2.ZERO
var move_point = Vector2.ZERO
var touch_axis = Vector2.ZERO
var jump_requested = false
var action_timer = 0.0

func clear_touch():
	move_touch = -1
	look_touch = -1
	touch_axis = Vector2.ZERO
	jump_requested = false

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			if world.active: world.pause_game()
			return
		if world.active:
			if event.keycode >= KEY_1 and event.keycode <= KEY_7: world.selected = event.keycode - KEY_1
			if event.keycode == KEY_C: world.pause_game()
			if event.keycode == KEY_E: world.cycle_tool()
			if event.keycode == KEY_SPACE: jump_requested = true
			if event.keycode == KEY_F: world.respawn()
	if not world.active: return
	if event is InputEventMouseMotion and world.mouse_captured():
		look(event.relative * 0.0024)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: world.selected = posmod(world.selected - 1, 7)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: world.selected = posmod(world.selected + 1, 7)

func _unhandled_input(event):
	if not world.active: return
	if event is InputEventMouseButton and event.pressed and action_timer <= 0:
		if event.device == -1: return
		if not world.mouse_captured(): return
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			world.edit_target(event.button_index == MOUSE_BUTTON_RIGHT)
			action_timer = 0.25
	if event is InputEventScreenTouch:
		if event.pressed:
			var size = get_viewport().get_visible_rect().size
			if event.position.x < size.x * 0.42 and event.position.y > size.y * 0.4 and move_touch == -1:
				move_touch = event.index
				move_origin = event.position
				move_point = event.position
			elif look_touch == -1: look_touch = event.index
		else:
			if event.index == move_touch:
				move_touch = -1
				touch_axis = Vector2.ZERO
			if event.index == look_touch: look_touch = -1
	if event is InputEventScreenDrag:
		if event.index == move_touch:
			move_point = event.position
			touch_axis = ((move_point - move_origin) / 55.0).limit_length()
		elif event.index == look_touch: look(event.relative * 0.004)

func look(delta: Vector2):
	rotation.y -= delta.x
	camera.rotation.x = clampf(camera.rotation.x - delta.y, -1.45, 1.45)

func _physics_process(dt):
	action_timer = maxf(0, action_timer - dt)
	if not world.active: return
	if world.mouse_captured() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and action_timer <= 0:
		world.edit_target(false)
		action_timer = 0.25
	var axis = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	axis = (axis + touch_axis).limit_length()
	var direction = global_basis * Vector3(axis.x, 0, axis.y)
	var speed = 7.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.6
	velocity.x = move_toward(velocity.x, direction.x * speed, dt * 32)
	velocity.z = move_toward(velocity.z, direction.z * speed, dt * 32)
	if not is_on_floor(): velocity.y -= 22 * dt
	if jump_requested and is_on_floor(): velocity.y = 8.2
	jump_requested = false
	move_and_slide()
	if position.y < -12 or abs(position.x) > 60 or abs(position.z) > 60: world.respawn()
