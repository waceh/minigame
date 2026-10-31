extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func click_button(button:Button) -> void:
	var point:Vector2=root.get_screen_transform()*(button.global_position+button.size/2)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	game.units=[game.make_unit(25,0,0),game.make_unit(24,0,1),game.make_unit(24,0,2),game.make_unit(24,0,3)]
	game.selected=0;game.selected_slots=[0,1,2];game.refresh()
	assert(game.merge_button.disabled and not game.merge_selected(),"unselected third copy must not be consumed")
	game.selected_slots=[0,1,2,3];game.refresh();assert(not game.merge_button.disabled and "황충" in game.merge_button.text)
	await process_frame;await process_frame;await click_button(game.merge_button)
	assert(game.units.size()==2 and game.units[game.unit_at(0)].id==25)
	assert(game.units[game.unit_at(game.selected)].id==16 and game.units[game.unit_at(game.selected)].rank==1)
	game.selected=-1;game.selected_slots.clear();game.refresh();assert(game.merge_button.disabled)
	# The requested mixed recipe: Sima Yi + tier-3 Cao Cao + two tier-2 Xiahou Dun + a tier-1 Cao Hong.
	var recipe_id:=-1
	for i in range(game.recipes.size()):
		if game.recipes[i].result==5 and game.recipes[i].materials==[[10,1],[3,1],[4,2],[30,1]]:recipe_id=i
	assert(recipe_id>=0)
	game.units=[game.make_unit(10,3,0),game.make_unit(3,2,1),game.make_unit(4,1,2),game.make_unit(4,1,3),game.make_unit(30,0,4),game.make_unit(4,1,5)]
	game.units[0].pos=Vector2(500,500);game.selected=0;game.selected_slots=[0,1,2,4,5]
	assert(game.craft_recipe(recipe_id))
	assert(game.units.size()==2 and game.units[game.unit_at(3)].id==4,"unselected Xiahou Dun stays untouched")
	assert(game.units[game.unit_at(0)].id==5 and game.units[game.unit_at(0)].rank==4 and game.units[game.unit_at(0)].pos==Vector2(500,500))
	# A missing selected ingredient never partially consumes the recipe.
	game.units=[game.make_unit(10,3,0),game.make_unit(3,2,1),game.make_unit(4,1,2),game.make_unit(4,1,3),game.make_unit(30,0,4)]
	game.selected_slots=[0,1,2,3];assert(not game.craft_recipe(recipe_id) and game.units.size()==5)
	game.selected_slots=[0,1,2,3,4];game.paused=true;assert(not game.craft_recipe(recipe_id));game.paused=false
	game.free();print("merge: PASS — actual M button, selected-only triple, different promoted hero, no selection rejection, mixed mythic recipe, unselected safety, atomic failure, pause");quit()
