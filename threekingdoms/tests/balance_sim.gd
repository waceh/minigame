extends SceneTree
func _initialize() -> void:call_deferred("run_sim")
func select_army(game) -> void:
	game.selected_slots.clear()
	for u in game.units:game.selected_slots.append(u.slot)
	if not game.units.is_empty():game.selected=game.units[0].slot
func consolidate(game) -> void:
	for attempt in range(100):
		select_army(game)
		var best:=-1;var rank:=-1
		for i in range(game.recipes.size()):
			var recipe:Dictionary=game.recipes[i];var value:int=game.R.data(recipe.result).rank
			if value>rank and not game.recipe_indices(recipe).is_empty():best=i;rank=value
		if best<0:break
		assert(game.craft_recipe(best))
func run_sim() -> void:
	for seed_value in [12,112,712]:
		var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game();game.rng.seed=seed_value
		for wave in range(30):
			consolidate(game)
			if wave>5 and game.upgrade<mini(10,wave/3) and game.gold>200:game.train_army()
			for attempt in range(100):
				if not game.summon():break
				consolidate(game)
			for u in game.units:
				game.selected_slots=[u.slot];game.command_move(Vector2(160+(u.slot%7)*100,285+(u.slot/7)*100))
			game.start_wave()
			for frame in range(1800):
				game.step(.1)
				if game.state!="battle":break
			if game.state in ["lost","won"]:break
		print("balance seed %d: wave=%d lives=%d units=%d upgrade=%d state=%s"%[seed_value,game.wave,game.lives,game.units.size(),game.upgrade,game.state])
		game.free()
	quit()
