extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await physics_frame
	if not game.player.is_on_floor():
		push_error("Player should start on the ground")
		quit(1)
		return
	Input.action_press("jump")
	await physics_frame
	for i in 60:
		await physics_frame
	Input.action_release("jump")
	await physics_frame
	await physics_frame
	if game.player.velocity.y >= -600.0:
		push_error("Releasing a full charge should launch upward")
		quit(1)
		return
	print("gameplay_test: PASS")
	quit()
