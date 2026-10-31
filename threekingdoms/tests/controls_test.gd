extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func mouse(pos:Vector2, down:bool, button:int=MOUSE_BUTTON_LEFT, double_click:bool=false) -> void:
	var event:=InputEventMouseButton.new();event.position=root.get_screen_transform()*pos;event.global_position=event.position;event.pressed=down;event.button_index=button;event.double_click=double_click
	Input.parse_input_event(event)
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false)
	game.reset_game();game.units=[game.make_unit(0,0,0),game.make_unit(1,0,1),game.make_unit(8,0,2)]
	await process_frame;await process_frame
	var point:Vector2=game.battlefield.screen_pos(game.units[0].pos,1.1)
	mouse(point,true);await process_frame;mouse(point,false);await process_frame
	assert(game.selected==0 and game.selected_slots==[0],"unit click must reach world input")
	var goal:Vector2=game.battlefield.screen_pos(Vector2(580,550))
	mouse(goal,true,MOUSE_BUTTON_RIGHT);mouse(goal,false,MOUSE_BUTTON_RIGHT);await process_frame
	assert(game.units[0].ordered and game.units[0].target.distance_to(Vector2(580,550))<1)
	game.selected_slots=[0,1,2]
	var before:Vector2=game.units[0].pos;game.command_move(Vector2(650,600));game.step(.5)
	assert(game.units[0].pos.distance_to(before)>25)
	game.wave=1;game.state="battle";game.spawn_left=1;game.spawn_enemy();game.enemies[0].distance=600
	var enemy_point:Vector2=game.battlefield.screen_pos(game.path_pos(game.enemies[0].distance),.9)
	game.command_at(enemy_point)
	for u in game.units:assert(u.focus_enemy==game.enemies[0].uid)
	game.command_move(Vector2(400,400))
	for u in game.units:assert(u.focus_enemy==-1)
	game.paused=true;var old:Vector2=game.units[0].target
	mouse(goal,true,MOUSE_BUTTON_RIGHT);mouse(goal,false,MOUSE_BUTTON_RIGHT);await process_frame
	assert(game.units[0].target==old)
	game.paused=false;game.state="build"
	# Drag selection must be based on projected unit positions, not old grid cells.
	game.selected_slots.clear();mouse(Vector2(1,37),true)
	var motion:=InputEventMouseMotion.new();motion.position=root.get_screen_transform()*Vector2(1279,567);Input.parse_input_event(motion)
	mouse(Vector2(1279,567),false);await process_frame
	assert(game.selected_slots.size()==3)
	# Double-click selects this hero across all ranks and positions, excluding other heroes.
	game.units=[game.make_unit(24,0,0),game.make_unit(25,0,1),game.make_unit(24,0,2),game.make_unit(24,0,3)]
	game.selected=-1;game.selected_slots.clear();game.refresh()
	point=game.battlefield.screen_pos(game.units[0].pos,1.1)
	mouse(point,true,MOUSE_BUTTON_LEFT,true);await process_frame;mouse(point,false);await process_frame
	assert(game.selected_slots==[0,2,3] and game.selected==0 and not game.dragging)
	var target:Vector2=game.units[0].target
	assert(game.units[0].pos==target,"double-click release must not issue a move")
	assert(game.detail.text.contains("3名") or game.detail.text.contains("3명"))
	# Minimap clicks pan the camera without issuing troop orders.
	var old_target:Vector2=game.units[0].target
	mouse(game.minimap.global_position+Vector2(180,145),true);await process_frame;mouse(game.minimap.global_position+Vector2(180,145),false);await process_frame
	assert(game.battlefield.focus.length()>1 and game.units[0].target==old_target)
	# Opening the codex suspends shortcuts until it is closed.
	game.codex_open=true;var count:int=game.units.size()
	var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_SPACE;Input.parse_input_event(key);await process_frame
	assert(game.units.size()==count)
	game.free();print("threekingdoms controls: PASS — engine-dispatched selection, right-click movement, drag selection, focus fire, double-click same hero across positions, pause, codex")
	quit()
