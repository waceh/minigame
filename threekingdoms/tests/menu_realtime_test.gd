extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	assert(game.wave_button.get_parent()==game.ui and game.wave_button.position.y<32)
	game.units=[game.make_unit(24,0,0)];game.start_wave();game.spawn_enemy();game.spawn_left=10
	for menu in [game.open_crafting,game.open_book,game.open_headquarters]:
		menu.call();assert(game.codex_open)
		var before:float=game.elapsed;var distance:float=game.enemies[0].distance
		game._process(.1)
		assert(game.elapsed>before and game.enemies[0].distance>distance,"menus must not pause the simulation")
		game.close_modals()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);assert(not game.paused)
	game.paused=true;game.refresh()
	game.open_crafting();assert(game.codex.visible)
	game.free();print("menu realtime: PASS — crafting, codex and upgrades keep combat running, focus loss does not pause, recipe table opens while paused");quit()
