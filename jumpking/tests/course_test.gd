extends SceneTree

const Game = preload("res://scripts/game.gd")
const JumpMath = preload("res://scripts/jump_math.gd")

func _initialize() -> void:
	var speed: float = JumpMath.launch_speed(JumpMath.MAX_CHARGE)
	var max_rise: float = speed * speed / (2.0 * 1150.0)
	for i in range(Game.PLATFORMS.size() - 1):
		var source: Rect2 = Game.PLATFORMS[i]
		var target: Rect2 = Game.PLATFORMS[i + 1]
		var rise: float = source.position.y - target.position.y
		if rise >= max_rise:
			_fail("Ledge %d is too high" % (i + 1))
			return
		var landing_time: float = (speed + sqrt(speed * speed - 2.0 * 1150.0 * rise)) / 1150.0
		var travel: float = 195.0 * landing_time
		var direction: float = signf(target.get_center().x - source.get_center().x)
		var launch_min: float = source.position.x + 12.0
		var launch_max: float = source.end.x - 12.0
		var landing_min: float = minf(launch_min + direction * travel, launch_max + direction * travel)
		var landing_max: float = maxf(launch_min + direction * travel, launch_max + direction * travel)
		if landing_max < target.position.x - 12.0 or landing_min > target.end.x + 12.0:
			_fail("Ledge %d is too far for a charged jump" % (i + 1))
			return
	print("course_test: PASS")
	quit()

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
