extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	for i in range(36):
		game.units.append(game.make_unit(24,0,i));game.selected_slots.append(i)
	for destination in [Vector2(600,500),Vector2(834,670),Vector2(110,240)]:
		game.command_move(destination)
		for frame in range(1200):game.move_army(1./60.)
		var positions:Array=[]
		for unit in game.units:
			assert(unit.pos.distance_to(unit.target)<1.1,"army must reach its formation, including map corners")
			positions.append(unit.pos)
		for frame in range(120):game.move_army(1./60.)
		for i in range(game.units.size()):assert(game.units[i].pos.distance_to(positions[i])<.01,"arrived formation must remain still")
	game.free();print("movement stability: PASS — 36 units reach center and both corners, then remain still");quit()
