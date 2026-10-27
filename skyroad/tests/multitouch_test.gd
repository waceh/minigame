extends SceneTree

const Main = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("run_test")

func _touch(index: int, pressed: bool, position: Vector2 = Vector2.ZERO) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	return event

func run_test() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	await process_frame
	assert(not Input.emulate_mouse_from_touch)
	game._start()
	game.joystick._gui_input(_touch(0, true, Vector2(175, 95)))
	assert(game.touch_steer > 0.9)
	var jump_pos: Vector2 = game.action_buttons["jump"].get_global_rect().get_center()
	var fast_pos: Vector2 = game.action_buttons["fast"].get_global_rect().get_center()
	game._input(_touch(1, true, jump_pos))
	assert(game.touch_jump and game.touch_steer > 0.9)
	var start_x: float = game.player_x
	game._physics_process(1.0 / 60.0)
	assert(game.player_x > start_x and game.vertical_speed > 0.0)
	game._input(_touch(2, true, fast_pos))
	assert(game.touch_fast and game.touch_jump)
	game._input(_touch(1, false, jump_pos))
	assert(not game.touch_jump and game.touch_fast and game.touch_steer > 0.9)
	game._input(_touch(2, false, fast_pos))
	assert(not game.touch_fast and game.touch_steer > 0.9)
	game.joystick._gui_input(_touch(0, false))
	assert(game.touch_steer == 0.0)
	print("multitouch_test: PASS")
	quit()
