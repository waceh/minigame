extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	for i in range(120):game._physics_process(1.0/60)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/soccer-menu.png")
	game.start_match();game.state="play";game.banner.text=""
	for i in range(180):game._physics_process(1.0/60)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/soccer-play.png")
	game.camera_mode=1
	for i in range(120):game.update_camera(1.0/60)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/soccer-wide.png")
	game.camera_mode=0
	game.goal(0)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/soccer-goal.png")
	for i in range(game.players.size()):game.players[i].visible=i==9
	var player=game.players[9];player.position=Vector3.ZERO;player.heading=Vector3.BACK;player.velocity=Vector3.ZERO;player.kick_time=0;player.celebrate_time=0;player.animate(1,false)
	game.ui.hide();game.camera.position=Vector3(2.0,1.9,3.8);game.camera.fov=40;game.camera.look_at(Vector3(0,1,0))
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/soccer-player-3d.png")
	print("preview render draw calls: ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
