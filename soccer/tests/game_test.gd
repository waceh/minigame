extends SceneTree
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	seed(1122)
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	assert(game.players.size()==22)
	assert(game.HALF_X*2==105 and game.HALF_Z*2==68)
	assert(game.players[0].rig!=null and game.players[0].limbs.size()==8)
	assert(game.players[0].body.get_child_count()<=3)
	for team in range(2):
		var count:=0;var keepers:=0
		for p in game.players:
			if p.team==team:
				count+=1
				if p.goalkeeper:keepers+=1
		assert(count==11 and keepers==1)
	game.start_match();assert(game.state=="kickoff" and game.ball_owner==9)
	game._physics_process(2);assert(game.state=="play")
	game.pass_ball(9);assert(game.ball_owner==-1 and game.ball_velocity.length()>9 and game.controlled!=9)
	assert(game.possession_lock>0)
	game.ball_owner=9;game.controlled=9;game.players[9].position=Vector3(5,0,0)
	game.shoot(9,0);var weak:float=game.ball_velocity.length()
	game.ball_owner=9;game.shoot(9,1);assert(game.ball_velocity.length()>weak)
	game.ball_owner=20;game.players[20].position=Vector3(0,0,0);game.players[9].position=Vector3(.5,0,0);game.players[9].cooldown=0;game.possession_lock=0
	game.tackle(9);assert(game.ball_owner==9 and game.players[20].stun>0)
	game.ball_owner=-1;game.possession_lock=0;game.ball_position=Vector3(game.HALF_X-.1,.3,0);game.ball_velocity=Vector3(20,0,0)
	game.step_ball(.02);assert(game.score[0]==1 and game.state=="goal")
	game._physics_process(3);assert(game.state=="kickoff" and game.ball_owner==20)
	game.state="play";game.ball_owner=-1;game.ball_position=Vector3(-game.HALF_X+.1,.3,0);game.ball_velocity=Vector3(-20,0,0);game.step_ball(.02)
	assert(game.score[1]==1)
	game.state="play";game.ball_owner=-1;game.last_touch=1;game.ball_position=Vector3(game.HALF_X-.1,.3,8);game.ball_velocity=Vector3(20,0,0);game.step_ball(.02)
	assert(game.state=="restart" and game.restart_kind=="corner" and game.players[game.restart_taker].team==0)
	game._physics_process(1.5);assert(game.state=="play" and game.ball_owner==-1 and game.ball_velocity.y>5)
	game.state="play";game.ball_owner=-1;game.last_touch=0;game.ball_position=Vector3(0,.3,game.HALF_Z-.1);game.ball_velocity=Vector3(0,0,20);game.step_ball(.02)
	assert(game.state=="restart" and game.restart_kind=="throw_in" and game.players[game.restart_taker].team==1)
	game._physics_process(1.5);assert(game.state=="play")
	game.state="play";game.last_touch=0;game.ball_owner=-1;game.ball_position=Vector3(game.HALF_X-.1,3.5,0);game.ball_velocity=Vector3(20,0,0);game.step_ball(.02)
	assert(game.state=="restart" and game.restart_kind=="goal_kick" and game.players[game.restart_taker].goalkeeper)
	game.state="play"
	game.toggle_pause();var time:float=game.remaining;game._physics_process(1);assert(game.state=="paused" and game.remaining==time);game.toggle_pause()
	game.kickoff(0);game.state="play"
	for i in range(1200):game._physics_process(1.0/60)
	for p in game.players:assert(is_finite(p.position.x) and absf(p.position.x)<game.HALF_X+1 and absf(p.position.z)<game.HALF_Z+1)
	game.state="play";game.remaining=.01;game._physics_process(.02);assert(game.state=="finished" and game.menu.visible)
	game.start_match();assert(game.remaining==180 and game.score==[0,0])
	game.state="play";game.ball_owner=9;game.players[9].position=Vector3(32,0,10)
	for i in range(90):game.update_camera(1.0/60)
	assert(game.camera_target.x>25 and game.camera_target.z>7)
	game.ball_owner=-1;game.players[0].position=Vector3(-49,0,0);game.ball_position=Vector3(-49,1.3,0);game.ball_velocity=Vector3.ZERO;game.possession_lock=0
	game.step_ball(.001);assert(game.ball_owner==0)
	game.players[0].possession_time=.6;game.ai_move(0,.01,[]);assert(game.ball_owner==-1)
	game.players[0].position=Vector3(-50,0,0);game.ball_owner=-1;game.ball_position=Vector3(-48,.7,2);game.ball_velocity=Vector3(-20,0,0)
	game.ai_move(0,.01,[]);assert(game.players[0].dive_time>0)
	game.state="play";game.touch_actions["up"]=true;game.focus_lost();assert(game.state=="paused" and game.touch_actions.is_empty())
	game.sounds.stop();await create_timer(.15).timeout
	game.free();print("soccer game_test: PASS — 11v11, keepers, kickoff, pass, charged shot, tackle, goals, corners, throw-ins, goal-kicks, crossbar, pause, 20s AI simulation, full-time, restart, focus")
	quit()
