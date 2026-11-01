extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	game.units=[game.make_unit(24,0,0),game.make_unit(26,0,1),game.make_unit(37,0,2)]
	game.selected=0;game.selected_slots=[0];game.refresh();await process_frame
	var panel=game.selection_recipes
	assert(panel.visible)
	assert(panel.recipe_buttons[0].tooltip_text.contains(" + ") and panel.recipe_buttons[0].tooltip_text.contains("→ "+game.R.title(16)))
	assert(panel.recipe_buttons[0].has_meta("recipe_bbcode"))
	var tooltip:Control=panel.recipe_buttons[0]._make_custom_tooltip(panel.recipe_buttons[0].tooltip_text)
	assert(tooltip.get_child(0).text.contains("[color=#"))
	tooltip.free()
	var first:Array=panel.related_indices(24)
	for result_index in first:
		assert(game.recipes[result_index].base==24,"only the designated base can show a recipe")
	assert(panel.cells.size()==12 and panel.recipe_buttons[0]==panel.cells[4])
	assert(first.has(0) and panel.recipe_buttons.has(0) and not panel.recipe_buttons[0].disabled)
	assert(panel.recipe_buttons.size()==first.size(),"all immediate recipes fit in the bottom eight cells")
	assert(panel.cells[0].text=="도감" and panel.cells[1].text=="공격 A")
	game.selected=1;game.selected_slots=[1];game.refresh();await process_frame
	assert(panel.heading.text.begins_with(game.R.title(26)) and panel.related_indices(26)!=first)
	assert(not panel.recipe_buttons.has(0),"support material B must not show the recipe")
	game.selected=2;game.selected_slots=[2];game.refresh();await process_frame
	assert(not panel.recipe_buttons.has(0),"support material C must not show the recipe")
	game.selected=0;game.selected_slots=[0];game.refresh();await process_frame
	var button:Button=panel.recipe_buttons[0]
	var point:Vector2=button.global_position+button.size*.5
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=root.get_screen_transform()*point;event.global_position=event.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;Input.parse_input_event(event);await process_frame
	assert(game.units.size()==1 and game.units[0].id==16)
	assert(panel.heading.text.begins_with(game.R.title(16)))
	for candidate in panel.recipe_buttons.values():assert(candidate.disabled)
	game.units=[game.make_unit(200,5,0)];game.selected=0;game.selected_slots=[0];game.refresh()
	assert(panel.visible and panel.recipe_buttons.is_empty())
	game.selected=-1;game.selected_slots=[];game.refresh();assert(panel.recipe_buttons.is_empty())
	game.free();print("selection recipes: PASS — per-unit recipes, inventory counts, real click crafts, product refresh, missing materials, final tier, deselection");quit()
