extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await physics_frame
	game._on_web_command([JSON.stringify({"type": "input", "action": "jump", "pressed": true})])
	for i in 20:
		await physics_frame
	if not game.player.charging or game.player.charge_time <= 0.0:
		_fail("Touch bridge must hold a jump charge")
		return
	game._on_web_command([JSON.stringify({"type": "cancel"})])
	for i in 3:
		await physics_frame
	if game.player.charging or game.player.velocity.y < -100.0 or Input.is_action_pressed("jump"):
		_fail("Cancelled touch must clear the charge without launching")
		return
	game._on_web_command([JSON.stringify({"type": "input", "action": "move_right", "pressed": true})])
	for i in 5:
		await physics_frame
	game._on_web_command([JSON.stringify({"type": "pause", "paused": true})])
	var paused_position: Vector2 = game.player.position
	for i in 10:
		await physics_frame
	if game.player.position != paused_position or Input.is_action_pressed("move_right"):
		_fail("Opening the menu must freeze the player and release movement")
		return
	game._on_web_command([JSON.stringify({"type": "input", "action": "jump", "pressed": true})])
	if Input.is_action_pressed("jump"):
		_fail("Touch inputs must be ignored while paused")
		return
	game._on_web_command([JSON.stringify({"type": "pause", "paused": false})])
	game._on_web_command([JSON.stringify({"type": "input", "action": "move_right", "pressed": true, "strength": 0.3})])
	for i in 4:
		await physics_frame
	if absf(game.player.velocity.x - 43.5) > 1.0:
		_fail("Partial joystick movement must allow slow precision walking")
		return
	game._on_web_command([JSON.stringify({"type": "input", "action": "jump", "pressed": true})])
	for i in 60:
		await physics_frame
	game._on_web_command([JSON.stringify({"type": "input", "action": "jump", "pressed": false})])
	for i in 3:
		await physics_frame
	if game.player.velocity.y >= -600.0 or absf(game.player.velocity.x - 195.0) > 1.0:
		_fail("An analog direction must preserve full horizontal launch speed after resuming")
		return
	print("mobile_controls_test: PASS")
	quit()

func _fail(reason: String) -> void:
	paused = false
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)
	push_error(reason)
	quit(1)
