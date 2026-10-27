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
	for level in range(game.track.level_count()):
		game.level = level
		game._start()
		game.player_z = -float(game.track.LAUNCH_ROWS[level] * 4) + 0.05
		game._physics_process(1.0 / 60.0)
		assert(game.boost_time > 0.0)
		assert(game.vertical_speed > 20.0)
		assert(game.speed >= 36.0)
		var peak: float = game.player_y
		var landed := false
		for i in range(180):
			game._physics_process(1.0 / 60.0)
			peak = maxf(peak, game.player_y)
			if i > 20 and game.player_y == game.SHIP_HEIGHT and game.vertical_speed == 0.0:
				landed = true
				break
		assert(peak > 8.0)
		assert(landed and game.mode == "playing")
		assert(int(floor(-game.player_z / 4.0)) >= game.track.LANDING_ROWS[level])
	print("game_test: PASS")
	quit()
