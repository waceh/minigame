extends SceneTree

const Main = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	var character: Sprite3D = game.get("character_sprite")
	if character == null:
		_fail("The Shiba needs a sprite that can change at the finish")
		return
	if not character.texture.resource_path.ends_with("shiba_astronaut_ufo_back.png"):
		_fail("Running should show the astronaut piloting a UFO from behind")
		return
	game.mode = "clear"
	game._physics_process(0.2)
	if not character.texture.resource_path.ends_with("shiba_astronaut_celebrate.png"):
		_fail("Finishing a course should show the front celebration")
		return
	if character.position.y <= 1.65:
		_fail("The victory pose should bounce")
		return
	game._start()
	if not character.texture.resource_path.ends_with("shiba_astronaut_ufo_back.png"):
		_fail("The next run should return to the rear-view UFO")
		return
	game.level = game.track.level_count() - 1
	game._start()
	game.player_z = -float(game.track.length(game.level)) * game.TILE_SIZE + 3.1
	game._physics_process(0.02)
	if game.mode != "complete" or not character.texture.resource_path.ends_with("shiba_astronaut_celebrate.png"):
		_fail("Reaching the final finish line should trigger the celebration")
		return
	print("celebration_test: PASS")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
