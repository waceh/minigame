extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func key(code:int, control:bool=false) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;event.ctrl_pressed=control;Input.parse_input_event(event)
func click(point:Vector2, button:int=MOUSE_BUTTON_LEFT) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=root.get_screen_transform()*point;event.global_position=event.position;event.button_index=button;event.pressed=down;Input.parse_input_event(event)
		await process_frame
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	game.units=[game.make_unit(1,0,0),game.make_unit(5,0,1)];game.selected=0;game.selected_slots=[0];game.refresh()
	await process_frame;await process_frame
	key(KEY_A);await process_frame
	assert(game.pending_order=="attack" and game.selected_slots==[0])
	await click(game.battlefield.screen_pos(Vector2(650,530)))
	assert(game.pending_order=="" and game.units[0].order=="attack_move" and not game.dragging)
	var destination:Vector2=game.units[0].target
	# A-move interrupts travel to acquire and chase a nearby enemy.
	game.wave=1;game.state="battle";game.spawn_left=1;game.spawn_enemy()
	var enemy:Dictionary=game.enemies[0];enemy.distance=90;enemy.hp=1000
	game.units[0].pos=Vector2(184,320)
	game.move_army(.25)
	assert(game.units[0].auto_enemy==enemy.uid and game.units[0].pos.y<320)
	enemy.hp=0;var old_distance:float=game.units[0].pos.distance_to(destination)
	game.move_army(.25)
	assert(game.units[0].auto_enemy==-1 and game.units[0].pos.distance_to(destination)<old_distance)
	# A + enemy click issues a specific attack, not a ground order.
	enemy.hp=1000;key(KEY_A);await process_frame
	await click(game.battlefield.screen_pos(game.path_pos(enemy.distance),.9))
	assert(game.units[0].order=="attack" and game.units[0].focus_enemy==enemy.uid)
	# H anchors the hero even if another body pushes against it, but allows attacks.
	key(KEY_H);await process_frame
	var anchor:Vector2=game.units[0].pos
	assert(game.units[0].order=="hold" and game.units[0].focus_enemy==-1 and not game.units[0].ordered)
	game.units[1].pos=anchor+Vector2(3,0);game.units[1].target=game.units[1].pos
	game.move_army(.5);assert(game.units[0].pos==anchor)
	game.units[0].pos=Vector2(184,252);game.command_hold();anchor=game.units[0].pos
	var hp:float=enemy.hp;game.attack(game.units[0]);assert(enemy.hp<hp and game.units[0].pos==anchor)
	# Move releases hold. Right-click and Esc cancel targeting without moving or pausing.
	game.command_move(Vector2(500,500));assert(game.units[0].order=="move")
	key(KEY_A);await process_frame;var target:Vector2=game.units[0].target
	await click(game.battlefield.screen_pos(Vector2(600,550)),MOUSE_BUTTON_RIGHT)
	assert(game.pending_order=="" and game.units[0].target==target)
	key(KEY_A);await process_frame;key(KEY_ESCAPE);await process_frame
	assert(game.pending_order=="" and not game.paused)
	key(KEY_A,true);await process_frame;assert(game.selected_slots.size()==2)
	# Pausing prevents attack and hold orders.
	game.paused=true;key(KEY_A);key(KEY_H);await process_frame
	assert(game.pending_order=="" and game.units[0].order=="move")
	game.free();print("orders: PASS — A target mode, focus fire, attack-move acquisition/resume, H anchoring/attacks, move release, cancel, Ctrl+A, pause")
	quit()
