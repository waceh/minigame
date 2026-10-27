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
	print("game_test: PASS")
	quit()
