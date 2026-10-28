extends SceneTree

const Main = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	game._start()
	assert(game.mode == "playing")
	var start_z: float = game.player_z
	game._physics_process(1.0 / 60.0)
	assert(game.player_z < start_z)
	assert(game.fuel < 100 and game.oxygen < 100)
	game.player_y = -5
	game._physics_process(1.0 / 60.0)
	assert(game.mode == "failed")
	game._start()
	assert(game.mode == "playing" and game.fuel == 100)
	var center_x: float = game.player_x
	game.touch_steer = 0.5
	game._physics_process(1.0 / 60.0)
	assert(game.player_x > center_x)
	game.touch_steer = 0.0
	game._start()
	game.touch_jump = true
	game._physics_process(1.0 / 60.0)
	game.touch_jump = false
	var normal_peak: float = game.player_y
	for i in range(75):
		game._physics_process(1.0 / 60.0)
		normal_peak = maxf(normal_peak, game.player_y)
	assert(normal_peak > 3.0 and normal_peak < 3.5)
	game._start()
	game.touch_fast = true
	for i in range(80):
		game.player_z = -5.0
		game._physics_process(1.0 / 60.0)
	assert(game.speed >= 39.9 and game.speed <= 40.1)
	for i in range(60):
		game.player_z = -5.0
		game._physics_process(1.0 / 60.0)
	assert(game.speed >= 44.8 and game.speed <= 45.2)
	for i in range(240):
		game.player_z = -5.0
		game._physics_process(1.0 / 60.0)
	assert(game.speed >= 59.9 and game.speed <= 60.1)
	game.fuel = 100.0
	for i in range(60):
		game.player_z = -5.0
		game._physics_process(1.0 / 60.0)
	assert(game.fuel >= 93.0)
	game.fuel = 20.0
	game.player_z = -float(23 * 4) + 0.1
	game._physics_process(1.0 / 60.0)
	assert(game.fuel > 79.0)
	game.touch_fast = false
	for level in range(game.track.level_count()):
		game.level = level
		game._start()
		game.player_z = -float(game.track.LAUNCH_ROWS[level] * 4) + 0.05
		game._physics_process(1.0 / 60.0)
		assert(game.boost_time > 0.0)
		assert(game.vertical_speed > 20.0)
		assert(game.speed >= 66.0)
		var peak: float = game.player_y
		var landed := false
		for i in range(360):
			game._physics_process(1.0 / 60.0)
			peak = maxf(peak, game.player_y)
			if i > 20 and game.player_y == game.SHIP_HEIGHT and game.vertical_speed == 0.0:
				landed = true
				break
		assert(peak > 3.0 * 22.0 * 22.0 / (2.0 * game.track.GRAVITY[level]) - 1.0)
		assert(landed and game.mode == "playing")
		assert(int(floor(-game.player_z / 4.0)) >= game.track.LANDING_ROWS[level])
		assert(int(floor(-game.player_z / 4.0)) <= game.track.LANDING_ROWS[level] + 5)
	game.level = 2
	game._start()
	var active_course_nodes := 0
	for child in game.course_root.get_children():
		if not child.is_queued_for_deletion():
			active_course_nodes += 1
	assert(active_course_nodes < 700)
	print("game_test: PASS")
	quit()
