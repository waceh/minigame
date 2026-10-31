extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func click(button:Button) -> void:
	var point:Vector2=root.get_screen_transform()*(button.global_position+button.size/2)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	game.units=[game.make_unit(24,0,0),game.make_unit(16,1,1),game.make_unit(25,0,2)]
	game.selected=0;game.selected_slots=[0,1];game.refresh();await process_frame;await process_frame
	assert("24" in game.sell_button.text and not game.sell_button.disabled)
	var gold:int=game.gold;await click(game.sell_button)
	assert(game.gold==gold+24 and game.units.size()==2 and game.unit_at(2)>=0 and game.selected==1)
	var key:=InputEventKey.new();key.physical_keycode=KEY_DELETE;key.pressed=true;Input.parse_input_event(key);await process_frame
	assert(game.gold==gold+24+73 and game.units.size()==1 and game.selected==-1)
	game.selected=2;game.selected_slots.clear();assert(not game.sell_selected() and game.units.size()==1)
	game.selected_slots=[2];game.paused=true;assert(not game.sell_selected());game.paused=false
	# The live recipe book lists every recipe and searches both outputs and ingredients.
	game.units=[game.make_unit(24,0,0),game.make_unit(24,0,1),game.make_unit(24,0,2)]
	game.selected=0;game.selected_slots=[0,1,2];game.open_book();assert(game.codex.rows.size()==63)
	game.codex.ready_only.button_pressed=true;game.codex.rebuild();assert(game.codex.rows.size()==1)
	assert(not game.codex.rows[0].button.disabled)
	await click(game.codex.rows[0].button)
	assert(game.units.size()==1 and game.units[0].id==16)
	game.codex.ready_only.button_pressed=false;game.codex.search.text="사마의";game.codex.rebuild();assert(game.codex.rows.size()>=3)
	for row in game.codex.rows:
		var recipe:Dictionary=game.recipes[row.index];assert(game.codex.matches(recipe.result,recipe.materials))
	game.codex.reset_filters();game.codex.rank_filter.select(4);game.codex.rebuild()
	for row in game.codex.rows:assert(game.R.data(game.recipes[row.index].result).rank==3)
	game.codex.close_book();assert(not game.codex_open)
	game.free();print("economy/book: PASS — actual sell button/Delete, one selected hero only, exact refunds, pause, 63 cards, ready/search/tier filters, actual craft click");quit()
