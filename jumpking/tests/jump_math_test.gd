extends SceneTree

const JumpMath = preload("res://scripts/jump_math.gd")

func _initialize() -> void:
	assert(JumpMath.launch_speed(0.0) == 380.0)
	assert(JumpMath.launch_speed(0.85) == 690.0)
	assert(JumpMath.launch_speed(2.0) == 690.0)
	assert(JumpMath.launch_speed(0.425) == 535.0)
	# The strongest jump must clear the highest 125 px step with margin.
	assert(pow(JumpMath.launch_speed(0.85), 2.0) / (2.0 * 1150.0) > 125.0)
	print("jump_math_test: PASS")
	quit()
