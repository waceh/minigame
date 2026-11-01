extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	var names:Array=[];var tiers:=[0,0,0,0,0,0];var reachable:Array=game.R.SUMMON_IDS.duplicate()
	for id in game.R.DATA:
		var h:Dictionary=game.R.data(id);assert(not names.has(game.R.title(id)));names.append(game.R.title(id));tiers[h.rank]+=1
		var art:Array=game.battlefield.art_for(id)
		for frame in range(4):
			var data:Dictionary=game.battlefield.frame_meta(id,frame);var r:Array=data.rect
			assert(r[0]>=0 and r[1]>=0 and r[2]>0 and r[3]>0 and r[0]+r[2]<=art[0].get_width() and r[1]+r[3]<=art[0].get_height())
	for common_id in game.R.SUMMON_IDS:
		var branches:=0
		for recipe in game.recipes:
			if recipe.base==common_id:
				branches+=1
				assert(game.R.data(recipe.result).rank==1,"common units only lead to the next grade")
		assert(branches==2,"each common base needs two direct choices")
	assert(names.size()==60 and tiers==[9,18,15,3,6,9] and game.recipes.size()==51)
	var outputs:Array=[];var ingredient_sets:Array=[]
	for recipe in game.recipes:
		assert(recipe.materials.any(func(m):return m[0]==recipe.base),"the designated base must be an actual ingredient")
		assert(not outputs.has(recipe.result),"every grade/name result must have exactly one recipe");outputs.append(recipe.result)
		var signature:Array=recipe.materials.duplicate(true);signature.sort_custom(func(a,b):return a[0]<b[0])
		assert(not ingredient_sets.has(signature),"the same ingredients must not give ambiguous results");ingredient_sets.append(signature)
	for i in range(6):
		for recipe in game.recipes:
			var all_ready:=true;var cost:=0
			for material in recipe.materials:
				assert(game.R.data(material[0]).rank<game.R.data(recipe.result).rank)
				all_ready=all_ready and reachable.has(material[0]);cost+=game.R.material_cost(material[0])*material[1]
			assert(game.R.sell_value(recipe.result)<cost,"craft/sell must not create money")
			if all_ready and not reachable.has(recipe.result):reachable.append(recipe.result)
	assert(reachable.size()==60)
	game.rng.seed=712
	for i in range(6):
		assert(game.summon());assert(game.units[-1].pos==game.SUMMON_POINT and game.units[-1].rank<=2 and game.R.SUMMON_POOLS[game.units[-1].rank].has(game.units[-1].id))
		assert(game.units[-1].target.distance_to(game.SUMMON_POINT)<100)
	assert(game.gold==0 and not game.summon());game.step(2)
	for u in game.units:assert(u.pos.distance_to(game.SUMMON_POINT)<110)
	game.units=[game.make_unit(9,3,0)];game.selected=0;game.selected_slots=[0];game.gold=500
	assert(game.train_army() and game.gold==420 and game.upgrade==1)
	game.start_wave();game.spawn_enemy();game.enemies[0].distance=90
	var enemy:Dictionary=game.enemies[0];game.attack(game.units[0]);assert(enemy.hp<=0 and enemy.slow>0)
	game.step(.01);assert(game.kills==1)
	game.units.clear();game.enemies=[{"uid":100,"distance":game.PATH_LENGTH-1,"hp":99999.0,"max_hp":99999.0,"speed":100.0,"boss":true,"elite":false,"slow":0.0,"stun":0.0,"burn":0.0,"burn_damage":0.0,"flash":0.0}];game.spawn_left=0;game.step(.1)
	assert(game.lives==25 and game.state=="build")
	game.reset_game();game.units=[game.make_unit(26,0,0)];game.start_wave();game.spawn_enemy();game.enemies[0].distance=90;game.attack(game.units[0]);assert(game.enemies[0].slow>0)
	game.units=[game.make_unit(32,0,0)];game.units[0].pos=Vector2(184,252)
	game.enemies[0].slow=0;game.enemies[0].hp=1000;game.attack(game.units[0])
	assert(game.enemies[0].hp<1000 and game.enemies[0].slow==0,"Yue Jin fights in melee and does not cast a scholar's slow")
	game.units=[game.make_unit(2,1,0)];game.units[0].pos=Vector2(184,252);game.units[0].hits=3;game.attack(game.units[0]);assert(game.enemies[0].stun>0)
	game.units=[game.make_unit(8,4,0)];game.enemies[0].hp=10000;game.attack(game.units[0]);assert(game.enemies[0].burn>0)
	game.reset_game()
	for slot in range(game.MAX_UNITS):game.units.append(game.make_unit(200,5,slot))
	game.upgrade=10
	for wave in range(30):
		game.start_wave()
		for frame in range(1800):
			game.step(.1)
			if game.state!="battle":break
		assert(game.state in ["build","won"])
	assert(game.state=="won" and game.wave==30)
	game.reset_game();game.state="battle";game.lives=0;game.step(.01);assert(game.state=="lost")
	game.free();print("game: PASS — 60 grade-specific heroes, 9 distinct common officers, 51 unique reachable recipes, no sell arbitrage, atlas bounds, fixed camp, economy, roles, bosses, 30-wave victory/defeat");quit()
