extends SubViewportContainer
const V=preload("res://scripts/visuals.gd")
const R=preload("res://scripts/roster.gd")
const ART=preload("res://assets/commanders.png")
const HEROES=preload("res://assets/chibi-heroes.png")
const RECRUITS=preload("res://assets/chibi-recruits.png")
const COURT=preload("res://assets/chibi-court.png")
const GENERALS=preload("res://assets/chibi-generals.png")
const VANGUARDS=preload("res://assets/chibi-vanguards.png")
const Frames=preload("res://scripts/frames.gd")
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
var hq_bounds:=Rect2()
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
render_mode unshaded;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=world_position.xz;
 float patches=sin(p.x*.24)*sin(p.y*.21)*.5+.5;
 vec3 grass=mix(vec3(.57,.75,.42),vec3(.66,.81,.50),patches*.6);
 // Soft rounded road follows the original rectangular enemy route.
 vec2 q=abs(p)-vec2(17.4,9.95);
 float distance_to_path=abs(length(max(q,vec2(0.)))+min(max(q.x,q.y),0.)-1.5);
 float border=1.-smoothstep(.95,1.05,distance_to_path);
 float road=1.-smoothstep(.76,.84,distance_to_path);
 vec3 color=mix(grass,vec3(.74,.65,.43),border);
 color=mix(color,vec3(.96,.87,.67),road);
 ALBEDO=color;ROUGHNESS=1.;
}
"""
	var m:=ShaderMaterial.new();m.shader=shader;return m
func prop(frame:int, pos:Vector3, height:float, _flip:bool=false) -> void:
	if frame>=4:
		var rock:=V.sphere(world,height*.32,pos+Vector3(0,height*.16,0),V.material(Color("bfd0c4"),0,1));rock.scale=Vector3(1,.65,.85)
		return
	# Rounded orchard trees belong to the same toy-like world as the chibi heroes.
	var trunk:=V.material(Color("bc9069"),0,1)
	var leaves:=V.material([Color("579b61"),Color("3f967a"),Color("d78da6")][frame%3],0,1)
	V.cylinder(world,height*.065,height*.095,height*.55,pos+Vector3(0,height*.27,0),trunk,8)
	for part in [Vector3(-.19,.65,0),Vector3(.19,.70,.04),Vector3(0,.87,-.03)]:
		var canopy:=V.sphere(world,height*.30,pos+part*height,leaves);canopy.scale=Vector3(1,.88,1)
func flowers(pos:Vector3, tint:Color) -> void:
	var stem:=V.material(Color("7ba970"),0,1)
	var bloom:=V.material(tint,0,1)
	for i in range(3):
		var point:=pos+Vector3((i-1)*.22,.12+float(i%2)*.08,0)
		V.cylinder(world,.018,.025,.25,point,stem,5)
		V.sphere(world,.10,point+Vector3(0,.16,0),bloom)
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
		var mat:=V.material(Color("f3e2b8") if bank else Color("83d8df"),.02,.3,.35 if not bank else 0.0)
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED;V.mesh(world,st.commit(),Vector3.ZERO,mat)
func build_terrain() -> void:
	var stone:=V.material(Color("f1dfb7"),0,.9);var dark:=V.material(Color("b8ce9d"),0,.95)
	var roof:=V.material(Color("dd8b76"),0,.85);var wood:=V.material(Color("c49b74"),0,.9)
	V.box(world,Vector3(120,2.8,120),Vector3(0,-1.5,0),dark)
	V.box(world,Vector3(120,.14,120),Vector3(0,-.07,0),grass_material())
	# Pastel orchard border, warm tiled gate and an uncluttered central meadow.
	for side in [-1,1]:
		V.box(world,Vector3(3,.35,35),Vector3(side*24,-.05,0),stone)
		for z in range(-17,18,6):
			if side<0 and abs(z)<4:continue
			prop(0 if z%3 else 1,Vector3(side*(23.7+sin(z)*.8),.5,z),3.6+absf(sin(z))*.55,z%2==0)
	for i in range(11):
		var x:float=-27+i*5.3
		prop(i%3,Vector3(x,.05,-18.5-sin(i)*.8),3.9+sin(i)*.35,i%2==0)
	for side in [-1,1]:
		for x in range(-20,21,5):
			if side>0 and abs(x)<12:continue
			prop(4 if x%2 else 5,Vector3(x,.02,side*14),1.3+absf(x)*.025,x%2==0)
	for i in range(12):
		var side:float=-1.0 if i%2 else 1.0
		flowers(Vector3(-19.8+float(i/2)*7.7,.03,side*13.4),[Color("ffe7a0"),Color("fff5df"),Color("f4b5c5")][i%3])
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
	build_headquarters(stone,wood,roof)
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
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("fff6ea");env.ambient_light_energy=.32
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.fog_enabled=false;env.fog_light_color=Color("bde0fe");env.fog_density=.001
	environment.environment=env;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);sun.light_color=Color("fff8ee");sun.light_energy=.6;sun.shadow_enabled=true;sun.directional_shadow_max_distance=80;world.add_child(sun)
func build_headquarters(stone:Material, wood:Material, roof:Material) -> void:
	var base:=to_world(game.HQ_POINT)
	V.box(world,Vector3(4.2,.35,3.1),base+Vector3(0,.17,0),stone)
	V.box(world,Vector3(3.6,1.75,2.6),base+Vector3(0,1.2,0),V.material(Color("f3dbb5"),0,1))
	for x in [-1.65,1.65]:
		for z in [-1.15,1.15]:V.box(world,Vector3(.17,2.45,.17),base+Vector3(x,1.45,z),wood)
	V.box(world,Vector3(.9,1.65,.08),base+Vector3(0,1.1,1.34),wood)
	for side in [-1,1]:
		var tile:=V.box(world,Vector3(2.35,.22,3.2),base+Vector3(side*.95,2.55,0),roof);tile.rotation.z=side*.26
	V.box(world,Vector3(.22,.25,3.5),base+Vector3(0,2.96,0),roof)
	V.box(world,Vector3(1.4,.38,.1),base+Vector3(0,2.15,1.42),V.material(Color("b0785e"),0,1))
	var sign:=Label3D.new();sign.text="업그레이드 [U]";sign.font=game.FONT;sign.font_size=40;sign.pixel_size=.018;sign.position=base+Vector3(0,4.2,0);sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.outline_size=9;sign.modulate=Color("ffd166");world.add_child(sign)
func headquarters_hit(screen:Vector2) -> bool:
	var base:=to_world(game.HQ_POINT)
	var first:=true;var bounds:=Rect2()
	for x in [-2.3,2.3]:
		for y in [0.0,3.8]:
			for z in [-1.7,1.7]:
				var point:=camera.unproject_position(base+Vector3(x,y,z))+position
				if first:bounds=Rect2(point,Vector2.ZERO);first=false
				else:bounds=bounds.expand(point)
	return bounds.has_point(screen)
func art_for(id:int) -> Array:
	if id>=24:
		var rows:Dictionary={24:0,25:1,26:3,30:1,31:2,32:3,36:0,37:2,38:1}
		return [RECRUITS,rows.get(id,0),4,"chibi-recruits.png"]
	match id:
		0:return [HEROES,0,4,"chibi-heroes.png"]
		1:return [ART,0,4,"commanders.png"]
		2:return [HEROES,1,4,"chibi-heroes.png"]
		3:return [ART,1,4,"commanders.png"]
		4:return [COURT,0,5,"chibi-court.png"]
		5:return [COURT,1,5,"chibi-court.png"]
		6:return [COURT,2,5,"chibi-court.png"]
		7:return [COURT,3,5,"chibi-court.png"]
		8:return [ART,2,4,"commanders.png"]
		9:return [HEROES,2,4,"chibi-heroes.png"]
		10:return [COURT,4,5,"chibi-court.png"]
		11:return [GENERALS,0,5,"chibi-generals.png"]
		15:return [HEROES,3,4,"chibi-heroes.png"]
		16:return [GENERALS,1,5,"chibi-generals.png"]
		17:return [GENERALS,2,5,"chibi-generals.png"]
		18:return [GENERALS,3,5,"chibi-generals.png"]
		19:return [GENERALS,4,5,"chibi-generals.png"]
		20:return [VANGUARDS,0,5,"chibi-vanguards.png"]
		21:return [VANGUARDS,1,5,"chibi-vanguards.png"]
		22:return [VANGUARDS,2,5,"chibi-vanguards.png"]
		23:return [VANGUARDS,3,5,"chibi-vanguards.png"]
		-2:return [VANGUARDS,4,5,"chibi-vanguards.png"]
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
		a.sprite.modulate=[Color("e6ffe8"),Color("e1eeff"),Color("ffe7df")][R.data(u.id).faction] if u.rank==0 else Color.WHITE
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
		pose_actor(a,-2 if e.boss else -1,[0,1,0,2][int(clock*8+e.uid)%4],2.2,a.sprite.flip_h)
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
