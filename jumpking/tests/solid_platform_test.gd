extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.player.position = Vector2(620, 470)
	for i in 30:
		await physics_frame
	Input.action_press("jump")
	for i in 60:
		await physics_frame
	Input.action_release("jump")
	var highest_y: float = game.player.position.y
	for i in 60:
		await physics_frame
		highest_y = minf(highest_y, game.player.position.y)
	Input.action_release("jump")
	if highest_y < 432.0:
		push_error("A solid ledge must stop a jump from below")
		quit(1)
		return
	print("solid_platform_test: PASS")
	quit()
