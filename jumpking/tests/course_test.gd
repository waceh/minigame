extends SceneTree

const Game = preload("res://scripts/game.gd")
const JumpMath = preload("res://scripts/jump_math.gd")

func _initialize() -> void:
	var ledges_per_tier: int = Game.BASE_PLATFORMS.size() - 1
	if Game.PLATFORMS.size() != 1 + ledges_per_tier * Game.COURSE_TIERS:
		_fail("The course must have five full tiers")
		return
	if Game.PLATFORMS[-1].position.y > -7800.0:
		_fail("The finish must be about five times higher")
		return
	for tier in range(1, Game.COURSE_TIERS):
		for ledge in ledges_per_tier:
			var previous: Rect2 = Game.PLATFORMS[1 + (tier - 1) * ledges_per_tier + ledge]
			var current: Rect2 = Game.PLATFORMS[1 + tier * ledges_per_tier + ledge]
			if current.size.x >= previous.size.x:
				_fail("Higher tiers must have narrower ledges")
				return
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
