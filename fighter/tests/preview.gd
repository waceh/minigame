extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for i in range(100):
		game._physics_process(1.0/60)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/fighter-menu.png")
	game.start_match()
	game.match_mode = 1
	game.state = "fight"
	game.fighters[0].position.x = -1.1
	game.fighters[1].position.x = 1.1
	for i in range(100):
		game._physics_process(1.0/60)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/fighter-play.png")
	game.fighters[0].attack("kick")
	game.fighters[0].step(0.22)
	game.fighters[0].pose(0.016)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/fighter-kick.png")
	quit()
