extends SceneTree

const Main = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	var character: Sprite3D
	for child in game.ship.get_children():
		if child is Sprite3D:
			character = child
		assert(not child is MeshInstance3D, "The old spaceship should be replaced")
	if character == null or character.texture == null:
		push_error("The runner needs a visible Shiba sprite")
		quit(1)
		return
	assert(character.pixel_size > 0.0)
	print("character_test: PASS")
	quit()
