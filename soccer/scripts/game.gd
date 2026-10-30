extends Node3D
const Player = preload("res://scripts/footballer.gd")
const Pitch = preload("res://scripts/pitch.gd")
const V = preload("res://scripts/visuals.gd")
const Radar = preload("res://scripts/radar.gd")
const FONT = preload("res://font.ttf")
const HALF_X := 52.5
const HALF_Z := 34.0
const GOAL_WIDTH := 3.66
const BALL_RADIUS := .14
const FORMATION = [Vector2(-49,0),Vector2(-33,-24),Vector2(-35,-8),Vector2(-35,8),Vector2(-33,24),Vector2(-15,-20),Vector2(-20,0),Vector2(-15,20),Vector2(10,-25),Vector2(13,0),Vector2(10,25)]
var players: Array = []
var controlled := 9
var ball_owner := -1
var last_touch := 0
var possession_lock := 0.0
var ball_position := Vector3(0,BALL_RADIUS,0)
var ball_velocity := Vector3.ZERO
var ball_node: Node3D
var ball_shadow: MeshInstance3D
var ball_roll: Node3D
var ball_rotation := Vector3.ZERO
var shot_charge := 0.0
var charging := false
var skill_combo := ""
var score := [0,0]
var remaining := 180.0
var state := "menu"
var previous_state := "play"
var phase_time := 0.0
var kickoff_team := 0
var difficulty := 1
var ai_clock := 0.0
var elapsed := 0.0
var camera: Camera3D
var camera_mode := 0
var camera_target := Vector3.ZERO
var radar: Control
var restart_kind := ""
var restart_taker := -1
var ui: Control
var menu: Panel
var score_label: Label
var time_label: Label
var status_label: Label
var banner: Label
var stamina_bar: ProgressBar
var charge_bar: ProgressBar
var start_button: Button
var difficulty_select: OptionButton
var pause_button: Button
var menu_description: Label
var touch_root: Control
var touches: Dictionary = {}
var touch_actions: Dictionary = {}
var action_buttons: Dictionary = {}
var sounds: AudioStreamPlayer
var kick_audio: AudioStreamWAV
var goal_audio: AudioStreamWAV
var pickup_ignore := -1

func _ready() -> void:
	Input.emulate_mouse_from_touch=false
	add_child(Pitch.new())
	for team in range(2):
		for i in range(11):
			var p=Player.new();add_child(p)
			var spawn:Vector3=Vector3(FORMATION[i].x*(1 if team==0 else -1),0,FORMATION[i].y)
			p.setup(team,i+1,spawn);players.append(p)
	make_ball()
	camera=Camera3D.new();camera.fov=36;camera.position=Vector3(0,26,34);camera.current=true;camera.near=.15;camera.far=240;add_child(camera);camera.look_at(Vector3(0,.7,0))
	sounds=AudioStreamPlayer.new();add_child(sounds);kick_audio=make_audio(false);goal_audio=make_audio(true)
	build_ui();get_viewport().size_changed.connect(layout_ui);get_window().focus_exited.connect(focus_lost);layout_ui()

func make_audio(goal: bool) -> AudioStreamWAV:
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=44100
	var count:=28000 if goal else 10584
	var data:=PackedByteArray();data.resize(count*2)
	var rng:=RandomNumberGenerator.new();rng.seed=40819
	var leather:=0.0;var body_noise:=0.0
	for i in range(count):
		var t:=float(i)/44100;var sample:=0.0
		if goal:
			var freq:float=[523.25,659.25,783.99][mini(2,int(t*5))]
			sample=sin(t*TAU*freq)*.35*exp(-t*2)
		else:
			# Soft shoe contact, low air-cavity thump, and a short leather resonance.
			# A smooth attack avoids the old single-sample click; filtered noise avoids hiss.
			var noise:=rng.randf_range(-1,1)
			leather=lerpf(leather,noise,.12);body_noise=lerpf(body_noise,noise,.026)
			var attack:=1-exp(-t*950)
			var body:=sin(TAU*(86*t+1.2*(1-exp(-t*35))))*.48*exp(-t*31)
			var resonance:=(sin(TAU*156*t)*.15+sin(TAU*238*t)*.06)*exp(-t*47)
			var contact:=leather*.55*exp(-t*95)+body_noise*.65*exp(-t*35)
			sample=(body+resonance+contact)*attack*smoothstep(0,.018,.24-t)
		data.encode_s16(i*2,int(clampf(sample,-1,1)*26000))
	wav.data=data;return wav
func play_sound(goal: bool=false, power: float=1.0) -> void:
	if DisplayServer.get_name()=="headless":return
	sounds.stream=goal_audio if goal else kick_audio
	sounds.pitch_scale=1.0 if goal else clampf(1.07-power*.12,.91,1.04)
	sounds.volume_db=-5 if goal else lerpf(-12,-3,clampf(power,0,1))
	sounds.play()
func make_ball() -> void:
	ball_node=Node3D.new();add_child(ball_node);ball_roll=Node3D.new();ball_node.add_child(ball_roll)
	V.sphere(ball_roll,BALL_RADIUS,Vector3.ZERO,V.material(Color("f5f0d5"),0,.7))
	var black:=V.material(Color("202b32"),0,.85)
	for i in range(12):
		var y:float=1-2*(i+.5)/12;var r:=sqrt(1-y*y);var angle:=i*2.39996
		V.sphere(ball_roll,.043,Vector3(cos(angle)*r,y,sin(angle)*r)*.118,black)
	var mat:=V.material(Color(.01,.03,.02,.4));mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_shadow=V.cylinder(self,.18,.18,.003,Vector3.ZERO,mat,24);ball_shadow.scale.z=.65
func start_match() -> void:
	difficulty=difficulty_select.selected;score=[0,0];remaining=180;menu.hide();kickoff(0)
func kickoff(team: int) -> void:
	kickoff_team=team;ball_owner=-1;pickup_ignore=-1;possession_lock=0;ball_position=Vector3(0,BALL_RADIUS,0);ball_velocity=Vector3.ZERO;charging=false;shot_charge=0
	for i in range(22):
		var p=players[i];p.position=p.home;p.velocity=Vector3.ZERO;p.cooldown=0;p.stun=0;p.possession_time=0;p.stamina=100;p.skill_time=0;p.skill_cooldown=0;p.support_time=0;p.dive_time=0;p.celebrate_time=0
		# Both teams start in their own half; attackers spread after the whistle.
		p.position.x=clampf(p.position.x,-49,-1.5) if p.team==0 else clampf(p.position.x,1.5,49)
	var taker:=9 if team==0 else 20
	players[taker].position=Vector3(-.8 if team==0 else .8,0,0)
	controlled=9;ball_owner=taker;last_touch=team;state="kickoff";phase_time=1.8;banner.text="KICK OFF";touch_root.visible=DisplayServer.is_touchscreen_available();clear_touches()
func switch_player() -> void:
	if ball_owner>=0 and players[ball_owner].team==0 and not players[ball_owner].goalkeeper:
		controlled=ball_owner;return
	var best:=controlled;var distance:=INF
	for i in range(1,11):
		var d:float=players[i].position.distance_squared_to(ball_position)
		if d<distance:
			distance=d;best=i
	controlled=best
func held(action: String) -> bool:
	var keys={"left":KEY_LEFT,"right":KEY_RIGHT,"up":KEY_UP,"down":KEY_DOWN,"sprint":KEY_W,"feint":KEY_Q,"cut":KEY_SHIFT}
	return touch_actions.has(action) or (keys.has(action) and Input.is_physical_key_pressed(keys[action]))
func act(action: String) -> void:
	if state!="play":return
	match action:
		"pass":
			if ball_owner==controlled:pass_ball(controlled)
		"long":
			if ball_owner==controlled:pass_ball(controlled,"long")
		"through":
			if ball_owner==controlled:pass_ball(controlled,"through")
		"shoot":
			if ball_owner==controlled:charging=true;shot_charge=0
		"tackle":tackle(controlled)
		"switch":switch_player()
func release_shot() -> void:
	if charging:
		charging=false
		if state=="play" and ball_owner==controlled:shoot(controlled,shot_charge)
		shot_charge=0
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE:toggle_pause()
				KEY_S:act("pass")
				KEY_D:act("shoot")
				KEY_L:act("tackle")
				KEY_A:act("long")
				KEY_E:act("through")
				KEY_TAB:act("switch")
				KEY_C:camera_mode=(camera_mode+1)%3
		elif not event.pressed and event.physical_keycode==KEY_D:release_shot()
	if event is InputEventScreenTouch:
		if event.pressed:
			for action in action_buttons:
				if touch_root.visible and action_buttons[action].get_global_rect().has_point(event.position):
					touches[event.index]=action;touch_actions[action]=true;act(action);get_viewport().set_input_as_handled();break
		elif touches.has(event.index):
			var action:String=touches[event.index];touches.erase(event.index)
			if not touches.values().has(action):touch_actions.erase(action)
			if action=="shoot":release_shot()
	if event is InputEventScreenDrag and touches.has(event.index):
		var old:String=touches[event.index]
		if old in ["up","down","left","right"]:
			for action in ["up","down","left","right"]:
				if action_buttons[action].get_global_rect().has_point(event.position):
					touch_actions.erase(old);touches[event.index]=action;touch_actions[action]=true;break
func clear_touches() -> void:
	touches.clear();touch_actions.clear();charging=false;shot_charge=0;skill_combo=""
func focus_lost() -> void:
	clear_touches()
	if state in ["play","kickoff","goal","restart"]:toggle_pause()
func toggle_pause() -> void:
	if state in ["menu","finished"]:return
	if state=="paused":state=previous_state;banner.text="";pause_button.text="일시정지  ESC"
	else:previous_state=state;state="paused";clear_touches();banner.text="PAUSED";pause_button.text="계속하기  ESC"
func try_skill(i: int, direction: Vector3, kind: String) -> bool:
	var p=players[i]
	var cost:=10.0 if kind=="feint" else 17.0
	if ball_owner!=i or direction.length()<.1 or p.skill_cooldown>0 or p.stun>0 or p.stamina<cost:return false
	p.skill_kind=kind;p.skill_direction=direction.normalized();p.skill_time=.24 if kind=="feint" else .20
	p.skill_cooldown=.8 if kind=="feint" else 1.05;p.stamina-=cost;p.kick_time=.2
	return true
func move_player(i: int, direction: Vector3, speed: float, dt: float) -> void:
	var p=players[i]
	if p.skill_time>0:
		direction=p.skill_direction
		speed=7.8 if p.skill_kind=="feint" else 10.8
	if p.stun>0:p.velocity=Vector3.ZERO;return
	var wanted:Vector3=direction.limit_length(1)*speed
	p.velocity=wanted if p.skill_time>0 else p.velocity.move_toward(wanted,(21 if direction.length()>.1 else 26)*dt)
	if direction.length()>.1:
		p.heading=p.heading.lerp(direction.normalized(),minf(dt*11,1)).normalized()
	p.position+=p.velocity*dt;p.position.x=clampf(p.position.x,-HALF_X+.35,HALF_X-.35);p.position.z=clampf(p.position.z,-HALF_Z+.35,HALF_Z-.35)
func ai_move(i: int, dt: float, chasers: Array) -> void:
	var p=players[i];var attack_dir:=1.0 if p.team==0 else -1.0
	var target:Vector3=p.home;var speed:=4.5
	if ball_owner==i:
		p.possession_time+=dt
		if p.goalkeeper:
			p.velocity=Vector3.ZERO
			if p.possession_time>.5:pass_ball(i)
			return
		target=Vector3(attack_dir*51,0,clampf(p.position.z*.65,-7,7))
		var to_goal:float=absf(attack_dir*HALF_X-p.position.x)
		if to_goal<23 and absf(p.position.z)<16 and p.possession_time>.45:
			shoot(i,.45+randf()*.4);return
		if p.possession_time>1.0 and (nearest_opponent_distance(i)<2.6 or p.possession_time>3):
			pass_ball(i);return
		speed=4.3 if difficulty==0 else 4.8
	elif p.goalkeeper:
		target=Vector3(-attack_dir*50.7,0,clampf(ball_position.z*.3,-3,3))
		if ball_position.x*attack_dir < -37 and absf(ball_position.z)<14:
			var intercept_z:float=ball_position.z
			if ball_velocity.x*attack_dir < -7:
				var travel_time:float=absf((target.x-ball_position.x)/ball_velocity.x)
				intercept_z+=ball_velocity.z*travel_time
				if travel_time<.35 and absf(intercept_z-p.position.z)>.45 and p.dive_time<=0:
					p.dive_time=.5;p.dive_side=signf(intercept_z-p.position.z)
			target.z=clampf(intercept_z,-3.4,3.4)
			if ball_velocity.length()<6:target.x=clampf(ball_position.x,-51,51)
		speed=4.0 if difficulty==0 else 5.6
	elif p.support_time>0 and (ball_owner<0 or players[ball_owner].team==p.team):
		target=p.support_target;speed=5.5
	elif chasers.has(i):
		target=ball_position;target.y=0
		if ball_owner>=0 and players[ball_owner].team!=p.team and p.position.distance_to(players[ball_owner].position)<1.45 and p.cooldown==0:
			if randf()<dt*(1.0 if difficulty==0 else 2.5):tackle(i)
	else:
		var own_possession:bool=ball_owner>=0 and players[ball_owner].team==p.team
		target.x+=clampf(ball_position.x*.60,-20,30) if p.team==0 else clampf(ball_position.x*.60,-30,20)
		if own_possession:target.x+=attack_dir*3
		target.x=clampf(target.x,-46,46);target.z=clampf(p.home.z+ball_position.z*.20,-31,31)
	var delta:Vector3=target-p.position
	move_player(i,delta.normalized() if delta.length()>.25 else Vector3.ZERO,speed,dt)
func nearest_opponent_distance(i: int) -> float:
	var d:=INF
	for j in range(22):
		if players[j].team!=players[i].team:d=minf(d,players[j].position.distance_to(players[i].position))
	return d
func pass_ball(i: int, kind: String="short") -> void:
	if ball_owner!=i:return
	var p=players[i];var best:=-1;var quality:=-INF
	var direction:Vector3=p.heading
	for j in range(22):
		if j==i or players[j].team!=p.team or players[j].goalkeeper:continue
		var offset:Vector3=players[j].position-p.position;var distance:=offset.length()
		var max_distance:=56.0 if kind=="long" else 36.0 if kind=="through" else 23.0
		if distance<2 or distance>max_distance:continue
		var q:float=offset.normalized().dot(direction)*7+minf(nearest_opponent_distance(j),5)*.25
		q+=distance*.12 if kind=="long" else -distance*.16
		if q>quality:quality=q;best=j
	var target:Vector3=p.position+direction*(20 if kind=="long" else 12 if kind=="through" else 8)
	if best>=0:
		target=players[best].position+players[best].velocity*.2
		if kind=="through":
			var run:Vector3=players[best].velocity.normalized() if players[best].velocity.length()>1 else direction
			if run.dot(direction)<.2:run=direction
			target+=run*clampf(p.position.distance_to(target)*.28,4,7)
		target.x=clampf(target.x,-50.5,50.5);target.z=clampf(target.z,-32.5,32.5)
	var offset:Vector3=target-p.position;offset.y=0
	if kind=="long":
		var flight_time:=clampf(offset.length()/17.0,1.1,2.6)
		release_ball(i,offset.normalized()*maxf(1,offset.length()-.75)/flight_time,5.0*flight_time)
	elif kind=="through":
		release_ball(i,offset.normalized()*clampf(offset.length()*1.05,14,22),.12)
	else:
		release_ball(i,offset.normalized()*clampf(offset.length()*1.1,9,16),.3)
	if best>=0:
		players[best].support_target=target;players[best].support_time=2.6 if kind=="long" else 2.0
		if p.team==0:controlled=best
func shoot(i: int, charge: float) -> void:
	if ball_owner!=i:return
	var p=players[i];var sign_dir:=1.0 if p.team==0 else -1.0
	var aim_z:float=clampf(p.position.z*.12+randf_range(-1.8,1.8),-2.5,2.5)
	# Vertical movement keys let the user aim toward either goal corner.
	if i==controlled:aim_z=(float(held("down"))-float(held("up")))*2.4
	var direction:Vector3=(Vector3(sign_dir*(HALF_X+1),0,aim_z)-p.position).normalized()
	release_ball(i,direction*(18+charge*10),2.0+charge*3.6)
func release_ball(i: int, velocity: Vector3, lift: float) -> void:
	var p=players[i]
	if Vector2(velocity.x,velocity.z).length()>.1:p.heading=Vector3(velocity.x,0,velocity.z).normalized()
	ball_position=p.position+p.heading*.75+Vector3(0,BALL_RADIUS+.025,0);ball_velocity=velocity;ball_velocity.y=lift
	last_touch=p.team;ball_owner=-1;possession_lock=.24;pickup_ignore=i;p.cooldown=.3;p.kick_time=.25;p.possession_time=0;play_sound(false,clampf(velocity.length()/28,.25,1))
func tackle(i: int) -> void:
	var p=players[i]
	if p.cooldown>0 or possession_lock>0:return
	p.cooldown=1.2;p.kick_time=.22
	if ball_owner>=0 and players[ball_owner].team!=p.team and p.position.distance_to(players[ball_owner].position)<1.65:
		var victim=players[ball_owner]
		if victim.skill_time>0:return
		victim.stun=.5
		ball_owner=i;p.possession_time=0;possession_lock=.32;last_touch=p.team
		if p.team==0 and not p.goalkeeper:controlled=i
func step_ball(dt: float) -> void:
	possession_lock=maxf(0,possession_lock-dt)
	if ball_owner>=0:
		var p=players[ball_owner]
		var lead:=.44+clampf(p.velocity.length()*.08,0,.45)
		var desired:Vector3=p.position+p.heading*lead
		desired.y=BALL_RADIUS+.025+absf(sin(p.gait))*.025
		var before:=ball_position
		ball_position=ball_position.lerp(desired,minf(dt*20,1))
		ball_velocity=(ball_position-before)/maxf(dt,.001)
		return
	ball_position+=ball_velocity*dt;ball_velocity.y-=10*dt
	if ball_position.y<BALL_RADIUS:
		ball_position.y=BALL_RADIUS
		ball_velocity.y=absf(ball_velocity.y)*.35 if absf(ball_velocity.y)>1.2 else 0
		ball_velocity.x=move_toward(ball_velocity.x,0,dt*2.2);ball_velocity.z=move_toward(ball_velocity.z,0,dt*2.2)
	if absf(ball_position.x)>HALF_X:
		if absf(ball_position.z)<GOAL_WIDTH and ball_position.y<2.44:
			goal(0 if ball_position.x>0 else 1);return
		var defending:=1 if ball_position.x>0 else 0
		if last_touch==defending:
			begin_restart(1-defending,"corner",Vector3(signf(ball_position.x)*(HALF_X-.4),0,signf(ball_position.z)*(HALF_Z-.4)))
		else:
			begin_restart(defending,"goal_kick",Vector3(signf(ball_position.x)*(HALF_X-5.5),0,0))
		return
	if absf(ball_position.z)>HALF_Z:
		begin_restart(1-last_touch,"throw_in",Vector3(clampf(ball_position.x,-HALF_X+1,HALF_X-1),0,signf(ball_position.z)*(HALF_Z-.4)))
		return
	for i in range(22):
		var p=players[i]
		if p.stun>0 or (possession_lock>0 and pickup_ignore==i):continue
		if possession_lock>0 and last_touch!=p.team:continue
		var height:=1.95 if p.goalkeeper else .75
		if ball_position.y<height and Vector2(p.position.x,p.position.z).distance_to(Vector2(ball_position.x,ball_position.z))<(1.45 if p.goalkeeper and p.dive_time>0 else .9 if p.goalkeeper else .65):
			ball_owner=i;p.possession_time=0;ball_velocity=Vector3.ZERO;last_touch=p.team
			if p.team==0 and not p.goalkeeper:controlled=i
			break
func begin_restart(team: int, kind: String, spot: Vector3) -> void:
	for p in players:p.velocity=Vector3.ZERO
	restart_kind=kind;restart_taker=team*11 if kind=="goal_kick" else -1
	if restart_taker<0:
		var nearest:=INF
		for i in range(team*11+1,team*11+11):
			var d:float=players[i].position.distance_squared_to(spot)
			if d<nearest:nearest=d;restart_taker=i
	var taker=players[restart_taker]
	taker.position=spot;taker.velocity=Vector3.ZERO;taker.heading=(Vector3(0,0,0)-spot).normalized()
	ball_owner=restart_taker;ball_position=spot+taker.heading*.55+Vector3(0,BALL_RADIUS,0);ball_velocity=Vector3.ZERO
	state="restart";phase_time=1.35;clear_touches()
	banner.text={"throw_in":"THROW IN","corner":"CORNER","goal_kick":"GOAL KICK"}[kind]
	if team==0 and not taker.goalkeeper:controlled=restart_taker

func goal(team: int) -> void:
	for p in players:
		p.velocity=Vector3.ZERO
		if p.team==team:p.celebrate_time=2.6
	score[team]+=1;state="goal";phase_time=2.6;ball_owner=-1;ball_velocity=Vector3.ZERO;kickoff_team=1-team;clear_touches();banner.text="GOAL!  /  "+("FOREST FC" if team==0 else "CORAL UNITED");play_sound(true)
func finish_match() -> void:
	state="finished";clear_touches();touch_root.hide();menu.show();banner.text="FULL TIME"
	menu_description.text="경기 종료  /  %d : %d\n%s\n패스로 공간을 만들고 슛을 노려 보세요."%[score[0],score[1],"FOREST FC 승리!" if score[0]>score[1] else "무승부" if score[0]==score[1] else "CORAL UNITED 승리"]
	start_button.text="다시 경기  ↗"
func _physics_process(dt: float) -> void:
	if state=="paused":return
	elapsed+=dt
	if camera:update_camera(dt)
	if state=="restart":
		phase_time-=dt
		if phase_time<=0:
			state="play";banner.text=""
			pass_ball(restart_taker,"short" if restart_kind=="throw_in" else "long")
	elif state in ["kickoff","goal"]:
		phase_time-=dt
		if phase_time<=0:
			if state=="goal":kickoff(kickoff_team)
			else:state="play";banner.text=""
	elif state=="play":
		remaining=maxf(0,remaining-dt)
		var input_dir:=Vector3(float(held("right"))-float(held("left")),0,float(held("down"))-float(held("up")))
		var selected=players[controlled]
		var kind:="cut" if held("cut") else "feint" if held("feint") else ""
		var combo:="%s:%d:%d"%[kind,int(input_dir.x),int(input_dir.z)] if kind!="" and input_dir.length()>.1 else ""
		if combo!="" and combo!=skill_combo:try_skill(controlled,input_dir,kind)
		skill_combo=combo
		if input_dir.length()>.1:selected.support_time=0
		elif selected.support_time>0 and ball_owner<0:
			var lead:Vector3=selected.support_target-selected.position
			if lead.length()>.4:input_dir=lead.normalized()
		var sprint:bool=held("sprint") and selected.stamina>0 and input_dir.length()>.1
		selected.stamina=clampf(selected.stamina+(-25 if sprint else 15)*dt,0,100)
		move_player(controlled,input_dir,6.8 if sprint else 4.9,dt)
		if charging:shot_charge=minf(1,shot_charge+dt/0.75)
		var chasers:Array=[]
		for team in range(2):
			var candidates:Array=[]
			for i in range(team*11+1,team*11+11):
				if i!=controlled and i!=ball_owner:candidates.append(i)
			candidates.sort_custom(func(a,b):return players[a].position.distance_squared_to(ball_position)<players[b].position.distance_squared_to(ball_position))
			var own:bool=ball_owner>=0 and players[ball_owner].team==team
			if not own:
				for j in range(mini(2,candidates.size())):chasers.append(candidates[j])
		for i in range(22):
			if i!=controlled:ai_move(i,dt,chasers)
		# Separate nearby bodies so 22 players cannot stack in one point.
		for i in range(22):
			for j in range(i+1,22):
				var offset:Vector3=players[i].position-players[j].position;var d:=offset.length()
				if d<.65 and d>.01:
					var push:=offset.normalized()*(.65-d)*.5;players[i].position+=push;players[j].position-=push
		step_ball(dt)
		if remaining<=0:finish_match()
	for i in range(players.size()):players[i].animate(dt,i==controlled)
	if ball_node:
		ball_node.position=ball_position;ball_roll.rotate_z(-ball_velocity.x*dt/BALL_RADIUS);ball_roll.rotate_x(ball_velocity.z*dt/BALL_RADIUS)
		ball_shadow.position=Vector3(ball_position.x,.055,ball_position.z);ball_shadow.scale.x=1/(1+ball_position.y*.2)
	update_hud()

func update_camera(dt: float) -> void:
	var desired:Vector3=ball_position
	desired.y=.7
	if ball_owner>=0:desired=players[ball_owner].position+Vector3(0,.7,0)
	desired.x=clampf(desired.x,-39,39);desired.z=clampf(desired.z,-24,24)
	camera_target=camera_target.lerp(desired,1-exp(-dt*3))
	var aspect:=get_viewport().get_visible_rect().size.aspect()
	var portrait:=maxf(1,1.5/aspect)
	var target:Vector3=camera_target+Vector3(-2,26,34)*portrait
	var aim:Vector3=camera_target
	var fov:=36.0
	if camera_mode==1:
		target=Vector3(0,76,98)*portrait;aim=Vector3(0,0,0);fov=42
	elif camera_mode==2:
		target=camera_target+Vector3(-3,15,23)*portrait;fov=38
	if state in ["menu","finished"]:
		target=Vector3(28,20,38)*portrait;aim=Vector3(12,1,0);fov=48
	camera.position=camera.position.lerp(target,1-exp(-dt*3.5))
	camera.fov=lerpf(camera.fov,fov,minf(1,dt*4))
	camera.look_at(aim)

func skin(color: Color, border: Color = Color("263b53")) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(4);return s
func text(parent:Control, value:String, size:int, color:Color=Color("f1f5fb")) -> Label:
	var label:=Label.new();label.text=value;label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",size);label.add_theme_constant_override("outline_size",1);label.add_theme_color_override("font_outline_color",color);label.add_theme_color_override("font_color",color);label.add_theme_color_override("font_shadow_color",Color("0d1725"));label.add_theme_constant_override("shadow_offset_y",2);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label
func button(parent:Control,value:String) -> Button:
	var b:=Button.new();b.text=value;b.focus_mode=Control.FOCUS_NONE;b.add_theme_font_override("font",FONT);b.add_theme_font_size_override("font_size",15);b.add_theme_stylebox_override("normal",skin(Color("162b40")));b.add_theme_stylebox_override("hover",skin(Color("274663")));b.add_theme_stylebox_override("pressed",skin(Color("3b6079")));parent.add_child(b);return b
func build_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer);ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	var scoreboard:=Panel.new();scoreboard.name="Scoreboard";scoreboard.mouse_filter=Control.MOUSE_FILTER_IGNORE;scoreboard.add_theme_stylebox_override("panel",skin(Color(.025,.055,.09,.97)));ui.add_child(scoreboard)
	var accent:=ColorRect.new();accent.color=Color("c6f365");accent.position=Vector2(0,0);accent.size=Vector2(5,57);scoreboard.add_child(accent)
	score_label=text(scoreboard,"FOR    0 : 0    COR",22);score_label.position=Vector2(19,11);score_label.size=Vector2(263,35);score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	time_label=text(scoreboard,"03:00",20,Color("d9edb7"));time_label.position=Vector2(294,13);time_label.size=Vector2(85,30);time_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var live:=text(ui,"LIVE  /  CLUB MATCH  /  11 v 11",10,Color("d4dce8"));live.name="Live"
	banner=text(ui,"",48,Color("e8ffb2"));banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var info:=Panel.new();info.name="Info";info.mouse_filter=Control.MOUSE_FILTER_IGNORE;info.add_theme_stylebox_override("panel",skin(Color(.025,.055,.09,.94)));ui.add_child(info)
	var team_stripe:=ColorRect.new();team_stripe.color=Color("2b97ed");team_stripe.size=Vector2(5,86);info.add_child(team_stripe)
	status_label=text(info,"09  /  FOREST FC",17);status_label.position=Vector2(18,9)
	var stamina_text:=text(info,"STAMINA",9,Color("94abc6"));stamina_text.position=Vector2(18,42)
	stamina_bar=ProgressBar.new();stamina_bar.show_percentage=false;stamina_bar.position=Vector2(82,46);stamina_bar.size=Vector2(170,7);stamina_bar.add_theme_stylebox_override("background",skin(Color("192c40")));stamina_bar.add_theme_stylebox_override("fill",skin(Color("c6f365")));info.add_child(stamina_bar)
	charge_bar=ProgressBar.new();charge_bar.show_percentage=false;charge_bar.position=Vector2(18,66);charge_bar.size=Vector2(234,6);charge_bar.add_theme_stylebox_override("fill",skin(Color("f2d883")));info.add_child(charge_bar);charge_bar.hide()
	var opponent:=Panel.new();opponent.name="Opponent";opponent.mouse_filter=Control.MOUSE_FILTER_IGNORE;opponent.add_theme_stylebox_override("panel",skin(Color(.025,.055,.09,.94)));ui.add_child(opponent)
	var red_stripe:=ColorRect.new();red_stripe.color=Color("ee6761");red_stripe.size=Vector2(5,62);opponent.add_child(red_stripe)
	var opposition_label:=text(opponent,"CORAL UNITED   /   4-3-3",14);opposition_label.position=Vector2(18,10)
	var opposition_hint:=text(opponent,"AWAY  /  CPU",10,Color("94abc6"));opposition_hint.position=Vector2(18,36)
	radar=Radar.new();radar.game=self;radar.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(radar)
	var help:=text(ui,"방향키 이동 · S 패스 · D 슛 · A 롱패스 · E 쓰루패스\nW 달리기 · Q/Shift 개인기 · Tab 전환 · L 태클",10,Color("d0dbe9"));help.name="Help"
	pause_button=button(ui,"일시정지  ESC");pause_button.pressed.connect(toggle_pause)
	var view_button:=button(ui,"중계 카메라  C");view_button.name="ViewButton";view_button.pressed.connect(func():camera_mode=(camera_mode+1)%3)
	menu=Panel.new();menu.add_theme_stylebox_override("panel",skin(Color(.025,.055,.09,.97),Color("385369")));ui.add_child(menu)
	var eyebrow:=text(menu,"M A T C H D A Y  /  1 1  V  1 1",11,Color("c6f365"));eyebrow.position=Vector2(26,24)
	var title:=text(menu,"CLUB\nFOOTBALL",46);title.position=Vector2(22,56);title.add_theme_constant_override("line_spacing",-9)
	menu_description=text(menu,"11대11 · 3D 경기장 · 중계 카메라\n패스로 공간을 만들고 골문을 노려라.\n방향키 이동 / S·D·A·E 공격 / W 질주",13,Color("b5c6db"));menu_description.position=Vector2(26,198)
	var diff_label:=text(menu,"CPU 난이도",11);diff_label.position=Vector2(26,294)
	difficulty_select=OptionButton.new();difficulty_select.add_item("연습");difficulty_select.add_item("보통");difficulty_select.add_item("도전");difficulty_select.selected=1;difficulty_select.position=Vector2(26,322);difficulty_select.size=Vector2(300,42);difficulty_select.add_theme_font_override("font",FONT);difficulty_select.get_popup().add_theme_font_override("font",FONT);menu.add_child(difficulty_select)
	start_button=button(menu,"KICK OFF    ↗");start_button.position=Vector2(26,386);start_button.size=Vector2(300,54);start_button.add_theme_stylebox_override("normal",skin(Color("c6f365")));start_button.add_theme_color_override("font_color",Color("172331"));start_button.pressed.connect(start_match)
	var hint:=text(menu,"C 중계 / 전체 구장 / 가까운 시점 전환",10,Color("91a7c1"));hint.position=Vector2(26,460)
	touch_root=Control.new();touch_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(touch_root);touch_root.hide()
	for action in ["up","left","down","right","pass","shoot","long","through","tackle","switch","sprint","feint","cut"]:
		var names={"up":"↑","left":"←","down":"↓","right":"→","pass":"패스","shoot":"슛","tackle":"태클","switch":"전환","sprint":"질주","long":"롱패스","through":"쓰루","feint":"페인트","cut":"방향전환"}
		var b:=button(touch_root,names[action]);b.size=Vector2(56,48);action_buttons[action]=b
		b.button_down.connect(func():touch_actions[action]=true;act(action))
		b.button_up.connect(func():touch_actions.erase(action);release_shot() if action=="shoot" else null)
	var touch_button:=button(ui,"터치 조작");touch_button.name="TouchButton";touch_button.pressed.connect(func():touch_root.visible=not touch_root.visible;clear_touches())
func layout_ui() -> void:
	if not ui:return
	var size:=get_viewport().get_visible_rect().size
	ui.get_node("Scoreboard").position=Vector2(24,20);ui.get_node("Scoreboard").size=Vector2(395,57)
	ui.get_node("Live").position=Vector2(27,82)
	ui.get_node("Info").position=Vector2(24,size.y-146);ui.get_node("Info").size=Vector2(276,86)
	ui.get_node("Opponent").position=Vector2(size.x-300,size.y-122);ui.get_node("Opponent").size=Vector2(276,62)
	radar.position=Vector2(size.x/2-103,size.y-148);radar.size=Vector2(206,133)
	ui.get_node("Help").position=Vector2(26,size.y-49)
	pause_button.position=Vector2(size.x-165,20);pause_button.size=Vector2(140,30)
	ui.get_node("ViewButton").position=Vector2(size.x-345,20);ui.get_node("ViewButton").size=Vector2(170,30)
	ui.get_node("TouchButton").position=Vector2(size.x-135,58);ui.get_node("TouchButton").size=Vector2(110,28)
	banner.position=Vector2(0,size.y*.37);banner.size=Vector2(size.x,80)
	menu.size=Vector2(354,500);var ratio:=minf(1,(size.y-130)/500);menu.scale=Vector2.ONE*ratio;menu.position=Vector2(26,(size.y-500*ratio)/2+10)
	touch_root.position=Vector2(22,size.y-235)
	var positions={"up":Vector2(60,0),"left":Vector2(0,54),"down":Vector2(60,54),"right":Vector2(120,54),"pass":Vector2(size.x-222,54),"shoot":Vector2(size.x-160,54),"tackle":Vector2(size.x-98,54),"switch":Vector2(size.x-222,0),"sprint":Vector2(size.x-160,0),"long":Vector2(size.x-222,-54),"through":Vector2(size.x-160,-54),"feint":Vector2(size.x-98,0),"cut":Vector2(size.x-98,-54)}
	for action in action_buttons:action_buttons[action].position=positions[action]
func update_hud() -> void:
	if not score_label:return
	score_label.text="FOR    %d : %d    COR"%[score[0],score[1]]
	time_label.text="%02d:%02d"%[int(ceil(remaining))/60,int(ceil(remaining))%60]
	if players.size()>controlled:
		ui.get_node("ViewButton").text=["중계 카메라  C","전체 구장  C","가까운 시점  C"][camera_mode]
		status_label.text="%02d  /  %s"%[players[controlled].shirt_number,"드리블" if ball_owner==controlled else "공을 향해 이동"]
		stamina_bar.value=players[controlled].stamina;charge_bar.visible=charging;charge_bar.value=shot_charge*100
