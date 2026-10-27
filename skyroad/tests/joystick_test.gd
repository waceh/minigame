extends SceneTree

const Joystick = preload("res://scripts/joystick.gd")

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var stick = Joystick.new()
	stick.size = Vector2(170, 170)
	root.add_child(stick)
	var press = InputEventScreenTouch.new()
	press.index = 3
	press.pressed = true
	press.position = Vector2(165, 85)
	stick._gui_input(press)
	assert(stick.value > 0.9)
	var drag = InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(5, 85)
	stick._gui_input(drag)
	assert(stick.value < -0.9)
	var release = InputEventScreenTouch.new()
	release.index = 3
	release.pressed = false
	stick._gui_input(release)
	assert(stick.value == 0.0)
	assert(stick.steer_from_position(Vector2(89, 85)) == 0.0)
	print("joystick_test: PASS")
	quit()
