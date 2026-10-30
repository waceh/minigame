extends SceneTree
func _initialize() -> void:call_deferred("run_test")
func key(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func fixture(game) -> void:
	game.kickoff(0);game.state="play";game.ball_owner=9;game.controlled=9
	game.players[9].position=Vector3.ZERO;game.players[9].heading=Vector3.RIGHT
	game.players[10].position=Vector3(10,0,0);game.players[10].velocity=Vector3(4,0,0)
func run_test() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	await process_frame
	fixture(game)
	key(KEY_S,true);key(KEY_S,false)
	assert(game.ball_owner==-1 and game.ball_velocity.y<.5)
	assert(not game.held("down"))
	fixture(game)
	key(KEY_A,true);key(KEY_A,false)
	assert(game.ball_owner==-1 and game.ball_velocity.y>=5.5)
	for i in range(24):game.step_ball(1.0/60)
	assert(game.ball_position.y>1.4)
	fixture(game)
	key(KEY_E,true);key(KEY_E,false)
	assert(game.ball_owner==-1 and game.ball_velocity.y<.2)
	assert(game.players[game.controlled].support_target.x>game.players[game.controlled].position.x+3)
	fixture(game)
	key(KEY_D,true);assert(game.charging);game.shot_charge=.8;key(KEY_D,false)
	assert(not game.charging and game.ball_owner==-1 and game.ball_velocity.length()>25)
	assert(not game.held("right"))
	key(KEY_W,true);assert(game.held("sprint") and not game.held("up"));key(KEY_W,false)
	fixture(game)
	var old:int=game.controlled
	key(KEY_Q,true);assert(game.held("feint") and game.controlled==old);key(KEY_Q,false)
	key(KEY_SHIFT,true);assert(game.held("cut") and not game.held("sprint"));key(KEY_SHIFT,false)
	key(KEY_RIGHT,true);assert(game.held("right"));key(KEY_RIGHT,false)
	fixture(game)
	assert(game.try_skill(9,Vector3.FORWARD,"feint"))
	var stamina:float=game.players[9].stamina
	var start:Vector3=game.players[9].position
	game.move_player(9,Vector3.ZERO,0,.1)
	assert(game.players[9].position.z<start.z-.7 and stamina<100)
	assert(not game.try_skill(9,Vector3.RIGHT,"cut"))
	game.players[20].position=game.players[9].position+Vector3(.4,0,0);game.players[20].cooldown=0;game.possession_lock=0
	game.tackle(20);assert(game.ball_owner==9)
	fixture(game)
	key(KEY_SHIFT,true);key(KEY_RIGHT,true);game._physics_process(1.0/60)
	assert(game.players[9].skill_kind=="cut" and game.players[9].skill_time>0)
	var cooldown:float=game.players[9].skill_cooldown
	for i in range(6):game._physics_process(1.0/60)
	assert(game.players[9].skill_cooldown<cooldown)
	key(KEY_SHIFT,false);key(KEY_RIGHT,false)
	fixture(game);key(KEY_D,true);assert(game.charging);game.focus_lost();assert(not game.charging);key(KEY_D,false)
	assert(game.kick_audio.mix_rate==44100 and game.kick_audio.data.size()>20000)
	assert(game.kick_audio.data.decode_s16(0)==0)
	game.free()
	print("soccer controls_test: PASS — S short, A lob trajectory, E lead target, D release-shot, W sprint, Q/Shift skills, arrows, skill cooldown/evasion, focus cancel, softened kick PCM")
	quit()
