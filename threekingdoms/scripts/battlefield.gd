extends SubViewportContainer
const V=preload("res://scripts/visuals.gd")
const R=preload("res://scripts/roster.gd")
const ART=preload("res://assets/commanders.png")
const SUPPORT=preload("res://assets/commanders-support.png")
const LEGENDS=preload("res://assets/commanders-legends.png")
const Frames=preload("res://scripts/frames.gd")
const OAK=preload("res://assets/oak.png")
const BASE_SHU=preload("res://assets/base-shu.png")
const BASE_WEI=preload("res://assets/base-wei.png")
const BASE_WU=preload("res://assets/base-wu.png")
const RECRUIT_SHU=preload("res://assets/recruits-shu.png")
const RECRUIT_WEI=preload("res://assets/recruits-wei.png")
const RECRUIT_WU=preload("res://assets/recruits-wu.png")
var game
var viewport:SubViewport
var world:Node3D
var camera:Camera3D
var actors:Dictionary={}
var foes:Dictionary={}
var particles:Array=[]
var marker:MeshInstance3D
var marker_time:=0.0
var clock:=0.0
var zoom:=24.0
var focus:=Vector3.ZERO
var atlas_cache:Dictionary={}
var ribbon_material:StandardMaterial3D
var attack_clock:=0.0
func _ready() -> void:
	position=Vector2(0,36);size=Vector2(1280,560);mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new();viewport.size=Vector2i(1280,560);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.handle_input_locally=false
	viewport.msaa_3d=Viewport.MSAA_2X;add_child(viewport)
	world=Node3D.new();viewport.add_child(world)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=zoom;camera.near=.1;camera.far=180;camera.current=true;world.add_child(camera)
	set_camera();build_terrain()
	var mark_mat:=V.material(Color("91f4a6"),0,1,.5);mark_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker=V.ring(world,.6,.07,Vector3(0,.08,0),mark_mat);marker.visible=false
func set_camera() -> void:
	camera.position=focus+Vector3(0,42,28);camera.size=zoom;camera.look_at(focus)
func to_world(point:Vector2, height:float=0) -> Vector3:
	return Vector3((point.x-472)/20.0,height,(point.y-455)/20.0)
func to_map(point:Vector3) -> Vector2:
	return Vector2(point.x*20+472,point.z*20+455)
func ground_point(screen:Vector2) -> Vector2:
	var local:=screen-position
	var origin:=camera.project_ray_origin(local);var direction:=camera.project_ray_normal(local)
	var intersection=Plane(Vector3.UP,0).intersects_ray(origin,direction)
	if intersection==null:return Vector2(-1000,-1000)
	return to_map(intersection)
func screen_pos(point:Vector2, height:float=0) -> Vector2:
	return camera.unproject_position(to_world(point,height))+position
func move_marker(point:Vector2) -> void:
	marker.position=to_world(point,.09);marker_time=.9;marker.show()
func grass_material() -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
varying vec3 w;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){w=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float fine=hash(floor(w.xz*32.));
 float patch=noise(w.xz*.35)*.6+noise(w.xz*1.2)*.4;
 // 화사하고 싱그러운 파스텔 잔디
 vec3 grass1=vec3(.42,.78,.32);
 vec3 grass2=vec3(.55,.86,.40);
 vec3 grass=mix(grass1,grass2,patch);
 grass+=(fine-.5)*vec3(.03,.03,.015);
 // 아기자기한 파스텔 들꽃 도트 (노란꽃, 분홍꽃, 흰꽃)
 float flower_seed=hash(floor(w.xz*12.));
 if(flower_seed>.93){
  float fl=hash(floor(w.xz*12.)+vec2(3.1,7.4));
  vec3 fcol=fl>.65?vec3(1.,.88,.32):fl>.32?vec3(1.,.62,.76):vec3(.98,.98,.95);
  grass=mix(grass,fcol,.88);
 }
 float edge=min(abs(abs(w.x)-18.9),abs(abs(w.z)-11.45));
 float road=(1.-smoothstep(.64,.92+noise(w.xz*4.)*.2,edge))*step(abs(w.x),19.85)*step(abs(w.z),12.4);
 // 따뜻하고 달콤한 쿠키 모래길
 vec3 dirt1=vec3(.93,.84,.65);
 vec3 dirt2=vec3(.86,.75,.54);
 vec3 dirt=mix(dirt1,dirt2,noise(w.xz*2.2));dirt+=(fine-.5)*.025;
 ALBEDO=mix(grass,dirt,road);ROUGHNESS=.8;
}
"""
	var m:=ShaderMaterial.new();m.shader=shader;return m
func prop(frame:int, pos:Vector3, height:float, flip:bool=false) -> void:
	if frame>=4:
		var rock:=V.sphere(world,height*.32,pos+Vector3(0,height*.16,0),V.material(Color("dedbd2"),0,.9));rock.scale=Vector3(1,.6,.85);return
	var sprite:=Sprite3D.new();sprite.texture=OAK
	sprite.pixel_size=height/(OAK.get_height()*.76);sprite.offset=Vector2(0,OAK.get_height()*.39)
	sprite.position=pos;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.4;sprite.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE;sprite.alpha_antialiasing_edge=.65;sprite.shaded=false;sprite.flip_h=flip
	sprite.modulate=Color(1.05,1.05,.98) if frame%2 else Color.WHITE;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(sprite)
func creek() -> void:
	var curve:=Curve3D.new()
	for i in range(7):
		var p:=Vector3(8.2+sin(i*.85)*1.4,.035,-10+i*3.2)
		curve.add_point(p,Vector3(0,0,-1.1),Vector3(0,0,1.1))
	var points:=curve.get_baked_points()
	for bank in [true,false]:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var width:=1.0 if bank else .72
		for i in range(points.size()-1):
			var tangent:Vector3=(points[i+1]-points[maxi(0,i-1)]).normalized();var normal:=Vector3(-tangent.z,0,tangent.x)*width
			var next_tangent:Vector3=(points[mini(points.size()-1,i+2)]-points[i]).normalized();var next_normal:=Vector3(-next_tangent.z,0,next_tangent.x)*width
			var a:Vector3=points[i]-normal;var b:Vector3=points[i]+normal;var c:Vector3=points[i+1]-next_normal;var d:Vector3=points[i+1]+next_normal
			var lift:=Vector3(0,.025 if not bank else 0,0)
			for v in [a,c,b,b,c,d]:st.add_vertex(v+lift)
		st.generate_normals()
		var mat:=V.material(Color("d8cfbc") if bank else Color("48cae4"),.02,.3,.35 if not bank else 0.0)
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED;V.mesh(world,st.commit(),Vector3.ZERO,mat)
func build_terrain() -> void:
	var stone:=V.material(Color("e8e5dc"),0,.9);var dark:=V.material(Color("6a4c38"),0,.95)
	var roof:=V.material(Color("e76f51"),0,.85);var wood:=V.material(Color("b07d62"),0,.9)
	V.box(world,Vector3(120,2.8,120),Vector3(0,-1.5,0),dark)
	V.box(world,Vector3(120,.14,120),Vector3(0,-.07,0),grass_material())
	# Mossy stone terrace layers, wooden watchtowers and Chinese tiled gate.
	for side in [-1,1]:
		V.box(world,Vector3(4,1.2,35),Vector3(side*23,-.1,0),stone)
		for z in range(-17,18,6):prop(0 if z%3 else 1,Vector3(side*(23.7+sin(z)*.8),.5,z),5.5+absf(sin(z))*1.3,z%2==0)
	for i in range(11):
		var x:float=-27+i*5.3
		prop(i%3,Vector3(x,.05,-18.5-sin(i)*.8),5.8+sin(i)*.6,i%2==0)
	for side in [-1,1]:
		for x in range(-20,21,5):
			if side>0 and abs(x)<12:continue
			prop(4 if x%2 else 5,Vector3(x,.02,side*14),1.3+absf(x)*.025,x%2==0)
	# A creek and small bridge on the inner meadow.
	creek()
	for i in range(8):V.box(world,Vector3(3,.12,.28),Vector3(8.8,.14,-1+i*.3),wood)
	for x in [7.3,10.3]:
		V.box(world,Vector3(.13,.8,3.2),Vector3(x,.5,0),wood)
	# All new heroes materialize at this one camp and gather close around it.
	var camp:=to_world(game.SUMMON_POINT,.065)
	var camp_mat:=V.material(Color("ffbe0b"),0,.3,.5)
	V.ring(world,.9,.04,camp,camp_mat);V.ring(world,1.1,.03,camp,camp_mat)
	for i in range(8):
		var angle:float=i*TAU/8
		var tile:=V.box(world,Vector3(.18,.025,.07),camp+Vector3(cos(angle),0,sin(angle))*.99,camp_mat);tile.rotation.y=-angle
	var sign:=Label3D.new();sign.text="소환진";sign.font=game.FONT;sign.font_size=36;sign.pixel_size=.014;sign.position=camp+Vector3(0,.15,1.25);sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.modulate=Color("fff3b0");sign.outline_size=6;sign.outline_modulate=Color("7f5539");world.add_child(sign)
	# Gate at the route start; open center remains passable.
	var gate:=to_world(Vector2(94,226))
	for x in [-1.8,1.8]:
		V.box(world,Vector3(1.4,3.5,1.4),gate+Vector3(x,1.75,0),stone)
		V.box(world,Vector3(2.2,.3,2.2),gate+Vector3(x,3.6,0),roof)
		V.box(world,Vector3(1.8,.4,1.8),gate+Vector3(x,3.9,0),roof)
	V.box(world,Vector3(5.9,.6,1.7),gate+Vector3(0,3.4,0),wood)
	V.box(world,Vector3(6.6,.25,2.5),gate+Vector3(0,3.9,0),roof)
	V.box(world,Vector3(5.7,.35,1.8),gate+Vector3(0,4.2,0),roof)
	for p in [Vector3(-21,0,10),Vector3(21,0,-10),Vector3(-21,0,-10),Vector3(21,0,10)]:
		for x in [-.7,.7]:
			for z in [-.7,.7]:V.box(world,Vector3(.14,3.2,.14),p+Vector3(x,1.6,z),wood)
		V.box(world,Vector3(2.1,.18,2.1),p+Vector3(0,2.5,0),wood)
		V.box(world,Vector3(2.7,.2,2.7),p+Vector3(0,3.3,0),roof)
		V.box(world,Vector3(2,.3,2),p+Vector3(0,3.5,0),roof)
	# Banner standards and roadside stone lanterns.
	for team in range(3):
		var p:=Vector3(-8+team*8,0,-4)
		V.cylinder(world,.06,.08,3.4,p+Vector3(0,1.7,0),wood)
		V.box(world,Vector3(1.2,1.8,.04),p+Vector3(.62,2.35,0),V.material(R.COLORS[team]))
	for x in [-17.0,17.0]:
		for z in [-9.5,9.5]:
			V.box(world,Vector3(.6,.25,.6),Vector3(x,.15,z),stone)
			V.box(world,Vector3(.24,.8,.24),Vector3(x,.6,z),stone)
			V.box(world,Vector3(.55,.5,.55),Vector3(x,1.15,z),V.material(Color("ffdd80"),0,1,.4))
			V.box(world,Vector3(.8,.15,.8),Vector3(x,1.48,z),roof)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("bde0fe")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("fff6ea");env.ambient_light_energy=.9
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.fog_enabled=false;env.fog_light_color=Color("bde0fe");env.fog_density=.001
	environment.environment=env;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);sun.light_color=Color("fff8ee");sun.light_energy=1.15;sun.shadow_enabled=true;sun.directional_shadow_max_distance=80;world.add_child(sun)
func art_for(id:int) -> Array:
	if id>=24:
		var faction:int=(id-24)/6;var row:int=(id-24)%6
		return [[BASE_SHU,BASE_WEI,BASE_WU][faction],row,6,["base-shu.png","base-wei.png","base-wu.png"][faction]]
	match id:
		0:return [SUPPORT,0,4,"commanders-support.png"]
		1:return [ART,0,4,"commanders.png"]
		2:return [SUPPORT,1,4,"commanders-support.png"]
		3:return [ART,1,4,"commanders.png"]
		4:return [SUPPORT,2,4,"commanders-support.png"]
		5:return [SUPPORT,3,4,"commanders-support.png"]
		6:return [LEGENDS,0,5,"commanders-legends.png"]
		7:return [LEGENDS,1,5,"commanders-legends.png"]
		8:return [ART,2,4,"commanders.png"]
		9:return [LEGENDS,2,5,"commanders-legends.png"]
		10:return [LEGENDS,3,5,"commanders-legends.png"]
		11:return [LEGENDS,4,5,"commanders-legends.png"]
		15:return [RECRUIT_SHU,0,3,"recruits-shu.png"]
		16:return [RECRUIT_SHU,1,3,"recruits-shu.png"]
		17:return [RECRUIT_SHU,2,3,"recruits-shu.png"]
		18:return [RECRUIT_WEI,0,3,"recruits-wei.png"]
		19:return [RECRUIT_WEI,1,3,"recruits-wei.png"]
		20:return [RECRUIT_WEI,2,3,"recruits-wei.png"]
		21:return [RECRUIT_WU,0,3,"recruits-wu.png"]
		22:return [RECRUIT_WU,1,3,"recruits-wu.png"]
		23:return [RECRUIT_WU,2,3,"recruits-wu.png"]
	return [ART,3,4,"commanders.png"]
func frame_meta(id:int, frame:int) -> Dictionary:
	var art:=art_for(id)
	return Frames.META[art[3]][art[1]][frame]
func frame_texture(id:int, frame:int) -> AtlasTexture:
	var key:="%d:%d"%[id,frame]
	if not atlas_cache.has(key):
		var art:=art_for(id);var meta:=frame_meta(id,frame);var r:Array=meta.rect
		var texture:=AtlasTexture.new();texture.atlas=art[0];texture.region=Rect2(r[0],r[1],r[2],r[3]);texture.filter_clip=true;atlas_cache[key]=texture
	return atlas_cache[key]
func portrait_texture(id:int) -> AtlasTexture:
	var key:="portrait:%d"%id
	if not atlas_cache.has(key):
		var art:=art_for(id);var r:Array=frame_meta(id,0).rect
		var texture:=AtlasTexture.new();texture.atlas=art[0];texture.region=Rect2(r[0]+r[2]*.12,r[1],r[2]*.76,r[3]*.62);texture.filter_clip=true;atlas_cache[key]=texture
	return atlas_cache[key]
func pose_actor(actor:Dictionary, id:int, frame:int, height:float, flip:bool) -> void:
	var meta:=frame_meta(id,frame);var r:Array=meta.rect;var anchor:Array=meta.anchor
	actor.sprite.hframes=1;actor.sprite.vframes=1;actor.sprite.frame=0;actor.sprite.texture=frame_texture(id,frame)
	actor.sprite.pixel_size=height/meta.scale_height;actor.sprite.flip_h=flip
	actor.sprite.offset=Vector2((r[2]*.5-(anchor[0]-r[0]))*(-1 if flip else 1),anchor[1]-r[1]-r[3]*.5)
func make_actor(row:int, enemy:bool=false) -> Dictionary:
	var root:=Node3D.new();world.add_child(root)
	var sprite:=Sprite3D.new();sprite.texture=ART;sprite.hframes=4;sprite.vframes=4;sprite.frame=row*4
	sprite.pixel_size=(2.25 if enemy else 2.95)/(ART.get_height()/4.0);sprite.offset=Vector2(0,ART.get_height()/4.0*.42)
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.3;sprite.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE;sprite.alpha_antialiasing_edge=.6;sprite.shaded=false
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(sprite)
	var mat:=V.material(Color(.05,.08,.05,.32));mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow:=V.cylinder(root,.55,.55,.008,Vector3(0,.03,0),mat,24);shadow.scale.z=.65;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat:=V.material(Color("ffea00"),0,1,.8);ring_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring:=V.ring(root,.68,.045,Vector3(0,.05,0),ring_mat);ring.hide()
	var nameplate:=Label3D.new();nameplate.font=game.FONT;nameplate.font_size=32;nameplate.pixel_size=.015;nameplate.position.y=2.8;nameplate.billboard=BaseMaterial3D.BILLBOARD_ENABLED;nameplate.outline_size=7;nameplate.outline_modulate=Color("10211a");nameplate.no_depth_test=true;root.add_child(nameplate)
	var gradient:=Gradient.new();gradient.set_color(0,Color.WHITE);gradient.set_color(1,Color.WHITE)
	var health_texture:=GradientTexture2D.new();health_texture.gradient=gradient;health_texture.width=64;health_texture.height=6
	var health:=Sprite3D.new();health.texture=health_texture;health.pixel_size=.02;health.billboard=BaseMaterial3D.BILLBOARD_ENABLED;health.modulate=Color("52b788");health.position.y=2.5;health.shaded=false;health.visible=enemy;root.add_child(health)
	var caption:=Label.new();caption.add_theme_font_override("font",game.FONT);caption.add_theme_font_size_override("font_size",16);caption.add_theme_constant_override("outline_size",3);caption.add_theme_color_override("font_outline_color",Color("1b263b"));caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_offset_y",1);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var plate:StyleBoxFlat=game.style(Color("1b263be0"),Color("edd6aa"));plate.set_corner_radius_all(10);plate.content_margin_left=8;plate.content_margin_right=8;plate.content_margin_top=2;plate.content_margin_bottom=2;caption.add_theme_stylebox_override("normal",plate);game.ui.get_node("Nameplates").add_child(caption)
	return {"root":root,"sprite":sprite,"ring":ring,"label":nameplate,"caption":caption,"health":health,"row":row,"last":Vector3.ZERO,"attack":0.0}
func place_caption(actor:Dictionary, text:String, point:Vector2, color:Color, shown:bool) -> void:
	var caption:Label=actor.caption
	var anchor:=screen_pos(point,2.85)
	caption.visible=shown and Rect2(position,size).has_point(anchor) and game.state!="title"
	if not caption.visible:return
	caption.text=text;caption.add_theme_color_override("font_color",color);caption.reset_size()
	caption.position=Vector2(clampf(anchor.x-caption.size.x*.5,position.x+2,position.x+size.x-caption.size.x-2),maxf(position.y+2,anchor.y-caption.size.y))
func _process(dt:float) -> void:
	if not game:return
	var active:bool=game.state in ["build","battle"] and not game.paused and not game.codex_open
	if active:
		clock+=dt;marker_time=maxf(0,marker_time-dt)
		var pan:=Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		if pan.length()>.1:
			focus+=pan*dt*12;focus.x=clampf(focus.x,-10,10);focus.z=clampf(focus.z,-8,8);set_camera()
	marker.visible=marker_time>0;marker.scale=Vector3.ONE*(1+(1-marker_time)*.7)
	for u in game.units:
		var key:int=u.slot
		if not actors.has(key):actors[key]=make_actor(0)
		var a:Dictionary=actors[key];var point:Vector2=u.pos

		var pos:=to_world(point);var delta:Vector3=pos-a.last
		a.root.position=pos

		var moving:bool=delta.length()>.002
		var frame:int=3 if u.pulse>0 else [0,1,0,2][int(clock*8+key)%4] if moving else 0
		pose_actor(a,u.id,frame,2.4 if u.rank==0 else 2.65,u.face<0)
		if u.pulse>0:
			a.sprite.position.y=.22;a.sprite.rotation.z=0.0
		elif moving:
			a.sprite.position.y=absf(sin(clock*14.0+key))*.16
			a.sprite.rotation.z=sin(clock*14.0+key)*.09*(-1.0 if u.face<0 else 1.0)
		else:
			a.sprite.position.y=sin(clock*3.5+key)*.035
			a.sprite.rotation.z=0.0
		a.ring.visible=game.selected_slots.has(key)
		if a.ring.visible:a.ring.rotation.y=clock*3.0
		a.label.hide()
		place_caption(a,R.data(u.id).name+" · "+R.RANKS[u.rank],u.pos,R.RANK_COLORS[u.rank],game.selected_slots.has(key) or u.rank>=2)
		a.last=pos
	for key in actors.keys():
		if game.unit_at(key)<0:actors[key].caption.queue_free();actors[key].root.queue_free();actors.erase(key)
	var live:Dictionary={}
	for e in game.enemies:
		live[e.uid]=true
		if not foes.has(e.uid):foes[e.uid]=make_actor(3,true)
		var a:Dictionary=foes[e.uid];var point:Vector2=game.path_pos(e.distance)
		var pos:=to_world(point);var delta:Vector3=pos-a.last
		a.root.position=pos;a.sprite.flip_h=delta.x<-.001 if absf(delta.x)>.001 else a.sprite.flip_h
		pose_actor(a,-1,[0,1,0,2][int(clock*8+e.uid)%4],2.2,a.sprite.flip_h)
		a.sprite.position.y=absf(sin(clock*12.0+e.uid))*.13
		a.sprite.rotation.z=sin(clock*12.0+e.uid)*.07
		a.root.scale=Vector3.ONE*(1.55 if e.boss else 1.1 if e.elite else .85)
		a.sprite.modulate=Color(1.7,1.5,1.3) if e.flash>0 else Color(.7,.85,1) if e.slow>0 else Color.WHITE
		a.health.scale.x=maxf(.001,e.hp/e.max_hp);a.health.modulate=Color("ffb703") if e.boss else Color("52b788")
		a.label.position.y=3.0;a.label.text="적장" if e.boss else ""
		a.label.hide();place_caption(a,"적장",point,Color("ffe098"),e.boss);a.last=pos
	for key in foes.keys():
		if not live.has(key):foes[key].caption.queue_free();foes[key].root.queue_free();foes.erase(key)
	# Short-lived 3D attack bolts, expanding spell rings and summon pillars.
	for p in particles:p.time-=dt if active else 0
	for i in range(particles.size()-1,-1,-1):
		var p:Dictionary=particles[i]
		if p.time<=0:p.node.queue_free();particles.remove_at(i)
		elif p.kind=="ring":p.node.scale=Vector3.ONE*(1+(1-p.time/p.max)*4)
		elif p.kind=="bolt":p.node.position=p.start.lerp(p.end,1-p.time/p.max)
func emit_effect(effect:Dictionary) -> void:
	if not is_instance_valid(world):return
	var mat:=V.material(effect.color,0,.5,.8);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var node:MeshInstance3D;var time:=.28;var kind:="ring";var start:=Vector3.ZERO;var finish:=Vector3.ZERO
	if effect.type=="shot":
		start=to_world(effect.from,1.3);finish=to_world(effect.pos,.8);kind="bolt"
		node=V.sphere(world,.12,start,mat)
	elif effect.type=="blast":
		node=V.ring(world,.5,.06,to_world(effect.pos,.12),mat);time=.4
	else:
		node=V.ring(world,.4,.08,to_world(effect.pos,.1),mat);time=.8
	particles.append({"node":node,"time":time,"max":time,"kind":kind,"start":start,"end":finish})
