extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	for common_id in game.R.SUMMON_IDS:
		assert(game.selection_recipes.related_indices(common_id).size()==2)
	assert(game.selection_recipes.related_indices(19).any(func(i):return game.recipes[i].result==18),"uncommon Xu Chu must lead to Zhang Liao")
	assert(game.selection_recipes.related_indices(304).any(func(i):return game.recipes[i].result==5),"rare Xu Chu must lead to hidden Xun Yu")
	var pairs:=0;var repeated:=0;var mixed:=0
	for index in range(game.recipes.size()):
		var recipe:Dictionary=game.recipes[index];var slot:=0;game.units=[]
		var grades:Array=[];var total:=0
		for ingredient in recipe.materials:
			total+=ingredient[1]
			if ingredient[1]>1:repeated+=1
			if not grades.has(game.R.data(ingredient[0]).rank):grades.append(game.R.data(ingredient[0]).rank)
			for count in range(ingredient[1]):game.units.append(game.make_unit(ingredient[0],0,slot));slot+=1
		if total==2:pairs+=1
		if grades.size()>1:mixed+=1
		for ingredient in recipe.materials:
			assert(game.selection_recipes.related_indices(ingredient[0]).has(index)==(ingredient[0]==recipe.base),"support ingredients must not expose this recipe")
		var base_slot:=-1
		for unit in game.units:
			if unit.id==recipe.base:base_slot=unit.slot;break
		game.selected=base_slot;game.selected_slots=[base_slot];game.units[base_slot].pos=Vector2(430,470)
		assert(game.craft_recipe(index))
		assert(game.units.size()==1 and game.units[0].id==recipe.result and game.units[0].pos==Vector2(430,470))
	assert(pairs>=8 and repeated>=9 and mixed>=20)
	game.free();print("ORD reference recipes: PASS — 9 bases × 2 branches, pair/repeated/mixed-grade patterns, all 51 actual crafts, support hiding and base positions");quit()
