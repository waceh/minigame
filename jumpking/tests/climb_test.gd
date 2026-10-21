extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await physics_frame
	var launch_positions := [460.0, 595.0, 490.0, 630.0, 440.0, 330.0, 530.0, 665.0, 475.0, 315.0, 530.0, 650.0, 460.0, 335.0, 535.0, 660.0]
	for step in launch_positions.size():
		var direction := "move_right" if game.PLATFORMS[step + 1].get_center().x > game.PLATFORMS[step].get_center().x else "move_left"
		var launch_x: float = launch_positions[step]
		var expected_y: float = game.PLATFORMS[step + 1].position.y - 15.0
		if absf(game.player.position.x - launch_x) > 2.5:
			var walk_direction := "move_right" if game.player.position.x < launch_x else "move_left"
			Input.action_press(walk_direction)
			for i in 100:
				await physics_frame
				if absf(game.player.position.x - launch_x) <= 2.5:
					break
			Input.action_release(walk_direction)
			await physics_frame
		Input.action_press("jump")
		for i in 3:
			await physics_frame
		Input.action_press(direction)
		for i in 55:
			await physics_frame
		Input.action_release("jump")
		for i in 90:
			await physics_frame
			if game.player.is_on_floor() and absf(game.player.position.y - expected_y) < 2.0:
				break
		Input.action_release(direction)
		if not game.player.is_on_floor() or absf(game.player.position.y - expected_y) > 2.0:
			push_error("Planned jump %d should land on its ledge" % (step + 1))
			quit(1)
			return
	for i in 2:
		await physics_frame
	if game.won:
		push_error("The first tier must not complete the longer course")
		quit(1)
		return
	var penultimate: Rect2 = game.PLATFORMS[-2]
	var finish: Rect2 = game.PLATFORMS[-1]
	game.player.position = Vector2(penultimate.get_center().x, penultimate.position.y - 15.0)
	game.player.velocity = Vector2.ZERO
	for i in 3:
		await physics_frame
	Input.action_press("jump")
	Input.action_press("move_left")
	for i in 55:
		await physics_frame
	Input.action_release("jump")
	for i in 90:
		await physics_frame
		if game.player.is_on_floor() and absf(game.player.position.y - (finish.position.y - 15.0)) < 2.0:
			break
	Input.action_release("move_left")
	for i in 2:
		await physics_frame
	if not game.won:
		push_error("Landing on the narrow final ledge should complete the game")
		quit(1)
		return
	print("climb_test: PASS (all ledges reached)")
	quit()
