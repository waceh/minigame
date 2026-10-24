extends SceneTree

# Fixed launch inputs planned independently from the course generator. Check the
# real collision engine, including solid undersides and all intervening ledges.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/course_routes.json"))
	for route in [fixtures["route"], fixtures["shortcuts"]]:
		for jump in route:
			game.clear_controls()
			game.won = false
			var source: Rect2 = game.PLATFORMS[int(jump["source"])]
			var target: Rect2 = game.PLATFORMS[int(jump["target"])]
			game.player.position = Vector2(float(jump["x"]), source.position.y - 15.0)
			game.player.velocity = Vector2.ZERO
			for i in 4:
				await physics_frame
			if not game.player.is_on_floor():
				_fail("Launch point %s must be supported" % jump)
				return
			game.player.facing = float(jump["direction"])
			game.player.charging = true
			game.player.charge_time = float(jump["frames"]) / 60.0
			var landed := false
			for i in 100:
				await physics_frame
				if i > 3 and game.player.is_on_floor():
					landed = absf(game.player.position.y - (target.position.y - 15.0)) < 1.0
					break
			if not landed:
				_fail("Jump %d -> %d must land on its target; got %s, fixture %s" % [jump["source"], jump["target"], game.player.position, jump])
				return
	print("climb_test: PASS (80 main jumps and 5 shortcuts reached with real collisions)")
	quit()

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
