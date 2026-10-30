extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/soccer-menu.png")
	game.start_match();game.state="play";game.banner.text=""
	for i in range(180):game._physics_process(1.0/60)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/soccer-play.png")
	game.goal(0)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/soccer-goal.png")
	quit()
