extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await physics_frame
	if not game.player.is_on_floor():
		_fail("Player should start grounded")
		return

	Input.action_press("jump")
	for i in 3:
		await physics_frame
	if not game.player.charging:
		_fail("Holding jump must begin a charge")
		return
	var start_x: float = game.player.position.x
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	if absf(game.player.position.x - start_x) > 1.0:
		_fail("Charging must lock walking movement")
		return

	for i in 40:
		await physics_frame
	Input.action_release("jump")
	for i in 3:
		await physics_frame
	if game.player.velocity.y >= -600.0 or game.player.velocity.x <= 100.0:
		_fail("Releasing right plus full charge must launch up and right")
		return

	Input.action_release("move_right")
	Input.action_press("move_left")
	var airborne_x: float = game.player.position.x
	for i in 8:
		await physics_frame
	if game.player.velocity.x <= 100.0 or game.player.position.x <= airborne_x:
		_fail("Opposite input must not steer the player in midair")
		return

	Input.action_release("move_left")
	game.queue_free()
	await physics_frame
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await physics_frame
	Input.action_press("move_left")
	for i in 3:
		await physics_frame
	Input.action_release("move_left")
	if game.player.facing != -1.0:
		_fail("Walking left must set the facing direction")
		return
	Input.action_press("jump")
	for i in 60:
		await physics_frame
	Input.action_release("jump")
	for i in 3:
		await physics_frame
	if game.player.velocity.x >= -100.0:
		_fail("Releasing jump without direction input must launch toward the facing direction")
		return
	print("king_controls_test: PASS")
	quit()

func _fail(reason: String) -> void:
	push_error(reason)
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	quit(1)
