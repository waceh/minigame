extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func click_button(button:Button) -> void:
	var point:Vector2=root.get_screen_transform()*(button.global_position+button.size/2)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
func recipe_index(game,id:int) -> int:
	for i in range(game.recipes.size()):
		if game.recipes[i].result==id:return i
	return -1
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	game.units=[game.make_unit(24,0,0),game.make_unit(26,0,1),game.make_unit(37,0,2),game.make_unit(25,0,3)]
	game.selected=3;game.selected_slots=[3];game.refresh()
	await process_frame;await process_frame
	# The visible command button opens the same single-recipe table as M.
	var open_key:=InputEventKey.new();open_key.physical_keycode=KEY_M;open_key.pressed=true;Input.parse_input_event(open_key);await process_frame
	assert(game.codex.visible and game.codex_open and game.codex.rows.size()==51)
	assert(not game.codex.rows[0].button.disabled,"owned ingredients can be crafted without selection gymnastics")
	var preserved:Vector2=game.units[3].pos
	await click_button(game.codex.rows[0].button)
	assert(game.units.size()==2 and game.units[game.unit_at(3)].id==25 and game.units[game.unit_at(3)].pos==preserved)
	assert(game.units[game.unit_at(0)].id==16 and game.units[game.unit_at(0)].investment==105)
	game.codex.close_book()
	var key:=InputEventKey.new();key.physical_keycode=KEY_M;key.pressed=true;Input.parse_input_event(key);await process_frame
	assert(game.codex.visible and game.codex_open,"M opens the same table, never an alternate triple-upgrade path")
	game.codex.close_book()
	# Missing ingredients must fail atomically.
	game.units=[game.make_unit(24,0,0),game.make_unit(26,0,1)]
	assert(not game.craft_recipe(recipe_index(game,16)) and game.units.size()==2)
	# Same name in a lower grade cannot replace a required hidden character.
	game.units=[game.make_unit(3,2,0),game.make_unit(10,3,1),game.make_unit(19,1,2)]
	assert(not game.craft_recipe(recipe_index(game,203)) and game.units.size()==3)
	game.units=[game.make_unit(100,4,0),game.make_unit(10,3,1),game.make_unit(19,1,2),game.make_unit(3,2,3)]
	game.units[0].pos=Vector2(500,500);game.selected=0;game.selected_slots=[0]
	assert(game.craft_recipe(recipe_index(game,203)))
	assert(game.units.size()==2 and game.units[game.unit_at(0)].id==203 and game.units[game.unit_at(0)].pos==Vector2(500,500))
	assert(game.units[game.unit_at(3)].id==3,"the lower-grade Cao Cao is not an ingredient and stays intact")
	assert(game.R.data(203).damage>game.R.data(100).damage and game.R.title(203)=="초월 조조")
	game.paused=true;assert(not game.craft_recipe(0))
	game.free();print("crafting: PASS — actual command button and M open one table, actual craft click, owned quantities, exact consumption, grade identity, hidden-to-transcendent, atomic failure, pause");quit()
