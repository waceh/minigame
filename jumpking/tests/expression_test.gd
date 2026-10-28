extends SceneTree

const Player = preload("res://scripts/player.gd")

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var player = Player.new()
	root.add_child(player)
	if not player.has_method("_expression_state"):
		_fail("The character needs distinct expressions for jumping and falling")
		return
	player.velocity.y = -300.0
	if player.call("_expression_state") != "jumping":
		_fail("Rising should use the jumping expression")
		return
	player.velocity.y = 300.0
	if player.call("_expression_state") != "falling":
		_fail("Falling should use the grimace")
		return
	player.velocity.y = 0.0
	player.landing_squash = 0.5
	if player.call("_expression_state") != "falling":
		_fail("A hard landing should briefly keep the grimace")
		return
	player.landing_squash = 0.0
	if player.call("_expression_state") != "neutral":
		_fail("Standing should return to the neutral face")
		return
	print("expression_test: PASS")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
