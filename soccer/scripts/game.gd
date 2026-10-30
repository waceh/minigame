extends Node3D
const Player = preload("res://scripts/footballer.gd")
const Pitch = preload("res://scripts/pitch.gd")
const V = preload("res://scripts/visuals.gd")
const FONT = preload("res://font.ttf")
const HALF_X := 23.0
const HALF_Z := 14.0
const GOAL_WIDTH := 3.0
const FORMATION = [Vector2(-21,0),Vector2(-14,-10),Vector2(-15,-3.5),Vector2(-15,3.5),Vector2(-14,10),Vector2(-6,-8),Vector2(-7,0),Vector2(-6,8),Vector2(3,-9),Vector2(2,0),Vector2(3,9)]
var players: Array = []
var controlled := 9
var ball_owner := -1
var last_touch := 0
var possession_lock := 0.0
var ball_position := Vector3(0,.3,0)
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
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=36;camera.position=Vector3(0,32,36);camera.current=true;add_child(camera);camera.look_at(Vector3(0,1.2,0))
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
	V.sphere(ball_roll,.29,Vector3.ZERO,V.material(Color("f5f0d5"),0,.7))
	var black:=V.material(Color("202b32"),0,.85)
	for i in range(12):
		var y:float=1-2*(i+.5)/12;var r:=sqrt(1-y*y);var angle:=i*2.39996
		V.sphere(ball_roll,.09,Vector3(cos(angle)*r,y,sin(angle)*r)*.245,black)
	var mat:=V.material(Color(.01,.03,.02,.4));mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_shadow=V.cylinder(self,.34,.34,.003,Vector3.ZERO,mat,24);ball_shadow.scale.z=.65
func start_match() -> void:
	difficulty=difficulty_select.selected;score=[0,0];remaining=180;menu.hide();kickoff(0)
func kickoff(team: int) -> void:
	kickoff_team=team;ball_owner=-1;pickup_ignore=-1;possession_lock=0;ball_position=Vector3(0,.3,0);ball_velocity=Vector3.ZERO;charging=false;shot_charge=0
	for i in range(22):
		var p=players[i];p.position=p.home;p.velocity=Vector3.ZERO;p.cooldown=0;p.stun=0;p.possession_time=0;p.stamina=100;p.skill_time=0;p.skill_cooldown=0;p.support_time=0
		# Both teams start in their own half; attackers spread after the whistle.
		p.position.x=clampf(p.position.x,-21,-1.5) if p.team==0 else clampf(p.position.x,1.5,21)
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
	if state in ["play","kickoff","goal"]:toggle_pause()
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
	p.velocity=direction.limit_length(1)*speed
	if direction.length()>.1:p.heading=direction.normalized()
	p.position+=p.velocity*dt;p.position.x=clampf(p.position.x,-22.5,22.5);p.position.z=clampf(p.position.z,-13.5,13.5)
func ai_move(i: int, dt: float, chasers: Array) -> void:
	var p=players[i];var attack_dir:=1.0 if p.team==0 else -1.0
	var target:Vector3=p.home;var speed:=4.5
	if ball_owner==i:
		p.possession_time+=dt
		if p.goalkeeper:
			if p.possession_time>.5:pass_ball(i)
			return
		target=Vector3(attack_dir*22,0,clampf(p.position.z*.7,-3,3))
		var to_goal:float=absf(attack_dir*23-p.position.x)
		if to_goal<13 and absf(p.position.z)<8 and p.possession_time>.45:
			shoot(i,.45+randf()*.4);return
		if p.possession_time>1.0 and (nearest_opponent_distance(i)<2.6 or p.possession_time>3):
			pass_ball(i);return
		speed=4.3 if difficulty==0 else 4.8
	elif p.goalkeeper:
		target=Vector3(-attack_dir*21.6,0,clampf(ball_position.z*.7,-2.8,2.8))
		if ball_position.x*attack_dir < -17 and absf(ball_position.z)<6:target=Vector3(clampf(ball_position.x,-22,22),0,clampf(ball_position.z,-3,3))
		speed=4.0 if difficulty==0 else 5.6
	elif p.support_time>0 and (ball_owner<0 or players[ball_owner].team==p.team):
		target=p.support_target;speed=5.5
	elif chasers.has(i):
		target=ball_position;target.y=0
		if ball_owner>=0 and players[ball_owner].team!=p.team and p.position.distance_to(players[ball_owner].position)<1.45 and p.cooldown==0:
			if randf()<dt*(1.0 if difficulty==0 else 2.5):tackle(i)
	else:
		var own_possession:bool=ball_owner>=0 and players[ball_owner].team==p.team
		target.x+=clampf(ball_position.x*.45,-8,13) if p.team==0 else clampf(ball_position.x*.45,-13,8)
		if own_possession:target.x+=attack_dir*3
		target.x=clampf(target.x,-20,20);target.z=clampf(p.home.z+ball_position.z*.18,-12,12)
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
		var max_distance:=38.0 if kind=="long" else 28.0 if kind=="through" else 18.0
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
		target.x=clampf(target.x,-21.5,21.5);target.z=clampf(target.z,-12.5,12.5)
	var offset:Vector3=target-p.position;offset.y=0
	if kind=="long":
		var flight_time:=clampf(offset.length()/13.0,1.1,2.1)
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
	var direction:Vector3=(Vector3(sign_dir*24,0,aim_z)-p.position).normalized()
	release_ball(i,direction*(18+charge*10),2.0+charge*3.6)
func release_ball(i: int, velocity: Vector3, lift: float) -> void:
	var p=players[i]
	if Vector2(velocity.x,velocity.z).length()>.1:p.heading=Vector3(velocity.x,0,velocity.z).normalized()
	ball_position=p.position+p.heading*.75+Vector3(0,.32,0);ball_velocity=velocity;ball_velocity.y=lift
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
		var p=players[ball_owner];ball_position=p.position+p.heading*.62+Vector3(0,.3+absf(sin(elapsed*12))*.04,0);ball_velocity=Vector3.ZERO
		return
	ball_position+=ball_velocity*dt;ball_velocity.y-=10*dt
	if ball_position.y<.29:
		ball_position.y=.29
		ball_velocity.y=absf(ball_velocity.y)*.35 if absf(ball_velocity.y)>1.2 else 0
		ball_velocity.x=move_toward(ball_velocity.x,0,dt*2.2);ball_velocity.z=move_toward(ball_velocity.z,0,dt*2.2)
	if absf(ball_position.x)>HALF_X:
		if absf(ball_position.z)<GOAL_WIDTH and ball_position.y<2.3:
			goal(0 if ball_position.x>0 else 1);return
		ball_position.x=signf(ball_position.x)*HALF_X;ball_velocity.x*=-.65
	if absf(ball_position.z)>HALF_Z:
		ball_position.z=signf(ball_position.z)*HALF_Z;ball_velocity.z*=-.65
	for i in range(22):
		var p=players[i]
		if p.stun>0 or (possession_lock>0 and pickup_ignore==i):continue
		if possession_lock>0 and last_touch!=p.team:continue
		var height:=1.7 if p.goalkeeper else .85
		if ball_position.y<height and Vector2(p.position.x,p.position.z).distance_to(Vector2(ball_position.x,ball_position.z))<(.85 if p.goalkeeper else .7):
			ball_owner=i;p.possession_time=0;ball_velocity=Vector3.ZERO;last_touch=p.team
			if p.team==0 and not p.goalkeeper:controlled=i
			break
func goal(team: int) -> void:
	score[team]+=1;state="goal";phase_time=2.6;ball_owner=-1;ball_velocity=Vector3.ZERO;kickoff_team=1-team;clear_touches();banner.text="GOAL!  /  "+("FOREST FC" if team==0 else "CORAL UNITED");play_sound(true)
func finish_match() -> void:
	state="finished";clear_touches();touch_root.hide();menu.show();banner.text="FULL TIME"
	menu_description.text="경기 종료  /  %d : %d\n%s\n패스로 공간을 만들고 슛을 노려 보세요."%[score[0],score[1],"FOREST FC 승리!" if score[0]>score[1] else "무승부" if score[0]==score[1] else "CORAL UNITED 승리"]
	start_button.text="다시 경기  ↗"
func _physics_process(dt: float) -> void:
	if state=="paused":return
	elapsed+=dt
	if camera:
		var aspect:=get_viewport().get_visible_rect().size.aspect();camera.size=maxf(36,60/aspect)
	if state in ["kickoff","goal"]:
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
		ball_node.position=ball_position;ball_roll.rotate_z(-ball_velocity.x*dt*2);ball_roll.rotate_x(ball_velocity.z*dt*2)
		ball_shadow.position=Vector3(ball_position.x,.055,ball_position.z);ball_shadow.scale.x=1/(1+ball_position.y*.2)
	update_hud()

func skin(color: Color, border: Color = Color("67866b")) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(12);return s
func text(parent:Control, value:String, size:int, color:Color=Color("f6efda")) -> Label:
	var label:=Label.new();label.text=value;label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",size);label.add_theme_constant_override("outline_size",1);label.add_theme_color_override("font_outline_color",color);label.add_theme_color_override("font_color",color);label.add_theme_color_override("font_shadow_color",Color("182d27"));label.add_theme_constant_override("shadow_offset_y",2);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label
func button(parent:Control,value:String) -> Button:
	var b:=Button.new();b.text=value;b.focus_mode=Control.FOCUS_NONE;b.add_theme_font_override("font",FONT);b.add_theme_font_size_override("font_size",15);b.add_theme_stylebox_override("normal",skin(Color("29443a")));b.add_theme_stylebox_override("hover",skin(Color("456b4b")));b.add_theme_stylebox_override("pressed",skin(Color("5f8155")));parent.add_child(b);return b
func build_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer);ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	var scoreboard:=Panel.new();scoreboard.name="Scoreboard";scoreboard.mouse_filter=Control.MOUSE_FILTER_IGNORE;scoreboard.add_theme_stylebox_override("panel",skin(Color(.055,.10,.10,.96)));ui.add_child(scoreboard)
	score_label=text(scoreboard,"FOREST FC    0 : 0    CORAL UNITED",23);score_label.position=Vector2(22,10);score_label.size=Vector2(566,38);score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	time_label=text(scoreboard,"03:00  /  11 vs 11",13,Color("e5d59b"));time_label.position=Vector2(16,48);time_label.size=Vector2(578,23);time_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	banner=text(ui,"",44,Color("ffe49c"));banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var info:=Panel.new();info.name="Info";info.mouse_filter=Control.MOUSE_FILTER_IGNORE;info.add_theme_stylebox_override("panel",skin(Color(.055,.10,.10,.93)));ui.add_child(info)
	status_label=text(info,"09 / FOREST FC",17);status_label.position=Vector2(18,10)
	var stamina_text:=text(info,"SPRINT",10,Color("b8cdb2"));stamina_text.position=Vector2(18,44)
	stamina_bar=ProgressBar.new();stamina_bar.show_percentage=false;stamina_bar.position=Vector2(76,49);stamina_bar.size=Vector2(170,9);stamina_bar.add_theme_stylebox_override("background",skin(Color("22332c")));stamina_bar.add_theme_stylebox_override("fill",skin(Color("99d897")));info.add_child(stamina_bar)
	charge_bar=ProgressBar.new();charge_bar.show_percentage=false;charge_bar.position=Vector2(18,69);charge_bar.size=Vector2(228,8);charge_bar.add_theme_stylebox_override("fill",skin(Color("f3cb7b")));info.add_child(charge_bar);charge_bar.hide()
	var help:=text(ui,"방향키 이동  S 짧은 패스  D 눌렀다 떼면 슛  A 롱패스  E 쓰루패스  W 달리기\nQ+방향키 페인트  Shift+방향키 방향 전환  Tab 선수 전환  L 태클",12);help.name="Help"
	pause_button=button(ui,"일시정지  ESC");pause_button.pressed.connect(toggle_pause)
	menu=Panel.new();menu.add_theme_stylebox_override("panel",skin(Color(.055,.10,.10,.97),Color("9ba978")));ui.add_child(menu)
	var eyebrow:=text(menu,"W O O D L A N D  /  1 1  V  1 1",11,Color("f1d594"));eyebrow.position=Vector2(26,24)
	var title:=text(menu,"FOREST\nFOOTBALL",46);title.position=Vector2(22,56);title.add_theme_constant_override("line_spacing",-9)
	menu_description=text(menu,"도트 선수, 입체 구장, 11대11 한 판.\n패스를 연결하고 골문을 노려라!\n3분 경기 · 나머지 선수는 자동 플레이",14,Color("c3d4be"));menu_description.position=Vector2(26,198)
	var diff_label:=text(menu,"CPU 난이도",11);diff_label.position=Vector2(26,294)
	difficulty_select=OptionButton.new();difficulty_select.add_item("연습");difficulty_select.add_item("보통");difficulty_select.add_item("도전");difficulty_select.selected=1;difficulty_select.position=Vector2(26,322);difficulty_select.size=Vector2(300,42);difficulty_select.add_theme_font_override("font",FONT);difficulty_select.get_popup().add_theme_font_override("font",FONT);menu.add_child(difficulty_select)
	start_button=button(menu,"경기 시작   ↗");start_button.position=Vector2(26,386);start_button.size=Vector2(300,54);start_button.add_theme_stylebox_override("normal",skin(Color("f2d892")));start_button.add_theme_color_override("font_color",Color("233d31"));start_button.pressed.connect(start_match)
	var hint:=text(menu,"골라인·터치라인은 공이 튕기는 아케이드 규칙",10,Color("a5bda3"));hint.position=Vector2(26,460)
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
	ui.get_node("Scoreboard").position=Vector2((size.x-610)/2,16);ui.get_node("Scoreboard").size=Vector2(610,82)
	ui.get_node("Info").position=Vector2(26,size.y-140);ui.get_node("Info").size=Vector2(266,92)
	ui.get_node("Help").position=Vector2(26,size.y-45)
	pause_button.position=Vector2(size.x-166,size.y-45);pause_button.size=Vector2(140,30)
	ui.get_node("TouchButton").position=Vector2(size.x-276,size.y-45);ui.get_node("TouchButton").size=Vector2(100,30)
	banner.position=Vector2(0,size.y*.4);banner.size=Vector2(size.x,70)
	menu.size=Vector2(354,500);var ratio:=minf(1,(size.y-130)/500);menu.scale=Vector2.ONE*ratio;menu.position=Vector2(26,(size.y-500*ratio)/2+10)
	touch_root.position=Vector2(22,size.y-235)
	var positions={"up":Vector2(60,0),"left":Vector2(0,54),"down":Vector2(60,54),"right":Vector2(120,54),"pass":Vector2(size.x-222,54),"shoot":Vector2(size.x-160,54),"tackle":Vector2(size.x-98,54),"switch":Vector2(size.x-222,0),"sprint":Vector2(size.x-160,0),"long":Vector2(size.x-222,-54),"through":Vector2(size.x-160,-54),"feint":Vector2(size.x-98,0),"cut":Vector2(size.x-98,-54)}
	for action in action_buttons:action_buttons[action].position=positions[action]
func update_hud() -> void:
	if not score_label:return
	score_label.text="FOREST FC    %d : %d    CORAL UNITED"%[score[0],score[1]]
	time_label.text="%02d:%02d  /  11 vs 11"%[int(ceil(remaining))/60,int(ceil(remaining))%60]
	if players.size()>controlled:
		status_label.text="%02d / %s"%[players[controlled].shirt_number,"드리블" if ball_owner==controlled else "공을 향해 이동"]
		stamina_bar.value=players[controlled].stamina;charge_bar.visible=charging;charge_bar.value=shot_charge*100
